// Supabase Edge Function — mezun aidat/bağış ödemesi başlatır (iyzico Checkout Form).
// Deploy: supabase functions deploy create-payment
// Gerekli secret'lar: IYZICO_API_KEY, IYZICO_SECRET_KEY, IYZICO_BASE_URL
//   (sandbox: https://sandbox-api.iyzipay.com, prod: https://api.iyzipay.com)
// Çağıran: DestekScreen → supabase.functions.invoke('create-payment', ...)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { iyzicoPost } from "../_shared/iyzico.ts";

const CHECKOUT_FORM_INITIALIZE_PATH =
  "/payment/iyzipos/checkoutform/initialize/auth/ecom";

function formatDate(date: Date): string {
  return date.toISOString().slice(0, 19).replace("T", " ");
}

serve(async (req) => {
  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Yetkisiz istek." }), {
        status: 401,
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError || !userData.user) {
      return new Response(JSON.stringify({ error: "Kullanıcı doğrulanamadı." }), {
        status: 401,
      });
    }
    const user = userData.user;

    const { data: profile } = await supabase
      .from("profiles")
      .select("full_name, phone")
      .eq("id", user.id)
      .maybeSingle();

    const body = await req.json();
    const amount = Number(body.amount);
    const type = body.type as "aidat" | "bagis";
    const identityNumber = String(body.identityNumber ?? "").trim();
    const address = String(body.address ?? "Belirtilmedi").trim();
    const city = String(body.city ?? "İstanbul").trim();

    if (!amount || amount <= 0) {
      return new Response(JSON.stringify({ error: "Geçersiz tutar." }), {
        status: 400,
      });
    }
    if (type !== "aidat" && type !== "bagis") {
      return new Response(JSON.stringify({ error: "Geçersiz işlem tipi." }), {
        status: 400,
      });
    }
    if (!/^[0-9]{11}$/.test(identityNumber)) {
      return new Response(
        JSON.stringify({ error: "Geçerli bir TC kimlik numarası girin." }),
        { status: 400 },
      );
    }

    const fullName = (profile?.full_name as string | undefined)?.trim() || "Mezun Üye";
    const [name, ...rest] = fullName.split(" ");
    const surname = rest.length > 0 ? rest.join(" ") : "-";

    const conversationId = crypto.randomUUID();
    const priceStr = amount.toFixed(2);
    const now = formatDate(new Date());
    const ip = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ||
      "85.34.78.112";

    const iyzicoRequest = {
      locale: "tr",
      conversationId,
      price: priceStr,
      paidPrice: priceStr,
      currency: "TRY",
      basketId: conversationId,
      paymentGroup: "PRODUCT",
      callbackUrl: `${Deno.env.get("SUPABASE_URL")}/functions/v1/payment-callback`,
      enabledInstallments: [1],
      buyer: {
        id: user.id,
        name,
        surname,
        gsmNumber: (profile?.phone as string | undefined) || "+905000000000",
        email: user.email ?? "mezun@buik.net",
        identityNumber,
        lastLoginDate: now,
        registrationDate: now,
        registrationAddress: address,
        ip,
        city,
        country: "Turkey",
      },
      shippingAddress: {
        contactName: fullName,
        city,
        country: "Turkey",
        address,
      },
      billingAddress: {
        contactName: fullName,
        city,
        country: "Turkey",
        address,
      },
      basketItems: [
        {
          id: type,
          name: type === "aidat" ? "BUİK Mezun Aidatı" : "BUİK Bağışı",
          category1: "Destek",
          itemType: "VIRTUAL",
          price: priceStr,
        },
      ],
    };

    const iyzicoResult = await iyzicoPost(
      CHECKOUT_FORM_INITIALIZE_PATH,
      iyzicoRequest,
    );

    if (iyzicoResult.status !== "success") {
      return new Response(
        JSON.stringify({
          error: iyzicoResult.errorMessage ?? "Ödeme başlatılamadı.",
        }),
        { status: 400 },
      );
    }

    const { error: insertError } = await supabase.from("donations").insert({
      user_id: user.id,
      type,
      amount,
      status: "pending",
      conversation_id: conversationId,
      iyzico_token: iyzicoResult.token as string,
      description: type === "aidat" ? "Mezun aidatı" : "Bağış",
    });

    if (insertError) {
      return new Response(JSON.stringify({ error: insertError.message }), {
        status: 500,
      });
    }

    return new Response(
      JSON.stringify({ paymentPageUrl: iyzicoResult.paymentPageUrl }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: `Beklenmeyen hata: ${e}` }), {
      status: 500,
    });
  }
});
