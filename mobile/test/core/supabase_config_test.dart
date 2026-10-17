import 'package:flutter_test/flutter_test.dart';
import 'package:bilimyol_mobile/core/config/supabase_config.dart';

void main() {
  test('clean checkout without compile-time defines stays in explicit demo mode', () async {
    // This test is compiled without SUPABASE_URL/SUPABASE_ANON_KEY. It guards
    // the no-secret path used by a fresh checkout and offline/demo launch.
    SupabaseConfig.isConfigured = false;
    SupabaseConfig.hasRemoteConfiguration = false;

    await SupabaseConfig.initialize();

    expect(SupabaseConfig.hasRemoteConfiguration, isFalse);
    expect(SupabaseConfig.isConfigured, isFalse);
    expect(SupabaseConfig.client, isNull);
  });
}
