import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/learner_profile.dart';
import '../../domain/entities/lesson.dart';
import '../../domain/personalization/learning_start.dart';

final _lessonById = FutureProvider.autoDispose.family<Lesson?, String>(
  (ref, id) => ref.watch(lessonRepositoryProvider).getLessonById(id),
);

class SessionPreview extends ConsumerWidget {
  const SessionPreview({
    super.key,
    required this.course,
    required this.profile,
    required this.sample,
    required this.strings,
  });
  final Course course;
  final LearnerProfile profile;
  final bool sample;
  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(roadmapStateNotifierProvider);
    final path = state.valueOrNull;
    final ru = strings.isRu;
    final locale = ru ? 'ru' : 'uz';
    final first = pendingFoundationLesson(course, profile);
    final rows = <String>[];
    final included = <String>{};
    var minutes = 0;
    var waiting = false;
    VoidCallback? retry;
    bool add(String id, String title, int duration) {
      if (included.contains(id)) return true;
      if (rows.isNotEmpty && minutes + duration > profile.dailyMinutes) {
        return false;
      }
      included.add(id);
      rows.add(title);
      minutes += duration;
      return true;
    }

    if (first != null) {
      for (final id in foundationLessons(
        course,
      ).where((id) => !profile.completedLessonIds.contains(id))) {
        final source = _lessonById(id);
        final result = ref.watch(source);
        final lesson = result.valueOrNull;
        if (result.isLoading) {
          waiting = true;
          break;
        }
        if (lesson == null ||
            lesson.id != id ||
            lesson.courseId != course.id ||
            lesson.estimatedMinutes <= 0) {
          retry = () => ref.invalidate(source);
          break;
        }
        if (!add(id, lesson.localizedTitle(locale), lesson.estimatedMinutes)) {
          break;
        }
        if (minutes >= profile.dailyMinutes) break;
      }
    } else {
      waiting = state.isLoading;
      if (state.hasError) {
        retry = () => ref
            .read(roadmapStateNotifierProvider.notifier)
            .loadRoadmap(course.id);
      }
      for (final node in availablePlanNodes(course.id, profile, path)) {
        if (node.estimatedMinutes <= 0 ||
            !add(
              node.targetLessonId!,
              node.localizedTitle(locale),
              node.estimatedMinutes,
            )) {
          break;
        }
      }
    }
    final heading = sample
        ? (ru ? 'Пример плана для начинающих' : 'Boşlanğiç reja namunasi')
        : (ru ? 'Первое занятие' : 'Birinçi maşğulot');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff343464), Color(0xff181b38)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          for (final title in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.menu_book_rounded,
                    size: 18,
                    color: Color(0xff9fe8db),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          if (rows.isNotEmpty) ...[
            LinearProgressIndicator(
              value: (minutes / profile.dailyMinutes).clamp(0, 1),
              color: const Color(0xff9fe8db),
              backgroundColor: Colors.white24,
            ),
            const SizedBox(height: 8),
            Text(
              strings.minutesOption(minutes),
              style: const TextStyle(color: Colors.white),
            ),
          ],
          if (waiting)
            const LinearProgressIndicator()
          else if (retry != null)
            TextButton(
              onPressed: retry,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: Text(strings.retry),
            )
          else if (rows.isEmpty)
            Text(
              ru ? 'Новых уроков пока нет.' : 'Hozirça yangi dars yöq.',
              style: const TextStyle(color: Colors.white),
            ),
        ],
      ),
    );
  }
}
