import 'package:dio/dio.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../models/lesson_models.dart';

class LessonService {
  final DioClient _client;

  LessonService(this._client);

  Future<DailyLessonSummary> getTodayLesson() async {
    try {
      final response = await _client.dio.get('/lessons/today');
      final apiRes = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (data) => DailyLessonSummary.fromJson(data as Map<String, dynamic>),
      );
      return apiRes.data!;
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }

  Future<LessonDetail> getLessonDetail(int lessonId) async {
    try {
      final response = await _client.dio.get('/lessons/$lessonId');
      final apiRes = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (data) => LessonDetail.fromJson(data as Map<String, dynamic>),
      );
      return apiRes.data!;
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }

  Future<UserProgress> updateProgress({
    required int lessonId,
    int? lastReadSectionIndex,
    double? scrollOffsetRatio,
    bool? markAsCompleted,
  }) async {
    try {
      final response = await _client.dio.post(
        '/lessons/$lessonId/progress',
        data: {
          'lastReadSectionIndex': ?lastReadSectionIndex,
          'scrollOffsetRatio': ?scrollOffsetRatio,
          'markAsCompleted': ?markAsCompleted,
        },
      );
      final apiRes = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (data) => UserProgress.fromJson(data as Map<String, dynamic>),
      );
      return apiRes.data!;
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }

  Future<List<Track>> getTracks({String? domain, int? level}) async {
    try {
      final response = await _client.dio.get(
        '/tracks',
        queryParameters: {
          'domain': ?domain,
          'level': ?level,
        },
      );
      final apiRes = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (data) => (data as List<dynamic>)
            .map((e) => Track.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
      return apiRes.data ?? [];
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }
}

