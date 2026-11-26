import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../domain/entities/learning_path_node.dart';
import '../../domain/entities/lesson.dart';
import '../../domain/entities/lesson_media.dart';
import '../../domain/personalization/learning_start.dart';
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

  static Object? _firstNonEmpty(
    Object? first, [
    Object? second,
    Object? third,
  ]) {
    for (final value in [first, second, third]) {
      if (value != null && value.toString().trim().isNotEmpty) {
        return value;
      }
    }
    return null;
  }

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

  static QuestionMode _questionMode(Object? raw) {
    final normalized = raw?.toString().trim().toLowerCase().replaceAll('_', '');
    switch (normalized) {
      case 'textinput':
        return QuestionMode.textInput;
      case 'fillblank':
        return QuestionMode.fillBlank;
      case 'wordmatch':
        return QuestionMode.wordMatch;
      case 'sentenceorder':
        return QuestionMode.sentenceOrder;
      case 'errorcorrection':
        return QuestionMode.errorCorrection;
      case 'conversationcompletion':
        return QuestionMode.conversationCompletion;
      case 'speakingprompt':
        return QuestionMode.speakingPrompt;
      case 'writingprompt':
        return QuestionMode.writingPrompt;
      case 'multiplechoice':
      default:
        return QuestionMode.multipleChoice;
    }
  }

  static List<WordMatchPair> _matchPairs(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => WordMatchPair.fromJson(Map<String, dynamic>.from(item)))
        .where((p) => p.id.isNotEmpty && p.left.isNotEmpty && p.right.isNotEmpty)
        .toList(growable: false);
  }

  static List<RubricCriterion> _rubricCriteria(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (item) => RubricCriterion.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((c) => c.id.isNotEmpty && c.labelUz.isNotEmpty)
        .toList(growable: false);
  }

  static Map<String, LocalizedFeedback> _mistakeFeedbackByOption(Object? raw) {
    if (raw is! Map) return const {};
    final map = <String, LocalizedFeedback>{};
    for (final entry in raw.entries) {
      if (entry.value is Map) {
        map[entry.key.toString()] = LocalizedFeedback.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
    }
    return map;
  }

  static Question _question(
    Map<String, dynamic> raw, {
    required String courseId,
    required String skillId,
  }) {
    final mode = _questionMode(
      _firstNonEmpty(raw['mode'], raw['questionType'], raw['question_type']),
    );
    return Question(
      id: _string(raw['id']),
      courseId: courseId,
      skillId: skillId,
      skillDomain:
          raw['skillDomain'] as String? ?? raw['skill_domain'] as String?,
      cefrLevel: raw['cefrLevel'] as String? ?? raw['cefr_level'] as String?,
      topic: raw['topic'] as String?,
      evaluationMode:
          (raw['evaluationMode'] as String? ??
                  raw['evaluation_mode'] as String?) ??
          ((mode == QuestionMode.speakingPrompt ||
                  mode == QuestionMode.writingPrompt)
              ? 'self_assessed'
              : 'deterministic'),
      text: _string(raw['text']),
      textRu: raw['textRu'] as String? ?? raw['text_ru'] as String?,
      contextSnippet: raw['context_snippet'] as String? ??
          raw['contextSnippet'] as String?,
      mode: mode,
      options: _strings(raw['options']),
      // Safe views intentionally omit all answer-key fields.
      correctIndex: -1,
      acceptedAnswers: _strings(
        raw['accepted_answers'] ?? raw['acceptedAnswers'],
      ),
      blankTemplate:
          raw['blankTemplate'] as String? ?? raw['blank_template'] as String?,
      sentenceWithError:
          raw['sentenceWithError'] as String? ??
          raw['sentence_with_error'] as String?,
      dialogueContext: _strings(
        raw['dialogueContext'] ?? raw['dialogue_context'],
      ),
      matchPairs: _matchPairs(raw['matchPairs'] ?? raw['match_pairs']),
      orderedTokens: _strings(raw['orderedTokens'] ?? raw['ordered_tokens']),
      sampleResponse:
          raw['sampleResponse'] as String? ??
          raw['sample_response'] as String?,
      rubricCriteria: _rubricCriteria(
        raw['rubricCriteria'] ?? raw['rubric_criteria'],
      ),
      selfAssessmentNoticeUz:
          raw['selfAssessmentNoticeUz'] as String? ??
          raw['self_assessment_notice_uz'] as String?,
      selfAssessmentNoticeRu:
          raw['selfAssessmentNoticeRu'] as String? ??
          raw['self_assessment_notice_ru'] as String?,
      mistakeFeedbackByOption: _mistakeFeedbackByOption(
        raw['mistakeFeedbackByOption'] ?? raw['mistake_feedback_by_option'],
      ),
      media: LessonMedia.tryParse(raw['media']),
      difficulty: _difficulty(raw['difficulty']),
      explanation: _string(raw['explanation']),
      explanationRu:
          raw['explanation_ru'] as String? ?? raw['explanationRu'] as String?,
      wrongFeedback:
          raw['wrong_feedback'] as String? ?? raw['wrongFeedback'] as String?,
      wrongFeedbackRu: raw['wrong_feedback_ru'] as String? ??
          raw['wrongFeedbackRu'] as String?,
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
      case 'flashcard':
        return LessonStepType.flashcard;
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

  static List<LessonFlashcard>? _flashcards(Object? value) {
    if (value is! List) return null;
    final items = value
        .whereType<Map>()
        .map((item) {
          final raw = Map<String, dynamic>.from(item);
          return LessonFlashcard(
            id: _string(raw['id']),
            front: _string(raw['front']),
            backUz: _string(raw['backUz'] ?? raw['back_uz']),
            backRu: _string(raw['backRu'] ?? raw['back_ru']),
            partOfSpeech:
                raw['partOfSpeech'] as String? ?? raw['part_of_speech'] as String?,
            ipa: raw['ipa'] as String?,
            ipaAmE:
                raw['ipaAmE'] as String? ?? raw['ipa_am_e'] as String?,
            cefrLevel:
                raw['cefrLevel'] as String? ?? raw['cefr_level'] as String?,
            example: _string(raw['example']),
            exampleUz: _string(raw['exampleUz'] ?? raw['example_uz']),
            exampleRu: _string(raw['exampleRu'] ?? raw['example_ru']),
            audioSrc:
                raw['audioSrc'] as String? ?? raw['audio_src'] as String?,
            imageSrc:
                raw['imageSrc'] as String? ?? raw['image_src'] as String?,
            alt: raw['alt'] as String?,
            altRu: raw['altRu'] as String? ?? raw['alt_ru'] as String?,
          );
        })
        .where((card) => card.id.isNotEmpty && card.front.isNotEmpty)
        .toList(growable: false);
    return items.isEmpty ? null : items;
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
      titleRu: raw['titleRu'] as String? ?? raw['title_ru'] as String?,
      subtitle: raw['subtitle'] as String?,
      subtitleRu:
          raw['subtitleRu'] as String? ?? raw['subtitle_ru'] as String?,
      content: _string(raw['content']),
      contentRu: raw['contentRu'] as String? ?? raw['content_ru'] as String?,
      highlightNotes: _strings(raw['highlightNotes'] ?? raw['highlight_notes']),
      highlightNotesRu: _strings(
        raw['highlightNotesRu'] ?? raw['highlight_notes_ru'],
      ),
      masteryCheckpoint:
          raw['masteryCheckpoint'] as String? ??
          raw['mastery_checkpoint'] as String?,
      formulaData: _formula(raw['formulaData'] ?? raw['formula_data']),
      visualModelData:
          _visual(raw['visualModelData'] ?? raw['visual_model_data']),
      media: LessonMedia.tryParse(raw['media']),
      flashcards: _flashcards(raw['flashcards']),
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
    if (raw['is_locked'] == true) {
      throw const FormatException('Dars hali ochilmagan. Avval tayanch mavzularni o‘zlashtiring.');
    }
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
    final rawAlternate =
        raw['alternate_exercise'] ?? raw['alternateExercise'];
    final isValidReinforcement = reinforcement != null &&
        reinforcement.id.isNotEmpty &&
        (reinforcement.usesOptionSelection
            ? reinforcement.options.length >= 2
            : reinforcement.mode == QuestionMode.wordMatch
            ? reinforcement.matchPairs.isNotEmpty
            : reinforcement.mode == QuestionMode.sentenceOrder
            ? reinforcement.orderedTokens.isNotEmpty
            : reinforcement.text.trim().isNotEmpty);
    if (!isValidReinforcement) {
      throw const FormatException('Darsning serverda baholanadigan savoli topilmadi.');
    }

    return Lesson(
      id: _string(raw['id']),
      courseId: courseId,
      skillId: skillId,
      skillDomain:
          raw['skillDomain'] as String? ?? raw['skill_domain'] as String?,
      communicativeFocus:
          raw['communicativeFocus'] as String? ??
          raw['communicative_focus'] as String?,
      cefrLevel: raw['cefrLevel'] as String? ?? raw['cefr_level'] as String?,
      moduleId: raw['moduleId'] as String? ?? raw['module_id'] as String?,
      unitId: raw['unitId'] as String? ?? raw['unit_id'] as String?,
      canDoObjective:
          raw['canDoObjective'] as String? ??
          raw['can_do_objective'] as String?,
      canDoObjectiveRu:
          raw['canDoObjectiveRu'] as String? ??
          raw['can_do_objective_ru'] as String?,
      prerequisites: _strings(raw['prerequisites']),
      title: _string(raw['title']),
      titleRu: raw['titleRu'] as String? ?? raw['title_ru'] as String?,
      estimatedMinutes: (raw['estimated_minutes'] as num?)?.toInt() ?? 15,
      summary: _string(raw['summary']),
      summaryRu: raw['summaryRu'] as String? ?? raw['summary_ru'] as String?,
      officialCefrDisclaimerUz:
          raw['officialCefrDisclaimerUz'] as String? ??
          raw['official_cefr_disclaimer_uz'] as String?,
      officialCefrDisclaimerRu:
          raw['officialCefrDisclaimerRu'] as String? ??
          raw['official_cefr_disclaimer_ru'] as String?,
      steps: steps,
      reinforcementExercise: reinforcement,
      alternateExercise: rawAlternate is Map
          ? _question(
              Map<String, dynamic>.from(rawAlternate),
              courseId: courseId,
              skillId: skillId,
            )
          : null,
      requiresMastery: raw['steps'] is List && (raw['steps'] as List).whereType<Map>().any(
        (step) => step['masteryCheckpoint'] == 'application' || step['masteryCheckpoint'] == 'retrieval',
      ),
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
    if (SupabaseConfig.isDemoModeActive) {
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
    if (SupabaseConfig.isDemoModeActive) {
      return _fallback.getLessonByCourseAndSkill(courseId, skillId);
    }
    final client = _requireClient();
    await _requireAuthenticated(client);
    final query = client
        .from('learner_lessons')
        .select('*')
        .eq('course_id', courseId)
        .eq('skill_id', skillId);
    final eligible = courseId == mathMasteryCourse ? query.eq('is_locked', false) : query;
    final row = await eligible
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

  static LearningNodeKind _nodeKind(Object? raw) {
    switch (raw?.toString().trim().toLowerCase().replaceAll('_', '')) {
      case 'unitcheckpoint':
        return LearningNodeKind.unitCheckpoint;
      case 'levelassessment':
        return LearningNodeKind.levelAssessment;
      default:
        return LearningNodeKind.lesson;
    }
  }

  static LearningPathNode parseRoadmapNode(
    Map<String, dynamic> node, {
    String fallbackCourseId = '',
  }) {
    final resolvedCourseId = _string(node['course_id'], fallbackCourseId);
    final isMathPilot = resolvedCourseId == mathMasteryCourse;
    final hasMasteryFields =
        isMathPilot ||
        node.containsKey('answered') ||
        node.containsKey('required_items');
    final reviewDue = node['review_due'] == true;
    final mastery = hasMasteryFields
        ? NodeMastery(
            state: node['mastery_state']?.toString() ?? 'not_started',
            answered: (node['answered'] as num?)?.toInt() ?? 0,
            correct: (node['correct'] as num?)?.toInt() ?? 0,
            requiredItems: (node['required_items'] as num?)?.toInt() ?? 5,
            passedCheckpoints: (node['passed_checkpoints'] as num?)?.toInt() ?? 0,
            requiredCheckpoints:
                (node['required_checkpoints'] as num?)?.toInt() ?? 2,
            reviewDue: reviewDue,
          )
        : null;
    final nodeKind = _nodeKind(node['nodeKind'] ?? node['node_kind']);

    return LearningPathNode(
      id: _string(node['id']),
      courseId: resolvedCourseId,
      skillId: _string(node['skill_id']),
      skillDomain:
          node['skillDomain'] as String? ?? node['skill_domain'] as String?,
      cefrLevel: node['cefrLevel'] as String? ?? node['cefr_level'] as String?,
      moduleId: node['moduleId'] as String? ?? node['module_id'] as String?,
      moduleTitle:
          node['moduleTitle'] as String? ?? node['module_title'] as String?,
      moduleTitleRu:
          node['moduleTitleRu'] as String? ??
          node['module_title_ru'] as String?,
      unitId: node['unitId'] as String? ?? node['unit_id'] as String?,
      canDoObjective:
          node['canDoObjective'] as String? ??
          node['can_do_objective'] as String?,
      canDoObjectiveRu:
          node['canDoObjectiveRu'] as String? ??
          node['can_do_objective_ru'] as String?,
      nodeKind: nodeKind,
      isCheckpoint:
          node['isCheckpoint'] == true ||
          node['is_checkpoint'] == true ||
          nodeKind != LearningNodeKind.lesson,
      hasRichExercise:
          node['hasRichExercise'] == true || node['has_rich_exercise'] == true,
      taskKind: node['taskKind'] as String? ?? node['task_kind'] as String?,
      title: _string(node['title']),
      titleRu: node['titleRu'] as String? ?? node['title_ru'] as String?,
      description: _string(node['description']),
      descriptionRu:
          node['descriptionRu'] as String? ?? node['description_ru'] as String?,
      prerequisites: _strings(node['prerequisites']),
      requiredScore: (node['required_score'] as num?)?.toInt() ?? 50,
      status: node['is_reinforcement'] == true
          ? NodeStatus.reinforcement
          : _nodeStatus(node['status']),
      score: (node['score'] as num?)?.toInt(),
      isReinforcement: node['is_reinforcement'] == true,
      targetLessonId: node['target_lesson_id'] as String?,
      estimatedMinutes: (node['estimated_minutes'] as num?)?.toInt() ?? 15,
      order: (node['order_index'] as num?)?.toDouble() ?? 0,
      isOptional: node['is_optional'] == true,
      serverMastery: isMathPilot,
      reviewDue: reviewDue,
      mastery: mastery,
    );
  }

  @override
  Future<List<LearningPathNode>> getBaseRoadmapNodes(String courseId) async {
    if (SupabaseConfig.isDemoModeActive) {
      return _fallback.getBaseRoadmapNodes(courseId);
    }
    final client = _requireClient();
    await _requireAuthenticated(client);
    final Object? rows = courseId == mathMasteryCourse ? await client.rpc('get_math_progression') : await client
        .from('roadmap_nodes')
        .select(
          'id, course_id, skill_id, title, description, prerequisites, '
          'required_score, is_reinforcement, target_lesson_id, '
          'estimated_minutes, order_index, is_active',
        )
        .eq('course_id', courseId)
        .eq('is_active', true)
        .order('order_index');
    if (rows is! List || (courseId == mathMasteryCourse && rows.isEmpty)) {
      throw const FormatException('Ta’lim yo‘li ma’lumotlari kelmadi.');
    }

    return rows
        .whereType<Map>()
        .map(
          (raw) => parseRoadmapNode(
            Map<String, dynamic>.from(raw),
            fallbackCourseId: courseId,
          ),
        )
        .toList(growable: false);
  }
}
