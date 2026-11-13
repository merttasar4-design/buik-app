// Supabase Edge Function — iyzico Checkout Form ödeme sonrası bu URL'e
// (callbackUrl) kullanıcının tarayıcısını/WebView'ini form-post ile yönlendirir.
// Sonucu iyzico'dan doğrular, donations kaydını günceller ve uygulamayı
// buik://payment-result deep link'ine yönlendiren bir HTML sayfası döner.
// Deploy: supabase functions deploy payment-callback --no-verify-jwt

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { iyzicoPost } from "../_shared/iyzico.ts";

const CHECKOUT_FORM_RETRIEVE_PATH =
  "/payment/iyzipos/checkoutform/auth/ecom/detail";

const supabaseAdmin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

function redirectHtml(status: "success" | "failed"): Response {
  return new Response(
    `<!doctype html><html><body>
      <script>window.location.href = "buik://payment-result?status=${status}";</script>
      <p>Ödeme sonucu alındı, BUİK uygulamasına dönebilirsiniz.</p>
    </body></html>`,
    { status: 200, headers: { "Content-Type": "text/html" } },
  );
}

serve(async (req) => {
  try {
    const form = await req.formData();
    const token = form.get("token")?.toString();
    if (!token) return redirectHtml("failed");

    const { data: donation } = await supabaseAdmin
      .from("donations")
      .select("conversation_id")
      .eq("iyzico_token", token)
      .maybeSingle();

    const iyzicoResult = await iyzicoPost(CHECKOUT_FORM_RETRIEVE_PATH, {
      locale: "tr",
      conversationId: donation?.conversation_id,
      token,
    });

    const success = iyzicoResult.status === "success" &&
      iyzicoResult.paymentStatus === "SUCCESS";

    await supabaseAdmin
      .from("donations")
      .update({
        status: success ? "success" : "failed",
        iyzico_payment_id: (iyzicoResult.paymentId as string) ?? null,
        updated_at: new Date().toISOString(),
      })
      .eq("iyzico_token", token);

    return redirectHtml(success ? "success" : "failed");
  } catch (_e) {
    return redirectHtml("failed");
  }
});
