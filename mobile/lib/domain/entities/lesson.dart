import 'question.dart';

enum LessonStepType {
  concept,
  formula,
  visualExample,
  audioSimulation,
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

class LessonStep {
  final String id;
  final int stepNumber;
  final LessonStepType type;
  final String title;
  final String? subtitle;
  final String content;
  final List<String>? highlightNotes;
  final LessonFormulaData? formulaData;
  final LessonVisualModelData? visualModelData;
  final Question? interactiveQuestion;

  const LessonStep({
    required this.id,
    required this.stepNumber,
    required this.type,
    required this.title,
    this.subtitle,
    required this.content,
    this.highlightNotes,
    this.formulaData,
    this.visualModelData,
    this.interactiveQuestion,
  });
}

class Lesson {
  final String id;
  final String courseId;
  final String skillId;
  final String title;
  final int estimatedMinutes;
  final String summary;
  final List<LessonStep> steps;
  final Question reinforcementExercise;

  const Lesson({
    required this.id,
    required this.courseId,
    required this.skillId,
    required this.title,
    required this.estimatedMinutes,
    required this.summary,
    required this.steps,
    required this.reinforcementExercise,
  });
}
