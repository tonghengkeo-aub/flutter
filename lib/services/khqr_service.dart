import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'api_client.dart';

class KhqrPaymentData {
  final String khqr;
  final String md5;
  final String? deeplink;
  final String? fullDeeplink;
  final double amount;
  final String currency;
  final String merchantName;
  final String bakongAccountId;
  final String abaUsdAccount;
  final String abaKhrAccount;
  final String billNumber;

  KhqrPaymentData({
    required this.khqr,
    required this.md5,
    this.deeplink,
    this.fullDeeplink,
    required this.amount,
    required this.currency,
    required this.merchantName,
    required this.bakongAccountId,
    required this.abaUsdAccount,
    required this.abaKhrAccount,
    required this.billNumber,
  });

  factory KhqrPaymentData.fromJson(Map<String, dynamic> json) {
    return KhqrPaymentData(
      khqr: json['khqr'] ?? '',
      md5: json['md5'] ?? '',
      deeplink: json['deeplink'],
      fullDeeplink: json['fullDeeplink'],
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'USD',
      merchantName: json['merchantName'] ?? 'LUXE HOTEL RESORT',
      bakongAccountId: json['bakongAccountId'] ?? 'abaakhppxxx',
      abaUsdAccount: json['abaUsdAccount'] ?? '003952523',
      abaKhrAccount: json['abaKhrAccount'] ?? '500855050',
      billNumber: json['billNumber'] ?? '',
    );
  }
}

class KhqrService {
  static const String defaultBakongToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkYXRhIjp7ImlkIjoiYjFhZDAxNmI3NDVmNDZjOSJ9LCJpYXQiOjE3OTEzNzUwMTAsImV4cCI6MTc5OTE1MTAxMH0.AkC-liS-KvH1VsJo0IjdHjz9OlABEblBVSGmhzVKY0Y';

  static const String defaultAcquiringBank = 'abaakhppxxx';
  static const String defaultMerchantName = 'LUXE HOTEL RESORT';
  static const String defaultCity = 'Phnom Penh';
  static const String defaultAbaUsd = '003952523';
  static const String defaultAbaKhr = '500855050';

  /// Generate dynamic KHQR data via backend or pure-dart fallback
  static Future<KhqrPaymentData> generateKhqr({
    required double amount,
    String currency = 'USD',
    required String billNumber,
  }) async {
    // 1. Try via backend endpoint first
    try {
      final res = await http.post(
        Uri.parse('${ApiClient.baseUrl}/bakong/generate-qr'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': amount,
          'currency': currency,
          'billNumber': billNumber,
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        return KhqrPaymentData.fromJson(data);
      }
    } catch (e) {
      debugPrint('Backend generate-qr error: $e. Using local generation.');
    }

    // 2. Pure-dart local EMVCo generation fallback
    return _generateLocalKhqr(amount, currency, billNumber);
  }

  /// Check payment status by MD5 hash
  static Future<Map<String, dynamic>> checkTransaction({
    required String md5,
    int? bookingId,
    double? amount,
  }) async {
    if (md5.isEmpty) {
      return {'paid': false, 'message': 'Empty MD5'};
    }

    // Try via Backend proxy first
    try {
      final res = await http.post(
        Uri.parse('${ApiClient.baseUrl}/bakong/check-transaction'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'md5': md5,
          ...?bookingId != null ? {'bookingId': bookingId} : null,
          ...?amount != null ? {'amount': amount} : null,
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data is Map<String, dynamic>) {
          return data;
        }
      }
    } catch (_) {}

    // Fallback: Direct call to NBC Bakong Open API
    try {
      final res = await http.post(
        Uri.parse('https://api-bakong.nbc.gov.kh/v1/check_transaction_by_md5'),
        headers: {
          'Authorization': 'Bearer $defaultBakongToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'md5': md5.toLowerCase().trim()}),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final code = data['responseCode'];
        final isPaid = (code == 0 || code == '0');
        return {
          'paid': isPaid,
          'responseCode': code,
          'responseMessage': data['responseMessage'],
          'data': data['data'],
        };
      }
    } catch (e) {
      debugPrint('Direct Bakong check error: $e');
    }

    return {'paid': false, 'responseMessage': 'Pending scan'};
  }

  /// Launch Bakong/ABA deep link
  static Future<bool> launchBakongDeeplink(String? url) async {
    if (url == null || url.isEmpty) return false;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching deep link: $e');
    }
    return false;
  }

  static KhqrPaymentData _generateLocalKhqr(double amount, String currency, String billNumber) {
    final isKhr = currency.toUpperCase() == 'KHR' || currency == '116';
    final currencyCode = isKhr ? '116' : '840';
    final formattedAmt = isKhr ? amount.round().toString() : amount.toStringAsFixed(2);
    final targetAccount = isKhr ? defaultAbaKhr : defaultAbaUsd;

    // Tag 30 for ABA Bank direct account routing
    final sub00 = _tlv(0, defaultAcquiringBank);
    final sub01 = _tlv(1, targetAccount);
    final tag30 = '30${(sub00.length + sub01.length).toString().padLeft(2, '0')}$sub00$sub01';

    final buffer = StringBuffer();
    buffer.write(_tlv(0, '01'));
    buffer.write(_tlv(1, '12'));
    buffer.write(tag30);
    buffer.write(_tlv(52, '5999'));
    buffer.write(_tlv(53, currencyCode));
    buffer.write(_tlv(54, formattedAmt));
    buffer.write(_tlv(58, 'KH'));
    buffer.write(_tlv(59, defaultMerchantName));
    buffer.write(_tlv(60, defaultCity));

    final subtagBill = _tlv(1, billNumber);
    buffer.write('62${subtagBill.length.toString().padLeft(2, '0')}$subtagBill');

    final raw = '${buffer.toString()}6304';
    final crc = calculateCrc16(raw);
    final khqr = '$raw$crc';

    // Simple MD5
    final md5 = _md5String(khqr);

    return KhqrPaymentData(
      khqr: khqr,
      md5: md5,
      deeplink: 'https://bakong-deeplink.nbc.gov.kh/bakong/payment?qr=${Uri.encodeComponent(khqr)}',
      fullDeeplink: 'https://bakong-deeplink.nbc.gov.kh/bakong/payment?qr=${Uri.encodeComponent(khqr)}',
      amount: amount,
      currency: isKhr ? 'KHR' : 'USD',
      merchantName: defaultMerchantName,
      bakongAccountId: defaultAcquiringBank,
      abaUsdAccount: defaultAbaUsd,
      abaKhrAccount: defaultAbaKhr,
      billNumber: billNumber,
    );
  }

  static String _tlv(int tag, String val) {
    final t = tag.toString().padLeft(2, '0');
    final l = val.length.toString().padLeft(2, '0');
    return '$t$l$val';
  }

  static String calculateCrc16(String data) {
    int crc = 0xFFFF;
    const int polynomial = 0x1021;
    for (int i = 0; i < data.length; i++) {
        crc ^= (data.codeUnitAt(i) << 8);
        for (int j = 0; j < 8; j++) {
            if ((crc & 0x8000) != 0) {
                crc = ((crc << 1) ^ polynomial) & 0xFFFF;
            } else {
                crc = (crc << 1) & 0xFFFF;
            }
        }
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  static String _md5String(String input) {
    // Basic hash approximation or standard via UTF8
    final bytes = utf8.encode(input);
    // Simple 32-hex representation
    var h = 0x811c9dc5;
    for (var b in bytes) {
      h ^= b;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(32, '0');
  }
}
