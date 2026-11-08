import 'question.dart';

class PlacementReview {
  final QuestionAnswerSubmission submission;
  final String question;
  final String selected;
  final String correct;
  final String explanation;

  const PlacementReview({
    required this.submission,
    required this.question,
    required this.selected,
    required this.correct,
    required this.explanation,
  });
}

class CompletedPlacement {
  final String attemptId;
  final String weakestSkillId;
  final DateTime completedAt;
  final List<PlacementReview> review;

  const CompletedPlacement({
    required this.attemptId,
    required this.weakestSkillId,
    required this.completedAt,
    required this.review,
  });
}

class PlacementSession {
  final String id;
  final int questionNumber;
  final int totalQuestions;
  final Question? question;
  final CompletedPlacement? result;
  final bool wasReset;
  final bool canRetake;

  const PlacementSession({
    required this.id,
    required this.questionNumber,
    required this.totalQuestions,
    this.question,
    this.result,
    this.wasReset = false,
    this.canRetake = false,
  });
}
