// Supabase Edge Function — yarın olan etkinlikler için hatırlatma bildirimi gönderir.
// Deploy: supabase functions deploy send-event-reminders
// Trigger: Supabase Cron job — her gün 18:00'de çalıştır
// Cron: select cron.schedule('event-reminders', '0 15 * * *', $$select net.http_post(...)$$);

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { FCM_PROJECT_ID, getFcmAccessToken } from "../_shared/fcm.ts";

const FCM_ENDPOINT =
  `https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`;

serve(async (_req) => {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // Yarının tarihini hesapla (UTC)
    const tomorrow = new Date();
    tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
    const dateStr = tomorrow.toISOString().split("T")[0]; // "2026-06-30"

    // Yarın olan etkinlikleri çek
    const eventsRes = await fetch(
      `${supabaseUrl}/rest/v1/events?select=id,title,date&date=gte.${dateStr}T00:00:00&date=lte.${dateStr}T23:59:59`,
      {
        headers: {
          apikey: supabaseKey,
          Authorization: `Bearer ${supabaseKey}`,
        },
      },
    );
    const events: { id: number; title: string; date: string }[] =
      await eventsRes.json();

    if (events.length === 0) {
      return new Response("No events tomorrow", { status: 200 });
    }

    // Tüm FCM token'larını çek
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

    const accessToken = await getFcmAccessToken();

    // Her etkinlik için tüm kullanıcılara bildirim gönder
    for (const event of events) {
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
              notification: {
                title: "📅 Yarın Etkinlik Var!",
                body: event.title,
              },
              data: {
                type: "event",
                id: String(event.id),
              },
            },
          }),
        }),
      );
      await Promise.all(sends);
    }

    return new Response(`Sent reminders for ${events.length} event(s)`, {
      status: 200,
    });
  } catch (err) {
    return new Response(String(err), { status: 500 });
  }
});
