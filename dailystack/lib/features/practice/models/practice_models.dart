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

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'orderIndex': orderIndex,
      };
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
    final rawType = json['type']?.toString().toUpperCase();
    return Exercise(
      id: json['id'] as int,
      lessonId: json['lessonId'] as int,
      conceptId: json['conceptId'] as int?,
      conceptName: json['conceptName'] as String?,
      type: ExerciseType.values.firstWhere(
        (e) => e.name == rawType,
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'lessonId': lessonId,
        if (conceptId != null) 'conceptId': conceptId,
        if (conceptName != null) 'conceptName': conceptName,
        'type': type.name,
        'question': question,
        if (codeSnippet != null) 'codeSnippet': codeSnippet,
        'points': points,
        'options': options.map((o) => o.toJson()).toList(),
      };
}

class EvaluationResult {
  final int exerciseId;
  final int? correctOptionId;
  final List<int>? correctOrderedOptionIds;
  final bool correct;
  final int scoreEarned;
  final String explanation;
  final String? optionFeedback;
  final MasteryLevel conceptMasteryLevel;
  final double conceptScoreRatio;
  final String? nextReviewDate;
  final int? reviewIntervalDays;

  EvaluationResult({
    required this.exerciseId,
    this.correctOptionId,
    this.correctOrderedOptionIds,
    required this.correct,
    required this.scoreEarned,
    required this.explanation,
    this.optionFeedback,
    required this.conceptMasteryLevel,
    required this.conceptScoreRatio,
    this.nextReviewDate,
    this.reviewIntervalDays,
  });

