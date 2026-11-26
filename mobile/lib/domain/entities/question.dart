import 'lesson_media.dart';

enum QuestionDifficulty {
  easy,
  medium,
  hard,
}

enum QuestionMode {
  multipleChoice,
  textInput,
  fillBlank,
  wordMatch,
  sentenceOrder,
  errorCorrection,
  conversationCompletion,
  speakingPrompt,
  writingPrompt,
}

class WordMatchPair {
  final String id;
  final String left;
  final String right;

  const WordMatchPair({
    required this.id,
    required this.left,
    required this.right,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'left': left,
    'right': right,
  };

  factory WordMatchPair.fromJson(Map<String, dynamic> json) => WordMatchPair(
    id: (json['id'] as String?)?.trim() ?? '',
    left: (json['left'] as String?)?.trim() ?? '',
    right: (json['right'] as String?)?.trim() ?? '',
  );
}

class RubricCriterion {
  final String id;
  final String labelUz;
  final String labelRu;

  const RubricCriterion({
    required this.id,
    required this.labelUz,
    required this.labelRu,
  });

  String localizedLabel(String uiLocale) {
    if (uiLocale == 'ru' && labelRu.trim().isNotEmpty) {
      return labelRu;
    }
    return labelUz;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'labelUz': labelUz,
    'labelRu': labelRu,
  };

  factory RubricCriterion.fromJson(Map<String, dynamic> json) =>
      RubricCriterion(
        id: (json['id'] as String?)?.trim() ?? '',
        labelUz:
            (json['labelUz'] as String?) ??
            (json['label_uz'] as String?) ??
            '',
        labelRu:
            (json['labelRu'] as String?) ??
            (json['label_ru'] as String?) ??
            '',
      );
}

class LocalizedFeedback {
  final String uz;
  final String ru;
  final String? en;

  const LocalizedFeedback({
    required this.uz,
    required this.ru,
    this.en,
  });

  String localized(String uiLocale) {
    if (uiLocale == 'ru' && ru.trim().isNotEmpty) return ru;
    if (uiLocale == 'en' && en != null && en!.trim().isNotEmpty) return en!;
    return uz.trim().isNotEmpty ? uz : ru;
  }

