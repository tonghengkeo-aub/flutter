import 'package:flutter/foundation.dart';
import '../models/booking_model.dart';
import '../models/category_model.dart';
import '../models/hotel_model.dart';
import '../models/notification_model.dart';
import '../models/provider_model.dart';
import '../models/room_model.dart';
import '../models/service_model.dart';
import '../models/user_model.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'booking_service.dart';
import 'favorite_service.dart';
import 'notification_service.dart';
import 'room_service.dart';

// Export sub-services so screens can optionally import them directly
export 'api_client.dart';
export 'auth_service.dart';
export 'booking_service.dart';
export 'favorite_service.dart';
export 'notification_service.dart';
export 'room_service.dart';

/// Facade Gateway providing 100% backward compatibility for existing screens
/// while delegating underlying logic to dedicated, isolated modular services.
class ApiService {
  // Base & Auth state
  static const String baseUrl = ApiClient.baseUrl;

  static String? get authToken => ApiClient.authToken;
  static set authToken(String? token) => ApiClient.authToken = token;

  static UserModel? get currentUser => ApiClient.currentUser;
  static set currentUser(UserModel? user) => ApiClient.currentUser = user;

  // ==========================================
  // AUTHENTICATION & SESSION
  // ==========================================
  static Future<void> saveSession(UserModel user, String token) =>
      AuthService.saveSession(user, token);

  static Future<void> restoreSession() =>
      AuthService.restoreSession();

  static Future<void> logout() =>
      AuthService.logout();

  static Future<UserModel> login(String email, String password) =>
      AuthService.login(email, password);

  static Future<UserModel> register(
    String fullName,
    String phone,
    String email,
    String password, {
    String gender = 'Not Specified',
    String address = '',
  }) =>
      AuthService.register(fullName, phone, email, password, gender: gender, address: address);

  static Future<UserModel> updateProfile({
    required String fullName,
    String? phone,
    String? gender,
    String? address,
    String? avatarUrl,
  }) =>
      AuthService.updateProfile(
        fullName: fullName,
        phone: phone,
        gender: gender,
        address: address,
        avatarUrl: avatarUrl,
      );

  static Future<UserModel?> refreshProfile() => AuthService.refreshProfile();

  static Future<UserModel> uploadAvatarFile(Uint8List fileBytes, String filename) =>
      AuthService.uploadAvatarFile(fileBytes, filename);

  static Future<void> changePassword(String oldPassword, String newPassword) =>
      AuthService.changePassword(oldPassword, newPassword);

  // ==========================================
  // ROOMS, HOTELS, SERVICES & CATALOG
  // ==========================================
  static Future<List<CategoryModel>> getCategories() =>
      RoomService.getCategories();

  static ServiceModel convertRoomJsonToServiceModel(Map<String, dynamic> r) =>
      RoomService.convertRoomJsonToServiceModel(r);

  static Future<List<ServiceModel>> getServices({
    String query = '',
    int? categoryId,
    String? roomType,
    bool? featured,
    bool? popular,
  }) =>
      RoomService.getServices(query: query, categoryId: categoryId, roomType: roomType, featured: featured, popular: popular);

  static Future<ServiceModel> getServiceById(int id) =>
      RoomService.getServiceById(id);

  static Future<List<ProviderModel>> getProviders() =>
      RoomService.getProviders();

  static Future<List<HotelModel>> getHotels({String query = '', String province = ''}) =>
      RoomService.getHotels(query: query, province: province);

  static Future<List<RoomModel>> getRoomsByHotel(int hotelId) =>
      RoomService.getRoomsByHotel(hotelId);

  // ==========================================
  // FAVORITES
  // ==========================================
  static ValueNotifier<Set<int>> get favoriteNotifier =>
      FavoriteService.favoriteNotifier;

  static Set<int> get favoriteRoomIds =>
      FavoriteService.favoriteRoomIds;