  factory EvaluationResult.fromJson(Map<String, dynamic> json) {
    return EvaluationResult(
      exerciseId: json['exerciseId'] as int,
      correctOptionId: json['correctOptionId'] as int?,
      correctOrderedOptionIds:
          (json['correctOrderedOptionIds'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList(),
      correct: json['correct'] as bool? ?? false,
      scoreEarned: json['scoreEarned'] as int? ?? 0,
      explanation: json['explanation'] as String? ?? '',
      optionFeedback: json['optionFeedback'] as String?,
      conceptMasteryLevel: MasteryLevel.values.firstWhere(
        (e) => e.name == json['conceptMasteryLevel'],
        orElse: () => MasteryLevel.DISCOVERY,
      ),
      conceptScoreRatio: (json['conceptScoreRatio'] as num?)?.toDouble() ?? 0.0,
      nextReviewDate: json['nextReviewDate'] as String?,
      reviewIntervalDays: (json['reviewIntervalDays'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        if (correctOptionId != null) 'correctOptionId': correctOptionId,
        if (correctOrderedOptionIds != null)
          'correctOrderedOptionIds': correctOrderedOptionIds,
        'correct': correct,
        'scoreEarned': scoreEarned,
        'explanation': explanation,
        if (optionFeedback != null) 'optionFeedback': optionFeedback,
        'conceptMasteryLevel': conceptMasteryLevel.name,
        'conceptScoreRatio': conceptScoreRatio,
        if (nextReviewDate != null) 'nextReviewDate': nextReviewDate,
        if (reviewIntervalDays != null)
          'reviewIntervalDays': reviewIntervalDays,
      };
}

class ConceptMasterySummary {
  final int conceptId;
  final int? lessonId;
  final String conceptName;
  final String domainCode;
  final MasteryLevel masteryLevel;
  final double scoreRatio;
  final int evaluationsCount;
  final String? nextReviewDate;

  ConceptMasterySummary({
    required this.conceptId,
    this.lessonId,
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
      lessonId: json['lessonId'] as int?,
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

  Map<String, dynamic> toJson() => {
        'conceptId': conceptId,
        if (lessonId != null) 'lessonId': lessonId,
        'conceptName': conceptName,
        'domainCode': domainCode,
        'masteryLevel': masteryLevel.name,
        'scoreRatio': scoreRatio,
        'evaluationsCount': evaluationsCount,
        if (nextReviewDate != null) 'nextReviewDate': nextReviewDate,
      };
}

class ActivityDay {
  final String date;
  final int lessonsCompleted;
  final int exercisesCompleted;
  final String? primaryDomain;
  final int intensity;

  const ActivityDay({
    required this.date,
    this.lessonsCompleted = 0,
    this.exercisesCompleted = 0,
    this.primaryDomain,
    this.intensity = 0,
  });

  factory ActivityDay.fromJson(Map<String, dynamic> json) {
    return ActivityDay(
      date: json['date'] as String? ?? '',
      lessonsCompleted: (json['lessonsCompleted'] as num?)?.toInt() ?? 0,
      exercisesCompleted: (json['exercisesCompleted'] as num?)?.toInt() ?? 0,
      primaryDomain: json['primaryDomain'] as String?,
      intensity: ((json['intensity'] as num?)?.toInt() ?? 0).clamp(0, 4),
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'lessonsCompleted': lessonsCompleted,
        'exercisesCompleted': exercisesCompleted,
        if (primaryDomain != null) 'primaryDomain': primaryDomain,
        'intensity': intensity,
      };
}

enum StreakStatus { ACTIVE_TODAY, PENDING_TODAY, FROZEN, EXTINGUISHED }

StreakStatus parseStreakStatus(String? raw, {int fallbackStreakDays = 0}) {
  return switch (raw?.toUpperCase()) {
    'ACTIVE_TODAY' => StreakStatus.ACTIVE_TODAY,
    'PENDING_TODAY' => StreakStatus.PENDING_TODAY,
    'FROZEN' => StreakStatus.FROZEN,
    'EXTINGUISHED' => StreakStatus.EXTINGUISHED,
    _ => fallbackStreakDays > 0
        ? StreakStatus.ACTIVE_TODAY
        : StreakStatus.EXTINGUISHED,
  };
}

class ProgressSummary {
  final int totalLessonsCompleted;
  final int totalNotionsMastered;
  final int notionsToConsolidate;
  final double backendCompletionPercent;
  final double devopsCompletionPercent;
  final double exercisesSuccessRate;
  final int streakDays;
  final StreakStatus streakStatus;
  final int streakShields;
  final bool shieldUsedRecently;
  final int dueReviewsCount;
  final List<ConceptMasterySummary> notions;
  final List<ActivityDay> activityCalendar;

  ProgressSummary({
    required this.totalLessonsCompleted,
    required this.totalNotionsMastered,
    required this.notionsToConsolidate,
    required this.backendCompletionPercent,
    required this.devopsCompletionPercent,
    required this.exercisesSuccessRate,
    required this.streakDays,
    this.streakStatus = StreakStatus.EXTINGUISHED,
    this.streakShields = 1,
    this.shieldUsedRecently = false,
    required this.dueReviewsCount,
    required this.notions,
    this.activityCalendar = const [],
  });

  factory ProgressSummary.fromJson(Map<String, dynamic> json) {
    return ProgressSummary(
      totalLessonsCompleted: json['totalLessonsCompleted'] as int? ?? 0,
      totalNotionsMastered: json['totalNotionsMastered'] as int? ?? 0,
      notionsToConsolidate: json['notionsToConsolidate'] as int? ?? 0,
      backendCompletionPercent:
          (json['backendCompletionPercent'] as num?)?.toDouble() ?? 0.0,
      devopsCompletionPercent:
          (json['devopsCompletionPercent'] as num?)?.toDouble() ?? 0.0,
      exercisesSuccessRate:
          (json['exercisesSuccessRate'] as num?)?.toDouble() ?? 0.0,
      streakDays: json['streakDays'] as int? ?? 0,
      streakStatus: parseStreakStatus(
        json['streakStatus'] as String?,
        fallbackStreakDays: json['streakDays'] as int? ?? 0,
      ),
      streakShields: json['streakShields'] as int? ?? 1,
      shieldUsedRecently: json['shieldUsedRecently'] as bool? ?? false,
      dueReviewsCount: json['dueReviewsCount'] as int? ?? 0,
      notions: (json['notions'] as List<dynamic>? ?? [])
          .map((e) => ConceptMasterySummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      activityCalendar: (json['activityCalendar'] as List<dynamic>? ?? [])
          .map((e) => ActivityDay.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'totalLessonsCompleted': totalLessonsCompleted,
        'totalNotionsMastered': totalNotionsMastered,
        'notionsToConsolidate': notionsToConsolidate,
        'backendCompletionPercent': backendCompletionPercent,
        'devopsCompletionPercent': devopsCompletionPercent,
        'exercisesSuccessRate': exercisesSuccessRate,
        'streakDays': streakDays,
        'streakStatus': streakStatus.name,
        'streakShields': streakShields,
        'shieldUsedRecently': shieldUsedRecently,
        'dueReviewsCount': dueReviewsCount,
        'notions': notions.map((n) => n.toJson()).toList(),
        'activityCalendar': activityCalendar.map((a) => a.toJson()).toList(),
      };
}
