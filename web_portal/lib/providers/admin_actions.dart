import 'package:flutter/material.dart';

enum ValidationAction {
  verify,
  approve,
  requestCorrection,
  reject,
}

class AdminActionsProvider extends ChangeNotifier {
  // Dummy method to advance status
  Future<void> processDeclaration(String declarationId, ValidationAction action, {String? remarks}) async {
    // In a real app, this would call Supabase or an API
    // e.g. await supabase.rpc('process_declaration', params: {...})
    await Future.delayed(const Duration(seconds: 1));
    notifyListeners();
  }
}
