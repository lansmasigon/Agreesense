import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Simple state provider to hold the current user's profile data after login
class CurrentUserNotifier extends Notifier<Map<String, dynamic>?> {
  @override
  Map<String, dynamic>? build() => null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('current_user');
    if (userStr != null) {
      state = jsonDecode(userStr);
    }
  }

  Future<void> setUser(Map<String, dynamic>? user) async {
    state = user;
    final prefs = await SharedPreferences.getInstance();
    if (user != null) {
      await prefs.setString('current_user', jsonEncode(user));
    } else {
      await prefs.remove('current_user');
    }
  }
}

final currentUserProvider = NotifierProvider<CurrentUserNotifier, Map<String, dynamic>?>(() {
  return CurrentUserNotifier();
});
