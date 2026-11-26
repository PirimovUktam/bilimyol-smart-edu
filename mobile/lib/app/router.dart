import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers.dart';
import '../core/auth/demo_session.dart';
import '../core/config/supabase_config.dart';
import '../core/l10n/app_strings.dart';
import '../domain/personalization/learning_start.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/welcome_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/reset_password_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/course_selection/course_selection_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/placement/placement_test_screen.dart';
import '../features/knowledge_map/knowledge_map_screen.dart';
import '../features/roadmap/roadmap_screen.dart';
import '../features/lesson/interactive_lesson_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/ai_tutor/ai_tutor_screen.dart';

const Set<String> _publicRoutes = {
  '/welcome',
  '/login',
  '/register',
  '/forgot-password',
};

@visibleForTesting
bool resolveAppHasStartedCourse(
  BuildContext context, {
  required bool isSessionActive,
  required bool recoveryActive,
}) {
  if (!isSessionActive || recoveryActive) {
    return false;
  }
  try {
    final container = ProviderScope.containerOf(context, listen: false);
    final courses = container.read(courseStateNotifierProvider).courses;
    final profile = container.read(learnerStateNotifierProvider).valueOrNull;
    if (courses.isNotEmpty && profile != null) {
      return courses.any((c) => hasStartedCourse(c, profile));
    }
  } catch (_) {
    // Standalone router tests without ProviderScope fall back to notifier.
  }
  return activeSessionHasStartedCourse.value;
}

@visibleForTesting
String? resolveAppRedirect({
  required String path,
  required Uri uri,
  required bool recoveryActive,
  required bool isRemoteConfigured,
  required bool isLoggedIn,
  required bool isDemoActive,
  required bool isTourCompleted,
  required bool hasStartedAnyCourse,
  bool isHydratingProfile = false,
  bool isDemoAllowed = true,
}) {
  if (recoveryActive) {
    return path == '/reset-password' ? null : '/reset-password';
  }

  if (path == '/welcome' && uri.queryParameters['replay'] == '1') {
    return null;
  }

  if (isHydratingProfile && path == '/login') {
    return null;
  }

  final effectiveDemoActive = isDemoAllowed && isDemoActive;
  final isSessionActive = isRemoteConfigured
      ? (isLoggedIn || effectiveDemoActive)
      : effectiveDemoActive;
  if (isSessionActive) {
    final destination = hasStartedAnyCourse ? '/dashboard' : '/courses';
    if (path == '/' ||
        _publicRoutes.contains(path) ||
        path == '/reset-password' ||
        (uri.scheme == 'uz.bilimyol.mobile' && uri.path == '/reset-password')) {
      return destination;
    }
    return null;
  }

  if (path == '/reset-password' ||
      (uri.scheme == 'uz.bilimyol.mobile' && uri.path == '/reset-password')) {
    return '/login';
  }

  final isPublic = _publicRoutes.contains(path);
  if (!isTourCompleted) {
    if (path == '/' || !isPublic) {
      return '/welcome';
    }
    return null;
  }

  if (path == '/' || path == '/welcome' || !isPublic) {
    return '/login';
  }
  return null;
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/welcome',
  refreshListenable: Listenable.merge([
    SupabaseConfig.authUserIdListenable,
    SupabaseConfig.recoveryActiveListenable,
    SupabaseConfig.authStateRevisionListenable,
    demoSessionActive,
    productTourCompleted,
    activeSessionHasStartedCourse,
    postLoginHydrating,
  ]),
  redirect: (context, state) {
    final recoveryActive = SupabaseConfig.isRecoveryActive;
    final isRemoteConfigured =
        SupabaseConfig.hasRemoteConfiguration || SupabaseConfig.isProductionEnv;
    final isDemoAllowed = SupabaseConfig.isDemoModeAllowed;
    final client = SupabaseConfig.client;
    final isLoggedIn =
        (client != null
            ? client.auth.currentUser?.id
            : SupabaseConfig.authUserIdListenable.value) !=
        null;
    final isDemoActive = isDemoAllowed && demoSessionActive.value;
    final isSessionActive = isRemoteConfigured
        ? (isLoggedIn || isDemoActive)
        : isDemoActive;
    return resolveAppRedirect(
      path: state.matchedLocation,
      uri: state.uri,
      recoveryActive: recoveryActive,
      isRemoteConfigured: isRemoteConfigured,
      isLoggedIn: isLoggedIn,
      isDemoActive: isDemoActive,
      isTourCompleted: productTourCompleted.value,
      hasStartedAnyCourse: resolveAppHasStartedCourse(
        context,
        isSessionActive: isSessionActive,
        recoveryActive: recoveryActive,
      ),
      isHydratingProfile: postLoginHydrating.value,
      isDemoAllowed: isDemoAllowed,
    );
  },
  routes: [
    GoRoute(
      path: '/',
      redirect: (context, state) =>
          productTourCompleted.value ? '/login' : '/welcome',
    ),
    GoRoute(
      path: '/welcome',
      builder: (context, state) => WelcomeScreen(
        isReplay: state.uri.queryParameters['replay'] == '1',
      ),
    ),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) => const ResetPasswordScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/courses',
      builder: (context, state) => const CourseSelectionScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/placement',
      builder: (context, state) => const PlacementTestScreen(),
    ),
    GoRoute(
      path: '/knowledge-map',
      builder: (context, state) => const KnowledgeMapScreen(),
    ),
    GoRoute(
      path: '/roadmap',
      builder: (context, state) => const RoadmapScreen(),
    ),
    GoRoute(
      path: '/lesson',
      builder: (context, state) => const InteractiveLessonScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/progress',
      builder: (context, state) => const ProgressScreen(),
    ),
    GoRoute(
      path: '/ai-tutor',
      builder: (context, state) => const AITutorScreen(),
    ),
  ],
  errorBuilder: (context, state) {
    final s = AppStrings.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Theme.of(context).colorScheme.error,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                s.pageNotFound(state.uri.toString()),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => context.go(
                  activeSessionHasStartedCourse.value ? '/dashboard' : '/courses',
                ),
                child: Text(s.goHomeBtn),
              ),
            ],
          ),
        ),
      ),
    );
  },
);
