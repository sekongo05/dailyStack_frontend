enum LessonProgressStatus { LOCKED, AVAILABLE, IN_PROGRESS, COMPLETED }

enum SectionType {
  TITLE,
  INTRODUCTION,
  OBJECTIVES,
  EXPLANATION,
  EXAMPLES,
  ILLUSTRATIONS,
  PRO_SCENARIO,
  SUMMARY
}

class LessonSection {
  final int id;
  final SectionType sectionType;
  final String title;
  final String contentMarkdown;
  final int orderIndex;

  LessonSection({
    required this.id,
    required this.sectionType,
    required this.title,
    required this.contentMarkdown,
    required this.orderIndex,
  });

  factory LessonSection.fromJson(Map<String, dynamic> json) {
    return LessonSection(
      id: json['id'] as int,
      sectionType: SectionType.values.firstWhere(
        (e) => e.name == json['sectionType'],
        orElse: () => SectionType.EXPLANATION,
      ),
      title: json['title'] as String,
      contentMarkdown: json['contentMarkdown'] as String,
      orderIndex: json['orderIndex'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sectionType': sectionType.name,
        'title': title,
        'contentMarkdown': contentMarkdown,
        'orderIndex': orderIndex,
      };
}

class UserProgress {
  final LessonProgressStatus status;
  final int lastReadSectionIndex;
  final double scrollOffsetRatio;
  final String? startedAt;
  final String? completedAt;

  UserProgress({
    required this.status,
    required this.lastReadSectionIndex,
    required this.scrollOffsetRatio,
    this.startedAt,
    this.completedAt,
  });

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      status: LessonProgressStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => LessonProgressStatus.AVAILABLE,
      ),
      lastReadSectionIndex: json['lastReadSectionIndex'] as int? ?? 0,
      scrollOffsetRatio: (json['scrollOffsetRatio'] as num?)?.toDouble() ?? 0.0,
      startedAt: json['startedAt'] as String?,
      completedAt: json['completedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'lastReadSectionIndex': lastReadSectionIndex,
        'scrollOffsetRatio': scrollOffsetRatio,
        if (startedAt != null) 'startedAt': startedAt,
        if (completedAt != null) 'completedAt': completedAt,
      };
}

class DailyLessonSummary {
  final int id;
  final String domainCode;
  final String title;
  final int estimatedMinutes;
  final int sequenceDay;
  final bool revisionDay;
  final LessonProgressStatus status;
  final int lastReadSectionIndex;
  final double scrollOffsetRatio;
  final String? domainName;
  final String? colorHex;

  DailyLessonSummary({
    required this.id,
    required this.domainCode,
    required this.title,
    required this.estimatedMinutes,
    required this.sequenceDay,
    required this.revisionDay,
    required this.status,
    required this.lastReadSectionIndex,
    required this.scrollOffsetRatio,
    this.domainName,
    this.colorHex,
  });

  factory DailyLessonSummary.fromJson(Map<String, dynamic> json) {
    return DailyLessonSummary(
      id: json['id'] as int,
      domainCode: json['domainCode'] as String,
      title: json['title'] as String,
      estimatedMinutes: json['estimatedMinutes'] as int? ?? 5,
      sequenceDay: json['sequenceDay'] as int? ?? 1,
      revisionDay: json['revisionDay'] as bool? ?? false,
      status: LessonProgressStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => LessonProgressStatus.AVAILABLE,
      ),
      lastReadSectionIndex: json['lastReadSectionIndex'] as int? ?? 0,
      scrollOffsetRatio: (json['scrollOffsetRatio'] as num?)?.toDouble() ?? 0.0,
      domainName: json['domainName'] as String?,
      colorHex: json['colorHex'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'domainCode': domainCode,
        'title': title,
        'estimatedMinutes': estimatedMinutes,
        'sequenceDay': sequenceDay,
        'revisionDay': revisionDay,
        'status': status.name,
        'lastReadSectionIndex': lastReadSectionIndex,
        'scrollOffsetRatio': scrollOffsetRatio,
        if (domainName != null) 'domainName': domainName,
        if (colorHex != null) 'colorHex': colorHex,
      };
}

class LessonDetail {
  final int id;
  final int trackId;
  final String trackTitle;
  final String domainCode;
  final String title;
  final int estimatedMinutes;
  final int sequenceDay;
  final bool revisionDay;
  final UserProgress? userProgress;
  final List<LessonSection> sections;

  LessonDetail({
    required this.id,
    required this.trackId,
    required this.trackTitle,
    required this.domainCode,
    required this.title,
    required this.estimatedMinutes,
    required this.sequenceDay,
    required this.revisionDay,
    this.userProgress,
    required this.sections,
  });

  factory LessonDetail.fromJson(Map<String, dynamic> json) {
    return LessonDetail(
      id: json['id'] as int,
      trackId: json['trackId'] as int,
      trackTitle: json['trackTitle'] as String,
      domainCode: json['domainCode'] as String,
      title: json['title'] as String,
      estimatedMinutes: json['estimatedMinutes'] as int? ?? 5,
      sequenceDay: json['sequenceDay'] as int? ?? 1,
      revisionDay: json['revisionDay'] as bool? ?? false,
      userProgress: json['userProgress'] != null
          ? UserProgress.fromJson(json['userProgress'] as Map<String, dynamic>)
          : null,
      sections: (json['sections'] as List<dynamic>? ?? [])
          .map((e) => LessonSection.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'trackId': trackId,
        'trackTitle': trackTitle,
        'domainCode': domainCode,
        'title': title,
        'estimatedMinutes': estimatedMinutes,
        'sequenceDay': sequenceDay,
        'revisionDay': revisionDay,
        if (userProgress != null) 'userProgress': userProgress!.toJson(),
        'sections': sections.map((s) => s.toJson()).toList(),
      };
}

class Track {
  final int id;
  final String domainCode;
  final String title;
  final String? description;
  final int level;
  final int orderIndex;
  final int totalLessons;
  final int completedLessons;
  final List<DailyLessonSummary> lessons;

  Track({
    required this.id,
    required this.domainCode,
    required this.title,
    this.description,
    required this.level,
    required this.orderIndex,
    required this.totalLessons,
    required this.completedLessons,
    required this.lessons,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] as int,
      domainCode: json['domainCode'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      level: json['level'] as int? ?? 1,
      orderIndex: json['orderIndex'] as int? ?? 0,
      totalLessons: json['totalLessons'] as int? ?? 0,
      completedLessons: json['completedLessons'] as int? ?? 0,
      lessons: (json['lessons'] as List<dynamic>? ?? [])
          .map((e) => DailyLessonSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

