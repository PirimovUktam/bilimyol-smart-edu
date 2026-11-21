import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

class BilimYolApp extends StatelessWidget {
  const BilimYolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'BilimYo‘l Smart Edu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}
