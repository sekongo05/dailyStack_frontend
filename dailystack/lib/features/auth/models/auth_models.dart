enum ThemePreference { LIGHT, DARK, SYSTEM }

enum TextSizePreference { SMALL, MEDIUM, LARGE }

class UserPreferences {
  final ThemePreference theme;
  final TextSizePreference textSize;
  final String dailyReminderTime;
  final bool notifyDailyLesson;
  final bool notifyReviews;
  final bool notifyImportantNews;

  UserPreferences({
    required this.theme,
    required this.textSize,
    required this.dailyReminderTime,
    required this.notifyDailyLesson,
    required this.notifyReviews,
    required this.notifyImportantNews,
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
      dailyReminderTime: json['dailyReminderTime'] as String? ?? '06:00:00',
      notifyDailyLesson: json['notifyDailyLesson'] as bool? ?? true,
      notifyReviews: json['notifyReviews'] as bool? ?? true,
      notifyImportantNews: json['notifyImportantNews'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'theme': theme.name,
        'textSize': textSize.name,
        'dailyReminderTime': dailyReminderTime,
        'notifyDailyLesson': notifyDailyLesson,
        'notifyReviews': notifyReviews,
        'notifyImportantNews': notifyImportantNews,
      };
}

class UserProfile {
  final int id;
  final String email;
  final String username;
  final String role;
  final int currentLevel;
  final int streakDays;
  final String? lastActiveDate;
  final UserPreferences? preferences;

  UserProfile({
    required this.id,
    required this.email,
    required this.username,
    required this.role,
    required this.currentLevel,
    required this.streakDays,
    this.lastActiveDate,
    this.preferences,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int,
      email: json['email'] as String,
      username: json['username'] as String,
      role: json['role'] as String,
      currentLevel: json['currentLevel'] as int? ?? 1,
      streakDays: json['streakDays'] as int? ?? 0,
      lastActiveDate: json['lastActiveDate'] as String?,
      preferences: json['preferences'] != null
          ? UserPreferences.fromJson(json['preferences'] as Map<String, dynamic>)
          : null,
    );
  }
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

