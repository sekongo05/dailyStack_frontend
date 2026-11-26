import 'package:flutter_test/flutter_test.dart';
import 'package:dailystack/core/network/api_response.dart';
import 'package:dailystack/core/storage/web_kv_store.dart';
import 'package:dailystack/features/auth/models/auth_models.dart';
import 'package:dailystack/features/learning/models/lesson_models.dart';
import 'package:dailystack/features/practice/models/practice_models.dart';
import 'package:dailystack/features/sync/services/sync_service.dart';

void main() {
  group('API models serialization & deserialization', () {
    test('ApiResponse & AuthResponse parse correctly including streakShields', () {
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
              'streakShields': 2,
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
      expect(res.data?.user.preferences?.streakShields, 2);
      expect(res.data?.user.streakShields, 2);
    });

    test('LessonDetail round-trips toJson/fromJson for SQLite & Web cache', () {
      final lesson = LessonDetail(
        id: 1,
        trackId: 1,
        trackTitle: 'Niveau 1 : Fondamentaux du Backend & API REST',
        curriculumCode: 'B1.1',
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
      expect(restored.curriculumCode, 'B1.1');
      expect(restored.userProgress?.status, LessonProgressStatus.IN_PROGRESS);
      expect(restored.userProgress?.lastReadSectionIndex, 2);
      expect(restored.sections.first.sectionType, SectionType.TITLE);
    });

    test('EvaluationResult round-trips correctOrderedOptionIds & SM-2 fields', () {
      final eval = EvaluationResult.fromJson({
        'exerciseId': 7,
        'correct': false,
        'correctOrderedOptionIds': [14, 11, 13, 12],
        'scoreEarned': 0,
        'explanation': 'Commencez par valider le schéma avant le commit.',
        'optionFeedback': 'Ordre incomplet.',
        'conceptMasteryLevel': 'IN_PROGRESS',
        'conceptScoreRatio': 0.5,
        'nextReviewDate': '2026-11-30',
        'reviewIntervalDays': 4,
      });

      final restored = EvaluationResult.fromJson(eval.toJson());
      expect(restored.correct, isFalse);
      expect(restored.correctOrderedOptionIds, [14, 11, 13, 12]);
      expect(restored.nextReviewDate, '2026-11-30');
      expect(restored.reviewIntervalDays, 4);
      expect(restored.conceptMasteryLevel, MasteryLevel.IN_PROGRESS);
    });

    test('ProgressSummary & ActivityDay round-trip 12-week heatmap & shields', () {
      final summary = ProgressSummary.fromJson({
        'totalLessonsCompleted': 8,
        'totalNotionsMastered': 5,
        'notionsToConsolidate': 1,
        'backendCompletionPercent': 65.0,
        'devopsCompletionPercent': 40.0,
        'exercisesSuccessRate': 88.5,
        'streakDays': 9,
        'streakShields': 2,
        'shieldUsedRecently': true,
        'dueReviewsCount': 1,
        'notions': [
          {
            'conceptId': 1,
            'lessonId': 1,
            'conceptName': 'Idempotence des verbes HTTP',
            'domainCode': 'BACKEND',
            'masteryLevel': 'MASTERED',
            'scoreRatio': 1.0,
            'evaluationsCount': 3,
            'nextReviewDate': '2026-12-10',
          }
        ],
        'activityCalendar': [
          {
            'date': '2026-11-25',
            'lessonsCompleted': 1,
            'exercisesCompleted': 3,
            'primaryDomain': 'BACKEND',
            'intensity': 3,
          },
          {
            'date': '2026-11-26',
            'lessonsCompleted': 1,
            'exercisesCompleted': 4,
            'primaryDomain': 'DEVOPS',
            'intensity': 4,
          },
        ],
      });

      final restored = ProgressSummary.fromJson(summary.toJson());
      expect(restored.streakShields, 2);
      expect(restored.shieldUsedRecently, isTrue);
      expect(restored.activityCalendar.length, 2);
      expect(restored.activityCalendar.first.primaryDomain, 'BACKEND');
      expect(restored.activityCalendar.last.primaryDomain, 'DEVOPS');
      expect(restored.activityCalendar.last.intensity, 4);
      expect(restored.notions.first.masteryLevel, MasteryLevel.MASTERED);
    });

    test('HomeBootstrap & TechNewsSummary preserve J+1 preview and related curriculum links', () {
      final bootstrapJson = {
        'todayLesson': {
          'id': 10,
          'domainCode': 'BACKEND',
          'curriculumCode': 'B2.3',
          'level': 2,
          'title': 'Indexation B-Tree PostgreSQL',
          'estimatedMinutes': 6,
          'sequenceDay': 5,
          'revisionDay': false,
          'status': 'AVAILABLE',
          'lastReadSectionIndex': 0,
          'scrollOffsetRatio': 0.0,
        },
        'tomorrowLessonPreview': {
          'id': 11,
          'domainCode': 'DEVOPS',
          'curriculumCode': 'D2.3',
          'level': 2,
          'title': 'Dockerfile Multi-Stage & Sécurité',
          'estimatedMinutes': 6,
          'sequenceDay': 6,
          'revisionDay': false,
          'status': 'LOCKED',
          'lastReadSectionIndex': 0,
          'scrollOffsetRatio': 0.0,
        },
        'dueReviews': [],
        'recentNews': [
          {
            'id': 42,
            'title': 'PostgreSQL 18 : Async I/O',
            'category': 'BACKEND',
            'targetTechnology': 'PostgreSQL',
            'summary': 'Gains majeurs sur les lectures séquentielles et B-Tree.',
            'importance': 'HIGH',
            'publishedDate': '2026-11-20',
            'lastVerifiedDate': '2026-11-26',
            'aiGenerated': false,
            'bookmarked': true,
            'relatedLessonId': 10,
            'relatedCurriculumCode': 'B2.3',
            'relatedLessonTitle': 'Indexation B-Tree PostgreSQL',
          }
        ],
        'unreadNotificationsCount': 3,
        'streakShields': 2,
      };

      final bootstrap = HomeBootstrap.fromJson(bootstrapJson);
      final restored = HomeBootstrap.fromJson(bootstrap.toJson());

      expect(restored.todayLesson.curriculumCode, 'B2.3');
      expect(restored.tomorrowLessonPreview?.curriculumCode, 'D2.3');
      expect(restored.tomorrowLessonPreview?.domainCode, 'DEVOPS');
      expect(restored.unreadNotificationsCount, 3);
      expect(restored.streakShields, 2);
      expect(restored.recentNews.first.relatedLessonId, 10);
      expect(restored.recentNews.first.relatedCurriculumCode, 'B2.3');
      expect(
        restored.recentNews.first.relatedLessonTitle,
        'Indexation B-Tree PostgreSQL',
      );
    });

    test('SyncPullData & WebKvStore round-trip cleanly', () {
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
            'relatedCurriculumCode': 'B4.1',
          }
        ],
        'serverTimestamp': '2026-11-12T01:30:00',
      });

      expect(pulled.cachedNews.length, 1);
      expect(pulled.cachedNews.first.bookmarked, isTrue);
      expect(pulled.cachedNews.first.relatedCurriculumCode, 'B4.1');

      final store = WebKvStore();
      store.write('test_key', 'offline_payload');
      expect(store.read('test_key'), 'offline_payload');
      store.remove('test_key');
      expect(store.read('test_key'), isNull);
    });
  });
}
