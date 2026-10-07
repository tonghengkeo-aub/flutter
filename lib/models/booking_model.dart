class BookingModel {
  final int id;
  final String bookingCode;
  final String title;
  final String providerName;
  final String locationAddress;
  final String bookingDate;
  final String bookingTime;
  final int durationMinutes;
  final double totalPrice;
  final double discountAmount;
  final double finalPrice;
  final double finalPriceKhr;
  final String guestName;
  final String guestPhone;
  final String? guestEmail;
  final String status;
  final String? cancellationReason;
  final String imageUrl;

  BookingModel({
    required this.id,
    required this.bookingCode,
    required this.title,
    required this.providerName,
    required this.locationAddress,
    required this.bookingDate,
    required this.bookingTime,
    required this.durationMinutes,
    required this.totalPrice,
    required this.discountAmount,
    required this.finalPrice,
    required this.finalPriceKhr,
    required this.guestName,
    required this.guestPhone,
    this.guestEmail,
    required this.status,
    this.cancellationReason,
    required this.imageUrl,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    String title = 'Booking Service';
    String provider = 'Assigned Specialist';
    String loc = 'Phnom Penh, Cambodia';
    String img = 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=600';

    if (json['service'] != null) {
      title = json['service']['name'] ?? title;
      if (json['service']['imageUrl'] != null) {
        img = json['service']['imageUrl'];
      }
    } else if (json['hotel'] != null) {
      title = json['hotel']['name'] ?? 'Hotel Stay';
      if (json['hotel']['mainImage'] != null) {
        img = json['hotel']['mainImage'];
      }
    }

    if (json['provider'] != null) {
      provider = json['provider']['name'] ?? provider;
    }

    if (json['location'] != null) {
      loc = json['location']['address'] ?? json['location']['name'] ?? loc;
    }

    double finalP = 0.0;
    if (json['finalPrice'] != null) {
      finalP = double.tryParse(json['finalPrice'].toString()) ?? 0.0;
    } else if (json['totalPriceUsd'] != null) {
      finalP = double.tryParse(json['totalPriceUsd'].toString()) ?? 0.0;
    }

    double totP = 0.0;
    if (json['totalPrice'] != null) {
      totP = double.tryParse(json['totalPrice'].toString()) ?? finalP;
    } else {
      totP = finalP;
    }

    double disc = 0.0;
    if (json['discountAmount'] != null) {
      disc = double.tryParse(json['discountAmount'].toString()) ?? 0.0;
    }

    double finalKhr = finalP * 4100;
    if (json['finalPriceKhr'] != null) {
      finalKhr = double.tryParse(json['finalPriceKhr'].toString()) ?? (finalP * 4100);
    } else if (json['totalPriceKhr'] != null) {
      finalKhr = double.tryParse(json['totalPriceKhr'].toString()) ?? (finalP * 4100);
    }

    return BookingModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      bookingCode: json['bookingCode'] ?? 'BK-DEFAULT',
      title: title,
      providerName: provider,
      locationAddress: loc,
      bookingDate: json['bookingDate'] ?? json['checkIn'] ?? '',
      bookingTime: json['bookingTime'] ?? '10:00 AM',
      durationMinutes: json['durationMinutes'] is int ? json['durationMinutes'] : 60,
      totalPrice: totP,
      discountAmount: disc,
      finalPrice: finalP,
      finalPriceKhr: finalKhr,
      guestName: json['guestName'] ?? '',
      guestPhone: json['guestPhone'] ?? '',
      guestEmail: json['guestEmail'],
      status: json['status'] ?? 'CONFIRMED',
      cancellationReason: json['cancellationReason'],
      imageUrl: img,
    );
  }
}
