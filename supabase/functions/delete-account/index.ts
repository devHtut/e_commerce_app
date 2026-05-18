import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

type JsonResponse = {
  success: boolean;
  status: 'completed' | 'blocked' | 'failed';
  message: string;
  activeOrderCount?: number;
};

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const activeStatuses = ['pending', 'confirmed', 'in-delivery', 'refund'];

function json(body: JsonResponse, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function cleanEmail(email?: string | null): string {
  return email?.trim().toLowerCase() ?? '';
}

async function ignoreCleanupError(
  label: string,
  operation: PromiseLike<{ error: unknown }>,
) {
  const { error } = await operation;
  if (error) console.warn(`Account deletion cleanup skipped: ${label}`, error);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return json(
      {
        success: false,
        status: 'failed',
        message: 'Unsupported request method.',
      },
      405,
    );
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return json(
      {
        success: false,
        status: 'failed',
        message: 'Account deletion service is not configured.',
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
      {
        success: false,
        status: 'failed',
        message: 'Please sign in again before deleting your account.',
      },
      401,
    );
  }

  const userId = user.id;
  const email = cleanEmail(user.email);
  const deletionTimestamp = new Date().toISOString();

  const { data: userRow } = await admin
    .from('users')
    .select('user_type')
    .eq('id', userId)
    .maybeSingle();
  const userType =
    userRow?.user_type?.toString().trim().toLowerCase() === 'vendor'
      ? 'vendor'
      : 'customer';

  const { data: requestRow } = await admin
    .from('account_deletion_requests')
    .insert({
      user_id: userId,
      email,
      user_type: userType,
      status: 'pending',
      reason: 'Requested from app',
    })
    .select('id')
    .single();

  const requestId = requestRow?.id as string | undefined;

  async function finishRequest(
    status: 'completed' | 'blocked' | 'failed',
    failureReason?: string,
  ) {
    if (!requestId) return;
    await admin
      .from('account_deletion_requests')
      .update({
        status,
        failure_reason: failureReason ?? null,
        processed_at: new Date().toISOString(),
      })
      .eq('id', requestId);
  }

  try {
    const { count: customerActiveOrders } = await admin
      .from('orders')
      .select('id', { count: 'exact', head: true })
      .eq('customer_id', userId)
      .in('status', activeStatuses);

    if ((customerActiveOrders ?? 0) > 0) {
      await finishRequest('blocked', 'Customer has active orders.');
      return json(
        {
          success: false,
          status: 'blocked',
          message:
            'Please complete, cancel, or resolve your active orders before deleting your account.',
          activeOrderCount: customerActiveOrders ?? 0,
        },
        409,
      );
    }

    const { data: brandRows } = await admin
      .from('brands')
      .select('id')
      .eq('owner_id', userId);
    const brandIds = (brandRows ?? [])
      .map((row) => row.id?.toString())
      .filter((id): id is string => Boolean(id));

    if (brandIds.length > 0) {
      const { count: vendorActiveOrders } = await admin
        .from('order_items')
        .select('order_id, orders!inner(id,status)', {
          count: 'exact',
          head: true,
        })
        .in('brand_id', brandIds)
        .in('orders.status', activeStatuses);

      if ((vendorActiveOrders ?? 0) > 0) {
        await finishRequest('blocked', 'Vendor has active orders.');
        return json(
          {
            success: false,
            status: 'blocked',
            message:
              'Please complete, cancel, or refund active brand orders before deleting your account.',
            activeOrderCount: vendorActiveOrders ?? 0,
          },
          409,
        );
      }
    }

    await ignoreCleanupError(
      'cart',
      admin.from('cart').delete().eq('user_id', userId),
    );
    await ignoreCleanupError(
      'wishlist',
      admin.from('wishlist').delete().eq('user_id', userId),
    );
    await ignoreCleanupError(
      'user_addresses',
      admin.from('user_addresses').delete().eq('user_id', userId),
    );
    await ignoreCleanupError(
      'notifications',
      admin.from('notifications').delete().eq('user_id', userId),
    );
    await ignoreCleanupError(
      'reports',
      admin.from('reports').delete().eq('reporter_id', userId),
    );
    await ignoreCleanupError(
      'chat_members',
      admin.from('chat_members').delete().eq('user_id', userId),
    );
    await ignoreCleanupError(
      'profiles',
      admin.from('profiles').delete().eq('id', userId),
    );

    await ignoreCleanupError(
      'messages',
      admin
        .from('messages')
        .update({
          is_deleted: true,
          text: 'This message was removed because the account was deleted.',
          image_path: null,
          edited_at: deletionTimestamp,
        })
        .eq('sender_id', userId),
    );

    await ignoreCleanupError(
      'product_reviews',
      admin
        .from('product_reviews')
        .update({
          review_text: null,
          updated_at: deletionTimestamp,
        })
        .eq('customer_id', userId),
    );

    await ignoreCleanupError(
      'orders shipping address',
      admin
        .from('orders')
        .update({
          shipping_address_id: null,
        })
        .eq('customer_id', userId),
    );

    if (brandIds.length > 0) {
      const { data: vendorRows } = await admin
        .from('vendors')
        .select('id')
        .eq('user_id', userId);
      const vendorIds = (vendorRows ?? [])
        .map((row) => row.id?.toString())
        .filter((id): id is string => Boolean(id));
      const { data: productRows } = await admin
        .from('products')
        .select('id')
        .in('brand_id', brandIds);
      const productIds = (productRows ?? [])
        .map((row) => row.id?.toString())
        .filter((id): id is string => Boolean(id));

      if (productIds.length > 0) {
        await ignoreCleanupError(
          'product variant stock',
          admin
            .from('product_variants')
            .update({ stock_quantity: 0 })
            .in('product_id', productIds),
        );
      }

      if (vendorIds.length > 0) {
        await ignoreCleanupError(
          'vendor payments',
          admin.from('vendor_payments').delete().in('vendor_id', vendorIds),
        );
      }
      await ignoreCleanupError(
        'vendors',
        admin.from('vendors').delete().eq('user_id', userId),
      );
      await ignoreCleanupError(
        'brands',
        admin
          .from('brands')
          .update({
            brand_name: 'Deleted Brand',
            description: 'This brand account has been deleted.',
            logo_url: '',
            owner_id: null,
          })
          .eq('owner_id', userId),
      );
    }

    await ignoreCleanupError(
      'users',
      admin.from('users').delete().eq('id', userId),
    );

    const { error: deleteUserError } = await admin.auth.admin.deleteUser(userId);
    if (deleteUserError) {
      await finishRequest('failed', deleteUserError.message);
      return json(
        {
          success: false,
          status: 'failed',
          message:
            'Your personal app data was removed, but the auth account could not be fully deleted. Please contact Burma Brands Team.',
        },
        500,
      );
    }

    await finishRequest('completed');
    return json({
      success: true,
      status: 'completed',
      message: 'Your account has been deleted successfully.',
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    await finishRequest('failed', message);
    return json(
      {
        success: false,
        status: 'failed',
        message:
          'Unable to delete this account right now. Please contact Burma Brands Team.',
      },
      500,
    );
  }
});
