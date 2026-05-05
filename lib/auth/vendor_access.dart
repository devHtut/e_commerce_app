import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../home/home_screen.dart';
import 'auth_user_service.dart';
import 'signin_screen.dart';

/// Client-side gate: signed-in user must have `user_type` vendor.
class VendorAccess {
  VendorAccess._();

  /// Returns true if the current user is allowed on vendor UI; otherwise
  /// redirects to sign-in (no session) or [HomeScreen] (non-vendor) and returns false.
  static Future<bool> ensureVendorOrRedirect(BuildContext context) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const SignInScreen()),
          (_) => false,
        );
      }
      return false;
    }
    final ok = await AuthUserService.isVendorAccount(user.id, email: user.email);
    if (!ok && context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    }
    return ok;
  }
}
