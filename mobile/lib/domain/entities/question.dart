enum QuestionDifficulty {
  easy,
  medium,
  hard,
}

class Question {
  final String id;
  final String courseId;
  final String skillId;
  final String text;
  final String? contextSnippet;
  final List<String> options;
  final int correctIndex;
  final QuestionDifficulty difficulty;
  final String explanation;
  final String? formulaLatex;
  final String? audioSimText;
  final String? audioSimSpeaker;

  const Question({
    required this.id,
    required this.courseId,
    required this.skillId,
    required this.text,
    this.contextSnippet,
    required this.options,
    required this.correctIndex,
    required this.difficulty,
    required this.explanation,
    this.formulaLatex,
    this.audioSimText,
    this.audioSimSpeaker,
  });
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
