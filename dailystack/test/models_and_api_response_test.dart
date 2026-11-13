import 'package:flutter_test/flutter_test.dart';
import 'package:dailystack/core/network/api_response.dart';
import 'package:dailystack/features/auth/models/auth_models.dart';
import 'package:dailystack/features/learning/models/lesson_models.dart';
import 'package:dailystack/features/practice/models/practice_models.dart';
import 'package:dailystack/features/sync/services/sync_service.dart';
import 'package:dailystack/features/watch/models/news_models.dart';

void main() {
  group('API models serialization & deserialization', () {
    test('ApiResponse & AuthResponse parse correctly', () {
      final json = {
        'success': true,
        'message': 'Inscription réussie',
        'data': {
          'accessToken': 'access-123',
          'refreshToken': 'refresh-456',
          'expiresIn': 86400000,
          'user': {
            'id': 3,
            'email': 'nouveau.dev@gmail.com',
            'username': 'DevMobile',
            'role': 'ROLE_USER',
            'currentLevel': 1,
            'streakDays': 2,
            'preferences': {
              'theme': 'DARK',
              'textSize': 'LARGE',
              'dailyReminderTime': '07:30:00',
              'notifyDailyLesson': true,
              'notifyReviews': false,
              'notifyImportantNews': true,
            },
          },
        },
      };

      final res = ApiResponse.fromJson(
        json,
        (data) => AuthResponse.fromJson(data as Map<String, dynamic>),
      );

      expect(res.success, isTrue);
      expect(res.data?.accessToken, 'access-123');
      expect(res.data?.user.preferences?.theme, ThemePreference.DARK);
      expect(res.data?.user.preferences?.textSize, TextSizePreference.LARGE);
      expect(res.data?.user.preferences?.notifyReviews, isFalse);
    });

    test('LessonDetail round-trips toJson/fromJson for SQLite cache', () {
      final lesson = LessonDetail(
        id: 1,
        trackId: 1,
        trackTitle: 'Niveau 1 : Fondamentaux du Backend & API REST',
        domainCode: 'BACKEND',
        title: 'Les Fondations du Protocole HTTP',
        estimatedMinutes: 6,
        sequenceDay: 1,
        revisionDay: false,
        userProgress: UserProgress(
          status: LessonProgressStatus.IN_PROGRESS,
          lastReadSectionIndex: 2,
          scrollOffsetRatio: 0.45,
        ),
        sections: [
          LessonSection(
            id: 1,
            sectionType: SectionType.TITLE,
            title: 'Titre',
            contentMarkdown: '# HTTP',
            orderIndex: 0,
          ),
        ],
      );

      final restored = LessonDetail.fromJson(lesson.toJson());
      expect(restored.id, 1);
      expect(restored.userProgress?.status, LessonProgressStatus.IN_PROGRESS);
      expect(restored.userProgress?.lastReadSectionIndex, 2);
      expect(restored.sections.first.sectionType, SectionType.TITLE);
    });

    test('EvaluationResult & ProgressSummary parse mastery levels', () {
      final eval = EvaluationResult.fromJson({
        'exerciseId': 1,
        'correct': true,
        'scoreEarned': 10,
        'explanation': 'PUT est idempotent.',
        'optionFeedback': 'Exactement !',
        'conceptMasteryLevel': 'IN_PROGRESS',
        'conceptScoreRatio': 1.0,
      });

      expect(eval.correct, isTrue);
      expect(eval.conceptMasteryLevel, MasteryLevel.IN_PROGRESS);

      final summary = ProgressSummary.fromJson({
        'totalLessonsCompleted': 1,
        'totalNotionsMastered': 0,
        'notionsToConsolidate': 1,
        'backendCompletionPercent': 100.0,
        'devopsCompletionPercent': 0.0,
        'exercisesSuccessRate': 100.0,
        'streakDays': 3,
        'dueReviewsCount': 1,
        'notions': [
          {
            'conceptId': 1,
            'conceptName': 'Idempotence des verbes HTTP',
            'domainCode': 'BACKEND',
            'masteryLevel': 'IN_PROGRESS',
            'scoreRatio': 1.0,
            'evaluationsCount': 1,
            'nextReviewDate': '2026-11-14',
          }
        ],
      });

      expect(summary.notions.length, 1);
      expect(summary.notions.first.masteryLevel, MasteryLevel.IN_PROGRESS);
    });

    test('SyncPullData & TechNewsSummary parse correctly', () {
      final pulled = SyncPullData.fromJson({
        'availableLessons': [],
        'cachedNews': [
          {
            'id': 1,
            'title': 'Spring Boot 4.0',
            'category': 'BACKEND',
            'targetTechnology': 'Spring Boot',
            'summary': 'Virtual Threads',
            'importance': 'HIGH',
            'publishedDate': '2026-11-09',
            'lastVerifiedDate': '2026-11-12',
            'aiGenerated': false,
            'bookmarked': true,
          }
        ],
        'serverTimestamp': '2026-11-12T01:30:00',
      });

      expect(pulled.cachedNews.length, 1);
      expect(pulled.cachedNews.first.bookmarked, isTrue);
      expect(pulled.cachedNews.first.importance, WatchImportance.HIGH);
    });
  });
}

