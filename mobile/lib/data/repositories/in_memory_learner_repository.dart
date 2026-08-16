import '../../domain/repositories/i_learner_repository.dart';
import '../../domain/entities/learner_profile.dart';
import '../../domain/entities/skill_score.dart';

class InMemoryLearnerRepository implements ILearnerRepository {
  LearnerProfile _profile = LearnerProfile(
    id: 'learner_mobile_01',
    name: 'Azizbek',
    selectedCourseId: 'course_math_01',
    goal: OnboardingGoal.mastery,
    dailyMinutes: 15,
    initialLevel: InitialLevel.intermediate,
    xp: 120,
    streakDays: 3,
    lastActiveDate: DateTime.now().toIso8601String().split('T').first,
    scoresByCourse: {},
    completedLessonIds: [],
    completedNodeIds: ['node_math_alg', 'node_math_eq'],
    completedReinforcementIds: [],
    createdAt: DateTime.now().millisecondsSinceEpoch,
  );

  @override
  Future<LearnerProfile> getProfile() async {
    return _profile;
  }

  @override
  Future<LearnerProfile> updateProfile(LearnerProfile updated) async {
    _profile = updated;
    return _profile;
  }

  @override
  Future<void> saveSkillScores(String courseId, Map<String, SkillScore> scores) async {
    final currentScores = Map<String, Map<String, SkillScore>>.from(_profile.scoresByCourse);
    final courseMap = Map<String, SkillScore>.from(currentScores[courseId] ?? {});
    courseMap.addAll(scores);
    currentScores[courseId] = courseMap;

    _profile = _profile.copyWith(scoresByCourse: currentScores);
  }

  @override
  Future<void> markLessonCompleted(String lessonId) async {
    if (!_profile.completedLessonIds.contains(lessonId)) {
      final list = List<String>.from(_profile.completedLessonIds)..add(lessonId);
      _profile = _profile.copyWith(completedLessonIds: list);
    }
  }

  @override
  Future<void> markNodeCompleted(String nodeId) async {
    if (!_profile.completedNodeIds.contains(nodeId)) {
      final list = List<String>.from(_profile.completedNodeIds)..add(nodeId);
      _profile = _profile.copyWith(completedNodeIds: list);
    }
  }

  @override
  Future<void> markReinforcementCompleted(String reinforcementId) async {
    if (!_profile.completedReinforcementIds.contains(reinforcementId)) {
      final list = List<String>.from(_profile.completedReinforcementIds)..add(reinforcementId);
      _profile = _profile.copyWith(completedReinforcementIds: list);
    }
  }

  @override
  Future<LearnerProfile> resetAll() async {
    _profile = LearnerProfile(
      id: 'learner_mobile_01',
      name: 'Azizbek',
      selectedCourseId: 'course_math_01',
      goal: OnboardingGoal.mastery,
      dailyMinutes: 15,
      initialLevel: InitialLevel.intermediate,
      xp: 120,
      streakDays: 3,
      lastActiveDate: DateTime.now().toIso8601String().split('T').first,
      scoresByCourse: {},
      completedLessonIds: [],
      completedNodeIds: ['node_math_alg', 'node_math_eq'],
      completedReinforcementIds: [],
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    return _profile;
  }
}
