import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/service_model.dart';
import 'api_client.dart';
import 'room_service.dart';

class FavoriteService {
  static final ValueNotifier<Set<int>> favoriteNotifier = ValueNotifier<Set<int>>({});

  static Set<int> get favoriteRoomIds => favoriteNotifier.value;

  static bool isFavorite(int roomId) => favoriteNotifier.value.contains(roomId);

  static Future<void> syncUserFavoritesFromServer(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userKey = 'customer_favorites_user_$userId';

      // 1. Immediately load user-specific cached favorites from local device (instant UI)
      final localList = prefs.getStringList(userKey);
      if (localList != null) {
        favoriteNotifier.value = localList.map((e) => int.tryParse(e)).whereType<int>().toSet();
      } else {
        favoriteNotifier.value = <int>{};
      }

      // 2. Fetch fresh user favorites from MySQL database
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/favorites/user/$userId'),
        headers: ApiClient.defaultHeaders(isJson: false),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        final serverIds = list.map((e) => (e as num).toInt()).toSet();
        favoriteNotifier.value = serverIds;
        await prefs.setStringList(userKey, serverIds.map((id) => id.toString()).toList());
      }
    } catch (e) {
      debugPrint('Error syncing user favorites from server: $e');
    }
  }

  static Future<bool> toggleFavorite(int roomId) async {
    final updated = Set<int>.from(favoriteNotifier.value);
    bool added;
    if (updated.contains(roomId)) {
      updated.remove(roomId);
      added = false;
    } else {
      updated.add(roomId);
      added = true;
    }
    favoriteNotifier.value = updated;

    final user = ApiClient.currentUser;
    if (user != null) {
      // 1. Save to user-specific cache
      try {
        final prefs = await SharedPreferences.getInstance();
        final userKey = 'customer_favorites_user_${user.id}';
        await prefs.setStringList(userKey, updated.map((id) => id.toString()).toList());
      } catch (_) {}

      // 2. Persist to MySQL database via API
      try {
        await http.post(
          Uri.parse('${ApiClient.baseUrl}/favorites/toggle'),
          headers: ApiClient.defaultHeaders(),
          body: jsonEncode({'userId': user.id, 'roomId': roomId}),
        ).timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('Error toggling favorite in database: $e');
      }
    }

    return added;
  }

  static Future<List<ServiceModel>> getFavoriteRooms() async {
    final user = ApiClient.currentUser;
    if (user != null) {
      try {
        final res = await http.get(
          Uri.parse('${ApiClient.baseUrl}/favorites/rooms/user/${user.id}'),
          headers: ApiClient.defaultHeaders(isJson: false),
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final List list = jsonDecode(utf8.decode(res.bodyBytes));
          final rooms = list.map((r) => RoomService.convertRoomJsonToServiceModel(r as Map<String, dynamic>)).toList();
          favoriteNotifier.value = rooms.map((r) => r.id).toSet();
          return rooms;
        }
      } catch (e) {
        debugPrint('Error getting favorite rooms from server: $e');
      }
    }

    final allRooms = await RoomService.getServices();
    return allRooms.where((r) => favoriteNotifier.value.contains(r.id)).toList();
  }
}
