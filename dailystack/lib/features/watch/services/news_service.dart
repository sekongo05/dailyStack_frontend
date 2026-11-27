import 'package:dio/dio.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../models/news_models.dart';

class TechNewsPage {
  final List<TechNewsSummary> items;
  final bool hasMore;

  const TechNewsPage({required this.items, required this.hasMore});
}

class NewsService {
  final DioClient _client;

  NewsService(this._client);

  Future<TechNewsPage> getNewsPage({
    WatchCategory? category,
    String? keyword,
    bool importantOnly = false,
    int page = 0,
    int size = 15,
  }) async {
    try {
      final response = await _client.dio.get(
        '/news',
        queryParameters: {
          if (category != null) 'category': category.name,
          if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
          if (importantOnly) 'importantOnly': true,
          'page': page,
          'size': size,
        },
      );
      final apiRes = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (data) {
          final map = data as Map<String, dynamic>;
          final content = map['content'] as List<dynamic>? ?? [];
          final isLast = map['last'] as bool? ?? true;
          return TechNewsPage(
            items: content
                .map((e) => TechNewsSummary.fromJson(e as Map<String, dynamic>))
                .toList(),
            hasMore: !isLast,
          );
        },
      );
      return apiRes.data ?? const TechNewsPage(items: [], hasMore: false);
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }

  Future<List<TechNewsSummary>> getNews({
    WatchCategory? category,
    String? keyword,
    bool importantOnly = false,
    int page = 0,
    int size = 10,
  }) async {
    final result = await getNewsPage(
      category: category,
      keyword: keyword,
      importantOnly: importantOnly,
      page: page,
      size: size,
    );
    return result.items;
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

