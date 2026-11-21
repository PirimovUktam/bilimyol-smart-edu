import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

/// Bridges Supabase auth state changes into a [Listenable] so GoRouter can
/// re-evaluate its redirect guard whenever the session appears or disappears.
class _AuthRefreshNotifier extends ChangeNotifier {
  StreamSubscription<AuthState>? _sub;
  String? _recoveryUserId;

  bool get recoveryActive =>
      _recoveryUserId != null &&
      _recoveryUserId == SupabaseConfig.client?.auth.currentUser?.id;

  _AuthRefreshNotifier() {
    _sub = SupabaseConfig.client?.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.passwordRecovery) {
        _recoveryUserId = state.session?.user.id;
      } else if (state.event == AuthChangeEvent.signedOut) {
        _recoveryUserId = null;
      }
      notifyListeners();
    }, onError: (Object _) => notifyListeners());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

const Set<String> _publicRoutes = {
  '/welcome',
  '/login',
  '/register',
  '/forgot-password',
};

bool _resolveHasStartedCourse(BuildContext context) {
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
}) {
  if (recoveryActive) {
    return path == '/reset-password' ? null : '/reset-password';
  }

  if (path == '/welcome' && uri.queryParameters['replay'] == '1') {
    return null;
  }

  final isSessionActive = isRemoteConfigured ? isLoggedIn : isDemoActive;
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

final _authRefresh = _AuthRefreshNotifier();
final GoRouter appRouter = GoRouter(
  initialLocation: '/welcome',
  refreshListenable: Listenable.merge([
    _authRefresh,
    demoSessionActive,
    productTourCompleted,
    activeSessionHasStartedCourse,
  ]),
  redirect: (context, state) {
    return resolveAppRedirect(
      path: state.matchedLocation,
      uri: state.uri,
      recoveryActive: _authRefresh.recoveryActive,
      isRemoteConfigured: SupabaseConfig.hasRemoteConfiguration,
      isLoggedIn: SupabaseConfig.client?.auth.currentUser != null,
      isDemoActive: demoSessionActive.value,
      isTourCompleted: productTourCompleted.value,
      hasStartedAnyCourse: _resolveHasStartedCourse(context),
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
