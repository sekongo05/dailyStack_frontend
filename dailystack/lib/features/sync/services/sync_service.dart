import 'package:dio/dio.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../../learning/models/lesson_models.dart';
import '../../watch/models/news_models.dart';

class SyncPullData {
  final List<LessonDetail> availableLessons;
  final List<TechNewsSummary> cachedNews;
  final String serverTimestamp;

  SyncPullData({
    required this.availableLessons,
    required this.cachedNews,
    required this.serverTimestamp,
  });

  factory SyncPullData.fromJson(Map<String, dynamic> json) {
    return SyncPullData(
      availableLessons: (json['availableLessons'] as List<dynamic>? ?? [])
          .map((e) => LessonDetail.fromJson(e as Map<String, dynamic>))
          .toList(),
      cachedNews: (json['cachedNews'] as List<dynamic>? ?? [])
          .map((e) => TechNewsSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      serverTimestamp: json['serverTimestamp'] as String? ?? '',
    );
  }
}

class SyncService {
  final DioClient _client;

  SyncService(this._client);

  Future<SyncPullData> pullSync() async {
    try {
      final response = await _client.dio.get('/sync/pull');
      final apiRes = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (data) => SyncPullData.fromJson(data as Map<String, dynamic>),
      );
      return apiRes.data!;
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }

  Future<Map<String, dynamic>> pushSync({
    List<Map<String, dynamic>> progresses = const [],
    List<Map<String, dynamic>> attempts = const [],
    List<Map<String, dynamic>> bookmarks = const [],
  }) async {
    try {
      final response = await _client.dio.post(
        '/sync/push',
        data: {
          'progresses': progresses,
          'attempts': attempts,
          'bookmarks': bookmarks,
        },
      );
      final apiRes = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (data) => data as Map<String, dynamic>,
      );
      return apiRes.data ?? {};
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }
}

