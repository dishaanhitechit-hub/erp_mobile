import 'package:flutter/material.dart';
import '../../services/api_service.dart';

/// Logs out and returns to the login screen when the token is rejected.
Future<void> handleSessionExpired(BuildContext context) async {
  await ApiService.instance.logout();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Session expired. Please log in again.')),
  );
  Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/login', (_) => false);
}
