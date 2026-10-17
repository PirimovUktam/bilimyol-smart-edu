import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  /// Values are supplied at compile time with `--dart-define` or
  /// `--dart-define-from-file`.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool isConfigured = false;
  /// True when real backend credentials were supplied, even if client
  /// initialization failed. This prevents an online outage from being treated
  /// as demo mode and exposing bundled answer keys or accepting local scores.
  static bool hasRemoteConfiguration = false;

  static Future<void> initialize() async {
    hasRemoteConfiguration = supabaseUrl.isNotEmpty &&
        supabaseAnonKey.isNotEmpty &&
        !supabaseUrl.contains('bilimyol-demo') &&
        !supabaseAnonKey.contains('demo-anon-key');

    if (!hasRemoteConfiguration) {
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
