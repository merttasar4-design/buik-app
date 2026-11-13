// iyzico REST API'sine IYZWSv2 (HMAC-SHA256) imzalı istek atan yardımcı.
//
// Not: iyzico'nun resmi Node SDK'sı (npm:iyzipay) çalışma zamanında dinamik
// `fs.readdirSync` + hesaplanmış `require(...)` çağrılarıyla kaynak dosyalarını
// yüklüyor. Bu, Supabase Edge Functions'ın deploy sırasında kodu tek dosyaya
// paketleyen (bundling) yapısıyla uyumsuz ve deploy/çalışma zamanında
// "Cannot find module" hatasına yol açar. Bu yüzden imzalama algoritması
// SDK kaynağından (lib/utils.js: generateHashV2) birebir alınıp burada
// Deno'nun Web Crypto API'siyle bağımlılıksız olarak yeniden uygulandı.

const BASE_URL = Deno.env.get("IYZICO_BASE_URL") ??
  "https://sandbox-api.iyzipay.com";
const API_KEY = Deno.env.get("IYZICO_API_KEY")!;
const SECRET_KEY = Deno.env.get("IYZICO_SECRET_KEY")!;

async function hmacSha256Hex(secretKey: string, data: string): Promise<string> {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secretKey),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, enc.encode(data));
  return Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/** POST /path gönderir ve iyzico'nun ayrıştırılmış JSON yanıtını döner. */
export async function iyzicoPost(
  path: string,
  body: Record<string, unknown>,
): Promise<Record<string, any>> {
  const randomString = crypto.randomUUID().replace(/-/g, "");
  const bodyString = JSON.stringify(body);
  const signature = await hmacSha256Hex(
    SECRET_KEY,
    randomString + path + bodyString,
  );
  const authorizationParams = [
    `apiKey:${API_KEY}`,
    `randomKey:${randomString}`,
    `signature:${signature}`,
  ].join("&");
  const authHeader = "IYZWSv2 " + btoa(authorizationParams);

  const res = await fetch(`${BASE_URL}${path}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": authHeader,
      "x-iyzi-rnd": randomString,
      "x-iyzi-client-version": "buik-app-edge/1.0",
    },
    body: bodyString,
  });
  return await res.json();
}