  static bool isFavorite(int roomId) =>
      FavoriteService.isFavorite(roomId);

  static Future<void> syncUserFavoritesFromServer(int userId) =>
      FavoriteService.syncUserFavoritesFromServer(userId);

  static Future<bool> toggleFavorite(int roomId) =>
      FavoriteService.toggleFavorite(roomId);

  static Future<List<ServiceModel>> getFavoriteRooms() =>
      FavoriteService.getFavoriteRooms();

  // ==========================================
  // BOOKINGS & AVAILABILITY
  // ==========================================
  static Future<Map<String, dynamic>> checkAvailability({
    required int providerId,
    required String date,
    String? requestedTime,
  }) =>
      BookingService.checkAvailability(providerId: providerId, date: date, requestedTime: requestedTime);

  static Future<Map<String, dynamic>> validateCoupon(String code, double spendAmount) =>
      BookingService.validateCoupon(code, spendAmount);

  static Future<BookingModel> createBooking({
    int? serviceId,
    int? providerId,
    int? locationId,
    int? roomId,
    int? hotelId,
    int? numberOfRooms,
    String? checkIn,
    String? checkOut,
    required String bookingDate,
    required String bookingTime,
    required String guestName,
    required String guestPhone,
    String? guestEmail,
    String? notes,
    String? couponCode,
    String paymentMethod = 'KHQR',
    List<Map<String, dynamic>> extras = const [],
    bool payDepositOnly = false,
  }) =>
      BookingService.createBooking(
        serviceId: serviceId,
        providerId: providerId,
        locationId: locationId,
        roomId: roomId,
        hotelId: hotelId,
        numberOfRooms: numberOfRooms,
        checkIn: checkIn,
        checkOut: checkOut,
        bookingDate: bookingDate,
        bookingTime: bookingTime,
        guestName: guestName,
        guestPhone: guestPhone,
        guestEmail: guestEmail,
        notes: notes,
        couponCode: couponCode,
        paymentMethod: paymentMethod,
        extras: extras,
        payDepositOnly: payDepositOnly,
      );

  static Future<Map<String, dynamic>> calculatePrice({
    required int roomId,
    int unitCount = 1,
    required String checkIn,
    required String checkOut,
    List<Map<String, dynamic>> extras = const [],
    String couponCode = '',
  }) =>
      BookingService.calculatePrice(
        roomId: roomId,
        unitCount: unitCount,
        checkIn: checkIn,
        checkOut: checkOut,
        extras: extras,
        couponCode: couponCode,
      );

  static Future<List<BookingModel>> getMyBookings() =>
      BookingService.getMyBookings();

  static Future<List<BookingModel>> getUpcomingBookings() =>
      BookingService.getUpcomingBookings();

  static Future<List<BookingModel>> getHistoryBookings() =>
      BookingService.getHistoryBookings();

  static Future<BookingModel> rescheduleBooking({
    required int bookingId,
    required String newDate,
    required String newTime,
    String? reason,
  }) =>
      BookingService.rescheduleBooking(bookingId: bookingId, newDate: newDate, newTime: newTime, reason: reason);

  static Future<BookingModel> cancelBooking({
    required int bookingId,
    required String reason,
  }) =>
      BookingService.cancelBooking(bookingId: bookingId, reason: reason);

  // ==========================================
  // NOTIFICATIONS
  // ==========================================
  static Future<List<NotificationModel>> getNotifications() =>
      NotificationService.getNotifications();

  static Future<int> getUnreadNotificationCount() =>
      NotificationService.getUnreadNotificationCount();

  static Future<void> markNotificationRead(int id) =>
      NotificationService.markNotificationRead(id);

  static Future<void> markAllNotificationsRead() =>
      NotificationService.markAllNotificationsRead();

  static Future<bool> deleteNotification(int id) =>
      NotificationService.deleteNotification(id);

  static Future<bool> clearAllNotifications() =>
      NotificationService.clearAllNotifications();
}
