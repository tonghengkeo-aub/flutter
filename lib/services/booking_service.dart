import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/booking_model.dart';
import '../models/notification_model.dart';
import 'api_client.dart';
import 'notification_service.dart';

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
  // PRICE CALCULATION (BACKEND DRIVEN)
  // ==========================================
  static Future<Map<String, dynamic>> calculatePrice({
    required int roomId,
    int unitCount = 1,
    required String checkIn,
    required String checkOut,
    List<Map<String, dynamic>> extras = const [],
    String couponCode = '',
  }) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiClient.baseUrl}/bookings/calculate'),
        headers: ApiClient.defaultHeaders(requiresAuth: false),
        body: jsonEncode({
          'roomId': roomId,
          'unitCount': unitCount,
          'checkIn': checkIn,
          'checkOut': checkOut,
          'extras': extras,
          'couponCode': couponCode,
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes));
      }
    } catch (_) {}

    // Fallback calculation matching backend precision formula
    final inDate = DateTime.tryParse(checkIn) ?? DateTime.now();
    final outDate = DateTime.tryParse(checkOut) ?? inDate.add(const Duration(days: 1));
    int nights = outDate.difference(inDate).inDays;
    if (nights <= 0) nights = 1;

    double pricePerNight = 45.0;
    double roomTotal = pricePerNight * nights * unitCount;
    double extrasTotal = 0.0;
    for (var e in extras) {
      final p = (e['price'] as num?)?.toDouble() ?? 0.0;
      final q = (e['quantity'] as num?)?.toInt() ?? 1;
      extrasTotal += p * q;
    }

    double discount = 0.0;
    final cleanCode = couponCode.trim().toUpperCase();
    if (cleanCode == 'WELCOME10') {
      discount = (roomTotal + extrasTotal) * 0.10;
    } else if (cleanCode == 'KH2026') {
      discount = (roomTotal + extrasTotal) * 0.15;
    }

    double taxable = (roomTotal + extrasTotal - discount).clamp(0.0, double.infinity);
    double serviceCharge = taxable * 0.05;
    double tax = (taxable + serviceCharge) * 0.10;
    double total = taxable + serviceCharge + tax;
    double depositRequired = total * 0.20;
    double balanceDue = total - depositRequired;

    return {
      'nights': nights,
      'quantity': unitCount,
      'pricePerNight': pricePerNight,
      'roomTotal': roomTotal,
      'extrasTotal': extrasTotal,
      'subtotal': roomTotal + extrasTotal,
      'discount': discount,
      'couponCode': cleanCode.isNotEmpty ? cleanCode : null,
      'serviceCharge': serviceCharge,
      'serviceChargePercent': 5.0,
      'tax': tax,
      'taxPercent': 10.0,
      'total': total,
      'totalKhr': total * 4100,
      'depositPercent': 20.0,
      'depositRequired': depositRequired,
      'balanceDue': balanceDue,
      'cancellationPolicy': 'Free cancellation up to 48 hours prior to check-in. Cancellations within 48 hours forfeit the deposit.',
    };
  }

  // ==========================================
  // BOOKINGS MANAGEMENT
  // ==========================================
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
  }) async {
    final Map<String, dynamic> body = {
      if (serviceId != null && serviceId > 0) 'serviceId': serviceId,
      if (providerId != null && providerId > 0) 'providerId': providerId,
      if (locationId != null && locationId > 0) 'locationId': locationId,
      if (roomId != null && roomId > 0) 'roomId': roomId,
      if (hotelId != null && hotelId > 0) 'hotelId': hotelId,
      'numberOfRooms': (numberOfRooms != null && numberOfRooms > 0) ? numberOfRooms : 1,
      if (checkIn != null && checkIn.isNotEmpty) 'checkIn': checkIn,
      if (checkOut != null && checkOut.isNotEmpty) 'checkOut': checkOut,
      'bookingDate': bookingDate,
      'bookingTime': bookingTime,
      'guestName': guestName,
      'guestPhone': guestPhone,
      if (guestEmail != null && guestEmail.isNotEmpty) 'guestEmail': guestEmail,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
      'paymentMethod': paymentMethod,
      'extras': extras,
      'payDepositOnly': payDepositOnly,
    };

    try {
      final res = await http.post(
        Uri.parse('${ApiClient.baseUrl}/bookings'),
        headers: ApiClient.defaultHeaders(),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final created = BookingModel.fromJson(data);
        _localBookings.insert(0, created);
        return created;
      } else {
        String errMsg = 'Could not create booking';
        try {
          final err = jsonDecode(utf8.decode(res.bodyBytes));
          if (err is Map) {
            errMsg = err['message'] ?? err['error'] ?? errMsg;
          }
        } catch (_) {}
        throw Exception(errMsg);
      }
    } catch (e) {
      rethrow;
    }
  }

  static void clearLocalCache() {
    _localBookings.clear();
  }

  static Future<List<BookingModel>> getMyBookings() async {
    try {
      final userEmail = ApiClient.currentUser?.email;
      final queryParam = (userEmail != null && userEmail.isNotEmpty)
          ? '?email=${Uri.encodeComponent(userEmail)}'
          : '';
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/bookings/my$queryParam'),
        headers: ApiClient.defaultHeaders(isJson: false),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        final remote = list.map((e) => BookingModel.fromJson(e)).toList();
        _localBookings.clear();
        _localBookings.addAll(remote);
        return remote;
      }
    } catch (_) {}

    return _localBookings;
  }

  static Future<List<BookingModel>> getUpcomingBookings() async {
    try {
      final userEmail = ApiClient.currentUser?.email;
      final queryParam = (userEmail != null && userEmail.isNotEmpty)
          ? '?email=${Uri.encodeComponent(userEmail)}'
          : '';
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/bookings/upcoming$queryParam'),
        headers: ApiClient.defaultHeaders(isJson: false),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.map((e) => BookingModel.fromJson(e)).toList();
      }
    } catch (_) {}

    final all = await getMyBookings();
    return all.where((b) => b.status == 'CONFIRMED' || b.status == 'RESCHEDULED' || b.status == 'PENDING' || b.status == 'CHECKED_IN').toList();
  }

  static Future<List<BookingModel>> getHistoryBookings() async {
    try {
      final userEmail = ApiClient.currentUser?.email;
      final queryParam = (userEmail != null && userEmail.isNotEmpty)
          ? '?email=${Uri.encodeComponent(userEmail)}'
          : '';
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/bookings/history$queryParam'),
        headers: ApiClient.defaultHeaders(isJson: false),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.map((e) => BookingModel.fromJson(e)).toList();
      }
    } catch (_) {}

    final all = await getMyBookings();
    return all.where((b) => b.status == 'COMPLETED' || b.status == 'CANCELLED' || b.status == 'NO_SHOW').toList();
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
}
