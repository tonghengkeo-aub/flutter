import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/category_model.dart';
import '../models/hotel_model.dart';
import '../models/provider_model.dart';
import '../models/room_model.dart';
import '../models/service_model.dart';
import 'api_client.dart';

class RoomService {
  // ==========================================
  // CATEGORIES
  // ==========================================
  static Future<List<CategoryModel>> getCategories() async {
    return [
      CategoryModel(id: 1, name: 'Single Rooms', icon: 'single_bed', description: 'Cozy modern single bed rooms'),
      CategoryModel(id: 2, name: 'Double / King Rooms', icon: 'bed', description: 'Luxury King and Double bed rooms'),
      CategoryModel(id: 3, name: 'Executive Suites', icon: 'meeting_room', description: 'Corner suites with private lounge'),
      CategoryModel(id: 4, name: 'VIP Presidential Villas', icon: 'villa', description: 'Presidential and pool villas'),
      CategoryModel(id: 5, name: 'Family Suites', icon: 'family_restroom', description: 'Spacious interconnected suites'),
    ];
  }

  // ==========================================
  // ROOM CONVERTER & IMAGE PARSER
  // ==========================================
  static String safeWebUrl(String raw) {
    if (raw.isEmpty) return raw;
    if (raw.startsWith('data:image')) return raw;
    if (raw.contains('wsrv.nl')) return raw;
    // Pinterest and various external servers omit Access-Control-Allow-Origin,
    // which causes browser HTML5 canvas security blocks in Flutter Web.
    if (kIsWeb || raw.contains('pinimg.com')) {
      if (raw.startsWith('http://') || raw.startsWith('https://')) {
        return 'https://wsrv.nl/?url=${Uri.encodeComponent(raw)}';
      }
    }
    return raw;
  }

  static String getRoomTypeDisplayName(String? type) {
    switch (type?.toUpperCase()) {
      case 'SINGLE':
        return 'Single Room';
      case 'DOUBLE':
        return 'Double / King Room';
      case 'SUITE':
        return 'Executive Suite';
      case 'VIP':
        return 'VIP Presidential Villa';
      case 'FAMILY':
        return 'Family Suite';
      default:
        return (type != null && type.isNotEmpty) ? '$type Room' : 'Double / King Room';
    }
  }

  static ServiceModel convertRoomJsonToServiceModel(Map<String, dynamic> r) {
    final roomNum = r['roomNumber']?.toString() ?? '';
    final imagesStr = r['images']?.toString() ?? '';
    List<String> rawImages = [];
    if (imagesStr.isNotEmpty) {
      final cleanedStr = imagesStr
          .replaceAllMapped(RegExp(r'(https?://)', caseSensitive: false), (m) => '\n${m[1]}')
          .replaceAllMapped(RegExp(r'(data:image/)', caseSensitive: false), (m) => '\n${m[1]}');
      rawImages = cleanedStr
          .split(RegExp(r'[\r\n,;\s]+'))
          .map((s) => s.trim())
          .where((s) => s.startsWith('http://') || s.startsWith('https://') || s.startsWith('data:image/'))
          .map(safeWebUrl)
          .toList();
    }
    final imgUrl = rawImages.isNotEmpty
        ? rawImages.first
        : 'https://images.unsplash.com/photo-1590490360182-c33d57733427?w=800';

    final rawType = r['type']?.toString().toUpperCase() ?? 'DOUBLE';
    final typeDisplay = getRoomTypeDisplayName(rawType);
    final parsedPrice = (r['priceUsd'] as num?)?.toDouble() ?? 75.0;
    final parsedPriceKhr = (r['priceKhr'] as num?)?.toDouble() ?? (parsedPrice * 4100);
    final parsedRating = (r['rating'] as num?)?.toDouble() ?? 4.8;
    final parsedStars = (r['starRating'] as num?)?.toInt() ?? 5;
    final parsedReviewCount = (r['reviewCount'] as num?)?.toInt() ?? 128;
    final parsedBedType = (r['bedType']?.toString().isNotEmpty == true)
        ? r['bedType'].toString()
        : '1 King Bed';
    final parsedFoodType = (r['foodType']?.toString().isNotEmpty == true)
        ? r['foodType'].toString()
        : 'Breakfast included';
    final parsedMapUrl = (r['mapUrl']?.toString().isNotEmpty == true)
        ? r['mapUrl'].toString()
        : ((r['hotel']?['mapUrl']?.toString().isNotEmpty == true)
            ? r['hotel']!['mapUrl'].toString()
            : 'https://maps.google.com/?q=Riverside+Blvd+Phnom+Penh');

    return ServiceModel(
      id: r['id'] ?? (100 + (int.tryParse(roomNum) ?? 0)),
      name: 'Room $roomNum · $typeDisplay',
      description: r['description'] ?? 'Spacious and luxury hotel room with modern amenities.',
      durationMinutes: 1440,
      price: parsedPrice,
      priceKhr: parsedPriceKhr,
      rating: parsedRating,
      reviewCount: parsedReviewCount,
      imageUrl: imgUrl,
      images: rawImages.isNotEmpty ? rawImages : [imgUrl],
      isFeatured: parsedPrice >= 75 || parsedRating >= 4.9 || rawType == 'VIP' || rawType == 'SUITE',
      isPopular: true,
      categoryName: typeDisplay,
      locationName: r['hotel']?['name'] ?? 'Grand Luxury Hotel Phnom Penh',
      locationAddress: r['hotel']?['address'] ?? 'Preah Sisowath Quay, Daun Penh',
      province: r['hotel']?['province'] ?? 'Phnom Penh',
      providers: [],
      starRating: parsedStars,
      foodType: parsedFoodType,
      mapUrl: parsedMapUrl,
      bedType: parsedBedType,
      roomType: rawType,
    );
  }

