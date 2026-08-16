import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

final GoRouter appRouter = GoRouter(
  initialLocation: '/courses',
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
