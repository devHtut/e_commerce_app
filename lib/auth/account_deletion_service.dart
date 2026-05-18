import 'package:supabase_flutter/supabase_flutter.dart';

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.message, {this.isBlocked = false});

  final String message;
  final bool isBlocked;

  @override
  String toString() => message;
}

class AccountDeletionService {
  AccountDeletionService._();

  static final AccountDeletionService instance = AccountDeletionService._();

  Future<String> deleteAccount() async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'delete-account',
      );
      final data = response.data;
      if (data is Map) {
        final success = data['success'] == true;
        final message =
            data['message']?.toString() ?? 'Account deletion completed.';
        if (success) return message;
        throw AccountDeletionException(
          message,
          isBlocked: data['status']?.toString() == 'blocked',
        );
      }
      return 'Account deletion completed.';
    } on AuthException catch (error) {
      throw AccountDeletionException(error.message);
    } catch (error) {
      throw AccountDeletionException(error.toString());
    }
  }
}
