import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bilimyol_mobile/core/utils/question_option_order.dart';
import 'package:bilimyol_mobile/data/datasources/courses_data.dart';
import 'package:bilimyol_mobile/data/datasources/english/a1_lessons_data.dart';
import 'package:bilimyol_mobile/data/datasources/english/a1_roadmap_data.dart';
import 'package:bilimyol_mobile/data/datasources/english/a2_lessons_data.dart';
import 'package:bilimyol_mobile/data/datasources/english/a2_roadmap_data.dart';
import 'package:bilimyol_mobile/data/datasources/english/b1_lessons_data.dart';
import 'package:bilimyol_mobile/data/datasources/english/b1_roadmap_data.dart';
import 'package:bilimyol_mobile/data/datasources/english/cefr_skeleton_data.dart';
import 'package:bilimyol_mobile/data/datasources/english/placement_questions_data.dart';
import 'package:bilimyol_mobile/data/datasources/lessons_data.dart';
import 'package:bilimyol_mobile/data/datasources/questions_data.dart';
import 'package:bilimyol_mobile/data/datasources/roadmaps_data.dart';
import 'package:bilimyol_mobile/data/datasources/starter_lessons_data.dart';
import 'package:bilimyol_mobile/domain/entities/learning_path_node.dart';
import 'package:bilimyol_mobile/domain/entities/lesson.dart';
import 'package:bilimyol_mobile/domain/entities/lesson_media.dart';
import 'package:bilimyol_mobile/domain/entities/question.dart';

File resolveRepoFile(String repoRelativePath) {
  final direct = File(repoRelativePath);
  if (direct.existsSync()) return direct;
  final parent = File('../$repoRelativePath');
  if (parent.existsSync()) return parent;
  throw StateError('Unable to locate canonical repo file: $repoRelativePath');
}

