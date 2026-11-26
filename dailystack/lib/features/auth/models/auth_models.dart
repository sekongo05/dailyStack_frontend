enum ThemePreference { LIGHT, DARK, SYSTEM }

enum TextSizePreference { SMALL, MEDIUM, LARGE }

class UserPreferences {
  final ThemePreference theme;
  final TextSizePreference textSize;
  final int currentLevel;
  final String dailyReminderTime;
  final bool notifyDailyLesson;
  final bool notifyReviews;
  final bool notifyImportantNews;
  final int streakShields;

  UserPreferences({
    required this.theme,
    required this.textSize,
    this.currentLevel = 1,
    required this.dailyReminderTime,
    required this.notifyDailyLesson,
    required this.notifyReviews,
    required this.notifyImportantNews,
    this.streakShields = 1,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      theme: ThemePreference.values.firstWhere(
        (e) => e.name == json['theme'],
        orElse: () => ThemePreference.SYSTEM,
      ),
      textSize: TextSizePreference.values.firstWhere(
        (e) => e.name == json['textSize'],
        orElse: () => TextSizePreference.MEDIUM,
      ),
      currentLevel: json['currentLevel'] as int? ?? 1,
      dailyReminderTime: json['dailyReminderTime'] as String? ?? '06:00:00',
      notifyDailyLesson: json['notifyDailyLesson'] as bool? ?? true,
      notifyReviews: json['notifyReviews'] as bool? ?? true,
      notifyImportantNews: json['notifyImportantNews'] as bool? ?? true,
      streakShields: json['streakShields'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'theme': theme.name,
        'textSize': textSize.name,
        'currentLevel': currentLevel,
        'dailyReminderTime': dailyReminderTime,
        'notifyDailyLesson': notifyDailyLesson,
        'notifyReviews': notifyReviews,
        'notifyImportantNews': notifyImportantNews,
        'streakShields': streakShields,
      };
}

class UserProfile {
  final int id;
  final String email;
  final String username;
  final String role;
  final int currentLevel;
  final int streakDays;
  final int streakShields;
  final String? lastActiveDate;
  final UserPreferences? preferences;

  UserProfile({
    required this.id,
    required this.email,
    required this.username,
    required this.role,
    required this.currentLevel,
    required this.streakDays,
    this.streakShields = 1,
    this.lastActiveDate,
    this.preferences,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final prefs = json['preferences'] != null
        ? UserPreferences.fromJson(json['preferences'] as Map<String, dynamic>)
        : null;
    return UserProfile(
      id: json['id'] as int,
      email: json['email'] as String,
      username: json['username'] as String,
      role: json['role'] as String,
      currentLevel: json['currentLevel'] as int? ?? 1,
      streakDays: json['streakDays'] as int? ?? 0,
      streakShields:
          json['streakShields'] as int? ?? prefs?.streakShields ?? 1,
      lastActiveDate: json['lastActiveDate'] as String?,
      preferences: prefs,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'username': username,
        'role': role,
        'currentLevel': currentLevel,
        'streakDays': streakDays,
        'streakShields': streakShields,
        if (lastActiveDate != null) 'lastActiveDate': lastActiveDate,
        if (preferences != null) 'preferences': preferences!.toJson(),
      };
}

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final UserProfile user;

  AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresIn: json['expiresIn'] as int? ?? 86400000,
      user: UserProfile.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