  factory LocalizedFeedback.fromJson(Map<String, dynamic> json) =>
      LocalizedFeedback(
        uz: (json['uz'] as String?) ?? '',
        ru: (json['ru'] as String?) ?? '',
        en: json['en'] as String?,
      );
}

String normalizeTextAnswer(String input) {
  var value = input.trim();
  if (value.isEmpty) return '';
  value = value
      .replaceAll('\u2019', "'")
      .replaceAll('\u2018', "'")
      .replaceAll('\u02bc', "'")
      .replaceAll('\u02bb', "'")
      .replaceAll('\u00b4', "'")
      .replaceAll('`', "'")
      .replaceAll(',', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .toLowerCase()
      .replaceAll(RegExp(r'[.!?]+$'), '')
      .trim();
  return value;
}

class Question {
  final String id;
  final String courseId;
  final String skillId;
  final String? skillDomain;
  final String? cefrLevel;
  final String? topic;
  final String evaluationMode;
  final String text;
  final String? textRu;
  final String? contextSnippet;
  final QuestionMode mode;
  final List<String> options;
  final int correctIndex;
  final List<String> acceptedAnswers;
  final String? blankTemplate;
  final String? sentenceWithError;
  final List<String> dialogueContext;
  final List<WordMatchPair> matchPairs;
  final List<String> orderedTokens;
  final String? sampleResponse;
  final List<RubricCriterion> rubricCriteria;
  final String? selfAssessmentNoticeUz;
  final String? selfAssessmentNoticeRu;
  final Map<String, LocalizedFeedback> mistakeFeedbackByOption;
  final LessonMedia? media;
  final QuestionDifficulty difficulty;
  final String explanation;
  final String? explanationRu;
  final String? wrongFeedback;
  final String? wrongFeedbackRu;
  final String? formulaLatex;
  final String? audioSimText;
  final String? audioSimSpeaker;
  final bool isPlacement;

  const Question({
    required this.id,
    required this.courseId,
    required this.skillId,
    this.skillDomain,
    this.cefrLevel,
    this.topic,
    this.evaluationMode = 'deterministic',
    required this.text,
    this.textRu,
    this.contextSnippet,
    this.mode = QuestionMode.multipleChoice,
    this.options = const [],
    this.correctIndex = 0,
    this.acceptedAnswers = const [],
    this.blankTemplate,
    this.sentenceWithError,
    this.dialogueContext = const [],
    this.matchPairs = const [],
    this.orderedTokens = const [],
    this.sampleResponse,
    this.rubricCriteria = const [],
    this.selfAssessmentNoticeUz,
    this.selfAssessmentNoticeRu,
    this.mistakeFeedbackByOption = const {},
    this.media,
    required this.difficulty,
    required this.explanation,
    this.explanationRu,
    this.wrongFeedback,
    this.wrongFeedbackRu,
    this.formulaLatex,
    this.audioSimText,
    this.audioSimSpeaker,
    this.isPlacement = false,
  });

  bool get isSelfAssessed =>
      evaluationMode == 'self_assessed' ||
      mode == QuestionMode.speakingPrompt ||
      mode == QuestionMode.writingPrompt;

  bool get usesOptionSelection =>
      mode == QuestionMode.multipleChoice ||
      mode == QuestionMode.errorCorrection ||
      mode == QuestionMode.conversationCompletion;

  bool get usesTextEvaluation =>
      mode == QuestionMode.textInput || mode == QuestionMode.fillBlank;

  bool isTextAnswerCorrect(String input) {
    final normalized = normalizeTextAnswer(input);
    if (normalized.isEmpty) return false;
    return acceptedAnswers.any(
      (candidate) => normalizeTextAnswer(candidate) == normalized,
    );
  }

  bool isWordMatchCorrect(Map<String, String> selectedRightByPairId) {
    if (matchPairs.isEmpty || selectedRightByPairId.length != matchPairs.length) {
      return false;
    }
    for (final pair in matchPairs) {
      final selected = selectedRightByPairId[pair.id];
      if (selected == null) return false;
      final normalizedSelected = normalizeTextAnswer(selected);
      if (normalizedSelected.isEmpty ||
          normalizedSelected != normalizeTextAnswer(pair.right)) {
        return false;
      }
    }
    return true;
  }

  bool isSentenceOrderCorrect(List<String> submittedTokens) {
    if (orderedTokens.isEmpty || submittedTokens.isEmpty) return false;
    if (submittedTokens.length == orderedTokens.length) {
      var exact = true;
      for (var i = 0; i < orderedTokens.length; i++) {
        if (submittedTokens[i] != orderedTokens[i]) {
          exact = false;
          break;
        }
      }
      if (exact) return true;
    }
    final joined = submittedTokens.join(' ');
    if (acceptedAnswers.isNotEmpty && isTextAnswerCorrect(joined)) {
      return true;
    }
    final normalizedJoined = normalizeTextAnswer(joined);
    return normalizedJoined.isNotEmpty &&
        normalizedJoined == normalizeTextAnswer(orderedTokens.join(' '));
  }

  String localizedText(String uiLocale) {
    if (uiLocale == 'ru') {
      final ru = textRu?.trim();
      if (ru != null && ru.isNotEmpty) return ru;
    }
    return text;
  }

  String localizedExplanation(String uiLocale) {
    if (uiLocale == 'ru') {
      final ru = explanationRu?.trim();
      if (ru != null && ru.isNotEmpty) return ru;
    }
    return explanation;
  }

  String? localizedWrongFeedback(String uiLocale) {
    if (uiLocale == 'ru') {
      final ru = wrongFeedbackRu?.trim();
      if (ru != null && ru.isNotEmpty) return ru;
    }
    final uz = wrongFeedback?.trim();
    return (uz != null && uz.isNotEmpty) ? uz : null;
  }

  String? localizedOptionFeedback(String option, String uiLocale) {
    final entry = mistakeFeedbackByOption[option];
    if (entry != null) {
      final localized = entry.localized(uiLocale).trim();
      if (localized.isNotEmpty) return localized;
    }
    return localizedWrongFeedback(uiLocale);
  }

  String? localizedSelfAssessmentNotice(String uiLocale) {
    if (uiLocale == 'ru') {
      final ru = selfAssessmentNoticeRu?.trim();
      if (ru != null && ru.isNotEmpty) return ru;
    }
    final uz = selfAssessmentNoticeUz?.trim();
    return (uz != null && uz.isNotEmpty) ? uz : null;
  }

  Question copyWith({
    String? id,
    String? courseId,
    String? skillId,
    String? skillDomain,
    String? cefrLevel,
    String? topic,
    String? evaluationMode,
    String? text,
    String? textRu,
    String? contextSnippet,
    QuestionMode? mode,
    List<String>? options,
    int? correctIndex,
    List<String>? acceptedAnswers,
    String? blankTemplate,
    String? sentenceWithError,
    List<String>? dialogueContext,
    List<WordMatchPair>? matchPairs,
    List<String>? orderedTokens,
    String? sampleResponse,
    List<RubricCriterion>? rubricCriteria,
    String? selfAssessmentNoticeUz,
    String? selfAssessmentNoticeRu,
    Map<String, LocalizedFeedback>? mistakeFeedbackByOption,
    LessonMedia? media,
    QuestionDifficulty? difficulty,
    String? explanation,
    String? explanationRu,
    String? wrongFeedback,
    String? wrongFeedbackRu,
    String? formulaLatex,
    String? audioSimText,
    String? audioSimSpeaker,
    bool? isPlacement,
  }) {
    return Question(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      skillId: skillId ?? this.skillId,
      skillDomain: skillDomain ?? this.skillDomain,
      cefrLevel: cefrLevel ?? this.cefrLevel,
      topic: topic ?? this.topic,
      evaluationMode: evaluationMode ?? this.evaluationMode,
      text: text ?? this.text,
      textRu: textRu ?? this.textRu,
      contextSnippet: contextSnippet ?? this.contextSnippet,
      mode: mode ?? this.mode,
      options: options ?? this.options,
      correctIndex: correctIndex ?? this.correctIndex,
      acceptedAnswers: acceptedAnswers ?? this.acceptedAnswers,
      blankTemplate: blankTemplate ?? this.blankTemplate,
      sentenceWithError: sentenceWithError ?? this.sentenceWithError,
      dialogueContext: dialogueContext ?? this.dialogueContext,
      matchPairs: matchPairs ?? this.matchPairs,
      orderedTokens: orderedTokens ?? this.orderedTokens,
      sampleResponse: sampleResponse ?? this.sampleResponse,
      rubricCriteria: rubricCriteria ?? this.rubricCriteria,
      selfAssessmentNoticeUz:
          selfAssessmentNoticeUz ?? this.selfAssessmentNoticeUz,
      selfAssessmentNoticeRu:
          selfAssessmentNoticeRu ?? this.selfAssessmentNoticeRu,
      mistakeFeedbackByOption:
          mistakeFeedbackByOption ?? this.mistakeFeedbackByOption,
      media: media ?? this.media,
      difficulty: difficulty ?? this.difficulty,
      explanation: explanation ?? this.explanation,
      explanationRu: explanationRu ?? this.explanationRu,
      wrongFeedback: wrongFeedback ?? this.wrongFeedback,
      wrongFeedbackRu: wrongFeedbackRu ?? this.wrongFeedbackRu,
      formulaLatex: formulaLatex ?? this.formulaLatex,
      audioSimText: audioSimText ?? this.audioSimText,
      audioSimSpeaker: audioSimSpeaker ?? this.audioSimSpeaker,
      isPlacement: isPlacement ?? this.isPlacement,
    );
  }
}

class QuestionAnswerSubmission {
  final String questionId;
  final int selectedIndex;
  final bool isCorrect;
  final int timeSpentSeconds;

  const QuestionAnswerSubmission({
    required this.questionId,
    required this.selectedIndex,
    required this.isCorrect,
    this.timeSpentSeconds = 5,
  });
}
