import 'package:flutter/foundation.dart';
import 'provider_model.dart';

class ServiceModel {
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
  final String name;
  final String description;
  final int durationMinutes;
  final double price;
  final double priceKhr;
  final double rating;
  final int reviewCount;
  final String imageUrl;
  final bool isFeatured;
  final bool isPopular;
  final String categoryName;
  final String locationName;
  final String locationAddress;
  final String province;
  final List<ProviderModel> providers;
  final List<String> images;
  final int starRating;
  final String foodType;
  final String mapUrl;
  final String bedType;
  final String roomType;
  final String roomTier;
  final int hotelId;
  final int availableUnits;
  final int totalRooms;

  ServiceModel({
    required this.id,
    this.hotelId = 1,
    required this.name,
    required this.description,
    required this.durationMinutes,
    required this.price,
    required this.priceKhr,
    required this.rating,
    required this.reviewCount,
    required this.imageUrl,
    required this.isFeatured,
    required this.isPopular,
    required this.categoryName,
    required this.locationName,
    required this.locationAddress,
    required this.province,
    required this.providers,
    this.images = const [],
    this.starRating = 5,
    this.foodType = 'Breakfast included',
    this.mapUrl = 'https://maps.google.com/?q=Riverside+Blvd+Phnom+Penh',
    this.bedType = '1 King Bed',
    this.roomType = 'DOUBLE',
    this.roomTier = 'STANDARD',
    this.availableUnits = 1,
    this.totalRooms = 1,
  });

  String get cleanName {
    final stripped = name.replaceFirst(RegExp(r'^Room\s+[A-Za-z0-9\-]+\s*[·\-–]\s*', caseSensitive: false), '').trim();
    return stripped.isNotEmpty ? stripped : name;
  }

  String get roomTypeDisplay {
    switch (roomType.toUpperCase()) {
      case 'SINGLE':
        return 'Single Room';
      case 'DOUBLE':
        return 'Double Room';
      case 'TWIN':
        return 'Twin Room';
      case 'TRIPLE':
        return 'Triple Room';
      case 'FAMILY':
        return 'Family Room';
      case 'SUITE':
      case 'VIP':
        return 'Suite Room';
      default:
        return roomType.isNotEmpty ? roomType : categoryName;
    }
  }

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    String catName = 'Service';
    if (json['category'] != null) {
      catName = json['category']['name'] ?? catName;
    }

    String locName = 'Headquarters';
    String locAddr = 'Phnom Penh, Cambodia';
    String prov = 'Phnom Penh';
    if (json['location'] != null) {
      locName = json['location']['name'] ?? locName;
      locAddr = json['location']['address'] ?? locAddr;
      prov = json['location']['province'] ?? prov;
    }

    List<ProviderModel> provList = [];
    if (json['providers'] != null && json['providers'] is List) {
      provList = (json['providers'] as List).map((p) => ProviderModel.fromJson(p)).toList();
    }

    double p = 0.0;
    if (json['price'] != null) {
      p = double.tryParse(json['price'].toString()) ?? 0.0;
    }

    double pKhr = p * 4100;
    if (json['priceKhr'] != null) {
      pKhr = double.tryParse(json['priceKhr'].toString()) ?? (p * 4100);
    }

    List<String> imgList = [];
    if (json['images'] != null) {
      if (json['images'] is List) {
        imgList = (json['images'] as List)
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .map(_safeUrl)
            .toList();
      } else if (json['images'] is String) {
        final str = (json['images'] as String).trim();
        final cleanedStr = str
            .replaceAllMapped(RegExp(r'(https?://)', caseSensitive: false), (m) => '\n${m[1]}')
            .replaceAllMapped(RegExp(r'(data:image/)', caseSensitive: false), (m) => '\n${m[1]}');
        imgList = cleanedStr
            .split(RegExp(r'[\r\n,;\s]+'))
            .map((e) => e.trim())
            .where((e) => e.startsWith('http://') || e.startsWith('https://') || e.startsWith('data:image/'))
            .map(_safeUrl)
            .toList();
      }
    }

    String mainImg = (json['imageUrl'] != null && json['imageUrl'].toString().isNotEmpty)
        ? _safeUrl(json['imageUrl'].toString())
        : (imgList.isNotEmpty ? imgList.first : '');

    if (imgList.isEmpty && mainImg.isNotEmpty) {
      imgList = [mainImg];
    }

    final int sRating = json['starRating'] is int
        ? json['starRating']
        : int.tryParse(json['starRating']?.toString() ?? '5') ?? 5;
    final String fType = json['foodType']?.toString().isNotEmpty == true
        ? json['foodType'].toString()
        : 'Breakfast included';
    final String mUrl = json['mapUrl']?.toString().isNotEmpty == true
        ? json['mapUrl'].toString()
        : (json['location']?['mapUrl']?.toString() ?? 'https://maps.google.com/?q=Riverside+Blvd+Phnom+Penh');
    final String bType = json['bedType']?.toString().isNotEmpty == true
        ? json['bedType'].toString()
        : '1 King Bed';

    final int aUnits = json['availableUnits'] != null
        ? (int.tryParse(json['availableUnits'].toString()) ?? 5)
        : 5;
    final int tRooms = json['totalRooms'] != null
        ? (int.tryParse(json['totalRooms'].toString()) ?? aUnits)
        : aUnits;

    return ServiceModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? 'Service',
      description: json['description'] ?? '',
      durationMinutes: json['durationMinutes'] is int ? json['durationMinutes'] : 60,
      price: p,
      priceKhr: pKhr,
      rating: json['rating'] != null ? (double.tryParse(json['rating'].toString()) ?? 4.8) : 4.8,
      reviewCount: json['reviewCount'] is int ? json['reviewCount'] : 45,
      imageUrl: mainImg,
      isFeatured: json['isFeatured'] ?? false,
      isPopular: json['isPopular'] ?? false,
      categoryName: catName,
      locationName: locName,
      locationAddress: locAddr,
      province: prov,
      providers: provList,
      images: imgList,
      starRating: sRating,
      foodType: fType,
      mapUrl: mUrl,
      bedType: bType,
      roomType: json['type']?.toString().toUpperCase() ?? (json['roomType']?.toString().toUpperCase() ?? 'DOUBLE'),
      roomTier: json['roomTier'] != null && json['roomTier'].toString().isNotEmpty ? json['roomTier'].toString().toUpperCase() : 'STANDARD',
      hotelId: json['hotel'] != null ? (json['hotel']['id'] ?? 1) : (json['hotelId'] ?? 1),
      availableUnits: aUnits,
      totalRooms: tRooms,
    );
  }
}
