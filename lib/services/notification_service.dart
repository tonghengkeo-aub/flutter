import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/notification_model.dart';
import 'api_client.dart';

class NotificationService {
  static final List<NotificationModel> _localNotifications = [];

  static void addNotification(NotificationModel n) {
    _localNotifications.insert(0, n);
  }

  static Future<List<NotificationModel>> getNotifications() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/notifications'),
        headers: ApiClient.defaultHeaders(isJson: false),
      ).timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.map((e) => NotificationModel.fromJson(e)).toList();
      }
    } catch (_) {}

    if (_localNotifications.isEmpty) {
      _localNotifications.addAll([
        NotificationModel(
          id: 1,
          title: 'Welcome to Booking Pro KH!',
          message: 'Enjoy 10% off your first appointment with promo code WELCOME10.',
          type: 'PROMOTION',
          isRead: false,
          createdAt: 'Today',
        ),
        NotificationModel(
          id: 2,
          title: 'Booking Confirmed',
          message: 'Your reservation for Room 201 - Riverside Deluxe King Suite has been confirmed!',
          type: 'BOOKING_CONFIRMED',
          isRead: true,
          createdAt: 'Yesterday',
        ),
      ]);
    }
    return _localNotifications;
  }

  static Future<int> getUnreadNotificationCount() async {
    final list = await getNotifications();
    return list.where((n) => !n.isRead).length;
  }

  static Future<void> markNotificationRead(int id) async {
    try {
      await http.put(
        Uri.parse('${ApiClient.baseUrl}/notifications/$id/read'),
        headers: ApiClient.defaultHeaders(isJson: false),
      ).timeout(const Duration(seconds: 2));
    } catch (_) {}

    final idx = _localNotifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      final old = _localNotifications[idx];
      _localNotifications[idx] = NotificationModel(
        id: old.id,
        title: old.title,
        message: old.message,
        type: old.type,
        isRead: true,
        createdAt: old.createdAt,
      );
    }
  }

  static Future<void> markAllNotificationsRead() async {
    try {
      await http.put(
        Uri.parse('${ApiClient.baseUrl}/notifications/read-all'),
        headers: ApiClient.defaultHeaders(isJson: false),
      ).timeout(const Duration(seconds: 2));
    } catch (_) {}

    for (int i = 0; i < _localNotifications.length; i++) {
      final old = _localNotifications[i];
      _localNotifications[i] = NotificationModel(
        id: old.id,
        title: old.title,
        message: old.message,
        type: old.type,
        isRead: true,
        createdAt: old.createdAt,
      );
    }
  }
}
