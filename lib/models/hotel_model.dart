class HotelModel {
  final int id;
  final String name;
  final String description;
  final String address;
  final String province;
  final String phone;
  final String email;
  final double rating;
  final String mainImage;
  final String facilities;
  final String status;
  final String mapUrl;
  final String tagline;
  final int starRating;
  final String checkInTime;
  final String checkOutTime;
  final String policy;
  final String website;

  HotelModel({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    required this.province,
    required this.phone,
    required this.email,
    required this.rating,
    required this.mainImage,
    required this.facilities,
    required this.status,
    this.mapUrl = 'https://maps.google.com/?q=Riverside+Blvd+Phnom+Penh',
    this.tagline = 'Luxury 5-Star Boutique & Riverside Retreat',
    this.starRating = 5,
    this.checkInTime = '02:00 PM',
    this.checkOutTime = '12:00 PM',
    this.policy = 'Free cancellation up to 24 hours prior to arrival. Valid ID required at check-in.',
    this.website = 'https://bosshenghotel.com',
  });

  factory HotelModel.fromJson(Map<String, dynamic> json) {
    return HotelModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      address: json['address'] ?? '',
      province: json['province'] ?? 'Phnom Penh',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      rating: json['rating'] != null ? (double.tryParse(json['rating'].toString()) ?? 4.5) : 4.5,
      mainImage: json['mainImage'] ?? 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800',
      facilities: json['facilities'] ?? 'Free WiFi, Swimming Pool, Rooftop Bar, Luxury Spa',
      status: json['status'] ?? 'ACTIVE',
      mapUrl: json['mapUrl']?.toString().isNotEmpty == true
          ? json['mapUrl'].toString()
          : 'https://maps.google.com/?q=Riverside+Blvd+Phnom+Penh',
      tagline: json['tagline']?.toString().isNotEmpty == true
          ? json['tagline'].toString()
          : 'Luxury 5-Star Boutique & Riverside Retreat',
      starRating: json['starRating'] is int
          ? json['starRating']
          : int.tryParse(json['starRating']?.toString() ?? '5') ?? 5,
      checkInTime: json['checkInTime']?.toString().isNotEmpty == true
          ? json['checkInTime'].toString()
          : '02:00 PM',
      checkOutTime: json['checkOutTime']?.toString().isNotEmpty == true
          ? json['checkOutTime'].toString()
          : '12:00 PM',
      policy: json['policy']?.toString().isNotEmpty == true
          ? json['policy'].toString()
          : 'Free cancellation up to 24 hours prior to arrival. Valid ID required at check-in.',
      website: json['website']?.toString().isNotEmpty == true
          ? json['website'].toString()
          : 'https://bosshenghotel.com',
    );
  }

  List<String> get facilityList {
    return facilities.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
}
