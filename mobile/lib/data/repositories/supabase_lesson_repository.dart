import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../domain/entities/learning_path_node.dart';
import '../../domain/entities/lesson.dart';
import '../../domain/entities/question.dart';
import '../../domain/repositories/i_lesson_repository.dart';
import 'in_memory_lesson_repository.dart';

/// Reads only learner-safe lesson views when the remote backend is configured.
class SupabaseLessonRepository implements ILessonRepository {
  final InMemoryLessonRepository _fallback = InMemoryLessonRepository();

  SupabaseClient _requireClient() {
    final client = SupabaseConfig.client;
    if (client == null) {
      throw StateError('Supabase ishga tushmadi. Qayta urinib ko‘ring.');
    }
    return client;
  }

  Future<void> _requireAuthenticated(SupabaseClient client) async {
    if (client.auth.currentUser == null) {
      throw StateError('Autentifikatsiyadan o‘tilmagan.');
    }
  }

  static String _string(Object? value, [String fallback = '']) =>
      value is String ? value : fallback;

  static List<String> _strings(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList(growable: false);
  }

  static QuestionDifficulty _difficulty(Object? raw) {
    switch (raw?.toString().trim().toLowerCase()) {
      case 'easy':
      case 'oson':
        return QuestionDifficulty.easy;
      case 'hard':
      case 'qiyin':
        return QuestionDifficulty.hard;
      default:
        return QuestionDifficulty.medium;
    }
  }

  static Question _question(
    Map<String, dynamic> raw, {
    required String courseId,
    required String skillId,
  }) {
    return Question(
      id: _string(raw['id']),
      courseId: courseId,
      skillId: skillId,
      text: _string(raw['text']),
      contextSnippet: raw['context_snippet'] as String? ??
          raw['contextSnippet'] as String?,
      options: _strings(raw['options']),
      // Safe views intentionally omit all answer-key fields.
      correctIndex: -1,
      difficulty: _difficulty(raw['difficulty']),
      explanation: '',
      formulaLatex: raw['formula_latex'] as String? ??
          raw['formulaLatex'] as String?,
      audioSimText: raw['audio_sim_text'] as String? ??
          raw['audioSimText'] as String?,
      audioSimSpeaker: raw['audio_sim_speaker'] as String? ??
          raw['audioSimSpeaker'] as String?,
    );
  }

  static LessonStepType _stepType(Object? raw) {
    final value = raw?.toString().replaceAll('_', '').toLowerCase();
    switch (value) {
      case 'formula':
        return LessonStepType.formula;
      case 'visualexample':
        return LessonStepType.visualExample;
      case 'audiosimulation':
        return LessonStepType.audioSimulation;
      case 'interactivequestion':
        return LessonStepType.interactiveQuestion;
      case 'concept':
      default:
        return LessonStepType.concept;
    }
  }

  static LessonFormulaData? _formula(Object? value) {
    if (value is! Map) return null;
    final raw = Map<String, dynamic>.from(value);
    final variables = raw['variables'];
    return LessonFormulaData(
      latex: _string(raw['latex'] ?? raw['formula']),
      description: _string(raw['description']),
      variables: variables is List
          ? variables
              .whereType<Map>()
              .map(
                (item) => Map<String, String>.from(
                  item.map(
                    (key, value) => MapEntry(key.toString(), value.toString()),
                  ),
                ),
              )
              .toList(growable: false)
          : const [],
    );
  }

  static LessonVisualModelData? _visual(Object? value) {
    if (value is! Map) return null;
    final raw = Map<String, dynamic>.from(value);
    final points = raw['points'];
    return LessonVisualModelData(
      type: _string(raw['type']),
      functionExpr: raw['functionExpr'] as String? ??
          raw['function_expr'] as String?,
      points: points is List
          ? points
              .whereType<Map>()
              .map((point) => Map<String, dynamic>.from(point))
              .toList(growable: false)
          : null,
      audioTranscript: raw['audioTranscript'] as String? ??
          raw['audio_transcript'] as String?,
      speakerName: raw['speakerName'] as String? ??
          raw['speaker_name'] as String?,
    );
  }

  static LessonStep _step(
    Map<String, dynamic> raw, {
    required int fallbackNumber,
    required String courseId,
    required String skillId,
    Question? fallbackQuestion,
  }) {
    final rawQuestion = raw['interactiveQuestion'] ??
        raw['interactive_question'];
    return LessonStep(
      id: _string(raw['id'], 'step_$fallbackNumber'),
      stepNumber: (raw['stepNumber'] as num?)?.toInt() ??
          (raw['step_number'] as num?)?.toInt() ??
          fallbackNumber,
      type: _stepType(raw['type']),
      title: _string(raw['title']),
      subtitle: raw['subtitle'] as String?,
      content: _string(raw['content']),
      highlightNotes: _strings(raw['highlightNotes'] ?? raw['highlight_notes']),
      formulaData: _formula(raw['formulaData'] ?? raw['formula_data']),
      visualModelData:
          _visual(raw['visualModelData'] ?? raw['visual_model_data']),
      interactiveQuestion: rawQuestion is Map
          ? _question(
              Map<String, dynamic>.from(rawQuestion),
              courseId: courseId,
              skillId: skillId,
            )
          : fallbackQuestion,
    );
  }

