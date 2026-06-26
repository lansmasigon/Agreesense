import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Simple state provider to hold the current user's profile data after login
class CurrentUserNotifier extends Notifier<Map<String, dynamic>?> {
  @override
  Map<String, dynamic>? build() => null;

  void setUser(Map<String, dynamic>? user) {
    state = user;
  }
}

final currentUserProvider = NotifierProvider<CurrentUserNotifier, Map<String, dynamic>?>(() {
  return CurrentUserNotifier();
});
