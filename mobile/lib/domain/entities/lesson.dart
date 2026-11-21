import 'lesson_media.dart';
import 'question.dart';

enum LessonStepType {
  concept,
  formula,
  visualExample,
  audioSimulation,
  flashcard,
  interactiveQuestion,
}

class LessonFormulaData {
  final String latex;
  final String description;
  final List<Map<String, String>> variables;

  const LessonFormulaData({
    required this.latex,
    required this.description,
    required this.variables,
  });
}

class LessonVisualModelData {
  final String type; // 'function_graph' | 'audio_wave'
  final String? functionExpr;
  final List<Map<String, dynamic>>? points;
  final String? audioTranscript;
  final String? speakerName;

  const LessonVisualModelData({
    required this.type,
    this.functionExpr,
    this.points,
    this.audioTranscript,
    this.speakerName,
  });
}

class LessonFlashcard {
  final String id;
  final String front;
  final String backUz;
  final String backRu;
  final String? partOfSpeech;
  final String? ipa;
  final String? ipaAmE;
  final String? cefrLevel;
  final String example;
  final String exampleUz;
  final String exampleRu;
  final String? audioSrc;
  final String? imageSrc;
  final String? alt;
  final String? altRu;

  const LessonFlashcard({
    required this.id,
    required this.front,
    required this.backUz,
    this.backRu = '',
    this.partOfSpeech,
    this.ipa,
    this.ipaAmE,
    this.cefrLevel,
    required this.example,
    this.exampleUz = '',
    this.exampleRu = '',
    this.audioSrc,
    this.imageSrc,
    this.alt,
    this.altRu,
  });

  String? localizedAlt(String uiLocale) {
    if (uiLocale == 'ru') {
      final ru = altRu?.trim();
      if (ru != null && ru.isNotEmpty) return ru;
    }
    final uz = alt?.trim();
    return (uz != null && uz.isNotEmpty) ? uz : null;
  }
}

class LessonStep {
  final String id;
  final int stepNumber;
  final LessonStepType type;
  final String title;
  final String? titleRu;
  final String? subtitle;
  final String? subtitleRu;
  final String content;
  final String? contentRu;
  final List<String>? highlightNotes;
  final List<String>? highlightNotesRu;
  final String? masteryCheckpoint;
  final LessonFormulaData? formulaData;
  final LessonVisualModelData? visualModelData;
  final LessonMedia? media;
  final List<LessonFlashcard>? flashcards;
  final Question? interactiveQuestion;

  const LessonStep({
    required this.id,
    required this.stepNumber,
    required this.type,
    required this.title,
    this.titleRu,
    this.subtitle,
    this.subtitleRu,
    required this.content,
    this.contentRu,
    this.highlightNotes,
    this.highlightNotesRu,
    this.masteryCheckpoint,
    this.formulaData,
    this.visualModelData,
    this.media,
    this.flashcards,
    this.interactiveQuestion,
  });

  String localizedTitle(String uiLocale) {
    if (uiLocale == 'ru') {
      final ru = titleRu?.trim();
      if (ru != null && ru.isNotEmpty) return ru;
    }
    return title;
  }

  String? localizedSubtitle(String uiLocale) {
    if (uiLocale == 'ru') {
      final ru = subtitleRu?.trim();
      if (ru != null && ru.isNotEmpty) return ru;
    }
    return subtitle;
  }

  String localizedContent(String uiLocale) {
    if (uiLocale == 'ru') {
      final ru = contentRu?.trim();
      if (ru != null && ru.isNotEmpty) return ru;
    }
    return content;
  }

  List<String>? localizedHighlightNotes(String uiLocale) {
    if (uiLocale == 'ru' &&
        highlightNotesRu != null &&
        highlightNotesRu!.isNotEmpty) {
      return highlightNotesRu;
    }
    return highlightNotes;
  }
}

class Lesson {
  final String id;
  final String courseId;
  final String skillId;
  final String? skillDomain;
  final String? communicativeFocus;
  final String? cefrLevel;
  final String? moduleId;
  final String? unitId;
  final String? canDoObjective;
  final String? canDoObjectiveRu;
  final List<String> prerequisites;
  final String title;
  final String? titleRu;
  final int estimatedMinutes;
  final String summary;
  final String? summaryRu;
  final String? officialCefrDisclaimerUz;
  final String? officialCefrDisclaimerRu;
  final List<LessonStep> steps;
  final Question reinforcementExercise;
  final Question? alternateExercise;
  final bool requiresMastery;

  const Lesson({
    required this.id,
    required this.courseId,
    required this.skillId,
    this.skillDomain,
    this.communicativeFocus,
    this.cefrLevel,
    this.moduleId,
    this.unitId,
    this.canDoObjective,
    this.canDoObjectiveRu,
    this.prerequisites = const [],
    required this.title,
    this.titleRu,
    required this.estimatedMinutes,
    required this.summary,
    this.summaryRu,
    this.officialCefrDisclaimerUz,
    this.officialCefrDisclaimerRu,
    required this.steps,
    required this.reinforcementExercise,
    this.alternateExercise,
    this.requiresMastery = false,
  });

  String localizedTitle(String uiLocale) {
    if (uiLocale == 'ru') {
      final ru = titleRu?.trim();
      if (ru != null && ru.isNotEmpty) return ru;
    }
    return title;
  }

  String localizedSummary(String uiLocale) {
    if (uiLocale == 'ru') {
      final ru = summaryRu?.trim();
      if (ru != null && ru.isNotEmpty) return ru;
    }
    return summary;
  }

  String? localizedCanDo(String uiLocale) {
    if (uiLocale == 'ru') {
      final ru = canDoObjectiveRu?.trim();
      if (ru != null && ru.isNotEmpty) return ru;
    }
    final uz = canDoObjective?.trim();
    return (uz != null && uz.isNotEmpty) ? uz : null;
  }

  String? localizedDisclaimer(String uiLocale) {
    if (uiLocale == 'ru') {
      final ru = officialCefrDisclaimerRu?.trim();
      if (ru != null && ru.isNotEmpty) return ru;
    }
    final uz = officialCefrDisclaimerUz?.trim();
    return (uz != null && uz.isNotEmpty) ? uz : null;
  }
}
