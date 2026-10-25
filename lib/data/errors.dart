// lib/data/errors.dart
import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns Supabase/Postgres errors into text that can be shown in the UI.
String friendlyError(Object error) {
  if (error is PostgrestException) {
    final message = error.message.trim();
    // Postgres prefixes custom exceptions with "P0001: ". Strip that noise.
    return message.replaceFirst(RegExp(r'^P[0-9A-Z]{4}:\s*'), '');
  }
  if (error is AuthException) {
    return error.message;
  }
  final text = error.toString();
  return text.startsWith('Exception: ') ? text.substring(11) : text;
}
