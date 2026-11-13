// FCM HTTP v1 için Google OAuth2 access token üretir.
//
// Önceki tasarım `FCM_ACCESS_TOKEN` adında sabit bir secret bekliyordu — ama
// Google OAuth2 access token'ları ~1 saatte bir dolar, yani bu yaklaşım
// saatte bir elle yenilenmesi gereken, prodüksiyonda kullanılamaz bir
// tasarımdı. Bunun yerine Firebase servis hesabının private key'iyle kendi
// JWT'imizi imzalayıp (RS256) Google'ın token endpoint'inden anlık access
// token alıyoruz — Admin SDK olmadan, sadece Web Crypto ile.
//
// Gerekli secret: FIREBASE_SERVICE_ACCOUNT_JSON — Firebase Console →
// Project Settings → Service Accounts → "Generate new private key" ile
// inilen JSON dosyasının TAMAMI (tek satır/stringify edilmiş).

export const FCM_PROJECT_ID = "buik-appandro";

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const TOKEN_URL = "https://oauth2.googleapis.com/token";

let cachedToken: { token: string; expiresAt: number } | null = null;

function base64url(bytes: Uint8Array): string {
  let str = "";
  for (const b of bytes) str += String.fromCharCode(b);
  return btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64urlFromString(input: string): string {
  return base64url(new TextEncoder().encode(input));
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const pkcs8 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const binaryDer = Uint8Array.from(atob(pkcs8), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    "pkcs8",
    binaryDer.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

export async function getFcmAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt > now + 60) {
    return cachedToken.token;
  }

  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!raw) {
    throw new Error(
      "FIREBASE_SERVICE_ACCOUNT_JSON secret'ı ayarlanmamış — Firebase Console > Project Settings > Service Accounts'tan indirilip Supabase secret olarak eklenmeli.",
    );
  }
  const serviceAccount = JSON.parse(raw);

  const header = { alg: "RS256", typ: "JWT" };
  const claim = {
    iss: serviceAccount.client_email,
    scope: FCM_SCOPE,
    aud: TOKEN_URL,
    iat: now,
    exp: now + 3600,
  };
  const unsigned =
    `${base64urlFromString(JSON.stringify(header))}.${base64urlFromString(JSON.stringify(claim))}`;

  const key = await importPrivateKey(serviceAccount.private_key);
  const signature = await crypto.subtle.sign(
    { name: "RSASSA-PKCS1-v1_5" },
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${base64url(new Uint8Array(signature))}`;

  const res = await fetch(TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body:
      `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  if (!res.ok) {
    throw new Error(`FCM OAuth2 token alınamadı: ${res.status} ${await res.text()}`);
  }
  const data = await res.json();
  cachedToken = { token: data.access_token, expiresAt: now + data.expires_in };
  return data.access_token;
}
