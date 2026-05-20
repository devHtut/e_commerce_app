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
};

type RecipientPush = {
  token: string;
  copy: StatusCopy;
};

type StatusCopy = {
  title: string;
  body: string;
  type: string;
};

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const supportedStatuses = new Set([
  'confirmed',
  'in-delivery',
  'completed',
  'canceled',
  'refund',
]);

function json(body: JsonResponse, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function normalizeStatus(status: string): string {
  const value = status.trim().toLowerCase();
  if (
    value === 'indelivery' ||
    value === 'in_delivery' ||
    value === 'in delivery'
  ) {
    return 'in-delivery';
  }
  if (value === 'cancel' || value === 'cancelled') return 'canceled';
  if (value === 'refunded') return 'refund';
  return value;
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
  const unsignedJwt = `${base64UrlEncode(
    JSON.stringify({ alg: 'RS256', typ: 'JWT' }),
  )}.${base64UrlEncode(
    JSON.stringify({
      iss: clientEmail,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }),
  )}`;
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
  copy: StatusCopy,
  orderId: string,
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
            title: copy.title,
            body: copy.body,
          },
          data: {
            type: copy.type,
            order_id: orderId,
          },
          android: {
            priority: 'HIGH',
          },
          apns: {
            payload: {
              aps: { sound: 'default' },
            },
          },
        },
      }),
    },
  );
  const responseBody = await response.json();

  if (!response.ok) {
    throw new Error(responseBody.error?.message ?? 'FCM send failed.');
  }
}

function buildItemSummary(itemNames: string[], itemCount: number): string {
  const countLabel = itemCount <= 1 ? '1 item' : `${itemCount} items`;
  if (itemNames.length === 0) return countLabel;

  const extra = itemNames.length - 1;
  return extra > 0
    ? `${itemNames[0]} + ${extra} more (${countLabel})`
    : `${itemNames[0]} (${countLabel})`;
}

function statusCopy(
  status: string,
  readableId: string,
  itemSummary: string,
): StatusCopy | null {
  const orderLabel = `#${readableId}`;
  switch (status) {
    case 'confirmed':
      return {
        title: 'Order confirmed',
        body: `Good news. The vendor confirmed order ${orderLabel} for ${itemSummary}.`,
        type: 'order_confirmed',
      };
    case 'in-delivery':
      return {
        title: 'Order is on the way',
        body: `Order ${orderLabel} is now in delivery. Keep an eye out for ${itemSummary}.`,
        type: 'order_in_delivery',
      };
    case 'completed':
      return {
        title: 'Order completed',
        body: `Order ${orderLabel} is marked completed. Thanks for shopping with us.`,
        type: 'order_completed',
      };
    case 'canceled':
      return {
        title: 'Order canceled',
        body: `Order ${orderLabel} was canceled. Reserved stock has been restored and refund handling can continue if needed.`,
        type: 'order_canceled',
      };
    case 'refund':
      return {
        title: 'Refund completed',
        body: `Refund for order ${orderLabel} has been marked completed.`,
        type: 'order_refund',
      };
    default:
      return null;
  }
}

function vendorStatusCopy(
  status: string,
  readableId: string,
): StatusCopy | null {
  const orderLabel = `#${readableId}`;
  switch (status) {
    case 'completed':
      return {
        title: 'Order completed',
        body: `Order ${orderLabel} has been marked arrived and completed.`,
        type: 'order_completed',
      };
    case 'canceled':
      return {
        title: 'Order canceled',
        body: `Order ${orderLabel} was canceled. Stock has been restored.`,
        type: 'order_canceled',
      };
    case 'refund':
      return {
        title: 'Refund completed',
        body: `Refund for order ${orderLabel} has been marked completed.`,
        type: 'order_refund',
      };
    default:
      return null;
  }
}

