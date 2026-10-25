class SupabaseConfig {
  // Prefer --dart-define so keys do not live in source control:
  // flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://rdhoxwhrkzyvcpscynsj.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_bUi1fEIJDUJuNT7Qb9whVg_0zlA1Xhm',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseAnonKey.contains('PASTE_YOUR_ANON_OR_PUBLISHABLE_KEY_HERE');
}

