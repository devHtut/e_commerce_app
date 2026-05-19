import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

type JsonResponse = {
  success: boolean;
  message: string;
  sentCount?: number;
  failedCount?: number;
  errors?: string[];
};

type PushTokenRow = {
  token: string;
  platform: string;
};

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

function json(body: JsonResponse, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function base64UrlEncode(input: string | ArrayBuffer): string {
  const bytes =
    typeof input === 'string'
      ? new TextEncoder().encode(input)
      : new Uint8Array(input);
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '');
}

function privateKeyToArrayBuffer(privateKey: string): ArrayBuffer {
  const cleanKey = privateKey
    .replaceAll('\\n', '\n')
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replaceAll(/\s/g, '');
  const binary = atob(cleanKey);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

async function createFirebaseJwt(
  clientEmail: string,
  privateKey: string,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = {
    alg: 'RS256',
    typ: 'JWT',
  };
  const payload = {
    iss: clientEmail,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };

  const unsignedJwt = `${base64UrlEncode(JSON.stringify(header))}.${
    base64UrlEncode(JSON.stringify(payload))
  }`;
  const key = await crypto.subtle.importKey(
    'pkcs8',
    privateKeyToArrayBuffer(privateKey),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsignedJwt),
  );

  return `${unsignedJwt}.${base64UrlEncode(signature)}`;
}

async function getFirebaseAccessToken(
  clientEmail: string,
  privateKey: string,
): Promise<string> {
  const assertion = await createFirebaseJwt(clientEmail, privateKey);
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  const body = await response.json();

  if (!response.ok || !body.access_token) {
    throw new Error(body.error_description ?? 'Unable to get Firebase token.');
  }

  return body.access_token as string;
}

async function sendPushToToken(
  projectId: string,
  accessToken: string,
  token: string,
) {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: {
            title: 'Burma Brands test',
            body: 'Push notifications are connected.',
          },
          data: {
            type: 'test_push',
            source: 'send-test-push',
          },
          android: {
            priority: 'HIGH',
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
              },
            },
          },
        },
      }),
    },
  );
  const body = await response.json();

  if (!response.ok) {
    throw new Error(body.error?.message ?? 'FCM send failed.');
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return json(
      { success: false, message: 'Unsupported request method.' },
      405,
    );
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const firebaseProjectId = Deno.env.get('FIREBASE_PROJECT_ID');
  const firebaseClientEmail = Deno.env.get('FIREBASE_CLIENT_EMAIL');
  const firebasePrivateKey = Deno.env.get('FIREBASE_PRIVATE_KEY');

  if (
    !supabaseUrl ||
    !anonKey ||
    !serviceRoleKey ||
    !firebaseProjectId ||
    !firebaseClientEmail ||
    !firebasePrivateKey
  ) {
    return json(
      {
        success: false,
        message: 'Push notification service is not configured.',
      },
      500,
    );
  }

  const authHeader = req.headers.get('Authorization') ?? '';
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const admin = createClient(supabaseUrl, serviceRoleKey);

  const {
    data: { user },
    error: userError,
  } = await userClient.auth.getUser();

  if (userError || !user) {
    return json(
      { success: false, message: 'Please sign in before sending a test push.' },
      401,
    );
  }

  const { data: tokenRows, error: tokenError } = await admin
    .from('user_push_tokens')
    .select('token, platform')
    .eq('user_id', user.id)
    .eq('is_active', true)
    .returns<PushTokenRow[]>();

  if (tokenError) {
    return json(
      { success: false, message: 'Unable to load push tokens.' },
      500,
    );
  }

  const tokens = (tokenRows ?? [])
    .map((row) => row.token?.trim())
    .filter((token): token is string => Boolean(token));

  if (tokens.length === 0) {
    return json(
      { success: false, message: 'No active push token found for this user.' },
      404,
    );
  }

  try {
    const accessToken = await getFirebaseAccessToken(
      firebaseClientEmail,
      firebasePrivateKey,
    );
    const sendJobs = tokens.map((token) =>
      sendPushToToken(firebaseProjectId, accessToken, token)
    );
    const results = await Promise.allSettled(sendJobs);
    const errors = results
      .filter((result): result is PromiseRejectedResult =>
        result.status === 'rejected'
      )
      .map((result) =>
        result.reason instanceof Error
          ? result.reason.message
          : String(result.reason)
      );
    const sentCount = results.length - errors.length;

    return json(
      {
        success: sentCount > 0,
        message: sentCount > 0
          ? 'Test push sent.'
          : 'Unable to send test push.',
        sentCount,
        failedCount: errors.length,
        errors: errors.length > 0 ? errors : undefined,
      },
      sentCount > 0 ? 200 : 502,
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return json(
      {
        success: false,
        message,
      },
      500,
    );
  }
});