Map<String, dynamic> readCanonicalJson(String repoRelativePath) {
  final file = resolveRepoFile(repoRelativePath);
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

String resolveRepoRootPath() {
  if (File('content/english/cefr-skeleton.json').existsSync()) {
    return '.';
  }
  if (File('../content/english/cefr-skeleton.json').existsSync()) {
    return '..';
  }
  throw StateError('Unable to locate repository root from ${Directory.current.path}');
}

void _assertDiskMediaAssetMatches(String canonicalSource, String repoRoot) {
  expect(
    canonicalSource.startsWith('/lesson-media/english/'),
    isTrue,
    reason: 'Unexpected media source: $canonicalSource',
  );
  final flutterAssetPath = LessonMedia.resolveAssetPath(canonicalSource);
  expect(flutterAssetPath, isNotNull, reason: 'Invalid media source: $canonicalSource');

  final rel = canonicalSource.substring('/lesson-media/'.length);
  final flutterFile = File('$repoRoot/mobile/$flutterAssetPath');
  final webFile = File('$repoRoot/public/lesson-media/$rel');
  expect(flutterFile.existsSync(), isTrue, reason: 'Missing Flutter asset: ${flutterFile.path}');
  expect(webFile.existsSync(), isTrue, reason: 'Missing Web asset: ${webFile.path}');

  final flutterBytes = flutterFile.readAsBytesSync();
  final webBytes = webFile.readAsBytesSync();
  expect(flutterBytes.length, greaterThan(0));
  expect(webBytes.length, greaterThan(0));
  expect(
    flutterBytes,
    orderedEquals(webBytes),
    reason: 'Byte mismatch between Flutter and Web asset for $canonicalSource',
  );

  if (canonicalSource.endsWith('.wav')) {
    expect(webBytes.length, greaterThan(44));
    expect(String.fromCharCodes(webBytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(webBytes.sublist(8, 12)), 'WAVE');
  } else if (canonicalSource.endsWith('.png')) {
    expect(webBytes.length, greaterThan(8));
    expect(
      webBytes.sublist(0, 8),
      orderedEquals(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
    );
  }
}

String _stepTypeToCanonical(LessonStepType type) {
  switch (type) {
    case LessonStepType.concept:
      return 'concept';
    case LessonStepType.formula:
      return 'formula';
    case LessonStepType.visualExample:
      return 'visual_example';
    case LessonStepType.audioSimulation:
      return 'audio_simulation';
    case LessonStepType.flashcard:
      return 'flashcard';
    case LessonStepType.interactiveQuestion:
      return 'interactive_question';
  }
}

String _questionModeToCanonical(QuestionMode mode) {
  switch (mode) {
    case QuestionMode.multipleChoice:
      return 'multiple_choice';
    case QuestionMode.textInput:
      return 'text_input';
    case QuestionMode.fillBlank:
      return 'fill_blank';
    case QuestionMode.wordMatch:
      return 'word_match';
    case QuestionMode.sentenceOrder:
      return 'sentence_order';
    case QuestionMode.errorCorrection:
      return 'error_correction';
    case QuestionMode.conversationCompletion:
      return 'conversation_completion';
    case QuestionMode.speakingPrompt:
      return 'speaking_prompt';
    case QuestionMode.writingPrompt:
      return 'writing_prompt';
  }
}

String _nodeKindToCanonical(LearningNodeKind kind) {
  switch (kind) {
    case LearningNodeKind.lesson:
      return 'lesson';
    case LearningNodeKind.unitCheckpoint:
      return 'unit_checkpoint';
    case LearningNodeKind.levelAssessment:
      return 'level_assessment';
  }
}

String _nodeStatusToCanonical(NodeStatus status) {
  switch (status) {
    case NodeStatus.locked:
      return 'locked';
    case NodeStatus.available:
      return 'available';
    case NodeStatus.inProgress:
      return 'in_progress';
    case NodeStatus.completed:
      return 'completed';
    case NodeStatus.reinforcement:
      return 'reinforcement';
  }
}

String _mediaKindToCanonical(LessonMediaKind kind) {
  switch (kind) {
    case LessonMediaKind.audio:
      return 'audio';
    case LessonMediaKind.video:
      return 'video';
    case LessonMediaKind.image:
      return 'image';
  }
}

List<String> _asStringList(Object? raw) {
  if (raw is! List) return const [];
  return raw.map((e) => e.toString()).toList();
}

Set<String> _extractPubspecFlutterAssets(String pubspecContent) {
  final assets = <String>{};
  final lines = pubspecContent.split(RegExp(r'\r?\n'));
  var inFlutter = false;
  var inAssets = false;
  var assetsIndent = -1;
  final flutterHeader = RegExp(r'^flutter\s*:(?:\s*(?:#.*)?)?$');
  final assetsHeader = RegExp(r'^assets\s*:(?:\s*(?:#.*)?)?$');

  for (final rawLine in lines) {
    final trimmed = rawLine.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

    final indent = rawLine.length - rawLine.trimLeft().length;

    if (indent == 0) {
      inFlutter = flutterHeader.hasMatch(trimmed);
      inAssets = false;
      assetsIndent = -1;
      continue;
    }

    if (!inFlutter) continue;

    if (inAssets &&
        (indent < assetsIndent ||
            (indent == assetsIndent && !trimmed.startsWith('-')))) {
      inAssets = false;
      assetsIndent = -1;
    }

    if (!inAssets) {
      if (assetsHeader.hasMatch(trimmed)) {
        inAssets = true;
        assetsIndent = indent;
      }
      continue;
    }

    if (trimmed.startsWith('-')) {
      final itemBody = trimmed.substring(1).trim();
      if (itemBody.isEmpty || itemBody.startsWith('#')) continue;

      String value;
      if (itemBody.startsWith("'") || itemBody.startsWith('"')) {
        final quote = itemBody[0];
        final endIdx = itemBody.indexOf(quote, 1);
        value = endIdx > 0 ? itemBody.substring(1, endIdx) : itemBody.substring(1);
      } else {
        final commentIdx = itemBody.indexOf('#');
        value = (commentIdx >= 0 ? itemBody.substring(0, commentIdx) : itemBody)
            .trim();
      }
      if (value.isNotEmpty) assets.add(value);
    }
  }

  return assets;
}

void _assertMediaMatches(LessonMedia? media, Map<String, dynamic>? cm) {
  if (cm == null) {
    expect(media, isNull);
    return;
  }
  expect(media, isNotNull);
  expect(media!.id, cm['id']);
  expect(_mediaKindToCanonical(media.kind), cm['kind']);
  expect(media.languageCode, cm['language']);
  expect(media.reviewStatus.name, cm['reviewStatus']);
  expect(media.source, cm['source']);
  expect(media.title, cm['title']);
  expect(media.titleUz, cm['titleUz']);
  expect(media.titleRu, cm['titleRu']);
  expect(media.posterImage, cm['posterImage']);
  expect(media.posterAlt, cm['posterAlt']);
  expect(media.posterAltUz, cm['posterAltUz']);
  expect(media.posterAltRu, cm['posterAltRu']);
  expect(media.alt, cm['alt']);
  expect(media.altUz, cm['altUz']);
  expect(media.altRu, cm['altRu']);
  expect(media.provenance, cm['provenance']);
  expect(media.attribution, cm['attribution']);
  if (media.kind == LessonMediaKind.image) {
    expect(cm['transcript'], isNull);
    expect(media.transcript, isNull);
  } else {
    expect(media.transcript, cm['transcript']);
    expect(media.durationSeconds, cm['durationSeconds']);
  }
}

void _assertVisualModelDataMatches(
  LessonVisualModelData? vmd,
  Map<String, dynamic>? cv,
) {
  if (cv == null) {
    expect(vmd, isNull);
    return;
  }
  expect(vmd, isNotNull);
  expect(vmd!.type, cv['type']);
  expect(vmd.functionExpr, cv['functionExpr']);
  expect(vmd.audioTranscript, cv['audioTranscript']);
  expect(vmd.speakerName, cv['speakerName']);

  final canonPoints = (cv['points'] as List<dynamic>?)
      ?.map((e) => e as Map<String, dynamic>)
      .toList();
  if (canonPoints == null) {
    expect(vmd.points, isNull);
  } else {
    expect(vmd.points, isNotNull);
    expect(vmd.points!.length, canonPoints.length);
    for (var i = 0; i < canonPoints.length; i++) {
      expect(vmd.points![i], canonPoints[i]);
    }
  }
}

void _assertFlashcardMatches(LessonFlashcard card, Map<String, dynamic> canon) {
  expect(card.id, canon['id']);
  expect(card.front, canon['front']);
  expect(card.backUz, canon['backUz']);
  expect(card.backRu, canon['backRu'] ?? '');
  expect(card.partOfSpeech, canon['partOfSpeech']);
  expect(card.ipa, canon['ipa']);
  expect(card.ipaAmE, canon['ipaAmE']);
  expect(card.cefrLevel, canon['cefrLevel']);
  expect(card.example, canon['example']);
  expect(card.exampleUz, canon['exampleUz'] ?? '');
  expect(card.exampleRu, canon['exampleRu'] ?? '');
  expect(card.audioSrc, canon['audioSrc']);
  expect(card.imageSrc, canon['imageSrc']);
  expect(card.alt, canon['alt']);
  expect(card.altRu, canon['altRu']);
}

void _assertQuestionMatches(
  Question q,
  Map<String, dynamic> canon, {
  bool expectPermuted = false,
  Question? rawQuestion,
}) {
  expect(q.id, canon['id']);
  expect(q.courseId, canon['courseId']);
  expect(q.skillId, canon['skillId']);
  expect(q.skillDomain, canon['skillDomain']);
  expect(q.cefrLevel, canon['cefrLevel']);
  expect(q.topic, canon['topic']);
  expect(q.difficulty.name, canon['difficulty']);
  expect(_questionModeToCanonical(q.mode), canon['questionType']);
  expect(q.evaluationMode, canon['evaluationMode'] ?? 'deterministic');
  expect(q.isPlacement, canon['isPlacement'] ?? false);
  expect(q.text, canon['text']);
  expect(q.textRu, canon['textRu']);
  expect(q.contextSnippet, canon['contextSnippet']);
  expect(q.blankTemplate, canon['blankTemplate']);
  expect(q.sentenceWithError, canon['sentenceWithError']);
  expect(q.dialogueContext, _asStringList(canon['dialogueContext']));

  final canonOptions = _asStringList(canon['options']);
  if (!expectPermuted) {
    expect(q.options, canonOptions);
    if (q.usesOptionSelection) {
      expect(q.correctIndex, canon['correctIndex']);
    }
  } else {
    expect(rawQuestion, isNotNull, reason: 'Missing rawQuestion for ${q.id}');
    final expectedPermuted = permuteQuestionOptions(rawQuestion!);
    expect(q.options, expectedPermuted.options);
    if (q.usesOptionSelection) {
      expect(q.correctIndex, expectedPermuted.correctIndex);
      expect(
        q.options[q.correctIndex],
        canonOptions[canon['correctIndex'] as int],
      );
    }
  }

  expect(q.acceptedAnswers, _asStringList(canon['acceptedAnswers']));

  final canonPairs = (canon['matchPairs'] as List<dynamic>? ?? [])
      .map((e) => e as Map<String, dynamic>)
      .toList();
  expect(q.matchPairs.length, canonPairs.length);
  for (var i = 0; i < canonPairs.length; i++) {
    expect(q.matchPairs[i].id, canonPairs[i]['id']);
    expect(q.matchPairs[i].left, canonPairs[i]['left']);
    expect(q.matchPairs[i].right, canonPairs[i]['right']);
  }

  expect(q.orderedTokens, _asStringList(canon['orderedTokens']));
  expect(q.sampleResponse, canon['sampleResponse']);

  final canonRubric = (canon['rubricCriteria'] as List<dynamic>? ?? [])
      .map((e) => e as Map<String, dynamic>)
      .toList();
  expect(q.rubricCriteria.length, canonRubric.length);
  for (var i = 0; i < canonRubric.length; i++) {
    expect(q.rubricCriteria[i].id, canonRubric[i]['id']);
    expect(q.rubricCriteria[i].labelUz, canonRubric[i]['labelUz']);
    expect(q.rubricCriteria[i].labelRu, canonRubric[i]['labelRu']);
  }

  expect(q.selfAssessmentNoticeUz, canon['selfAssessmentNoticeUz']);
  expect(q.selfAssessmentNoticeRu, canon['selfAssessmentNoticeRu']);

  final canonFeedback =
      (canon['mistakeFeedbackByOption'] as Map<String, dynamic>? ?? {});
  expect(q.mistakeFeedbackByOption.keys.toSet(), canonFeedback.keys.toSet());
  for (final entry in canonFeedback.entries) {
    final expected = entry.value as Map<String, dynamic>;
    final actual = q.mistakeFeedbackByOption[entry.key];
    expect(actual, isNotNull);
    expect(actual!.uz, expected['uz']);
    expect(actual.ru, expected['ru']);
  }

  expect(q.explanation, canon['explanation']);
  expect(q.explanationRu, canon['explanationRu']);
  expect(q.wrongFeedback, canon['wrongFeedback']);
  expect(q.wrongFeedbackRu, canon['wrongFeedbackRu']);
  expect(q.audioSimText, canon['audioSimText']);
  expect(q.audioSimSpeaker, canon['audioSimSpeaker']);
  _assertMediaMatches(q.media, canon['media'] as Map<String, dynamic>?);
}

void _assertLessonMatches(
  Lesson lesson,
  Map<String, dynamic> canon, {
  bool expectPermuted = false,
  Lesson? rawLesson,
}) {
  expect(lesson.id, canon['id']);
  expect(lesson.courseId, canon['courseId']);
  expect(lesson.skillId, canon['skillId']);
  expect(lesson.skillDomain, canon['skillDomain']);
  expect(lesson.communicativeFocus, canon['communicativeFocus']);
  expect(lesson.cefrLevel, canon['cefrLevel']);
  expect(lesson.moduleId, canon['moduleId']);
  expect(lesson.unitId, canon['unitId']);
  expect(lesson.canDoObjective, canon['canDoObjective']);
  expect(lesson.canDoObjectiveRu, canon['canDoObjectiveRu']);
  expect(lesson.prerequisites, _asStringList(canon['prerequisites']));
  expect(lesson.title, canon['title']);
  expect(lesson.titleRu, canon['titleRu']);
  expect(lesson.estimatedMinutes, canon['estimatedMinutes']);
  expect(lesson.summary, canon['summary']);
  expect(lesson.summaryRu, canon['summaryRu']);
  expect(lesson.requiresMastery, canon['requiresMastery'] ?? false);
  expect(lesson.officialCefrDisclaimerUz, canon['officialCefrDisclaimerUz']);
  expect(lesson.officialCefrDisclaimerRu, canon['officialCefrDisclaimerRu']);

  final canonSteps = (canon['steps'] as List<dynamic>)
      .map((e) => e as Map<String, dynamic>)
      .toList();
  expect(lesson.steps.length, canonSteps.length);

  for (var i = 0; i < canonSteps.length; i++) {
    final step = lesson.steps[i];
    final cs = canonSteps[i];
    expect(step.id, cs['id']);
    expect(step.stepNumber, cs['stepNumber']);
    expect(_stepTypeToCanonical(step.type), cs['type']);
    expect(step.title, cs['title']);
    expect(step.titleRu, cs['titleRu']);
    expect(step.subtitle, cs['subtitle']);
    expect(step.subtitleRu, cs['subtitleRu']);
    expect(step.content, cs['content']);
    expect(step.contentRu, cs['contentRu']);
    expect(
      step.highlightNotes,
      cs['highlightNotes'] == null ? isNull : _asStringList(cs['highlightNotes']),
    );
    expect(
      step.highlightNotesRu,
      cs['highlightNotesRu'] == null
          ? isNull
          : _asStringList(cs['highlightNotesRu']),
    );
    expect(step.masteryCheckpoint, cs['masteryCheckpoint']);

    _assertVisualModelDataMatches(
      step.visualModelData,
      cs['visualModelData'] as Map<String, dynamic>?,
    );
    _assertMediaMatches(step.media, cs['media'] as Map<String, dynamic>?);

    final cfList = (cs['flashcards'] as List<dynamic>?)
        ?.map((e) => e as Map<String, dynamic>)
        .toList();
    if (cfList == null) {
      expect(step.flashcards, isNull);
    } else {
      expect(step.flashcards, isNotNull);
      expect(step.flashcards!.length, cfList.length);
      for (var j = 0; j < cfList.length; j++) {
        _assertFlashcardMatches(step.flashcards![j], cfList[j]);
      }
    }

    final cq = cs['interactiveQuestion'] as Map<String, dynamic>?;
    if (cq == null) {
      expect(step.interactiveQuestion, isNull);
    } else {
      expect(step.interactiveQuestion, isNotNull);
      _assertQuestionMatches(
        step.interactiveQuestion!,
        cq,
        expectPermuted: expectPermuted,
        rawQuestion: rawLesson?.steps[i].interactiveQuestion,
      );
    }
  }

  _assertQuestionMatches(
    lesson.reinforcementExercise,
    canon['reinforcementExercise'] as Map<String, dynamic>,
    expectPermuted: expectPermuted,
    rawQuestion: rawLesson?.reinforcementExercise,
  );

  final altQ = canon['alternateExercise'] as Map<String, dynamic>?;
  if (altQ == null) {
    expect(lesson.alternateExercise, isNull);
  } else {
    expect(lesson.alternateExercise, isNotNull);
    _assertQuestionMatches(
      lesson.alternateExercise!,
      altQ,
      expectPermuted: expectPermuted,
      rawQuestion: rawLesson?.alternateExercise,
    );
  }
}

void _assertRoadmapNodesMatch(
  List<LearningPathNode> nodeList,
  List<Map<String, dynamic>> canonNodes,
) {
  expect(nodeList.length, canonNodes.length);
  for (var i = 0; i < canonNodes.length; i++) {
    final n = nodeList[i];
    final cn = canonNodes[i];
    expect(n.id, cn['id']);
    expect(n.order, (cn['order'] as num).toDouble());
    expect(n.courseId, cn['courseId']);
    expect(n.skillId, cn['skillId']);
    expect(n.skillDomain, cn['skillDomain']);
    expect(n.cefrLevel, cn['cefrLevel']);
    expect(n.moduleId, cn['moduleId']);
    expect(n.moduleTitle, cn['moduleTitle']);
    expect(n.moduleTitleRu, cn['moduleTitleRu']);
    expect(n.unitId, cn['unitId']);
    expect(n.canDoObjective, cn['canDoObjective']);
    expect(n.canDoObjectiveRu, cn['canDoObjectiveRu']);
    expect(_nodeKindToCanonical(n.nodeKind), cn['nodeKind']);
    expect(n.isCheckpoint, cn['isCheckpoint'] ?? false);
    expect(n.hasRichExercise, cn['hasRichExercise'] ?? false);
    expect(n.taskKind, cn['taskKind']);
    expect(n.title, cn['title']);
    expect(n.titleRu, cn['titleRu']);
    expect(n.description, cn['description']);
    expect(n.descriptionRu, cn['descriptionRu']);
    expect(n.prerequisites, _asStringList(cn['prerequisites']));
    expect(n.requiredScore, cn['requiredScore']);
    expect(_nodeStatusToCanonical(n.status), cn['status']);
    expect(n.isReinforcement, cn['isReinforcement']);
    expect(n.targetLessonId, cn['targetLessonId']);
    expect(n.estimatedMinutes, cn['estimatedMinutes']);
  }
}

class _LevelParitySpec {
  final String level;
  final Map<String, dynamic> canonJson;
  final Map<String, Lesson> rawLessons;
  final List<LessonFlashcard> rawFlashcards;
  final int expectedLessons;
  final int expectedQuestions;
  final int expectedFlashcards;
  final int expectedStepMedia;
  final bool expectPermutedInSeed;

  const _LevelParitySpec({
    required this.level,
    required this.canonJson,
    required this.rawLessons,
    required this.rawFlashcards,
    required this.expectedLessons,
    required this.expectedQuestions,
    required this.expectedFlashcards,
    required this.expectedStepMedia,
    required this.expectPermutedInSeed,
  });
}

void main() {
  final skeletonJson = readCanonicalJson('content/english/cefr-skeleton.json');
  final a1Json = readCanonicalJson('content/english/a1-curriculum.json');
  final a2Json = readCanonicalJson('content/english/a2-curriculum.json');
  final b1Json = readCanonicalJson('content/english/b1-curriculum.json');
  final starterMediaJson = readCanonicalJson('content/english/starter-media.json');
  final a1MediaJson = readCanonicalJson('content/english/a1-media.json');
  final a2MediaJson = readCanonicalJson('content/english/a2-media.json');
  final b1MediaJson = readCanonicalJson('content/english/b1-media.json');

  group('EnglishCurriculumParity — Flutter vs Canonical JSON', () {
    test('CEFR skeleton matches cefr-skeleton.json 1:1 (Pre-A1, 6 levels, 22 modules, disclaimers)', () {
      final preA1 =
          skeletonJson['preA1FoundationAlignment'] as Map<String, dynamic>;
      expect(cefrPreA1TargetLevel, preA1['cefrLevel']);
      expect(cefrPreA1TitleUz, preA1['titleUz']);
      expect(cefrPreA1TitleRu, preA1['titleRu']);
      expect(cefrPreA1RationaleUz, preA1['noteUz']);
      expect(cefrPreA1RationaleRu, preA1['noteRu']);
      expect(cefrPreA1LessonIds, _asStringList(preA1['foundationLessonIds']));
      expect(
        cefrOfficialDisclaimerUz,
        skeletonJson['officialCefrDisclaimerUz'],
      );
      expect(
        cefrOfficialDisclaimerRu,
        skeletonJson['officialCefrDisclaimerRu'],
      );

      final canonLevels = (skeletonJson['levels'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
      expect(cefrSkeletonLevels.length, 6);
      expect(canonLevels.length, 6);

      const expectedCounts = [4, 4, 4, 4, 3, 3];
      var totalModules = 0;

      for (var i = 0; i < canonLevels.length; i++) {
        final actualLvl = cefrSkeletonLevels[i];
        final canonLvl = canonLevels[i];
        expect(actualLvl.cefrLevel, canonLvl['cefrLevel']);
        expect(actualLvl.order, canonLvl['order']);
        expect(actualLvl.titleUz, canonLvl['titleUz']);
        expect(actualLvl.titleRu, canonLvl['titleRu']);
        expect(
          actualLvl.canDoObjectivesUz,
          _asStringList(canonLvl['canDoObjectivesUz']),
        );
        expect(
          actualLvl.canDoObjectivesRu,
          _asStringList(canonLvl['canDoObjectivesRu']),
        );
        expect(
          actualLvl.prerequisites,
          _asStringList(canonLvl['prerequisites']),
        );
        expect(
          actualLvl.grammarScope,
          _asStringList(canonLvl['grammarScope']),
        );
        expect(
          actualLvl.vocabularyThemes,
          _asStringList(canonLvl['vocabularyThemes']),
        );
        expect(
          actualLvl.plannedLessonIds,
          _asStringList(canonLvl['plannedLessonIds']),
        );
        expect(
          actualLvl.exitAssessmentNodeId,
          canonLvl['exitAssessmentNodeId'],
        );

        final canonMods = (canonLvl['modules'] as List<dynamic>)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        expect(actualLvl.modules.length, expectedCounts[i]);
        expect(canonMods.length, expectedCounts[i]);
        totalModules += actualLvl.modules.length;

        for (var m = 0; m < canonMods.length; m++) {
          final actualMod = actualLvl.modules[m];
          final canonMod = canonMods[m];
          expect(actualMod.id, canonMod['id']);
          expect(actualMod.cefrLevel, canonMod['cefrLevel']);
          expect(actualMod.order, canonMod['order']);
          expect(actualMod.titleUz, canonMod['titleUz']);
          expect(actualMod.titleRu, canonMod['titleRu']);
          expect(actualMod.canDoObjectiveUz, canonMod['canDoObjectiveUz']);
          expect(actualMod.canDoObjectiveRu, canonMod['canDoObjectiveRu']);
          expect(
            actualMod.prerequisites,
            _asStringList(canonMod['prerequisites']),
          );
          expect(
            actualMod.grammarScope,
            _asStringList(canonMod['grammarScope']),
          );
          expect(
            actualMod.vocabularyThemes,
            _asStringList(canonMod['vocabularyThemes']),
          );
          expect(
            actualMod.plannedLessonIds,
            _asStringList(canonMod['plannedLessonIds']),
          );
          expect(actualMod.checkpointNodeId, canonMod['checkpointNodeId']);
        }
      }
      expect(totalModules, 22);
    });

    test('course_eng_01 matches combined A1+A2+B1 order (33 lessons, listening_01 first), skills, and starter/foundation IDs', () {
      final course = seedCourses.firstWhere((c) => c.id == 'course_eng_01');
      final a1Order = _asStringList(a1Json['lessonsOrder']);
      final a2Order = _asStringList(a2Json['lessonsOrder']);
      final b1Order = _asStringList(b1Json['lessonsOrder']);
      expect(a1Order.length, 17);
      expect(a2Order.length, 8);
      expect(b1Order.length, 8);

      final combinedOrder = [...a1Order, ...a2Order, ...b1Order];
      expect(combinedOrder.length, 33);
      expect(combinedOrder.toSet().length, 33);
      expect(combinedOrder.first, 'lesson_eng_listening_01');
      expect(course.lessons.first, 'lesson_eng_listening_01');
      expect(course.lessons, combinedOrder);

      for (final levelJson in [a1Json, a2Json, b1Json]) {
        expect(course.skills, _asStringList(levelJson['skills']));
        expect(course.starterLessonId, levelJson['starterLessonId']);
        expect(
          course.foundationLessonIds,
          _asStringList(levelJson['foundationLessonIds']),
        );
      }
    });

    test('all 31 roadmap nodes (A1+A2+B1, order 1..31) & prerequisite chains match canonical JSON 1:1', () {
      final canonA1Nodes = (a1Json['roadmapNodes'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
      final canonA2Nodes = (a2Json['roadmapNodes'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
      final canonB1Nodes = (b1Json['roadmapNodes'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
      expect(canonA1Nodes.length, 15);
      expect(canonA2Nodes.length, 8);
      expect(canonB1Nodes.length, 8);

      final canonCombinedNodes = [
        ...canonA1Nodes,
        ...canonA2Nodes,
        ...canonB1Nodes,
      ];
      expect(canonCombinedNodes.length, 31);

      final seedNodes = seedRoadmapNodes['course_eng_01'];
      expect(seedNodes, isNotNull);

      _assertRoadmapNodesMatch(a1RoadmapNodes, canonA1Nodes);
      _assertRoadmapNodesMatch(a2RoadmapNodes, canonA2Nodes);
      _assertRoadmapNodesMatch(b1RoadmapNodes, canonB1Nodes);
      _assertRoadmapNodesMatch(seedNodes!, canonCombinedNodes);

      for (var i = 0; i < seedNodes.length; i++) {
        expect(seedNodes[i].order, (i + 1).toDouble());
      }

      // Cross-level and intra-level prerequisite chains
      expect(a1RoadmapNodes.last.id, 'node_eng_a1_exit');
      expect(a2RoadmapNodes.first.prerequisites, ['node_eng_a1_exit']);
      for (var i = 1; i < a2RoadmapNodes.length; i++) {
        expect(a2RoadmapNodes[i].prerequisites, [a2RoadmapNodes[i - 1].id]);
      }
      expect(a2RoadmapNodes.last.id, 'node_eng_a2_exit');

      expect(b1RoadmapNodes.first.prerequisites, ['node_eng_a2_exit']);
      for (var i = 1; i < b1RoadmapNodes.length; i++) {
        expect(b1RoadmapNodes[i].prerequisites, [b1RoadmapNodes[i - 1].id]);
      }
      expect(b1RoadmapNodes.last.id, 'node_eng_b1_exit');

      // Structural referential integrity across all 31 nodes & 33 lessons
      final nodeIds = seedNodes.map((n) => n.id).toSet();
      final allLessons = {
        ...a1LessonsData,
        ...a2LessonsData,
        ...b1LessonsData,
      };
      for (final node in seedNodes) {
        expect(node.targetLessonId, isNotNull);
        final targetLesson = allLessons[node.targetLessonId!];
        expect(targetLesson, isNotNull, reason: 'Missing lesson ${node.targetLessonId}');
        expect(targetLesson!.cefrLevel, node.cefrLevel);
        expect(targetLesson.moduleId, node.moduleId);
        expect(targetLesson.unitId, node.unitId);
        for (final prereq in node.prerequisites) {
          expect(nodeIds.contains(prereq), isTrue, reason: 'Missing prereq $prereq');
        }
      }
    });

    test('all 33 A1+A2+B1 lessons, 98 questions, 9 modes, permutation parity, 49 flashcards, 25 step media, and 83 disk assets match 1:1', () {
      final levelSpecs = [
        _LevelParitySpec(
          level: 'A1',
          canonJson: a1Json,
          rawLessons: a1LessonsData,
          rawFlashcards: a1AllFlashcards,
          expectedLessons: 17,
          expectedQuestions: 42,
          expectedFlashcards: 17,
          expectedStepMedia: 11,
          expectPermutedInSeed: false,
        ),
        _LevelParitySpec(
          level: 'A2',
          canonJson: a2Json,
          rawLessons: a2LessonsData,
          rawFlashcards: a2AllFlashcards,
          expectedLessons: 8,
          expectedQuestions: 27,
          expectedFlashcards: 16,
          expectedStepMedia: 8,
          expectPermutedInSeed: true,
        ),
        _LevelParitySpec(
          level: 'B1',
          canonJson: b1Json,
          rawLessons: b1LessonsData,
          rawFlashcards: b1AllFlashcards,
          expectedLessons: 8,
          expectedQuestions: 29,
          expectedFlashcards: 16,
          expectedStepMedia: 6,
          expectPermutedInSeed: true,
        ),
      ];

      final seenLessonIds = <String>{};
      final seenQuestionIds = <String>{};
      final combinedModes = <QuestionMode>{};
      final combinedCanonFlashcards = <Map<String, dynamic>>[];
      final combinedActualFlashcards = <LessonFlashcard>[];
      final referencedMediaSources = <String>{};
      final permutedA2B1Indices = <int>{};
      var totalStepMedia = 0;

      for (final spec in levelSpecs) {
        final canonLessons = (spec.canonJson['lessons'] as List<dynamic>)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        expect(canonLessons.length, spec.expectedLessons);
        expect(spec.rawLessons.length, spec.expectedLessons);

        final levelQuestionIds = <String>{};
        final levelModes = <QuestionMode>{};
        final levelCanonFlashcards = <Map<String, dynamic>>[];
        var levelStepMedia = 0;

        for (final cl in canonLessons) {
          final id = cl['id'] as String;
          seenLessonIds.add(id);

          final rawLesson = spec.rawLessons[id];
          final seedLesson = seedLessons[id];
          expect(rawLesson, isNotNull, reason: 'Missing $id in ${spec.level} rawLessons');
          expect(seedLesson, isNotNull, reason: 'Missing $id in seedLessons');

          _assertLessonMatches(rawLesson!, cl);
          _assertLessonMatches(
            seedLesson!,
            cl,
            expectPermuted: spec.expectPermutedInSeed,
            rawLesson: rawLesson,
          );

          if (id == 'lesson_eng_starter' || id == 'lesson_eng_foundation_02') {
            final starter = starterLessons[id];
            expect(starter, isNotNull, reason: 'Missing $id in starterLessons');
            _assertLessonMatches(starter!, cl);
          }

          void recordQuestion(Question rawQ, Question seedQ) {
            levelQuestionIds.add(rawQ.id);
            seenQuestionIds.add(rawQ.id);
            levelModes.add(rawQ.mode);
            combinedModes.add(rawQ.mode);
            if (rawQ.media != null) {
              referencedMediaSources.add(rawQ.media!.source);
              if (rawQ.media!.posterImage != null) {
                referencedMediaSources.add(rawQ.media!.posterImage!);
              }
            }
            if (spec.expectPermutedInSeed && rawQ.usesOptionSelection) {
              expect(rawQ.correctIndex, 0);
              permutedA2B1Indices.add(seedQ.correctIndex);
            }
          }

          for (var sIdx = 0; sIdx < rawLesson.steps.length; sIdx++) {
            final step = rawLesson.steps[sIdx];
            final seedStep = seedLesson.steps[sIdx];
            if (step.media != null) {
              levelStepMedia += 1;
              totalStepMedia += 1;
              referencedMediaSources.add(step.media!.source);
              if (step.media!.posterImage != null) {
                referencedMediaSources.add(step.media!.posterImage!);
              }
            }
            if (step.flashcards != null) {
              for (final card in step.flashcards!) {
                if (card.audioSrc != null) referencedMediaSources.add(card.audioSrc!);
                if (card.imageSrc != null) referencedMediaSources.add(card.imageSrc!);
              }
            }
            if (step.interactiveQuestion != null) {
              recordQuestion(step.interactiveQuestion!, seedStep.interactiveQuestion!);
            }
          }
          recordQuestion(
            rawLesson.reinforcementExercise,
            seedLesson.reinforcementExercise,
          );
          if (rawLesson.alternateExercise != null) {
            recordQuestion(
              rawLesson.alternateExercise!,
              seedLesson.alternateExercise!,
            );
          }

          for (final rawStep in (cl['steps'] as List<dynamic>)) {
            final cs = rawStep as Map<String, dynamic>;
            final cards = cs['flashcards'] as List<dynamic>?;
            if (cards != null) {
              levelCanonFlashcards.addAll(cards.cast<Map<String, dynamic>>());
            }
          }
        }

        expect(levelStepMedia, spec.expectedStepMedia);
        expect(levelQuestionIds.length, spec.expectedQuestions);
        expect(levelModes, containsAll(QuestionMode.values));
        expect(levelCanonFlashcards.length, spec.expectedFlashcards);
        expect(spec.rawFlashcards.length, spec.expectedFlashcards);
        for (var i = 0; i < levelCanonFlashcards.length; i++) {
          _assertFlashcardMatches(spec.rawFlashcards[i], levelCanonFlashcards[i]);
        }
        combinedCanonFlashcards.addAll(levelCanonFlashcards);
        combinedActualFlashcards.addAll(spec.rawFlashcards);
      }

      expect(seenLessonIds.length, 33);
      expect(seenQuestionIds.length, 98);
      expect(combinedModes, containsAll(QuestionMode.values));
      expect(totalStepMedia, 25);
      expect(permutedA2B1Indices.length, greaterThanOrEqualTo(3));
      expect(combinedCanonFlashcards.length, 49);
      expect(combinedActualFlashcards.length, 49);
      expect(combinedActualFlashcards.map((c) => c.id).toSet().length, 49);

      // Verify all 5 active asset directories in pubspec.yaml (and zero B2-C2),
      // confirm deleted B2 paths stay removed, and verify all 83 lesson + 3 placement = 86 assets
      final repoRoot = resolveRepoRootPath();
      final pubspecText = resolveRepoFile('mobile/pubspec.yaml').readAsStringSync();
      final flutterAssets = _extractPubspecFlutterAssets(pubspecText);
      expect(flutterAssets.contains('assets/lesson_media/english/'), isTrue);
      expect(flutterAssets.contains('assets/lesson_media/english/a1/'), isTrue);
      expect(flutterAssets.contains('assets/lesson_media/english/a2/'), isTrue);
      expect(flutterAssets.contains('assets/lesson_media/english/b1/'), isTrue);
      expect(flutterAssets.contains('assets/lesson_media/english/placement/'), isTrue);
      expect(flutterAssets.contains('assets/lesson_media/english/b2/'), isFalse);
      expect(flutterAssets.contains('assets/lesson_media/english/c1/'), isFalse);
      expect(flutterAssets.contains('assets/lesson_media/english/c2/'), isFalse);

      for (final deletedRel in const [
        'content/english/b2-media.json',
        'content/english/svg/b2',
        'public/lesson-media/english/b2',
        'mobile/assets/lesson_media/english/b2',
      ]) {
        final fullPath = '$repoRoot/$deletedRel';
        expect(File(fullPath).existsSync(), isFalse, reason: 'Deleted B2 file exists: $deletedRel');
        expect(Directory(fullPath).existsSync(), isFalse, reason: 'Deleted B2 dir exists: $deletedRel');
      }

      final placementMediaJson = readCanonicalJson('content/english/placement-media.json');
      final placementAudio = (placementMediaJson['audio'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
      expect(placementAudio.length, 3);

      final sources = <String>{};
      var wavCount = 0;
      var pngCount = 0;
      for (final manifest in [
        starterMediaJson,
        a1MediaJson,
        a2MediaJson,
        b1MediaJson,
      ]) {
        for (final item in (manifest['audio'] as List<dynamic>)) {
          final src = (item as Map<String, dynamic>)['canonicalSource'] as String;
          sources.add(src);
          wavCount += 1;
        }
        for (final item in (manifest['images'] as List<dynamic>)) {
          final src = (item as Map<String, dynamic>)['canonicalSource'] as String;
          sources.add(src);
          pngCount += 1;
        }
      }
      expect(wavCount, 68);
      expect(pngCount, 15);
      expect(sources.length, 83);
      expect(sources, referencedMediaSources);

      final allDiskSources = <String>{
        ...sources,
        ...placementAudio.map((item) => item['canonicalSource'] as String),
      };
      expect(allDiskSources.length, 86);

      for (final src in allDiskSources) {
        _assertDiskMediaAssetMatches(src, repoRoot);
      }
    });

    test('enforces 1:1 placement parity across 12 A1-B1 questions, 3 WAVs, permutation, and non-collision', () {
      final repoRoot = resolveRepoRootPath();
      final placementJson = readCanonicalJson('content/english/placement-questions.json');
      final placementMediaJson = readCanonicalJson('content/english/placement-media.json');

      expect(placementJson['schemaVersion'], 1);
      expect(placementJson['documentType'], 'placement_bank');
      expect(placementJson['courseId'], 'course_eng_01');
      expect(_asStringList(placementJson['cefrRange']), ['A1', 'A2', 'B1']);

      final canonQuestions = (placementJson['questions'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
      expect(canonQuestions.length, 12);

      expect(placementMediaJson['schemaVersion'], 1);
      expect(placementMediaJson['courseId'], 'course_eng_01');
      expect(placementMediaJson['language'], 'en');
      expect(placementMediaJson['reviewStatus'], 'approved');
      final canonPlacementAudio = (placementMediaJson['audio'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
      final canonPlacementImages = (placementMediaJson['images'] as List<dynamic>);
      expect(canonPlacementAudio.length, 3);
      expect(canonPlacementImages.length, 0);

      final audioById = <String, Map<String, dynamic>>{
        for (final entry in canonPlacementAudio) entry['id'] as String: entry,
      };
      expect(audioById.length, 3);

      // Collect all 98 A1-B1 lesson question IDs and prompts to ensure zero collisions
      final lessonQuestionIds = <String>{};
      final lessonPrompts = <String>{};
      for (final lesson in [
        ...a1LessonsData.values,
        ...a2LessonsData.values,
        ...b1LessonsData.values,
      ]) {
        for (final step in lesson.steps) {
          final iq = step.interactiveQuestion;
          if (iq != null) {
            lessonQuestionIds.add(iq.id);
            lessonPrompts.add(iq.text.trim());
            if (iq.textRu != null && iq.textRu!.trim().isNotEmpty) {
              lessonPrompts.add(iq.textRu!.trim());
            }
          }
        }
        lessonQuestionIds.add(lesson.reinforcementExercise.id);
        lessonPrompts.add(lesson.reinforcementExercise.text.trim());
        if (lesson.reinforcementExercise.textRu != null &&
            lesson.reinforcementExercise.textRu!.trim().isNotEmpty) {
          lessonPrompts.add(lesson.reinforcementExercise.textRu!.trim());
        }
        if (lesson.alternateExercise != null) {
          lessonQuestionIds.add(lesson.alternateExercise!.id);
          lessonPrompts.add(lesson.alternateExercise!.text.trim());
          if (lesson.alternateExercise!.textRu != null &&
              lesson.alternateExercise!.textRu!.trim().isNotEmpty) {
            lessonPrompts.add(lesson.alternateExercise!.textRu!.trim());
          }
        }
      }
      expect(lessonQuestionIds.length, 98);

      const expectedDifficultyByCefr = {
        'A1': 'easy',
        'A2': 'medium',
        'B1': 'hard',
      };
      final skillLevels = <String, Set<String>>{};

      final seedQuestions = placementQuestionsData['course_eng_01'];
      expect(seedQuestions, isNotNull);
      expect(englishPlacementQuestionsRaw.length, 12);
      expect(seedQuestions!.length, 12);

      final permutedIndices = <int>{};

      for (var i = 0; i < canonQuestions.length; i++) {
        final cq = canonQuestions[i];
        final rawQ = englishPlacementQuestionsRaw[i];
        final seedQ = seedQuestions[i];

        final cefr = cq['cefrLevel'] as String?;
        expect(['A1', 'A2', 'B1'].contains(cefr), isTrue);
        expect(['B2', 'C1', 'C2'].contains(cefr), isFalse);
        expect(cq['difficulty'], expectedDifficultyByCefr[cefr]);
        expect(cq['isPlacement'], isTrue);
        expect(cq['questionType'], 'multiple_choice');

        final options = _asStringList(cq['options']);
        expect(options.length, 4);
        final text = cq['text'] as String;
        final textRu = cq['textRu'] as String?;
        expect(text.contains('Audio context:'), isFalse);
        expect((textRu ?? '').contains('Audio context:'), isFalse);
        expect(lessonQuestionIds.contains(cq['id']), isFalse);
        expect(lessonPrompts.contains(text.trim()), isFalse);
        if (textRu != null) {
          expect(lessonPrompts.contains(textRu.trim()), isFalse);
        }

        final feedbackMap = cq['mistakeFeedbackByOption'] as Map<String, dynamic>?;
        expect(feedbackMap, isNotNull);
        expect(feedbackMap!.keys.toSet(), options.toSet());
        for (final opt in options) {
          final fb = feedbackMap[opt] as Map<String, dynamic>;
          expect((fb['uz'] as String).trim().isNotEmpty, isTrue);
          expect((fb['ru'] as String).trim().isNotEmpty, isTrue);
        }

        final skillId = cq['skillId'] as String;
        skillLevels.putIfAbsent(skillId, () => <String>{}).add(cefr!);

        _assertQuestionMatches(rawQ, cq, expectPermuted: false);
        _assertQuestionMatches(
          seedQ,
          cq,
          expectPermuted: true,
          rawQuestion: rawQ,
        );
        permutedIndices.add(seedQ.correctIndex);

        if (skillId == 'skill_eng_listening') {
          final mediaMap = cq['media'] as Map<String, dynamic>?;
          expect(mediaMap, isNotNull);
          final parsed = LessonMedia.tryParse(mediaMap);
          expect(parsed, isNotNull);
          expect(parsed!.kind, LessonMediaKind.audio);
          expect(parsed.language, LessonMediaLanguage.en);
          expect(parsed.provenance, 'local-system-speech');
          expect(parsed.durationSeconds, greaterThan(0));

          final manifestEntry = audioById[mediaMap!['id']];
          expect(manifestEntry, isNotNull);
          expect(manifestEntry!['canonicalSource'], mediaMap['source']);
          expect(manifestEntry['transcript'], mediaMap['transcript']);
          expect(manifestEntry['durationSeconds'], mediaMap['durationSeconds']);

          final turns = (mediaMap['transcript'] as String)
              .split('\n')
              .map((line) => line.replaceFirst(RegExp(r'^[^:]+:\s*'), '').trim())
              .where((turn) => turn.length >= 20)
              .toList();
          expect(turns.isNotEmpty, isTrue);
          for (final turn in turns) {
            expect(text.contains(turn), isFalse);
            expect((textRu ?? '').contains(turn), isFalse);
          }

          _assertDiskMediaAssetMatches(mediaMap['source'] as String, repoRoot);
        } else {
          expect(cq['media'], isNull);
          expect(cq['audioSimText'], isNull);
          expect(rawQ.media, isNull);
          expect(rawQ.audioSimText, isNull);
          expect(seedQ.media, isNull);
          expect(seedQ.audioSimText, isNull);
        }
      }

      expect(
        skillLevels.keys.toSet(),
        {
          'skill_eng_vocab',
          'skill_eng_grammar',
          'skill_eng_listening',
          'skill_eng_reading',
        },
      );
      for (final levels in skillLevels.values) {
        expect(levels, {'A1', 'A2', 'B1'});
      }
      expect(permutedIndices.length, greaterThanOrEqualTo(3));

      final rawReadingA1 = englishPlacementQuestionsRaw.firstWhere(
        (q) => q.id == 'q_eng_place_reading_a1',
      );
      final seedReadingA1 = seedQuestions.firstWhere(
        (q) => q.id == 'q_eng_place_reading_a1',
      );
      expect(rawReadingA1.correctIndex, 2);
      expect(rawReadingA1.options[2], 'On Wednesday at 11:00 AM');
      expect(seedReadingA1.correctIndex, 3);
      expect(seedReadingA1.options[3], 'On Wednesday at 11:00 AM');
    });

    test('T2-F4-03 listening 03:15 AM/PM disambiguation holds on Flutter datasources', () {
      final listening = a1LessonsData['lesson_eng_listening_01']!;
      final audioStep = listening.steps.firstWhere(
        (s) => s.media?.kind == LessonMediaKind.audio,
      );
      expect(audioStep.media!.transcript, contains('quarter past three'));
      expect(audioStep.media!.transcript, contains('in the afternoon'));

      final q = listening.steps
          .firstWhere((s) => s.interactiveQuestion?.id == 'q_eng_listening_01')
          .interactiveQuestion!;
      expect(q.options, contains('03:15 (quarter past three AM)'));
      expect(q.options, contains('15:15 (quarter past three)'));
      expect(q.options[q.correctIndex], '15:15 (quarter past three)');
      expect(
        q.mistakeFeedbackByOption['03:15 (quarter past three AM)']?.uz,
        contains('in the afternoon'),
      );
      expect(
        q.mistakeFeedbackByOption['03:15 (quarter past three AM)']?.ru,
        contains('in the afternoon'),
      );
    });
  });
}
