import 'package:dio/dio.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../models/news_models.dart';

class NewsService {
  final DioClient _client;

  NewsService(this._client);

  Future<List<TechNewsSummary>> getNews({
    WatchCategory? category,
    String? keyword,
    int page = 0,
    int size = 10,
  }) async {
    try {
      final response = await _client.dio.get(
        '/news',
        queryParameters: {
          if (category != null) 'category': category.name,
          if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
          'page': page,
          'size': size,
        },
      );
      final apiRes = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (data) {
          final content = (data as Map<String, dynamic>)['content'] as List<dynamic>? ?? [];
          return content.map((e) => TechNewsSummary.fromJson(e as Map<String, dynamic>)).toList();
        },
      );
      return apiRes.data ?? [];
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }

  Future<TechNewsDetail> getNewsDetail(int id) async {
    try {
      final response = await _client.dio.get('/news/$id');
      final apiRes = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (data) => TechNewsDetail.fromJson(data as Map<String, dynamic>),
      );
      return apiRes.data!;
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }

  Future<bool> toggleBookmark(int newsId) async {
    try {
      final response = await _client.dio.post('/news/$newsId/bookmark');
      final apiRes = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (data) => (data as Map<String, dynamic>)['bookmarked'] as bool? ?? false,
      );
      return apiRes.data ?? false;
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }

  Future<List<TechNewsSummary>> getBookmarks({int page = 0, int size = 10}) async {
    try {
      final response = await _client.dio.get(
        '/news/bookmarks',
        queryParameters: {'page': page, 'size': size},
      );
      final apiRes = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (data) {
          final content = (data as Map<String, dynamic>)['content'] as List<dynamic>? ?? [];
          return content.map((e) => TechNewsSummary.fromJson(e as Map<String, dynamic>)).toList();
        },
      );
      return apiRes.data ?? [];
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }
}

