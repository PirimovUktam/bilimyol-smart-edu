import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  /// Reads configuration dynamically via `--dart-define=SUPABASE_URL=...`
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// Reads anon key dynamically via `--dart-define=SUPABASE_ANON_KEY=...`
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool isConfigured = false;

  static Future<void> initialize() async {
    // Only attempt Supabase initialization when valid production/staging credentials are provided
    if (supabaseUrl.isEmpty ||
        supabaseAnonKey.isEmpty ||
        supabaseUrl.contains('bilimyol-demo') ||
        supabaseAnonKey.contains('demo-anon-key')) {
      isConfigured = false;
      return;
    }

    try {
      await Supabase.initialize(
        url: supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: supabaseAnonKey,
      );
      isConfigured = true;
    } catch (_) {
      isConfigured = false;
    }
  }

  static SupabaseClient? get client {
    if (!isConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}
