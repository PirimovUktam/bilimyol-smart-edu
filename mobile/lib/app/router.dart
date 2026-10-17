import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/forgot_password_screen.dart';
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

  _AuthRefreshNotifier() {
    if (SupabaseConfig.isConfigured) {
      try {
        _sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
          notifyListeners();
        });
      } catch (_) {
        // Supabase not available: guard falls back to demo (always signed-in) mode.
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

const Set<String> _publicRoutes = {
  '/login',
  '/register',
  '/forgot-password',
};

final GoRouter appRouter = GoRouter(
  initialLocation: '/courses',
  refreshListenable: _AuthRefreshNotifier(),
  redirect: (context, state) {
    // When Supabase is not configured the app runs in local demo mode:
    // demo users are treated as authenticated so they can explore the platform.
    if (!SupabaseConfig.isConfigured) return null;

    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
    final path = state.matchedLocation;
    final isPublic = _publicRoutes.contains(path);

    if (!isLoggedIn && !isPublic) {
      return '/login';
    }
    if (isLoggedIn && isPublic) {
      return '/dashboard';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      redirect: (context, state) => '/courses',
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
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
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          Text('Sahifa topilmadi: ${state.uri}'),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => context.go('/courses'),
            child: const Text('Bosh sahifaga qaytish'),
          ),
        ],
      ),
    ),
  ),
);