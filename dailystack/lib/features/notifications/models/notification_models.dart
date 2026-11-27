class DailyNotificationItem {
  final int id;
  final int lessonId;
  final String? targetRoute;
  final String title;
  final String message;
  final String sentDate;
  final bool read;
  final String createdAt;

  DailyNotificationItem({
    required this.id,
    required this.lessonId,
    this.targetRoute,
    required this.title,
    required this.message,
    required this.sentDate,
    required this.read,
    required this.createdAt,
  });

  factory DailyNotificationItem.fromJson(Map<String, dynamic> json) {
    return DailyNotificationItem(
      id: json['id'] as int,
      lessonId: json['lessonId'] as int? ?? 0,
      targetRoute: json['targetRoute'] as String?,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      sentDate: json['sentDate'] as String? ?? '',
      read: json['read'] as bool? ?? false,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}
