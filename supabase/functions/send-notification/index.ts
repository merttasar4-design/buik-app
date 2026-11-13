// Supabase Edge Function — yeni duyuru veya etkinlik gelince FCM ile bildirim gönderir.
// Deploy: supabase functions deploy send-notification
// Trigger: Database Webhook → announcements INSERT veya events INSERT

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { FCM_PROJECT_ID, getFcmAccessToken } from "../_shared/fcm.ts";

const FCM_ENDPOINT =
  `https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`;

serve(async (req) => {
  try {
    const payload = await req.json();
    const record = payload.record;

    // Başlık ve içeriği belirle
    const isAnnouncement = payload.table === "announcements";
    const title = isAnnouncement
      ? "📢 Yeni Duyuru"
      : "📅 Yaklaşan Etkinlik";
    const body = isAnnouncement
      ? record.body
      : record.title;

    // Supabase'den tüm FCM token'larını çek
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const profilesRes = await fetch(
      `${supabaseUrl}/rest/v1/profiles?select=fcm_token&fcm_token=not.is.null`,
      {
        headers: {
          apikey: supabaseKey,
          Authorization: `Bearer ${supabaseKey}`,
        },
      },
    );
    const profiles: { fcm_token: string }[] = await profilesRes.json();
    const tokens = profiles
      .map((p) => p.fcm_token)
      .filter((t) => t && t.length > 0);

    if (tokens.length === 0) {
      return new Response("No tokens", { status: 200 });
    }

    // FCM HTTP v1 — her token için ayrı gönder (multicast için Admin SDK gerekir)
    const accessToken = await getFcmAccessToken();
    const sends = tokens.map((token) =>
      fetch(FCM_ENDPOINT, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title, body },
            data: {
              type: isAnnouncement ? "announcement" : "event",
              id: String(record.id),
            },
          },
        }),
      }),
    );

    await Promise.all(sends);
    return new Response("OK", { status: 200 });
  } catch (err) {
    return new Response(String(err), { status: 500 });
  }
});
