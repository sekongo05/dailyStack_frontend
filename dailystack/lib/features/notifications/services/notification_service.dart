import 'package:dio/dio.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../models/notification_models.dart';

class NotificationService {
  final DioClient _client;

  NotificationService(this._client);

  Future<List<DailyNotificationItem>> getNotifications() async {
    try {
      final response = await _client.dio.get('/notifications');
      final apiRes = ApiResponse<List<DailyNotificationItem>>.fromJson(
        response.data as Map<String, dynamic>,
        (data) => (data as List)
            .map((e) => DailyNotificationItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
      return apiRes.data ?? [];
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }

  Future<DailyNotificationItem> markAsRead(int notificationId) async {
    try {
      final response = await _client.dio.patch('/notifications/$notificationId/read');
      final apiRes = ApiResponse<DailyNotificationItem>.fromJson(
        response.data as Map<String, dynamic>,
        (data) => DailyNotificationItem.fromJson(data as Map<String, dynamic>),
      );
      if (apiRes.data == null) {
        throw Exception('Réponse notification invalide.');
      }
      return apiRes.data!;
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }
}
