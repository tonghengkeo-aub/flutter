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
      CategoryModel(id: 1, name: 'Single Rooms', icon: 'single_bed', description: 'Cozy private room with 1 Single Bed'),
      CategoryModel(id: 2, name: 'Double Rooms', icon: 'bed', description: 'Room with 1 Double or Queen/King Bed'),
      CategoryModel(id: 3, name: 'Twin Rooms', icon: 'hotel', description: 'Room with 2 separate Single Beds'),
      CategoryModel(id: 4, name: 'Triple Rooms', icon: 'groups', description: 'Room for 3 guests with separate beds'),
      CategoryModel(id: 5, name: 'Family Rooms', icon: 'family_restroom', description: 'Large room with multiple beds for 4+ guests'),
      CategoryModel(id: 6, name: 'Suite Rooms', icon: 'meeting_room', description: 'Spacious suite with separate living room'),
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
      case 'STANDARD':
        return 'Standard Room';
      case 'DELUXE':
        return 'Deluxe Room';
      case 'EXECUTIVE':
      case 'PREMIUM':
        return 'Executive Room';
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
        return (type != null && type.isNotEmpty) ? '$type Room' : 'Double Room';
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
        : '';

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
    final bool incBfast = (r['includesBreakfast'] == true || r['includesBreakfast']?.toString() == 'true');
    final String rawFood = r['foodType']?.toString().trim() ?? '';
    final parsedFoodType = rawFood.isNotEmpty
        ? rawFood
        : (incBfast ? 'Breakfast included' : 'Room only');
    final parsedMapUrl = (r['mapUrl']?.toString().isNotEmpty == true)
        ? r['mapUrl'].toString()
        : ((r['hotel']?['mapUrl']?.toString().isNotEmpty == true)
            ? r['hotel']!['mapUrl'].toString()
            : 'https://maps.google.com/?q=Riverside+Blvd+Phnom+Penh');

    final customName = (r['name']?.toString().trim().isNotEmpty == true)
        ? r['name'].toString().trim()
        : typeDisplay;

    final parsedAvailable = (r['availableUnits'] as num?)?.toInt() ?? 5;
    final parsedTotal = (r['totalRooms'] as num?)?.toInt() ?? parsedAvailable;
    final parsedMaxGuests = (r['maxGuests'] as num?)?.toInt() ?? 2;

    return ServiceModel(
      id: r['id'] ?? (100 + (int.tryParse(roomNum) ?? 0)),
      hotelId: (r['hotel'] != null ? (r['hotel']['id'] as num?)?.toInt() : null) ?? 1,
      name: customName, // Honors user's custom room name if set!
      description: r['description'] ?? 'Spacious and luxury hotel room with modern amenities.',
      durationMinutes: 1440,
      price: parsedPrice,
      priceKhr: parsedPriceKhr,
      rating: parsedRating,
      reviewCount: parsedReviewCount,
      imageUrl: imgUrl,
      images: rawImages,
      isFeatured: parsedPrice >= 75 || parsedRating >= 4.9 || rawType == 'VIP' || rawType == 'SUITE',
      isPopular: true,
      categoryName: typeDisplay,
      locationName: r['hotel']?['name'] ?? 'Boss_Heng Luxury Hotel',
      locationAddress: r['hotel']?['address'] ?? 'National Road 2, Ta Khmau, Kandal',
      province: (r['hotel']?['province']?.toString().isNotEmpty == true) ? r['hotel']!['province'].toString() : 'Kandal',
      providers: [],
      starRating: parsedStars,
      foodType: parsedFoodType,
      mapUrl: parsedMapUrl,
      bedType: parsedBedType,
      roomType: rawType,
      roomTier: r['roomTier']?.toString().toUpperCase() ?? 'STANDARD',
      availableUnits: parsedAvailable,
      totalRooms: parsedTotal,
      includesBreakfast: incBfast,
      maxGuests: parsedMaxGuests,
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
    bool apiSuccess = false;

    // 1. Fetch live rooms from /api/rooms/hotel/1 (directly reflects Admin/Owner CRUD)
    try {
      final resRooms = await http.get(Uri.parse('${ApiClient.baseUrl}/rooms/hotel/1')).timeout(const Duration(seconds: 10));
      if (resRooms.statusCode == 200) {
        apiSuccess = true;
        final List list = jsonDecode(utf8.decode(resRooms.bodyBytes));

        for (var item in list) {
          final r = item as Map<String, dynamic>;
          final model = convertRoomJsonToServiceModel(r);
          allRooms.add(model);
        }
      }
    } catch (e) {
      debugPrint('Error loading live rooms from /api/rooms/hotel/1: $e');
    }

    // Only if API completely failed to connect (e.g. backend offline / network failure):
    if (!apiSuccess) {
      return _getFallbackServices(query: query, categoryId: categoryId);
    }

    // When API succeeded (even if 0 rooms because all rooms were deleted in dashboard)
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
      province: 'Kandal',
      address: 'National Road 2, Ta Khmau, Kandal',
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
        name: 'Standard Room (Fan)',
        type: 'STANDARD',
        priceUsd: 28.0,
        priceKhr: 114800.0,
        maxGuests: 2,
        bedType: '1 Queen Bed (Fan Room)',
        description: 'Cozy standard room with ceiling fan, private bathroom, and essential amenities.',
        images: 'https://images.unsplash.com/photo-1631049307264-da0ec9d70304?w=600',
        status: 'AVAILABLE',
      ),
      RoomModel(
        id: 2,
        hotelId: hotelId,
        roomNumber: '102',
        name: 'Standard Room (AC)',
        type: 'STANDARD',
        priceUsd: 38.0,
        priceKhr: 155800.0,
        maxGuests: 2,
        bedType: '1 Queen Bed (AC Room)',
        description: 'Standard air-conditioned room with private bathroom, fast WiFi, and comfortable bed.',
        images: 'https://images.unsplash.com/photo-1590490360182-c33d57733427?w=600',
        status: 'AVAILABLE',
      ),
      RoomModel(
        id: 3,
        hotelId: hotelId,
        roomNumber: '201',
        name: 'Deluxe King Room (AC)',
        type: 'DELUXE',
        priceUsd: 65.0,
        priceKhr: 266500.0,
        maxGuests: 2,
        bedType: '1 King Bed (AC Room)',
        description: 'Spacious deluxe room with stylish decor, 1 King size bed, air conditioning, and city view balcony.',
        images: 'https://images.unsplash.com/photo-1582719508461-905c673771fd?w=600',
        status: 'AVAILABLE',
      ),
      RoomModel(
        id: 4,
        hotelId: hotelId,
        roomNumber: '301',
        name: 'Executive Premium Room (AC)',
        type: 'EXECUTIVE',
        priceUsd: 110.0,
        priceKhr: 451000.0,
        maxGuests: 2,
        bedType: '1 King Bed (AC Room)',
        description: 'Luxury executive room with designer interior, lounge sitting area, espresso bar, and VIP service.',
        images: 'https://images.unsplash.com/photo-1578683010236-d716f9a3f461?w=600',
        status: 'AVAILABLE',
      ),
      RoomModel(
        id: 5,
        hotelId: hotelId,
        roomNumber: '202',
        name: 'Double Room (King Bed)',
        type: 'DOUBLE',
        priceUsd: 55.0,
        priceKhr: 225500.0,
        maxGuests: 2,
        bedType: '1 King Bed (AC Room)',
        description: 'Comfortable double room with 1 large king bed, air conditioning, and full amenities.',
        images: 'https://images.unsplash.com/photo-1566665797739-1674de7a421a?w=600',
        status: 'AVAILABLE',
      ),
      RoomModel(
        id: 6,
        hotelId: hotelId,
        roomNumber: '203',
        name: 'Superior Twin Room',
        type: 'TWIN',
        priceUsd: 55.0,
        priceKhr: 225500.0,
        maxGuests: 2,
        bedType: '2 Single Beds (AC Room)',
        description: 'Twin room with two separate comfortable single beds and modern air conditioning.',
        images: 'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=600',
        status: 'AVAILABLE',
      ),
      RoomModel(
        id: 7,
        hotelId: hotelId,
        roomNumber: '401',
        name: 'Grand Luxury Suite',
        type: 'SUITE',
        priceUsd: 140.0,
        priceKhr: 574000.0,
        maxGuests: 3,
        bedType: '1 King Bed + Living Area (AC)',
        description: 'Top-tier luxury suite with panoramic river views, private living room, and soaking tub.',
        images: 'https://images.unsplash.com/photo-1590490360182-c33d57733427?w=600',
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
        name: 'Cozy Single Studio Room',
        description: 'Cozy private room for 1 guest with 1 Single Bed.',
        durationMinutes: 1440,
        price: 35.0,
        priceKhr: 143500.0,
        rating: 4.8,
        reviewCount: 65,
        imageUrl: 'https://images.unsplash.com/photo-1631049307264-da0ec9d70304?w=800',
        images: const [
          'https://images.unsplash.com/photo-1631049307264-da0ec9d70304?w=800',
          'https://images.unsplash.com/photo-1590490360182-c33d57733427?w=800',
        ],
        isFeatured: false,
        isPopular: true,
        categoryName: 'Single Rooms',
        locationName: 'Boss_Heng Luxury Hotel',
        locationAddress: 'Riverside Blvd, Daun Penh, Phnom Penh',
        province: 'Phnom Penh',
        providers: [_getFallbackProviders()[3]],
        bedType: '1 Single Bed',
        roomType: 'SINGLE',
      ),
      ServiceModel(
        id: 2,
        name: 'Deluxe King Double Room',
        description: 'Comfortable room with 1 Double or Queen/King Bed for 2 guests.',
        durationMinutes: 1440,
        price: 49.0,
        priceKhr: 200900.0,
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
        categoryName: 'Double Rooms',
        locationName: 'Boss_Heng Luxury Hotel',
        locationAddress: 'Riverside Blvd, Daun Penh, Phnom Penh',
        province: 'Phnom Penh',
        providers: [_getFallbackProviders()[3]],
        bedType: '1 Double / King Bed',
        roomType: 'DOUBLE',
      ),
      ServiceModel(
        id: 3,
        name: 'Superior Twin Bed Room',
        description: 'Spacious room with 2 separate Single Beds for 2 guests.',
        durationMinutes: 1440,
        price: 55.0,
        priceKhr: 225500.0,
        rating: 4.8,
        reviewCount: 92,
        imageUrl: 'https://images.unsplash.com/photo-1582719508461-905c673771fd?w=800',
        images: const [
          'https://images.unsplash.com/photo-1582719508461-905c673771fd?w=800',
          'https://images.unsplash.com/photo-1590490360182-c33d57733427?w=800',
        ],
        isFeatured: true,
        isPopular: true,
        categoryName: 'Twin Rooms',
        locationName: 'Boss_Heng Luxury Hotel',
        locationAddress: 'Riverside Blvd, Daun Penh, Phnom Penh',
        province: 'Phnom Penh',
        providers: [_getFallbackProviders()[3]],
        bedType: '2 Single Beds',
        roomType: 'TWIN',
      ),
      ServiceModel(
        id: 4,
        name: 'Executive Triple Suite',
        description: 'Ideal for 3 guests with 1 Double Bed and 1 Single Bed, or 3 separate beds.',
        durationMinutes: 1440,
        price: 75.0,
        priceKhr: 307500.0,
        rating: 4.9,
        reviewCount: 74,
        imageUrl: 'https://images.unsplash.com/photo-1578683010236-d716f9a3f461?w=800',
        images: const [
          'https://images.unsplash.com/photo-1578683010236-d716f9a3f461?w=800',
          'https://images.unsplash.com/photo-1566665797739-1674de7a421a?w=800',
        ],
        isFeatured: true,
        isPopular: true,
        categoryName: 'Triple Rooms',
        locationName: 'Boss_Heng Luxury Hotel',
        locationAddress: 'Riverside Blvd, Daun Penh, Phnom Penh',
        province: 'Phnom Penh',
        providers: [_getFallbackProviders()[3]],
        bedType: '1 Double + 1 Single Bed',
        roomType: 'TRIPLE',
      ),
      ServiceModel(
        id: 5,
        name: 'Grand Family Residence Room',
        description: 'Large family room with multiple beds accommodating 4 or more guests.',
        durationMinutes: 1440,
        price: 95.0,
        priceKhr: 389500.0,
        rating: 4.9,
        reviewCount: 110,
        imageUrl: 'https://images.unsplash.com/photo-1566665797739-1674de7a421a?w=800',
        images: const [
          'https://images.unsplash.com/photo-1566665797739-1674de7a421a?w=800',
          'https://images.unsplash.com/photo-1590490360182-c33d57733427?w=800',
        ],
        isFeatured: true,
        isPopular: true,
        categoryName: 'Family Rooms',
        locationName: 'Boss_Heng Luxury Hotel',
        locationAddress: 'Riverside Blvd, Daun Penh, Phnom Penh',
        province: 'Phnom Penh',
        providers: [_getFallbackProviders()[3]],
        bedType: 'Multiple Beds (4+ Guests)',
        roomType: 'FAMILY',
      ),
      ServiceModel(
        id: 6,
        name: 'Presidential Royal Suite Room',
        description: 'Luxury executive suite with separate living area and premium amenities.',
        durationMinutes: 1440,
        price: 140.0,
        priceKhr: 574000.0,
        rating: 5.0,
        reviewCount: 152,
        imageUrl: 'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=800',
        images: const [
          'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=800',
          'https://images.unsplash.com/photo-1590490360182-c33d57733427?w=800',
          'https://images.unsplash.com/photo-1584132967334-10e028bd69f7?w=800',
        ],
        isFeatured: true,
        isPopular: true,
        categoryName: 'Suite Rooms',
        locationName: 'Boss_Heng Luxury Hotel',
        locationAddress: 'Riverside Blvd, Daun Penh, Phnom Penh',
        province: 'Phnom Penh',
        providers: [_getFallbackProviders()[3]],
        bedType: '1 King Bed + Living Area',
        roomType: 'SUITE',
      ),
    ];

    return all.where((s) {
      if (categoryId != null && categoryId > 0) {
        if (categoryId == 1 && s.roomType != 'SINGLE') return false;
        if (categoryId == 2 && s.roomType != 'DOUBLE') return false;
        if (categoryId == 3 && s.roomType != 'TWIN') return false;
        if (categoryId == 4 && s.roomType != 'TRIPLE') return false;
        if (categoryId == 5 && s.roomType != 'FAMILY') return false;
        if (categoryId == 6 && s.roomType != 'SUITE') return false;
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
