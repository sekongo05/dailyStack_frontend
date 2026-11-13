enum MasteryLevel { DISCOVERY, IN_PROGRESS, MASTERED }

enum ExerciseType {
  MCQ,
  OPEN_QUESTION,
  REFLECTION,
  CASE_STUDY,
  CODE_SNIPPET,
  SHORT_CHALLENGE
}

class ExerciseOption {
  final int id;
  final String text;
  final int orderIndex;

  ExerciseOption({
    required this.id,
    required this.text,
    required this.orderIndex,
  });

  factory ExerciseOption.fromJson(Map<String, dynamic> json) {
    return ExerciseOption(
      id: json['id'] as int,
      text: json['text'] as String,
      orderIndex: json['orderIndex'] as int? ?? 0,
    );
  }
}

class Exercise {
  final int id;
  final int lessonId;
  final int? conceptId;
  final String? conceptName;
  final ExerciseType type;
  final String question;
  final String? codeSnippet;
  final int points;
  final List<ExerciseOption> options;

  Exercise({
    required this.id,
    required this.lessonId,
    this.conceptId,
    this.conceptName,
    required this.type,
    required this.question,
    this.codeSnippet,
    required this.points,
    required this.options,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as int,
      lessonId: json['lessonId'] as int,
      conceptId: json['conceptId'] as int?,
      conceptName: json['conceptName'] as String?,
      type: ExerciseType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ExerciseType.MCQ,
      ),
      question: json['question'] as String,
      codeSnippet: json['codeSnippet'] as String?,
      points: json['points'] as int? ?? 10,
      options: (json['options'] as List<dynamic>? ?? [])
          .map((e) => ExerciseOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class EvaluationResult {
  final int exerciseId;
  final bool correct;
  final int scoreEarned;
  final String explanation;
  final String? optionFeedback;
  final MasteryLevel conceptMasteryLevel;
  final double conceptScoreRatio;

  EvaluationResult({
    required this.exerciseId,
    required this.correct,
    required this.scoreEarned,
    required this.explanation,
    this.optionFeedback,
    required this.conceptMasteryLevel,
    required this.conceptScoreRatio,
  });

  factory EvaluationResult.fromJson(Map<String, dynamic> json) {
    return EvaluationResult(
      exerciseId: json['exerciseId'] as int,
      correct: json['correct'] as bool? ?? false,
      scoreEarned: json['scoreEarned'] as int? ?? 0,
      explanation: json['explanation'] as String? ?? '',
      optionFeedback: json['optionFeedback'] as String?,
      conceptMasteryLevel: MasteryLevel.values.firstWhere(
        (e) => e.name == json['conceptMasteryLevel'],
        orElse: () => MasteryLevel.DISCOVERY,
      ),
      conceptScoreRatio: (json['conceptScoreRatio'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ConceptMasterySummary {
  final int conceptId;
  final String conceptName;
  final String domainCode;
  final MasteryLevel masteryLevel;
  final double scoreRatio;
  final int evaluationsCount;
  final String? nextReviewDate;

  ConceptMasterySummary({
    required this.conceptId,
    required this.conceptName,
    required this.domainCode,
    required this.masteryLevel,
    required this.scoreRatio,
    required this.evaluationsCount,
    this.nextReviewDate,
  });

  factory ConceptMasterySummary.fromJson(Map<String, dynamic> json) {
    return ConceptMasterySummary(
      conceptId: json['conceptId'] as int,
      conceptName: json['conceptName'] as String,
      domainCode: json['domainCode'] as String,
      masteryLevel: MasteryLevel.values.firstWhere(
        (e) => e.name == json['masteryLevel'],
        orElse: () => MasteryLevel.DISCOVERY,
      ),
      scoreRatio: (json['scoreRatio'] as num?)?.toDouble() ?? 0.0,
      evaluationsCount: json['evaluationsCount'] as int? ?? 0,
      nextReviewDate: json['nextReviewDate'] as String?,
    );
  }
}

class ProgressSummary {
  final int totalLessonsCompleted;
  final int totalNotionsMastered;
  final int notionsToConsolidate;
  final double backendCompletionPercent;
  final double devopsCompletionPercent;
  final double exercisesSuccessRate;
  final int streakDays;
  final int dueReviewsCount;
  final List<ConceptMasterySummary> notions;

  ProgressSummary({
    required this.totalLessonsCompleted,
    required this.totalNotionsMastered,
    required this.notionsToConsolidate,
    required this.backendCompletionPercent,
    required this.devopsCompletionPercent,
    required this.exercisesSuccessRate,
    required this.streakDays,
    required this.dueReviewsCount,
    required this.notions,
  });

  factory ProgressSummary.fromJson(Map<String, dynamic> json) {
    return ProgressSummary(
      totalLessonsCompleted: json['totalLessonsCompleted'] as int? ?? 0,
      totalNotionsMastered: json['totalNotionsMastered'] as int? ?? 0,
      notionsToConsolidate: json['notionsToConsolidate'] as int? ?? 0,
      backendCompletionPercent: (json['backendCompletionPercent'] as num?)?.toDouble() ?? 0.0,
      devopsCompletionPercent: (json['devopsCompletionPercent'] as num?)?.toDouble() ?? 0.0,
      exercisesSuccessRate: (json['exercisesSuccessRate'] as num?)?.toDouble() ?? 0.0,
      streakDays: json['streakDays'] as int? ?? 0,
      dueReviewsCount: json['dueReviewsCount'] as int? ?? 0,
      notions: (json['notions'] as List<dynamic>? ?? [])
          .map((e) => ConceptMasterySummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

