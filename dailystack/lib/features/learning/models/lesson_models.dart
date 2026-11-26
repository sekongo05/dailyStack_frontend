import '../../practice/models/practice_models.dart';
import '../../watch/models/news_models.dart';

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
  final String? curriculumCode;
  final int level;
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
    this.curriculumCode,
    this.level = 1,
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

  static String levelLabel(int lvl) => switch (lvl) {
        1 => 'Niv. 1 · Amateur',
        2 => 'Niv. 2 · Débutant',
        3 => 'Niv. 3 · Junior',
        4 => 'Niv. 4 · Senior',
        5 => 'Niv. 5 · Expert',
        _ => 'Niv. $lvl',
      };

  factory DailyLessonSummary.fromJson(Map<String, dynamic> json) {
    return DailyLessonSummary(
      id: json['id'] as int,
      domainCode: json['domainCode'] as String,
      curriculumCode: json['curriculumCode'] as String?,
      level: json['level'] as int? ?? 1,
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
        if (curriculumCode != null) 'curriculumCode': curriculumCode,
        'level': level,
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
  final int level;
  final String? curriculumCode;
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
    this.level = 1,
    this.curriculumCode,
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
      level: json['level'] as int? ?? 1,
      curriculumCode: json['curriculumCode'] as String?,
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
        'level': level,
        if (curriculumCode != null) 'curriculumCode': curriculumCode,
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'domainCode': domainCode,
        'title': title,
        if (description != null) 'description': description,
        'level': level,
        'orderIndex': orderIndex,
        'totalLessons': totalLessons,
        'completedLessons': completedLessons,
        'lessons': lessons.map((l) => l.toJson()).toList(),
      };
}

class HomeBootstrap {
  final DailyLessonSummary todayLesson;
  final LessonDetail? todayLessonDetail;
  final DailyLessonSummary? tomorrowLessonPreview;
  final LessonDetail? tomorrowLessonDetail;
  final List<ConceptMasterySummary> dueReviews;
  final ProgressSummary? progressSummary;
  final List<TechNewsSummary> recentNews;
  final int unreadNotificationsCount;
  final int streakShields;

  HomeBootstrap({
    required this.todayLesson,
    this.todayLessonDetail,
    this.tomorrowLessonPreview,
    this.tomorrowLessonDetail,
    this.dueReviews = const [],
    this.progressSummary,
    this.recentNews = const [],
    this.unreadNotificationsCount = 0,
    this.streakShields = 1,
  });

  factory HomeBootstrap.fromJson(Map<String, dynamic> json) {
    return HomeBootstrap(
      todayLesson: DailyLessonSummary.fromJson(
        json['todayLesson'] as Map<String, dynamic>,
      ),
      todayLessonDetail: json['todayLessonDetail'] != null
          ? LessonDetail.fromJson(
              json['todayLessonDetail'] as Map<String, dynamic>,
            )
          : null,
      tomorrowLessonPreview: json['tomorrowLessonPreview'] != null
          ? DailyLessonSummary.fromJson(
              json['tomorrowLessonPreview'] as Map<String, dynamic>,
            )
          : null,
      tomorrowLessonDetail: json['tomorrowLessonDetail'] != null
          ? LessonDetail.fromJson(
              json['tomorrowLessonDetail'] as Map<String, dynamic>,
            )
          : null,
      dueReviews: (json['dueReviews'] as List<dynamic>? ?? [])
          .map((e) => ConceptMasterySummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      progressSummary: json['progressSummary'] != null
          ? ProgressSummary.fromJson(
              json['progressSummary'] as Map<String, dynamic>,
            )
          : null,
      recentNews: (json['recentNews'] as List<dynamic>? ?? [])
          .map((e) => TechNewsSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      unreadNotificationsCount:
          (json['unreadNotificationsCount'] as num?)?.toInt() ?? 0,
      streakShields: (json['streakShields'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'todayLesson': todayLesson.toJson(),
        if (todayLessonDetail != null)
          'todayLessonDetail': todayLessonDetail!.toJson(),
        if (tomorrowLessonPreview != null)
          'tomorrowLessonPreview': tomorrowLessonPreview!.toJson(),
        if (tomorrowLessonDetail != null)
          'tomorrowLessonDetail': tomorrowLessonDetail!.toJson(),
        'dueReviews': dueReviews.map((r) => r.toJson()).toList(),
        if (progressSummary != null)
          'progressSummary': progressSummary!.toJson(),
        'recentNews': recentNews.map((n) => n.toJson()).toList(),
        'unreadNotificationsCount': unreadNotificationsCount,
        'streakShields': streakShields,
      };
}
