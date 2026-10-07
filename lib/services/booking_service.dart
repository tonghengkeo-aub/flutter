import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/booking_model.dart';
import '../models/notification_model.dart';
import 'api_client.dart';
import 'notification_service.dart';
import 'room_service.dart';

class BookingService {
  static final List<BookingModel> _localBookings = [];

  // ==========================================
  // AVAILABILITY & CONFLICT CHECKING
  // ==========================================
  static Future<Map<String, dynamic>> checkAvailability({
    required int providerId,
    required String date,
    String? requestedTime,
  }) async {
    try {
      String url = '${ApiClient.baseUrl}/bookings/check-availability?providerId=$providerId&date=$date';
      if (requestedTime != null) url += '&time=${Uri.encodeComponent(requestedTime)}';

      final res = await http.get(
        Uri.parse(url),
        headers: ApiClient.defaultHeaders(isJson: false),
      ).timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes));
      }
    } catch (_) {}

    // Dynamic local fallback checking against booked slots
    final bookedForDay = _localBookings
        .where((b) => b.bookingDate == date && b.status != 'CANCELLED')
        .map((b) => b.bookingTime)
        .toSet();

    const allSlots = [
      '08:30 AM', '09:30 AM', '10:30 AM', '11:30 AM',
      '01:30 PM', '02:30 PM', '03:30 PM', '04:30 PM', '05:30 PM', '06:30 PM'
    ];

    final available = allSlots.where((s) => !bookedForDay.contains(s)).toList();
    final isReqAvail = requestedTime == null || available.contains(requestedTime);

    return {
      'available': isReqAvail,
      'availableSlots': available,
      'bookedSlots': bookedForDay.toList(),
      'message': isReqAvail ? 'Slot available' : 'Slot already booked',
    };
  }

  // ==========================================
  // COUPON VALIDATION
  // ==========================================
  static Future<Map<String, dynamic>> validateCoupon(String code, double spendAmount) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiClient.baseUrl}/coupons/validate'),
        headers: ApiClient.defaultHeaders(requiresAuth: false),
        body: jsonEncode({'code': code, 'spendAmount': spendAmount}),
      ).timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes));
      }
    } catch (_) {}

    final clean = code.trim().toUpperCase();
    if (clean == 'WELCOME10') {
      final discount = spendAmount * 0.10;
      return {
        'valid': true,
        'code': 'WELCOME10',
        'discountPercent': 10,
        'discountAmount': discount,
        'finalAmount': spendAmount - discount,
        'message': 'WELCOME10 applied: 10% discount saved!',
      };
    } else if (clean == 'KH2026') {
      final discount = spendAmount * 0.15;
      return {
        'valid': true,
        'code': 'KH2026',
        'discountPercent': 15,
        'discountAmount': discount,
        'finalAmount': spendAmount - discount,
        'message': 'KH2026 applied: 15% special discount saved!',
      };
    }

    return {
      'valid': false,
      'code': code,
      'discountPercent': 0,
      'discountAmount': 0.0,
      'finalAmount': spendAmount,
      'message': 'Invalid coupon code. Try WELCOME10 or KH2026.',
    };
  }

  // ==========================================
  // BOOKINGS MANAGEMENT
  // ==========================================
  static Future<BookingModel> createBooking({
    required int serviceId,
    required int providerId,
    required int locationId,
    required String bookingDate,
    required String bookingTime,
    required String guestName,
    required String guestPhone,
    String? guestEmail,
    String? notes,
    String? couponCode,
    String paymentMethod = 'KHQR',
  }) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiClient.baseUrl}/bookings'),
        headers: ApiClient.defaultHeaders(),
        body: jsonEncode({
          'serviceId': serviceId,
          'providerId': providerId,
          'locationId': locationId,
          'bookingDate': bookingDate,
          'bookingTime': bookingTime,
          'guestName': guestName,
          'guestPhone': guestPhone,
          'guestEmail': guestEmail,
          'notes': notes,
          'couponCode': couponCode,
          'paymentMethod': paymentMethod,
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final created = BookingModel.fromJson(data);
        _localBookings.insert(0, created);
        return created;
      } else {
        final err = jsonDecode(utf8.decode(res.bodyBytes));
        throw Exception(err['message'] ?? 'Could not create booking');
      }
    } catch (e) {
      if (e.toString().contains('already booked')) rethrow;
    }

    // Dynamic fallback booking
    final services = await RoomService.getServices();
    final service = services.firstWhere((s) => s.id == serviceId, orElse: () => services.first);
    final providers = await RoomService.getProviders();
    final provider = providers.firstWhere((p) => p.id == providerId, orElse: () => providers.first);

    double discount = 0.0;
    if (couponCode?.toUpperCase() == 'WELCOME10') discount = service.price * 0.10;
    if (couponCode?.toUpperCase() == 'KH2026') discount = service.price * 0.15;
    final finalP = service.price - discount;

    final newBooking = BookingModel(
      id: DateTime.now().millisecondsSinceEpoch % 10000,
      bookingCode: 'BK-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().microsecond % 1000}',
      title: service.name,
      providerName: provider.name,
      locationAddress: service.locationAddress,
      bookingDate: bookingDate,
      bookingTime: bookingTime,
      durationMinutes: service.durationMinutes,
      totalPrice: service.price,
      discountAmount: discount,
      finalPrice: finalP,
      finalPriceKhr: finalP * 4100,
      guestName: guestName,
      guestPhone: guestPhone,
      guestEmail: guestEmail,
      status: 'CONFIRMED',
      imageUrl: service.imageUrl,
    );

    _localBookings.insert(0, newBooking);

    NotificationService.addNotification(
      NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch % 1000,
        title: 'Booking Confirmed #${newBooking.bookingCode}',
        message: 'Your booking for ${service.name} on $bookingDate at $bookingTime is confirmed.',
        type: 'BOOKING_CONFIRMED',
        isRead: false,
        createdAt: 'Just now',
      ),
    );

    return newBooking;
  }

  static Future<List<BookingModel>> getMyBookings() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/bookings/my'),
        headers: ApiClient.defaultHeaders(isJson: false),
      ).timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        final remote = list.map((e) => BookingModel.fromJson(e)).toList();
        if (remote.isNotEmpty) return remote;
      }
    } catch (_) {}

    if (_localBookings.isEmpty) {
      _seedDefaultBookings();
    }
    return _localBookings;
  }

  static Future<List<BookingModel>> getUpcomingBookings() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/bookings/upcoming'),
        headers: ApiClient.defaultHeaders(isJson: false),
      ).timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.map((e) => BookingModel.fromJson(e)).toList();
      }
    } catch (_) {}

    final all = await getMyBookings();
    return all.where((b) => b.status == 'CONFIRMED' || b.status == 'RESCHEDULED' || b.status == 'PENDING').toList();
  }

  static Future<List<BookingModel>> getHistoryBookings() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/bookings/history'),
        headers: ApiClient.defaultHeaders(isJson: false),
      ).timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.map((e) => BookingModel.fromJson(e)).toList();
      }
    } catch (_) {}

    final all = await getMyBookings();
    return all.where((b) => b.status == 'COMPLETED' || b.status == 'CANCELLED').toList();
  }

  static Future<BookingModel> rescheduleBooking({
    required int bookingId,
    required String newDate,
    required String newTime,
    String? reason,
  }) async {
    try {
      final res = await http.put(
        Uri.parse('${ApiClient.baseUrl}/bookings/$bookingId/reschedule'),
        headers: ApiClient.defaultHeaders(),
        body: jsonEncode({
          'newDate': newDate,
          'newTime': newTime,
          'reason': reason ?? 'Customer request',
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final updated = BookingModel.fromJson(data);
        _updateLocalBooking(updated);
        return updated;
      }
    } catch (_) {}

    final idx = _localBookings.indexWhere((b) => b.id == bookingId);
    if (idx != -1) {
      final old = _localBookings[idx];
      final updated = BookingModel(
        id: old.id,
        bookingCode: old.bookingCode,
        title: old.title,
        providerName: old.providerName,
        locationAddress: old.locationAddress,
        bookingDate: newDate,
        bookingTime: newTime,
        durationMinutes: old.durationMinutes,
        totalPrice: old.totalPrice,
        discountAmount: old.discountAmount,
        finalPrice: old.finalPrice,
        finalPriceKhr: old.finalPriceKhr,
        guestName: old.guestName,
        guestPhone: old.guestPhone,
        guestEmail: old.guestEmail,
        status: 'RESCHEDULED',
        imageUrl: old.imageUrl,
      );
      _localBookings[idx] = updated;

      NotificationService.addNotification(
        NotificationModel(
          id: DateTime.now().millisecondsSinceEpoch % 1000,
          title: 'Booking Rescheduled #${old.bookingCode}',
          message: 'Appointment moved to $newDate at $newTime.',
          type: 'BOOKING_RESCHEDULED',
          isRead: false,
          createdAt: 'Just now',
        ),
      );

      return updated;
    }
    throw Exception('Booking not found');
  }

  static Future<BookingModel> cancelBooking({
    required int bookingId,
    required String reason,
  }) async {
    try {
      final res = await http.put(
        Uri.parse('${ApiClient.baseUrl}/bookings/$bookingId/cancel'),
        headers: ApiClient.defaultHeaders(),
        body: jsonEncode({'reason': reason}),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final updated = BookingModel.fromJson(data);
        _updateLocalBooking(updated);
        return updated;
      }
    } catch (_) {}

    final idx = _localBookings.indexWhere((b) => b.id == bookingId);
    if (idx != -1) {
      final old = _localBookings[idx];
      final updated = BookingModel(
        id: old.id,
        bookingCode: old.bookingCode,
        title: old.title,
        providerName: old.providerName,
        locationAddress: old.locationAddress,
        bookingDate: old.bookingDate,
        bookingTime: old.bookingTime,
        durationMinutes: old.durationMinutes,
        totalPrice: old.totalPrice,
        discountAmount: old.discountAmount,
        finalPrice: old.finalPrice,
        finalPriceKhr: old.finalPriceKhr,
        guestName: old.guestName,
        guestPhone: old.guestPhone,
        guestEmail: old.guestEmail,
        status: 'CANCELLED',
        cancellationReason: reason,
        imageUrl: old.imageUrl,
      );
      _localBookings[idx] = updated;

      NotificationService.addNotification(
        NotificationModel(
          id: DateTime.now().millisecondsSinceEpoch % 1000,
          title: 'Booking Cancelled #${old.bookingCode}',
          message: 'Booking has been cancelled. Reason: $reason',
          type: 'BOOKING_CANCELLED',
          isRead: false,
          createdAt: 'Just now',
        ),
      );

      return updated;
    }
    throw Exception('Booking not found');
  }

  static void _updateLocalBooking(BookingModel updated) {
    final idx = _localBookings.indexWhere((b) => b.id == updated.id);
    if (idx != -1) {
      _localBookings[idx] = updated;
    } else {
      _localBookings.insert(0, updated);
    }
  }

  static void _seedDefaultBookings() {
    _localBookings.addAll([
      BookingModel(
        id: 101,
        bookingCode: 'BK-20260925-A101',
        title: 'Room 201 - Riverside Deluxe King Suite',
        providerName: 'Sreymom Chan (VIP Host)',
        locationAddress: 'Riverside Luxury Grand Hotel, Sisowath Quay, Phnom Penh',
        bookingDate: '2026-09-28',
        bookingTime: '02:00 PM',
        durationMinutes: 1440,
        totalPrice: 75.0,
        discountAmount: 7.5,
        finalPrice: 67.5,
        finalPriceKhr: 276750.0,
        guestName: 'Sophea Pich',
        guestPhone: '098111222',
        status: 'CONFIRMED',
        imageUrl: 'https://images.unsplash.com/photo-1590490360182-c33d57733427?w=800',
      ),
      BookingModel(
        id: 102,
        bookingCode: 'BK-20260920-B882',
        title: 'Rosewood Executive Suite & Breakfast',
        providerName: 'Concierge Sokha',
        locationAddress: 'Vattanac Capital Tower, Monivong Blvd, Phnom Penh',
        bookingDate: '2026-09-20',
        bookingTime: '02:00 PM',
        durationMinutes: 1440,
        totalPrice: 180.0,
        discountAmount: 18.0,
        finalPrice: 162.0,
        finalPriceKhr: 664200.0,
        guestName: 'Sophea Pich',
        guestPhone: '098111222',
        status: 'COMPLETED',
        imageUrl: 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800',
      ),
    ]);
  }
}
