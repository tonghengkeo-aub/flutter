import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_client.dart';
import 'booking_service.dart';
import 'favorite_service.dart';

class AuthService {
  static const String _prefUserKey = 'customer_saved_user_json';
  static const String _prefTokenKey = 'customer_saved_auth_token';

  static UserModel? get currentUser => ApiClient.currentUser;
  static set currentUser(UserModel? u) => ApiClient.currentUser = u;

  static String? get authToken => ApiClient.authToken;
  static set authToken(String? t) => ApiClient.authToken = t;

  static Future<void> saveSession(UserModel user, String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefUserKey, jsonEncode(user.toJson()));
      await prefs.setString(_prefTokenKey, token);
    } catch (e) {
      debugPrint('Error saving session: $e');
    }
  }

  static Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJsonStr = prefs.getString(_prefUserKey);
      final token = prefs.getString(_prefTokenKey);
      if (userJsonStr != null && token != null) {
        final Map<String, dynamic> userMap = jsonDecode(userJsonStr);
        currentUser = UserModel.fromJson(userMap);
        authToken = token;
        await FavoriteService.syncUserFavoritesFromServer(currentUser!.id);
      } else {
        currentUser = null;
        authToken = null;
        FavoriteService.favoriteNotifier.value = <int>{};
      }
    } catch (e) {
      debugPrint('Error restoring session: $e');
      FavoriteService.favoriteNotifier.value = <int>{};
    }
  }

  static Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefUserKey);
      await prefs.remove(_prefTokenKey);
    } catch (e) {
      debugPrint('Error clearing session: $e');
    }
    authToken = null;
    currentUser = null;
    FavoriteService.favoriteNotifier.value = <int>{};
    BookingService.clearLocalCache();
  }

  static Future<UserModel> login(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiClient.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'password': password}),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        authToken = data['token'];
        currentUser = UserModel.fromJson(data);
        BookingService.clearLocalCache();
        await saveSession(currentUser!, authToken!);
        await FavoriteService.syncUserFavoritesFromServer(currentUser!.id);
        return currentUser!;
      } else {
        String msg = 'Invalid email or password';
        try {
          final err = jsonDecode(utf8.decode(res.bodyBytes));
          if (err['message'] != null) msg = err['message'];
        } catch (_) {}
        throw Exception(msg);
      }
    } catch (e) {
      final errStr = e.toString().replaceAll('Exception: ', '');
      if (errStr.contains('Invalid email') ||
          errStr.contains('Invalid') ||
          errStr.contains('Bad credentials') ||
          errStr.contains('not found') ||
          errStr.contains('Unauthorized')) {
        throw Exception('Invalid email or password');
      }

      // If backend server is offline/unreachable:
      // Allow ONLY valid registered demo seeds if credentials match
      final cleanEmail = email.trim().toLowerCase();
      if ((cleanEmail == 'customer@booking.com' || cleanEmail == 'dara@booking.com') &&
          password == 'password123') {
        currentUser = UserModel(
          id: cleanEmail == 'customer@booking.com' ? 2 : 3,
          fullName: cleanEmail == 'customer@booking.com' ? 'Sophea Pich' : 'Dara Chan',
          email: cleanEmail,
          phone: cleanEmail == 'customer@booking.com' ? '098111222' : '097333444',
          role: 'CUSTOMER',
          token: 'offline-demo-token',
        );
        authToken = currentUser!.token;
        await saveSession(currentUser!, authToken!);
        await FavoriteService.syncUserFavoritesFromServer(currentUser!.id);
        return currentUser!;
      }

      // Reject all arbitrary/invalid inputs
      throw Exception('Invalid email or password. Please use registered account or Demo button.');
    }
  }

  static Future<UserModel> register(
    String fullName,
    String phone,
    String email,
    String password, {
    String gender = 'Not Specified',
    String address = '',
  }) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiClient.baseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': fullName,
          'phone': phone,
          'email': email,
          'password': password,
          'gender': gender,
          'address': address,
          'role': 'CUSTOMER',
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        authToken = data['token'];
        currentUser = UserModel.fromJson(data);
        BookingService.clearLocalCache();
        await saveSession(currentUser!, authToken!);
        await FavoriteService.syncUserFavoritesFromServer(currentUser!.id);
        return currentUser!;
      } else {
        final err = jsonDecode(utf8.decode(res.bodyBytes));
        throw Exception(err['message'] ?? 'Registration failed');
      }
    } catch (e) {
      if (e.toString().contains('Registration failed')) rethrow;
      currentUser = UserModel(
        id: DateTime.now().millisecondsSinceEpoch % 1000,
        fullName: fullName,
        email: email,
        phone: phone,
        role: 'CUSTOMER',
        token: 'new-session-token',
      );
      authToken = currentUser!.token;
      await saveSession(currentUser!, authToken!);
      await FavoriteService.syncUserFavoritesFromServer(currentUser!.id);
      return currentUser!;
    }
  }

  static Future<void> updateProfile({
    required String fullName,
    String? phone,
    String? gender,
    String? address,
  }) async {
    if (authToken != null) {
      try {
        await http.put(
          Uri.parse('${ApiClient.baseUrl}/users/profile'),
          headers: ApiClient.defaultHeaders(),
          body: jsonEncode({
            'fullName': fullName,
            'phone': phone,
            'gender': gender,
            'address': address,
          }),
        ).timeout(const Duration(seconds: 3));
      } catch (_) {}
    }

    if (currentUser != null) {
      currentUser = UserModel(
        id: currentUser!.id,
        fullName: fullName,
        email: currentUser!.email,
        phone: phone ?? currentUser!.phone,
        role: currentUser!.role,
        token: currentUser!.token,
      );
    }
  }

  static Future<void> changePassword(String oldPassword, String newPassword) async {
    if (authToken != null) {
      final res = await http.put(
        Uri.parse('${ApiClient.baseUrl}/users/change-password'),
        headers: ApiClient.defaultHeaders(),
        body: jsonEncode({
          'oldPassword': oldPassword,
          'newPassword': newPassword,
        }),
      ).timeout(const Duration(seconds: 3));

      if (res.statusCode != 200) {
        final err = jsonDecode(utf8.decode(res.bodyBytes));
        throw Exception(err['message'] ?? 'Password update failed');
      }
    }
  }
}
