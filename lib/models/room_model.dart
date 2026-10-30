import 'package:flutter/foundation.dart';

class RoomModel {
  static String _safeUrl(String raw) {
    if (raw.isEmpty) return raw;
    if (raw.startsWith('data:image')) return raw;
    if (raw.contains('wsrv.nl')) return raw;
    if (kIsWeb || raw.contains('pinimg.com')) {
      if (raw.startsWith('http://') || raw.startsWith('https://')) {
        return 'https://wsrv.nl/?url=${Uri.encodeComponent(raw)}';
      }
    }
    return raw;
  }

  final int id;
  final int hotelId;
  final String roomNumber;
  final String? name;
  final String type;
  final double priceUsd;
  final double priceKhr;
  final int maxGuests;
  final String bedType;
  final String description;
  final String images;
  final String status;
  final double deluxePriceExtra;
  final double premiumPriceExtra;
  final String? standardInfo;
  final String? deluxeInfo;
  final String? premiumInfo;
  final String roomTier;
  final String roomSize;
  final String amenities;
  final int totalRooms;
  final int availableUnits;
  final bool freeCancellation;
  final bool noPrepayment;
  final bool includesBreakfast;
  final bool includesMassage;

  RoomModel({
    required this.id,
    required this.hotelId,
    required this.roomNumber,
    this.name,
    required this.type,
    required this.priceUsd,
    required this.priceKhr,
    required this.maxGuests,
    required this.bedType,
    required this.description,
    required this.images,
    required this.status,
    this.deluxePriceExtra = 30.0,
    this.premiumPriceExtra = 50.0,
    this.standardInfo,
    this.deluxeInfo,
    this.premiumInfo,
    this.roomTier = 'STANDARD',
    this.roomSize = '28 m²',
    this.amenities = 'Free WiFi, Tea/Coffee maker, Balcony, Attached bathroom, City view',
    this.totalRooms = 1,
    this.availableUnits = 1,
    this.freeCancellation = true,
    this.noPrepayment = true,
    this.includesBreakfast = false,
    this.includesMassage = false,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    double usd = json['priceUsd'] != null ? (double.tryParse(json['priceUsd'].toString()) ?? 50.0) : 50.0;
    double khr = json['priceKhr'] != null ? (double.tryParse(json['priceKhr'].toString()) ?? (usd * 4100)) : (usd * 4100);
    double deluxeExtra = json['deluxePriceExtra'] != null ? (double.tryParse(json['deluxePriceExtra'].toString()) ?? 30.0) : 30.0;
    double premiumExtra = json['premiumPriceExtra'] != null ? (double.tryParse(json['premiumPriceExtra'].toString()) ?? 50.0) : 50.0;
    int units = json['availableUnits'] != null ? (int.tryParse(json['availableUnits'].toString()) ?? 1) : 1;
    int total = json['totalRooms'] != null ? (int.tryParse(json['totalRooms'].toString()) ?? units) : units;

    return RoomModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      hotelId: json['hotel'] != null && json['hotel']['id'] != null 
          ? json['hotel']['id'] 
          : (json['hotelId'] ?? 0),
      roomNumber: json['roomNumber'] ?? '',
      name: json['name']?.toString(),
      type: json['type'] ?? 'DOUBLE',
      priceUsd: usd,
      priceKhr: khr,
      maxGuests: json['maxGuests'] ?? 2,
      bedType: json['bedType'] ?? '1 King Bed',
      description: json['description'] ?? '',
      images: json['images']?.toString() ?? '',
      status: json['status'] ?? 'AVAILABLE',
      deluxePriceExtra: deluxeExtra,
      premiumPriceExtra: premiumExtra,
      standardInfo: json['standardInfo']?.toString(),
      deluxeInfo: json['deluxeInfo']?.toString(),
      premiumInfo: json['premiumInfo']?.toString(),
      roomTier: json['roomTier'] != null && json['roomTier'].toString().isNotEmpty ? json['roomTier'].toString().toUpperCase() : 'STANDARD',
      roomSize: json['roomSize'] != null && json['roomSize'].toString().isNotEmpty ? json['roomSize'].toString().replaceAll('ft²', 'm²') : '28 m²',
      amenities: json['amenities'] != null && json['amenities'].toString().isNotEmpty ? json['amenities'].toString() : 'Free WiFi, Tea/Coffee maker, Balcony, Attached bathroom, City view',
      totalRooms: total,
      availableUnits: units,
      freeCancellation: json['freeCancellation'] != null ? (json['freeCancellation'] == true || json['freeCancellation'].toString() == 'true') : true,
      noPrepayment: json['noPrepayment'] != null ? (json['noPrepayment'] == true || json['noPrepayment'].toString() == 'true') : true,
      includesBreakfast: json['includesBreakfast'] != null ? (json['includesBreakfast'] == true || json['includesBreakfast'].toString() == 'true') : (json['foodType'] != null && json['foodType'].toString().toLowerCase().contains('breakfast')),
      includesMassage: json['includesMassage'] != null ? (json['includesMassage'] == true || json['includesMassage'].toString() == 'true') : false,
    );
  }

  String get firstImageUrl {
    if (images.trim().isEmpty) return '';
    final cleaned = images
        .replaceAllMapped(RegExp(r'(https?://)', caseSensitive: false), (m) => '\n${m[1]}')
        .replaceAllMapped(RegExp(r'(data:image/)', caseSensitive: false), (m) => '\n${m[1]}');
    final list = cleaned
        .split(RegExp(r'[\r\n,;\s]+'))
        .map((s) => s.trim())
        .where((s) => s.startsWith('http://') || s.startsWith('https://') || s.startsWith('data:image/'))
        .map(_safeUrl)
        .toList();
    return list.isNotEmpty ? list.first : '';
  }

  List<String> get allImages {
    if (images.isEmpty) return [];
    final cleaned = images
        .replaceAllMapped(RegExp(r'(https?://)', caseSensitive: false), (m) => '\n${m[1]}')
        .replaceAllMapped(RegExp(r'(data:image/)', caseSensitive: false), (m) => '\n${m[1]}');
    return cleaned
        .split(RegExp(r'[\r\n,;\s]+'))
        .map((s) => s.trim())
        .where((s) => s.startsWith('http://') || s.startsWith('https://') || s.startsWith('data:image/'))
        .map(_safeUrl)
        .toList();
  }
}
