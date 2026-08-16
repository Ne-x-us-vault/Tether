// ══════════════════════════════════════════════════════════════════════════════
// supabase/functions/send-notification/index.ts
// Lovit App — Supabase Edge Function
//
// Sends an FCM push notification to a target user via the Firebase HTTP v1 API.
//
// SEC-01 hardening:
//   - The caller MUST be authenticated; their JWT is verified against the
//     project's anon key (no service-role trust of request payloads).
//   - The sender and recipient MUST share an active pairing before any push
//     is sent or notification row is written.
//   - User ids are validated as UUIDs so they can never inject into the
//     `.or()` filter string.
//   - Simple in-memory per-user rate limit (20 sends / minute).
//
// Secrets required (set via: supabase secrets set KEY=value):
//   FCM_PROJECT_ID   — Firebase project ID   (from service account JSON)
//   FCM_CLIENT_EMAIL — Service account email (from service account JSON)
//   FCM_PRIVATE_KEY  — Service account key   (from service account JSON)
// ══════════════════════════════════════════════════════════════════════════════

// @ts-ignore
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
// @ts-ignore
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Declare Deno namespace to satisfy TypeScript language server in non-Deno IDEs
declare const Deno: {
  env: {
    get(key: string): string | undefined;
  };
};

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
const RATE_LIMIT_MAX = 20
const RATE_LIMIT_WINDOW_MS = 60_000
const rateBuckets = new Map<string, number[]>()

// ── JWT helpers for Firebase OAuth2 ─────────────────────────────────────────

/** Base64url encode */
function b64url(input: string): string {
  return btoa(input).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '')
}

/** Sign a string with an RSA-SHA256 private key (PEM format) */
async function rsaSign(pemKey: string, data: string): Promise<string> {
  const pemBody = pemKey
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\n/g, '')

  const binaryString = atob(pemBody)
  const len = binaryString.length
  const bytes = new Uint8Array(len)
  for (let i = 0; i < len; i++) {
    bytes[i] = binaryString.charCodeAt(i)
  }

  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    bytes.buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )

  const encoder = new TextEncoder()
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    encoder.encode(data),
  )

  const signatureBytes = new Uint8Array(signature)
  let binary = ''
  for (let i = 0; i < signatureBytes.length; i++) {
    binary += String.fromCharCode(signatureBytes[i])
  }

  return b64url(binary)
}

/** Generate a short-lived Google OAuth2 access token using a service account */
async function getFirebaseAccessToken(
  clientEmail: string,
  privateKey: string,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  const payload = b64url(
    JSON.stringify({
      iss: clientEmail,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }),
  )

  const signature = await rsaSign(privateKey, `${header}.${payload}`)
  const jwt = `${header}.${payload}.${signature}`

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })

  const json = await res.json()
  if (!json.access_token) {
    console.error('OAuth token error:', res.status, JSON.stringify(json))
    throw new Error('Failed to obtain Firebase access token')
  }
  return json.access_token
}

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

// ── Main handler ─────────────────────────────────────────────────────────────

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    })
  }

  try {
    // ── 1. Authenticate the caller ───────────────────────────────────────────
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return jsonResponse(401, { error: 'Missing authorization header' })
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!

    // Verify the caller's JWT using the anon key — never trust the payload.
    const callerClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false },
    })
    const {
      data: { user: caller },
      error: authError,
    } = await callerClient.auth.getUser()
    if (authError || !caller) {
      return jsonResponse(401, { error: 'Invalid or expired session' })
    }
    const senderId = caller.id

    // ── 2. Parse + validate the payload ──────────────────────────────────────
    const bodyJson = await req.json()
    const toUserId = String(bodyJson.to_user_id ?? '')
    const type = String(bodyJson.type ?? '')
    const title = String(bodyJson.title ?? '')
    const body = String(bodyJson.body ?? '')
    const data = bodyJson.data as Record<string, string> | undefined

    if (!UUID_RE.test(toUserId)) {
      return jsonResponse(400, { error: 'to_user_id must be a valid UUID' })
    }
    if (!type || !title || !body) {
      return jsonResponse(400, { error: 'Missing required fields' })
    }

    // ── 3. Basic rate limiting (per caller) ──────────────────────────────────
    const now = Date.now()
    const window = (rateBuckets.get(senderId) ?? []).filter(
      (ts) => now - ts < RATE_LIMIT_WINDOW_MS,
    )
    if (window.length >= RATE_LIMIT_MAX) {
      return jsonResponse(429, { error: 'Too many notifications. Try again later.' })
    }
    window.push(now)
    rateBuckets.set(senderId, window)

    // ── 4. Enforce sender ↔ recipient pairing (SEC-01) ───────────────────────
    const admin = createClient(
      supabaseUrl,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    // senderId is a verified UUID from the JWT; toUserId is UUID-validated
    // above, so neither can inject into the .or() filter string.
    const { data: pairing, error: pairingError } = await admin
      .from('pairings')
      .select('id')
      .eq('status', 'active')
      .or(`user1_id.eq.${senderId},user2_id.eq.${senderId}`)
      .or(`user1_id.eq.${toUserId},user2_id.eq.${toUserId}`)
      .maybeSingle()

    if (pairingError || !pairing) {
      console.log(
        `[Push] Rejected: sender ${senderId} and recipient ${toUserId} ` +
          `do not share an active pairing`,
      )
      return jsonResponse(403, { error: 'Not authorized to message this user' })
    }
    const pairingId: string = pairing.id

    // ── 5. Log the notification ──────────────────────────────────────────────
    await admin.from('notifications').insert({
      user_id: toUserId,
      pairing_id: pairingId,
      title,
      body,
      notification_type: type,
      is_read: false,
    })

    // ── 6. Send FCM (skip gracefully if recipient has no token) ─────────────
    // push_token lives in the private push_tokens table (SEC-17): only the
    // owner can write their own row and only the service role can read it.
    const { data: tokenData, error } = await admin
      .from('push_tokens')
      .select('token')
      .eq('user_id', toUserId)
      .maybeSingle()

    const tokenRow = tokenData as { token: string } | null
    if (error || !tokenRow?.token) {
      console.log(`No push token for user ${toUserId} - skipped FCM but logged in DB`)
      return jsonResponse(200, { success: true, logged_db: true, reason: 'no_token' })
    }

    const fcmToken: string = tokenRow.token
    const projectId = Deno.env.get('FCM_PROJECT_ID')!
    const clientEmail = Deno.env.get('FCM_CLIENT_EMAIL')!
    const privateKey = Deno.env.get('FCM_PRIVATE_KEY')!.replace(/\\n/g, '\n')

    const accessToken = await getFirebaseAccessToken(clientEmail, privateKey)

    const message = {
      message: {
        token: fcmToken,
        notification: { title, body },
        android: {
          priority: 'high',
          notification: {
            channel_id: 'lovit_channel',
            color: '#9B6FFF',
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
        data: {
          type,
          ...(data ?? {}),
        },
      },
    }

    const fcmRes = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(message),
      },
    )

    const fcmJson = await fcmRes.json()
    if (!fcmRes.ok) {
      console.error('FCM error:', fcmRes.status, JSON.stringify(fcmJson))
      return jsonResponse(502, { error: 'Push provider unavailable' })
    }

    console.log(`[Push] Sent ${type} to ${toUserId}: ${fcmJson.name}`)
    return jsonResponse(200, { success: true, name: fcmJson.name })
  } catch (err) {
    console.error('Edge function error:', err)
    return jsonResponse(500, { error: 'Internal error' })
  }
})
