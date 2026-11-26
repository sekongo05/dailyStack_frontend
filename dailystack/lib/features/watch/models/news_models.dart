enum WatchCategory { BACKEND, DEVOPS, AI, EMERGING_TECH }

enum WatchImportance { LOW, MEDIUM, HIGH, CRITICAL }

class TechNewsSummary {
  final int id;
  final String title;
  final WatchCategory category;
  final String targetTechnology;
  final String summary;
  final WatchImportance importance;
  final String publishedDate;
  final String lastVerifiedDate;
  final bool aiGenerated;
  final bool bookmarked;
  final int? relatedLessonId;
  final String? relatedCurriculumCode;
  final String? relatedLessonTitle;

  TechNewsSummary({
    required this.id,
    required this.title,
    required this.category,
    required this.targetTechnology,
    required this.summary,
    required this.importance,
    required this.publishedDate,
    required this.lastVerifiedDate,
    required this.aiGenerated,
    required this.bookmarked,
    this.relatedLessonId,
    this.relatedCurriculumCode,
    this.relatedLessonTitle,
  });

  factory TechNewsSummary.fromJson(Map<String, dynamic> json) {
    return TechNewsSummary(
      id: json['id'] as int,
      title: json['title'] as String,
      category: WatchCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => WatchCategory.BACKEND,
      ),
      targetTechnology: json['targetTechnology'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      importance: WatchImportance.values.firstWhere(
        (e) => e.name == json['importance'],
        orElse: () => WatchImportance.MEDIUM,
      ),
      publishedDate: json['publishedDate'] as String? ?? '',
      lastVerifiedDate: json['lastVerifiedDate'] as String? ?? '',
      aiGenerated: json['aiGenerated'] as bool? ?? false,
      bookmarked: json['bookmarked'] as bool? ?? false,
      relatedLessonId: (json['relatedLessonId'] as num?)?.toInt(),
      relatedCurriculumCode: json['relatedCurriculumCode'] as String?,
      relatedLessonTitle: json['relatedLessonTitle'] as String?,
    );
  }

  TechNewsSummary copyWith({bool? bookmarked}) {
    return TechNewsSummary(
      id: id,
      title: title,
      category: category,
      targetTechnology: targetTechnology,
      summary: summary,
      importance: importance,
      publishedDate: publishedDate,
      lastVerifiedDate: lastVerifiedDate,
      aiGenerated: aiGenerated,
      bookmarked: bookmarked ?? this.bookmarked,
      relatedLessonId: relatedLessonId,
      relatedCurriculumCode: relatedCurriculumCode,
      relatedLessonTitle: relatedLessonTitle,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category.name,
        'targetTechnology': targetTechnology,
        'summary': summary,
        'importance': importance.name,
        'publishedDate': publishedDate,
        'lastVerifiedDate': lastVerifiedDate,
        'aiGenerated': aiGenerated,
        'bookmarked': bookmarked,
        if (relatedLessonId != null) 'relatedLessonId': relatedLessonId,
        if (relatedCurriculumCode != null)
          'relatedCurriculumCode': relatedCurriculumCode,
        if (relatedLessonTitle != null)
          'relatedLessonTitle': relatedLessonTitle,
      };
}

class TechNewsDetail extends TechNewsSummary {
  final String? fullContent;
  final String? changesSummary;
  final String? developerImpact;
  final String originalSourceUrl;

  TechNewsDetail({
    required super.id,
    required super.title,
    required super.category,
    required super.targetTechnology,
    required super.summary,
    required super.importance,
    required super.publishedDate,
    required super.lastVerifiedDate,
    required super.aiGenerated,
    required super.bookmarked,
    super.relatedLessonId,
    super.relatedCurriculumCode,
    super.relatedLessonTitle,
    this.fullContent,
    this.changesSummary,
    this.developerImpact,
    required this.originalSourceUrl,
  });

  factory TechNewsDetail.fromJson(Map<String, dynamic> json) {
    final base = TechNewsSummary.fromJson(json);
    return TechNewsDetail(
      id: base.id,
      title: base.title,
      category: base.category,
      targetTechnology: base.targetTechnology,
      summary: base.summary,
      importance: base.importance,
      publishedDate: base.publishedDate,
      lastVerifiedDate: base.lastVerifiedDate,
      aiGenerated: base.aiGenerated,
      bookmarked: base.bookmarked,
      relatedLessonId: base.relatedLessonId,
      relatedCurriculumCode: base.relatedCurriculumCode,
      relatedLessonTitle: base.relatedLessonTitle,
      fullContent: json['fullContent'] as String?,
      changesSummary: json['changesSummary'] as String?,
      developerImpact: json['developerImpact'] as String?,
      originalSourceUrl: json['originalSourceUrl'] as String? ?? '',
    );
  }

  @override
  TechNewsDetail copyWith({bool? bookmarked}) {
    return TechNewsDetail(
      id: id,
      title: title,
      category: category,
      targetTechnology: targetTechnology,
      summary: summary,
      importance: importance,
      publishedDate: publishedDate,
      lastVerifiedDate: lastVerifiedDate,
      aiGenerated: aiGenerated,
      bookmarked: bookmarked ?? this.bookmarked,
      relatedLessonId: relatedLessonId,
      relatedCurriculumCode: relatedCurriculumCode,
      relatedLessonTitle: relatedLessonTitle,
      fullContent: fullContent,
      changesSummary: changesSummary,
      developerImpact: developerImpact,
      originalSourceUrl: originalSourceUrl,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        if (fullContent != null) 'fullContent': fullContent,
        if (changesSummary != null) 'changesSummary': changesSummary,
        if (developerImpact != null) 'developerImpact': developerImpact,
        'originalSourceUrl': originalSourceUrl,
      };
}