  // ==========================================
  // GET SERVICES / ROOMS (SEARCH & FILTER)
  // ==========================================
  static Future<List<ServiceModel>> getServices({
    String query = '',
    int? categoryId,
    String? roomType,
    bool? featured,
    bool? popular,
  }) async {
    List<ServiceModel> allRooms = [];

    // 1. Fetch live rooms from /api/rooms/hotel/1 (directly reflects Admin CRUD & image uploads!)
    try {
      final resRooms = await http.get(Uri.parse('${ApiClient.baseUrl}/rooms/hotel/1')).timeout(const Duration(seconds: 10));
      if (resRooms.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(resRooms.bodyBytes));
        for (var r in list) {
          allRooms.add(convertRoomJsonToServiceModel(r as Map<String, dynamic>));
        }
      }
    } catch (e) {
      debugPrint('Error loading live rooms from /api/rooms/hotel/1: $e');
    }

    // Only if /api/rooms/hotel/1 is empty, fallback to /api/services
    if (allRooms.isEmpty) {
      try {
        final res = await http.get(Uri.parse('${ApiClient.baseUrl}/services')).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final List list = jsonDecode(utf8.decode(res.bodyBytes));
          allRooms = list.map((e) => ServiceModel.fromJson(e)).toList();
        }
      } catch (e) {
        debugPrint('Error loading services: $e');
      }
    }

    if (allRooms.isNotEmpty) {
      var filtered = allRooms;
      if (query.isNotEmpty) {
        final q = query.toLowerCase();
        filtered = filtered.where((r) =>
          r.name.toLowerCase().contains(q) ||
          r.description.toLowerCase().contains(q) ||
          r.categoryName.toLowerCase().contains(q) ||
          r.roomType.toLowerCase().contains(q) ||
          r.bedType.toLowerCase().contains(q) ||
          r.province.toLowerCase().contains(q)
        ).toList();
      }

      // Filter by roomType code (e.g. 'SINGLE', 'DOUBLE', 'SUITE', 'VIP', 'FAMILY')
      if (roomType != null && roomType.isNotEmpty && roomType.toUpperCase() != 'ALL') {
        final target = roomType.toUpperCase();
        filtered = filtered.where((r) => r.roomType.toUpperCase() == target).toList();
      } else if (categoryId != null && categoryId > 0) {
        filtered = filtered.where((r) {
          final type = r.roomType.toUpperCase();
          if (categoryId == 1) return type == 'SINGLE';
          if (categoryId == 2) return type == 'DOUBLE';
          if (categoryId == 3) return type == 'SUITE';
          if (categoryId == 4) return type == 'VIP';
          if (categoryId == 5) return type == 'FAMILY';
          return true;
        }).toList();
      }

      if (featured == true) {
        filtered = filtered.where((r) => r.isFeatured).toList();
      }
      return filtered;
    }

    return _getFallbackServices(query: query, categoryId: categoryId);
  }

  static Future<ServiceModel> getServiceById(int id) async {
    try {
      final resRoom = await http.get(Uri.parse('${ApiClient.baseUrl}/rooms/$id')).timeout(const Duration(seconds: 10));
      if (resRoom.statusCode == 200) {
        final Map<String, dynamic> r = jsonDecode(utf8.decode(resRoom.bodyBytes));
        return convertRoomJsonToServiceModel(r);
      }
    } catch (_) {}

    try {
      final res = await http.get(Uri.parse('${ApiClient.baseUrl}/services/$id')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return ServiceModel.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
      }
    } catch (_) {}

    final all = await getServices();
    return all.firstWhere((s) => s.id == id, orElse: () => _getFallbackServices().first);
  }

  static Future<List<ProviderModel>> getProviders() async {
    try {
      final res = await http.get(Uri.parse('${ApiClient.baseUrl}/providers')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.map((e) => ProviderModel.fromJson(e)).toList();
      }
    } catch (_) {}

    return _getFallbackProviders();
  }

  static HotelModel? cachedHotel;

  static Future<HotelModel> getDefaultHotel() async {
    try {
      final res = await http.get(Uri.parse('${ApiClient.baseUrl}/hotels/1')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(utf8.decode(res.bodyBytes));
        final h = HotelModel.fromJson(json);
        cachedHotel = h;
        return h;
      }
    } catch (e) {
      debugPrint('Error loading default hotel: $e');
    }

    if (cachedHotel != null) return cachedHotel!;

    return HotelModel(
      id: 1,
      name: 'Boss_Heng Luxury Hotel',
      province: 'Phnom Penh',
      address: 'Riverside Blvd, Daun Penh, Phnom Penh',
      phone: '023888999',
      email: 'info@bosshenghotel.com',
      rating: 4.9,
      mainImage: 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800',
      description: 'Experience five-star luxury with riverside views, an infinity pool overlooking the Mekong river, and world-class Khmer hospitality.',
      facilities: 'Free High-speed WiFi, Infinity Swimming Pool, Rooftop Sky Bar, Fine Dining Restaurant, Luxury Spa, Fitness Center, 24/7 Room Service, Airport Shuttle',
      status: 'ACTIVE',
      mapUrl: 'https://maps.google.com/?q=Riverside+Blvd+Phnom+Penh',
      tagline: 'Premier 5-Star Riverside Retreat & Suites',
      starRating: 5,
      checkInTime: '02:00 PM',
      checkOutTime: '12:00 PM',
      policy: 'Free cancellation up to 24 hours prior to arrival. Valid National ID or Passport required upon check-in.',
      website: 'https://bosshenghotel.com',
    );
  }

  static Future<List<HotelModel>> getHotels({String query = '', String province = ''}) async {
    try {
      String url = '${ApiClient.baseUrl}/hotels';
      List<String> params = [];
      if (query.isNotEmpty) params.add('query=${Uri.encodeComponent(query)}');
      if (province.isNotEmpty && province != 'All Cambodia') {
        params.add('province=${Uri.encodeComponent(province)}');
      }
      if (params.isNotEmpty) url += '?${params.join('&')}';

      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.map((e) => HotelModel.fromJson(e)).toList();
      }
    } catch (_) {}

    return [
      HotelModel(
        id: 1,
        name: 'Rosewood Phnom Penh',
        province: 'Phnom Penh',
        address: 'Vattanac Capital Tower, 66 Monivong Blvd',
        phone: '023 936 888',
        email: 'phnompenh@rosewoodhotels.com',
        rating: 4.9,
        mainImage: 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800',
        description: 'Soaring 188 meters above the heart of Phnom Penh with ultra-luxury sky suites.',
        facilities: 'Sky Bar, Indoor Pool, Spa, Fitness Center, 24/7 Concierge',
        status: 'ACTIVE',
      ),
      HotelModel(
        id: 2,
        name: 'Angkor Palace Resort & Spa',
        province: 'Siem Reap',
        address: '555 Khum Svay Dang Kum, Siem Reap',
        phone: '063 760 511',
        email: 'info@angkorpalaceresort.com',
        rating: 4.8,
        mainImage: 'https://images.unsplash.com/photo-1582719508461-905c673771fd?w=800',
        description: 'Sprawled across 11 hectares of tropical greenery near the iconic temples of Angkor.',
        facilities: 'Outdoor Pool, Khmer Spa, Tennis Court, Banquet Hall, Airport Transfer',
        status: 'ACTIVE',
      ),
    ];
  }

  static Future<List<RoomModel>> getRoomsByHotel(int hotelId) async {
    try {
      final res = await http.get(Uri.parse('${ApiClient.baseUrl}/rooms/hotel/$hotelId')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.map((e) => RoomModel.fromJson(e)).toList();
      }
    } catch (_) {}

    return [
      RoomModel(
        id: 1,
        hotelId: hotelId,
        roomNumber: '101',
        type: 'Deluxe City View Suite',
        priceUsd: 120.0,
        priceKhr: 492000.0,
        maxGuests: 2,
        bedType: '1 King Bed',
        description: 'Modern luxury suite overlooking the Phnom Penh skyline.',
        images: 'https://images.unsplash.com/photo-1590490360182-c33d57733427?w=600',
        status: 'AVAILABLE',
      ),
      RoomModel(
        id: 2,
        hotelId: hotelId,
        roomNumber: '205',
        type: 'Presidential Pool Villa Suite',
        priceUsd: 220.0,
        priceKhr: 902000.0,
        maxGuests: 4,
        bedType: '2 King Beds',
        description: 'Spacious villa with personal pool and luxury amenities.',
        images: 'https://images.unsplash.com/photo-1582719508461-905c673771fd?w=600',
        status: 'AVAILABLE',
      ),
    ];
  }

  // ==========================================
  // FALLBACK SERVICES & PROVIDERS
  // ==========================================
  static List<ProviderModel> _getFallbackProviders() {
    return [
      ProviderModel(
        id: 1,
        name: 'Samnang Vong',
        title: 'Executive Front Desk Host',
        phone: '012 345 678',
        rating: 4.9,
        workingHours: '08:00 AM - 05:00 PM',
        isAvailable: true,
        avatarUrl: 'https://images.unsplash.com/photo-1622253692010-333f2da6031d?w=200',
      ),
      ProviderModel(
        id: 2,
        name: 'Sreymom Chan',
        title: 'VIP Guest Relations Host',
        phone: '098 765 432',
        rating: 4.9,
        workingHours: '09:00 AM - 07:00 PM',
        isAvailable: true,
        avatarUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=200',
      ),
      ProviderModel(
        id: 3,
        name: 'Master Kosal Rim',
        title: 'Head of Guest Experience',
        phone: '015 999 888',
        rating: 4.8,
        workingHours: '09:00 AM - 08:00 PM',
        isAvailable: true,
        avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200',
      ),
      ProviderModel(
        id: 4,
        name: 'Concierge Sokha',
        title: 'VIP Hospitality Manager',
        phone: '023 888 999',
        rating: 5.0,
        workingHours: '24/7 Service',
        isAvailable: true,
        avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200',
      ),
    ];
  }

  static List<ServiceModel> _getFallbackServices({String query = '', int? categoryId}) {
    final all = [
      ServiceModel(
        id: 1,
        name: 'Room 201 - Riverside Deluxe King Suite',
        description: 'Spacious waterfront luxury hotel room overlooking the Mekong river. Features 1 King Bed, private balcony, luxury rain shower, high-speed WiFi and gourmet breakfast.',
        durationMinutes: 1440,
        price: 75.0,
        priceKhr: 307500.0,
        rating: 4.9,
        reviewCount: 128,
        imageUrl: 'https://images.unsplash.com/photo-1590490360182-c33d57733427?w=800',
        images: const [
          'https://images.unsplash.com/photo-1590490360182-c33d57733427?w=800',
          'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=800',
          'https://images.unsplash.com/photo-1578683010236-d716f9a3f461?w=800',
        ],
        isFeatured: true,
        isPopular: true,
        categoryName: 'Deluxe Rooms',
        locationName: 'Grand Luxury Hotel Phnom Penh',
        locationAddress: 'Riverside Blvd, Daun Penh, Phnom Penh',
        province: 'Phnom Penh',
        providers: [_getFallbackProviders()[3]],
      ),
      ServiceModel(
        id: 2,
        name: 'Room 301 - Executive Panoramic Suite',
        description: 'Executive corner suite with separate living area, 1 King bed + 1 Sofa bed, espresso coffee machine, marble bathroom, and panoramic city vistas.',
        durationMinutes: 1440,
        price: 140.0,
        priceKhr: 574000.0,
        rating: 5.0,
        reviewCount: 95,
        imageUrl: 'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=800',
        images: const [
          'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=800',
          'https://images.unsplash.com/photo-1590490360182-c33d57733427?w=800',
          'https://images.unsplash.com/photo-1584132967334-10e028bd69f7?w=800',
        ],
        isFeatured: true,
        isPopular: true,
        categoryName: 'Executive Suites',
        locationName: 'Grand Luxury Hotel Phnom Penh',
        locationAddress: 'Riverside Blvd, Daun Penh, Phnom Penh',
        province: 'Phnom Penh',
        providers: [_getFallbackProviders()[3]],
      ),
      ServiceModel(
        id: 3,
        name: 'Room 401 - VIP Presidential Penthouse Villa',
        description: 'Ultra-luxurious top-floor presidential suite with 2 King Beds, private jacuzzi plunge pool, 24/7 personal butler service, and complimentary champagne.',
        durationMinutes: 1440,
        price: 220.0,
        priceKhr: 902000.0,
        rating: 4.9,
        reviewCount: 64,
        imageUrl: 'https://images.unsplash.com/photo-1578683010236-d716f9a3f461?w=800',
        images: const [
          'https://images.unsplash.com/photo-1578683010236-d716f9a3f461?w=800',
          'https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=800',
          'https://images.unsplash.com/photo-1566665797739-1674de7a421a?w=800',
        ],
        isFeatured: true,
        isPopular: true,
        categoryName: 'VIP Villas',
        locationName: 'Grand Luxury Hotel Phnom Penh',
        locationAddress: 'Riverside Blvd, Daun Penh, Phnom Penh',
        province: 'Phnom Penh',
        providers: [_getFallbackProviders()[3]],
      ),
      ServiceModel(
        id: 4,
        name: 'Room 101 - Modern Cozy Single Room',
        description: 'Comfortable modern single room with ergonomic workstation, high-speed fiber internet, smart TV, and premium organic toiletries.',
        durationMinutes: 1440,
        price: 45.0,
        priceKhr: 184500.0,
        rating: 4.8,
        reviewCount: 88,
        imageUrl: 'https://images.unsplash.com/photo-1631049307264-da0ec9d70304?w=800',
        images: const [
          'https://images.unsplash.com/photo-1631049307264-da0ec9d70304?w=800',
          'https://images.unsplash.com/photo-1590490360182-c33d57733427?w=800',
        ],
        isFeatured: false,
        isPopular: true,
        categoryName: 'Deluxe Rooms',
        locationName: 'Grand Luxury Hotel Phnom Penh',
        locationAddress: 'Riverside Blvd, Daun Penh, Phnom Penh',
        province: 'Phnom Penh',
        providers: [_getFallbackProviders()[3]],
      ),
      ServiceModel(
        id: 11,
        name: 'Room 501 - Grand Family Interconnected Suite',
        description: 'Designed for families with two master bedrooms, 1 King bed and 2 Twin beds, kids play area, and double vanity bathroom.',
        durationMinutes: 1440,
        price: 160.0,
        priceKhr: 656000.0,
        rating: 4.9,
        reviewCount: 42,
        imageUrl: 'https://images.unsplash.com/photo-1566665797739-1674de7a421a?w=800',
        images: const [
          'https://images.unsplash.com/photo-1566665797739-1674de7a421a?w=800',
          'https://images.unsplash.com/photo-1590490360182-c33d57733427?w=800',
        ],
        isFeatured: true,
        isPopular: false,
        categoryName: 'Family Suites',
        locationName: 'Grand Luxury Hotel Phnom Penh',
        locationAddress: 'Riverside Blvd, Daun Penh, Phnom Penh',
        province: 'Phnom Penh',
        providers: [_getFallbackProviders()[3]],
      ),
      ServiceModel(
        id: 12,
        name: 'Room VIP-777 - 2 King Beds',
        description: 'Ultra-exclusive VIP Suite with private bar, infinity view balcony, jacuzzi and 24/7 butler service.',
        durationMinutes: 1440,
        price: 299.0,
        priceKhr: 1225900.0,
        rating: 5.0,
        reviewCount: 165,
        imageUrl: 'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=800',
        images: const [
          'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=800',
          'https://images.unsplash.com/photo-1578683010236-d716f9a3f461?w=800',
          'https://images.unsplash.com/photo-1584132967334-10e028bd69f7?w=800',
          'https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=800',
          'https://images.unsplash.com/photo-1566665797739-1674de7a421a?w=800',
        ],
        isFeatured: true,
        isPopular: true,
        categoryName: 'VIP Villas',
        locationName: 'Grand Luxury Hotel Phnom Penh',
        locationAddress: 'Riverside Blvd, Daun Penh, Phnom Penh',
        province: 'Phnom Penh',
        providers: [_getFallbackProviders()[3]],
      ),
      ServiceModel(
        id: 13,
        name: 'Room 502 - 1 King Bed',
        description: 'Executive Panoramic Suite with river view balcony and espresso bar.',
        durationMinutes: 1440,
        price: 190.0,
        priceKhr: 779000.0,
        rating: 4.9,
        reviewCount: 110,
        imageUrl: 'https://images.unsplash.com/photo-1578683010236-d716f9a3f461?w=800',
        images: const [
          'https://images.unsplash.com/photo-1578683010236-d716f9a3f461?w=800',
          'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=800',
          'https://images.unsplash.com/photo-1631049307264-da0ec9d70304?w=800',
        ],
        isFeatured: true,
        isPopular: true,
        categoryName: 'Executive Suites',
        locationName: 'Grand Luxury Hotel Phnom Penh',
        locationAddress: 'Riverside Blvd, Daun Penh, Phnom Penh',
        province: 'Phnom Penh',
        providers: [_getFallbackProviders()[3]],
      ),
      ServiceModel(
        id: 15,
        name: 'Room 302 - 1 King Bed',
        description: 'Modern luxury double room with customized interior decoration, high-speed fiber WiFi and complimentary buffet breakfast.',
        durationMinutes: 1440,
        price: 75.0,
        priceKhr: 307500.0,
        rating: 4.8,
        reviewCount: 92,
        imageUrl: 'https://i.pinimg.com/736x/5c/c2/8f/5cc28fedc6c9c731694c7e11f36775f3.jpg',
        images: const [
          'https://i.pinimg.com/736x/5c/c2/8f/5cc28fedc6c9c731694c7e11f36775f3.jpg',
          'https://i.pinimg.com/736x/5c/f6/f7/5cf6f7b980a66374660de3c09bf22fbb.jpg',
          'https://i.pinimg.com/736x/2d/ed/9e/2ded9ea0574075e72c6f7c1860437c8e.jpg',
        ],
        isFeatured: false,
        isPopular: true,
        categoryName: 'Deluxe Rooms',
        locationName: 'Grand Luxury Hotel Phnom Penh',
        locationAddress: 'Riverside Blvd, Daun Penh, Phnom Penh',
        province: 'Phnom Penh',
        providers: [_getFallbackProviders()[3]],
      ),
    ];

    return all.where((s) {
      if (categoryId != null && categoryId > 0) {
        if (categoryId == 2 && s.categoryName != 'Deluxe Rooms') return false;
        if (categoryId == 3 && s.categoryName != 'Executive Suites') return false;
        if (categoryId == 4 && s.categoryName != 'VIP Villas') return false;
        if (categoryId == 5 && s.categoryName != 'Family Suites') return false;
      }
      if (query.isNotEmpty) {
        final q = query.toLowerCase();
        return s.name.toLowerCase().contains(q) ||
            s.categoryName.toLowerCase().contains(q) ||
            s.province.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }
}