function uniqueNonEmptyTokens(rows: PushTokenRow[] | null): string[] {
  const tokens = new Set<string>();
  for (const row of rows ?? []) {
    const token = row.token?.trim();
    if (token) tokens.add(token);
  }
  return [...tokens];
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

  let requestBody: { orderId?: string; status?: string };
  try {
    requestBody = await req.json();
  } catch (_) {
    requestBody = {};
  }

  const orderId = requestBody.orderId?.trim();
  const status = normalizeStatus(requestBody.status ?? '');
  if (!orderId) {
    return json({ success: false, message: 'orderId is required.' }, 400);
  }
  if (!supportedStatuses.has(status)) {
    return json({ success: false, message: 'Unsupported order status.' }, 400);
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
      { success: false, message: 'Please sign in before sending order push.' },
      401,
    );
  }

  const { data: order, error: orderError } = await admin
    .from('orders')
    .select(
      'id,readable_id,customer_id,total_price,order_items(quantity,brand_id,product_variants(products(title)))',
    )
    .eq('id', orderId)
    .maybeSingle();

  if (orderError || !order) {
    return json({ success: false, message: 'Order not found.' }, 404);
  }

  const orderItems = Array.isArray(order.order_items)
    ? order.order_items as Record<string, unknown>[]
    : [];
  const itemNames: string[] = [];
  const brandIds = new Set<string>();
  let itemCount = 0;

  for (const item of orderItems) {
    itemCount += Number(item.quantity ?? 0);
    const brandId = item.brand_id?.toString();
    if (brandId) brandIds.add(brandId);

    const variant = item.product_variants as Record<string, unknown> | null;
    const product = variant?.products as Record<string, unknown> | null;
    const title = product?.title?.toString().trim();
    if (title) itemNames.push(title);
  }

  const { data: brandRows, error: brandError } = brandIds.size > 0
    ? await admin.from('brands').select('owner_id').in('id', [...brandIds])
    : { data: [], error: null };

  if (brandError) {
    return json({ success: false, message: 'Unable to load vendors.' }, 500);
  }

  const vendorIds = new Set(
    (brandRows ?? [])
      .map((row) => row.owner_id?.toString())
      .filter((id): id is string => Boolean(id)),
  );
  const isCustomer = order.customer_id === user.id;
  const isVendor = vendorIds.has(user.id);

  if (!isCustomer && !isVendor) {
    return json(
      { success: false, message: 'You cannot send updates for this order.' },
      403,
    );
  }

  const { data: customerTokenRows, error: customerTokenError } = await admin
    .from('user_push_tokens')
    .select('token')
    .eq('user_id', order.customer_id)
    .eq('is_active', true)
    .returns<PushTokenRow[]>();

  if (customerTokenError) {
    return json(
      { success: false, message: 'Unable to load customer push tokens.' },
      500,
    );
  }

  const customerTokens = uniqueNonEmptyTokens(customerTokenRows ?? []);

  const readableId = order.readable_id?.toString() || orderId;
  const copy = statusCopy(
    status,
    readableId,
    buildItemSummary(itemNames, itemCount),
  );
  if (!copy) {
    return json({ success: false, message: 'Unsupported order status.' }, 400);
  }
  const pushes: RecipientPush[] = [];
  const queuedTokens = new Set<string>();
  const addPush = (token: string, pushCopy: StatusCopy) => {
    if (queuedTokens.has(token)) return;
    queuedTokens.add(token);
    pushes.push({ token, copy: pushCopy });
  };

  for (const token of customerTokens) addPush(token, copy);
  const vendorCopy = vendorStatusCopy(status, readableId);

  if (vendorCopy && vendorIds.size > 0) {
    const { data: vendorTokenRows, error: vendorTokenError } = await admin
      .from('user_push_tokens')
      .select('token')
      .in('user_id', [...vendorIds])
      .eq('is_active', true)
      .returns<PushTokenRow[]>();

    if (vendorTokenError) {
      return json(
        { success: false, message: 'Unable to load vendor push tokens.' },
        500,
      );
    }

    for (const token of uniqueNonEmptyTokens(vendorTokenRows ?? [])) {
      addPush(token, vendorCopy);
    }
  }

  if (pushes.length === 0) {
    return json(
      { success: false, message: 'No active push tokens found.' },
      404,
    );
  }

  try {
    const accessToken = await getFirebaseAccessToken(
      firebaseClientEmail,
      firebasePrivateKey,
    );
    const sendJobs = pushes.map((push) =>
      sendPushToToken(
        firebaseProjectId,
        accessToken,
        push.token,
        push.copy,
        orderId,
      )
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
          ? 'Order status push sent.'
          : 'Unable to send order status push.',
        sentCount,
        failedCount: errors.length,
        errors: errors.length > 0 ? errors : undefined,
      },
      sentCount > 0 ? 200 : 502,
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return json({ success: false, message }, 500);
  }
});
