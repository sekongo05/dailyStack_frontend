import 'package:dio/dio.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../models/practice_models.dart';

class PracticeService {
  final DioClient _client;

  PracticeService(this._client);

  Future<List<Exercise>> getExercisesForLesson(int lessonId) async {
    try {
      final response = await _client.dio.get('/lessons/$lessonId/exercises');
      final apiRes = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (data) => (data as List<dynamic>)
            .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
      return apiRes.data ?? [];
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }

  Future<EvaluationResult> submitAnswer({
    required int exerciseId,
    int? selectedOptionId,
    List<int>? orderedOptionIds,
    String? submittedText,
    int? confidenceLevel,
  }) async {
    try {
      final response = await _client.dio.post(
        '/exercises/$exerciseId/submit',
        data: {
          'selectedOptionId': ?selectedOptionId,
          'orderedOptionIds': ?orderedOptionIds,
          'submittedText': ?submittedText,
          'confidenceLevel': ?confidenceLevel,
        },
      );
      final apiRes = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (data) => EvaluationResult.fromJson(data as Map<String, dynamic>),
      );
      return apiRes.data!;
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }

  Future<List<ConceptMasterySummary>> getDueReviews() async {
    try {
      final response = await _client.dio.get('/reviews/due');
      final apiRes = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (data) => (data as List<dynamic>)
            .map((e) => ConceptMasterySummary.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
      return apiRes.data ?? [];
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }

  Future<ProgressSummary> getProgressSummary() async {
    try {
      final response = await _client.dio.get('/progress/summary');
      final apiRes = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (data) => ProgressSummary.fromJson(data as Map<String, dynamic>),
      );
      return apiRes.data!;
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }

  Future<LeaderboardData> getLeaderboard({
    String period = 'WEEKLY',
    int limit = 30,
  }) async {
    try {
      final response = await _client.dio.get(
        '/progress/leaderboard',
        queryParameters: {'period': period, 'limit': limit},
      );
      final apiRes = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (data) => LeaderboardData.fromJson(data as Map<String, dynamic>),
      );
      return apiRes.data!;
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }
}
