import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app/app.dart';
import 'app/providers.dart';
import 'core/auth/demo_session.dart';
import 'core/config/supabase_config.dart';
import 'core/storage/local_storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  final storage = await LocalStorageService.load();
  await SupabaseConfig.initialize(storage: storage);
  if (SupabaseConfig.isConfigured) {
    unawaited(SupabaseConfig.verifyActiveSessionOrSignOut());
  }

  productTourCompleted.value = storage.getProductTourCompletedSync();
  if (!SupabaseConfig.isProductionEnv) {
    if (!SupabaseConfig.hasRemoteConfiguration) {
      demoSessionActive.value = storage.getDemoSessionActiveSync();
      activeSessionHasStartedCourse.value = demoSessionActive.value
          ? hasStartedCourseInDemoSnapshot(
              storage.getStringSync(LocalStorageService.demoLearnerSnapshotKey),
            )
          : false;
    } else {
      demoSessionActive.value = false;
      activeSessionHasStartedCourse.value = false;
    }
    demoSessionActive.addListener(() {
      if (SupabaseConfig.isProductionEnv) {
        if (demoSessionActive.value) {
          demoSessionActive.value = false;
        }
        activeSessionHasStartedCourse.value = false;
        return;
      }
      storage.setDemoSessionActive(demoSessionActive.value);
      if (demoSessionActive.value) {
        if (!activeSessionHasStartedCourse.value) {
          activeSessionHasStartedCourse.value = hasStartedCourseInDemoSnapshot(
            storage.getStringSync(LocalStorageService.demoLearnerSnapshotKey),
          );
        }
      } else {
        activeSessionHasStartedCourse.value = false;
      }
    });
  } else {
    demoSessionActive.value = false;
    activeSessionHasStartedCourse.value = false;
  }

  final initialSettings = AppSettingsState(
    localeCode: storage.getLocaleCodeSync(),
    themeMode: storage.getThemeModeSync(),
    productTourCompleted: productTourCompleted.value,
  );

  runApp(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        initialAppSettingsProvider.overrideWithValue(initialSettings),
      ],
      child: const BilimYolApp(),
    ),
  );
}
