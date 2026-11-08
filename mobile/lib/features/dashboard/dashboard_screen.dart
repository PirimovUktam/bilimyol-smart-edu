import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/providers.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/bilimyol_bottom_nav.dart';
import '../../core/widgets/demo_control_bar.dart';
import '../../core/widgets/edtech_reveal.dart';
import '../../core/widgets/friendly_error_state.dart';
import '../../core/widgets/subject_icon.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/learning_path_node.dart';
import '../../domain/personalization/learning_start.dart';
import '../../domain/personalization/skill_scoring_engine.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _courseTabIndex = 0; // 0: Aktiv, 1: Tavsiya etilgan, 2: Barchasi
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(courseStateNotifierProvider);
    final learner = ref.watch(learnerStateNotifierProvider);
    final activeCourse = state.activeCourse;
    final path = activeCourse == null
        ? null
        : ref.watch(roadmapStateNotifierProvider);
    final currentPath = path?.valueOrNull;
    final nodes =
        currentPath != null && currentPath.courseId == activeCourse?.id
        ? currentPath.nodes.where((node) => !node.isReinforcement).toList()
        : <LearningPathNode>[];
    final next = nodes
        .where(
          (node) =>
              node.status == NodeStatus.available ||
              node.status == NodeStatus.inProgress ||
              node.status == NodeStatus.reinforcement,
        )
        .firstOrNull;
    final continuationId = next?.targetLessonId;
    final completed = nodes
        .where((node) => node.status == NodeStatus.completed)
        .length;
    final starting = ref.watch(
      lessonSessionNotifierProvider.select((state) => state.isLoading),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF090C22),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0E29),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'BilimYo‘l Smart Edu',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
            tooltip: 'Fanni almashtirish',
            onPressed: () => context.go('/courses'),
          ),
        ],
      ),
      bottomNavigationBar: const BilimYolBottomNav(currentIndex: 0),
      body: SafeArea(
        child: learner.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => FriendlyErrorState(
            message: 'Profil ma’lumotlarini yuklab bo‘lmadi.',
            onRetry: () =>
                ref.read(learnerStateNotifierProvider.notifier).loadProfile(),
          ),
          data: (profile) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.error != null) {
              return FriendlyErrorState(
                message: state.error!,
                onRetry: () =>
                    ref.read(courseStateNotifierProvider.notifier).init(),
              );
            }
            if (activeCourse == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Davom etish uchun mavjud fanlardan birini tanlang.',
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        text: 'Fan tanlash',
                        onPressed: () => context.go('/courses'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final needsPlan = !hasStartedCourse(activeCourse, profile);
            final starter = pendingFoundationLesson(activeCourse, profile);
            final lessonId = starter ?? continuationId;
            final greetingName = profile.name.isEmpty
                ? 'O‘quvchi'
                : profile.name;

            final totalLessons = activeCourse.lessons.isNotEmpty
                ? activeCourse.lessons.length
                : (nodes.isNotEmpty ? nodes.length : 5);
            final completedInCourse = activeCourse.lessons
                .where((id) => profile.completedLessonIds.contains(id))
                .length;
            final doneCount = completedInCourse > 0
                ? completedInCourse
                : completed;
            final progressPct = totalLessons > 0
                ? ((100 * doneCount) / totalLessons).round().clamp(0, 100)
                : 0;

            final courseScores = profile.scoresByCourse[activeCourse.id] ?? {};
            final overallScore = courseScores.isNotEmpty
                ? SkillScoringEngine.computeOverallScore(courseScores)
                : progressPct;

            final allCourses = state.courses;
            final filteredCourses = allCourses.where((c) {
              if (_searchQuery.trim().isNotEmpty) {
                return c.title.toLowerCase().contains(
                      _searchQuery.trim().toLowerCase(),
                    ) ||
                    c.description.toLowerCase().contains(
                      _searchQuery.trim().toLowerCase(),
                    );
              }
              return true;
            }).toList();

            Future<void> triggerContinueLesson() async {
              if (needsPlan) {
                context.go('/courses');
                return;
              }
              if (lessonId == null) {
                context.push('/roadmap');
                return;
              }
              await ref
                  .read(lessonSessionNotifierProvider.notifier)
                  .startLesson(lessonId);
              if (!context.mounted ||
                  ref.read(courseStateNotifierProvider).activeCourse?.id !=
                      activeCourse.id) {
                return;
              }
              if (ref.read(lessonSessionNotifierProvider).lesson?.id ==
                  lessonId) {
                context.push('/lesson');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Dars yuklanmadi. Qayta urinib ko‘ring.'),
                  ),
                );
              }
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    const DemoControlBar(),

                    // Search + Streak Top Row
                    EdTechReveal(
                      index: 0,
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF14183E),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(
                                    0xFF8B5CF6,
                                  ).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.search_rounded,
                                    size: 18,
                                    color: Color(0xFFA5B4FC),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      onChanged: (v) =>
                                          setState(() => _searchQuery = v),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.5,
                                        color: Colors.white,
                                      ),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        border: InputBorder.none,
                                        hintText:
                                            'Dars, kurs yoki mavzu qidiring...',
                                        hintStyle: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: const Color(0xFF818CF8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF151A42),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(
                                  0xFF8B5CF6,
                                ).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.local_fire_department_rounded,
                                  size: 18,
                                  color: Color(0xFFFBBF24),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${profile.streakDays} kun',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Hero Banner
                    EdTechReveal(
                      index: 1,
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF161C52),
                              Color(0xFF2E1E72),
                              Color(0xFF4C1D95),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(
                              0xFFA855F7,
                            ).withValues(alpha: 0.4),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF7C3AED,
                              ).withValues(alpha: 0.35),
                              blurRadius: 28,
                              spreadRadius: -6,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Assalomu alaykum, $greetingName! 👋',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFC7D2FE),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Bilim yo‘lingizni davom ettiring!',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              needsPlan
                                  ? 'Fan va darajani tanlang. Keyingi darsni BilimYo‘l ko‘rsatadi.'
                                  : starter != null
                                  ? 'Boshlang‘ich darslar: tushuntirish va ishlangan misoldan boshlang.'
                                  : next?.description.isNotEmpty == true
                                  ? next!.description
                                  : 'Bugungi maqsadni bajaring va bilimingizni yangi bosqichga olib chiqing.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.88),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 18),
                            InkWell(
                              onTap: starting ? null : triggerContinueLesson,
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFF9447),
                                      Color(0xFFEC4899),
                                      Color(0xFF8B5CF6),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFEC4899,
                                      ).withValues(alpha: 0.45),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      needsPlan
                                          ? 'Fan tanlash'
                                          : starter != null
                                          ? 'Birinchi darsni ochish'
                                          : lessonId == null
                                          ? 'Ta’lim yo‘lini ochish'
                                          : 'Davom etish',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Bugungi maqsad Card
                    EdTechReveal(
                      index: 2,
                      child: _CosmosCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFEC4899,
                                    ).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.track_changes_rounded,
                                    size: 20,
                                    color: Color(0xFFF472B6),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Bugungi maqsad',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$doneCount/$totalLessons dars · Kunlik ${profile.dailyMinutes} daq',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFFA5B4FC),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF8B5CF6,
                                    ).withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '$progressPct%',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFFDDD6FE),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: (progressPct / 100).clamp(0.08, 1.0),
                                minHeight: 8,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.1,
                                ),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFFEC4899),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Mening kurslarim Section
                    EdTechReveal(
                      index: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Mening kurslarim',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              Row(
                                children: [
                                  for (final entry in [
                                    (0, 'Aktiv'),
                                    (1, 'Tavsiya'),
                                    (2, 'Barchasi'),
                                  ])
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: InkWell(
                                        onTap: () => setState(
                                          () => _courseTabIndex = entry.$1,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _courseTabIndex == entry.$1
                                                ? const Color(0xFF7C3AED)
                                                : const Color(0xFF151A42),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            entry.$2,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...filteredCourses.take(3).map((Course c) {
                            final cTotal = c.lessons.length;
                            final cDone = c.lessons
                                .where(
                                  (id) =>
                                      profile.completedLessonIds.contains(id),
                                )
                                .length;
                            final cPct = cTotal > 0
                                ? ((100 * cDone) / cTotal).round()
                                : 0;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _CosmosCard(
                                onTap: () async {
                                  await ref
                                      .read(
                                        courseStateNotifierProvider.notifier,
                                      )
                                      .selectCourse(c.id);
                                  if (!context.mounted) return;
                                  if (!hasStartedCourse(c, profile)) {
                                    context.push('/onboarding');
                                  }
                                },
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF6366F1),
                                            Color(0xFF8B5CF6),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        subjectIcon(c.subject),
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  c.title,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style:
                                                      GoogleFonts.plusJakartaSans(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: Colors.white,
                                                      ),
                                                ),
                                              ),
                                              Text(
                                                '$cPct%',
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: const Color(
                                                        0xFFC7D2FE,
                                                      ),
                                                    ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            child: LinearProgressIndicator(
                                              value: (cPct / 100).clamp(
                                                0.08,
                                                1.0,
                                              ),
                                              minHeight: 6,
                                              backgroundColor: Colors.white
                                                  .withValues(alpha: 0.1),
                                              valueColor:
                                                  const AlwaysStoppedAnimation<
                                                    Color
                                                  >(Color(0xFF22D3EE)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF7C3AED),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.play_arrow_rounded,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // AI Tutor & Diagnostic Block
                    EdTechReveal(
                      index: 4,
                      child: _CosmosCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF22D3EE,
                                    ).withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 22,
                                    color: Color(0xFF67E8F9),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'AI Tutor · Yo‘lchi AI',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Har qanday mavzuda savol bering, tushuntirish oling va mashq qiling.',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: const Color(0xFFC7D2FE),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                AppButton(
                                  text: 'Suhbatni ochish',
                                  onPressed: () => context.go('/ai-tutor'),
                                ),
                                if (!needsPlan)
                                  AppButton(
                                    text: 'Boshlash darajasi',
                                    variant: AppButtonVariant.outline,
                                    onPressed: () =>
                                        context.push('/onboarding'),
                                  ),
                                if (!needsPlan)
                                  AppButton(
                                    text: 'Ixtiyoriy diagnostika',
                                    variant: AppButtonVariant.outline,
                                    onPressed: () => context.push('/placement'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Mening yutuqlarim & Umumiy rivojlanish
                    EdTechReveal(
                      index: 5,
                      child: _CosmosCard(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatBadge(
                              icon: Icons.star_rounded,
                              color: const Color(0xFFF59E0B),
                              title: '${profile.streakDays} kun',
                              subtitle: 'ketma-ket',
                            ),
                            _StatBadge(
                              icon: Icons.menu_book_rounded,
                              color: const Color(0xFF8B5CF6),
                              title:
                                  '${profile.completedLessonIds.length} dars',
                              subtitle: 'tugallandi',
                            ),
                            _StatBadge(
                              icon: Icons.donut_large_rounded,
                              color: const Color(0xFF22D3EE),
                              title: '$overallScore%',
                              subtitle: 'rivojlanish',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CosmosCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _CosmosCard({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final container = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151A44),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return container;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: container,
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _StatBadge({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            color: const Color(0xFFA5B4FC),
          ),
        ),
      ],
    );
  }
}