  static List<LessonStep> _steps(
    Object? value, {
    required String courseId,
    required String skillId,
    Question? fallbackQuestion,
  }) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .toList(growable: false)
        .asMap()
        .entries
        .map(
          (entry) => _step(
            Map<String, dynamic>.from(entry.value),
            fallbackNumber: entry.key + 1,
            courseId: courseId,
            skillId: skillId,
            fallbackQuestion: _stepType(entry.value['type']) == LessonStepType.interactiveQuestion ||
                    entry.key == value.length - 1
                ? fallbackQuestion
                : null,
          ),
        )
        .toList(growable: false);
  }

  static Lesson parseLearnerLesson(Map<String, dynamic> raw) {
    final courseId = _string(raw['course_id']);
    final skillId = _string(raw['skill_id']);
    final rawQuestions = raw['questions'];
    final rawReinforcement = raw['reinforcement_exercise'];
    final firstQuestion = rawQuestions is List && rawQuestions.isNotEmpty && rawQuestions.first is Map
        ? _question(Map<String, dynamic>.from(rawQuestions.first as Map),
            courseId: courseId, skillId: skillId)
        : null;
    final steps = _steps(raw['steps'], courseId: courseId, skillId: skillId,
        fallbackQuestion: firstQuestion);
    final reinforcement = rawReinforcement is Map
        ? _question(
            Map<String, dynamic>.from(rawReinforcement),
            courseId: courseId,
            skillId: skillId,
          )
        : firstQuestion ?? steps.map((step) => step.interactiveQuestion).whereType<Question>().firstOrNull;
    if (reinforcement == null || reinforcement.id.isEmpty || reinforcement.options.length < 2) {
      throw const FormatException('Darsning serverda baholanadigan savoli topilmadi.');
    }

    return Lesson(
      id: _string(raw['id']),
      courseId: courseId,
      skillId: skillId,
      title: _string(raw['title']),
      estimatedMinutes: (raw['estimated_minutes'] as num?)?.toInt() ?? 15,
      summary: _string(raw['summary']),
      steps: steps,
      reinforcementExercise: reinforcement,
    );
  }

  Future<Lesson?> _getCuratedLessonById(
    SupabaseClient client,
    String lessonId,
  ) async {
    final row = await client
        .from('learner_lessons')
        .select('*')
        .eq('id', lessonId)
        .maybeSingle();
    return row == null ? null : parseLearnerLesson(Map<String, dynamic>.from(row));
  }

  Future<Lesson?> _getGeneratedLessonById(
    SupabaseClient client,
    String lessonId,
  ) async {
    final row = await client
        .from('learner_generated_lessons')
        .select('*')
        .eq('id', lessonId)
        .maybeSingle();
    return row == null ? null : parseLearnerLesson(Map<String, dynamic>.from(row));
  }

  @override
  Future<Lesson?> getLessonById(String lessonId) async {
    if (!SupabaseConfig.hasRemoteConfiguration) {
      return _fallback.getLessonById(lessonId);
    }
    final client = _requireClient();
    await _requireAuthenticated(client);
    return await _getCuratedLessonById(client, lessonId) ??
        await _getGeneratedLessonById(client, lessonId);
  }

  @override
  Future<Lesson?> getLessonByCourseAndSkill(
    String courseId,
    String skillId,
  ) async {
    if (!SupabaseConfig.hasRemoteConfiguration) {
      return _fallback.getLessonByCourseAndSkill(courseId, skillId);
    }
    final client = _requireClient();
    await _requireAuthenticated(client);
    final row = await client
        .from('learner_lessons')
        .select('*')
        .eq('course_id', courseId)
        .eq('skill_id', skillId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row != null) return parseLearnerLesson(Map<String, dynamic>.from(row));

    final generated = await client
        .from('learner_generated_lessons')
        .select('*')
        .eq('course_id', courseId)
        .eq('skill_id', skillId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return generated == null
        ? null
        : parseLearnerLesson(Map<String, dynamic>.from(generated));
  }

  static NodeStatus _nodeStatus(Object? raw) {
    switch (raw?.toString().replaceAll('_', '').toLowerCase()) {
      case 'available':
        return NodeStatus.available;
      case 'inprogress':
        return NodeStatus.inProgress;
      case 'completed':
        return NodeStatus.completed;
      case 'reinforcement':
        return NodeStatus.reinforcement;
      case 'locked':
      default:
        return NodeStatus.locked;
    }
  }

  @override
  Future<List<LearningPathNode>> getBaseRoadmapNodes(String courseId) async {
    if (!SupabaseConfig.hasRemoteConfiguration) {
      return _fallback.getBaseRoadmapNodes(courseId);
    }
    final client = _requireClient();
    await _requireAuthenticated(client);
    final rows = await client
        .from('roadmap_nodes')
        .select(
          'id, course_id, skill_id, title, description, prerequisites, '
          'required_score, is_reinforcement, target_lesson_id, '
          'estimated_minutes, order_index, is_active',
        )
        .eq('course_id', courseId)
        .eq('is_active', true)
        .order('order_index');

    return (rows as List)
        .whereType<Map>()
        .map((raw) {
          final node = Map<String, dynamic>.from(raw);
          return LearningPathNode(
            id: _string(node['id']),
            courseId: _string(node['course_id']),
            skillId: _string(node['skill_id']),
            title: _string(node['title']),
            description: _string(node['description']),
            prerequisites: _strings(node['prerequisites']),
            requiredScore: (node['required_score'] as num?)?.toInt() ?? 50,
            status: node['is_reinforcement'] == true
                ? NodeStatus.reinforcement
                : _nodeStatus(node['status']),
            score: (node['score'] as num?)?.toInt(),
            isReinforcement: node['is_reinforcement'] == true,
            targetLessonId: node['target_lesson_id'] as String?,
            estimatedMinutes:
                (node['estimated_minutes'] as num?)?.toInt() ?? 15,
            order: (node['order_index'] as num?)?.toDouble() ?? 0,
          );
        })
        .toList(growable: false);
  }
}
