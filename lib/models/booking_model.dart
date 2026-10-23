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

  // Hotel specific fields
  final String? hotelName;
  final String? roomName;
  final String? roomType;
  final String? roomTier;
  final String? checkIn;
  final String? checkOut;
  final int totalNights;
  final int numberOfRooms;
  final double amountPaid;
  final double balanceDue;
  final double depositRequired;
  final double subtotal;
  final double tax;
  final double serviceCharge;
  final String paymentStatus;

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
    this.hotelName,
    this.roomName,
    this.roomType,
    this.roomTier,
    this.checkIn,
    this.checkOut,
    this.totalNights = 1,
    this.numberOfRooms = 1,
    this.amountPaid = 0.0,
    this.balanceDue = 0.0,
    this.depositRequired = 0.0,
    this.subtotal = 0.0,
    this.tax = 0.0,
    this.serviceCharge = 0.0,
    this.paymentStatus = 'PAID',
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    String title = 'Hotel Room Stay';
    String provider = 'Hotel Front Desk';
    String loc = 'Phnom Penh, Cambodia';
    String img = 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=600';

    String? hName;
    String? rName;
    String? rType;
    String? rTier;

    if (json['hotel'] != null) {
      hName = json['hotel']['name'];
      provider = hName ?? provider;
      if (json['hotel']['mainImage'] != null && json['hotel']['mainImage'].toString().isNotEmpty) {
        img = json['hotel']['mainImage'];
      }
      if (json['hotel']['address'] != null) {
        loc = json['hotel']['address'];
      }
    }

    if (json['room'] != null) {
      rName = json['room']['name'] ?? 'Room ${json['room']['roomNumber'] ?? ''}';
      rType = json['room']['type'];
      rTier = json['room']['roomTier'];
      title = '$rName ${rTier != null ? "• $rTier" : ""}';

      final dynamic rawRoomImages = json['room']['images'];
      if (rawRoomImages is String && rawRoomImages.trim().isNotEmpty) {
        final cleaned = rawRoomImages
            .replaceAllMapped(RegExp(r'(https?://)', caseSensitive: false), (m) => '\n${m[1]}')
            .replaceAllMapped(RegExp(r'(data:image/)', caseSensitive: false), (m) => '\n${m[1]}');
        final firstUrl = cleaned
            .split(RegExp(r'[\r\n,;\s]+'))
            .map((s) => s.trim())
            .firstWhere((s) => s.startsWith('http://') || s.startsWith('https://') || s.startsWith('data:image/'), orElse: () => '');
        if (firstUrl.isNotEmpty) {
          img = firstUrl;
        }
      } else if (rawRoomImages is List && rawRoomImages.isNotEmpty) {
        img = rawRoomImages.first.toString();
      } else if (json['room']['imageUrl'] != null && json['room']['imageUrl'].toString().isNotEmpty) {
        img = json['room']['imageUrl'].toString();
      }
    } else if (json['service'] != null) {
      title = json['service']['name'] ?? title;
      if (json['service']['imageUrl'] != null) {
        img = json['service']['imageUrl'];
      }
    }

    if (json['roomImage'] != null && json['roomImage'].toString().trim().isNotEmpty) {
      img = json['roomImage'].toString().trim();
    }

    if (json['provider'] != null && (hName == null || hName.isEmpty)) {
      provider = json['provider']['name'] ?? provider;
    }

    if (json['location'] != null && (json['hotel'] == null || json['hotel']['address'] == null)) {
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

    double amtPaid = double.tryParse(json['amountPaid']?.toString() ?? '0') ?? 0.0;
    double balDue = double.tryParse(json['balanceDue']?.toString() ?? '0') ?? 0.0;
    double depReq = double.tryParse(json['depositRequired']?.toString() ?? '0') ?? 0.0;
    double sub = double.tryParse(json['subtotal']?.toString() ?? '0') ?? totP;
    double tx = double.tryParse(json['tax']?.toString() ?? '0') ?? 0.0;
    double sc = double.tryParse(json['serviceCharge']?.toString() ?? '0') ?? 0.0;

    int nights = 1;
    if (json['totalNights'] != null) {
      nights = int.tryParse(json['totalNights'].toString()) ?? 1;
    }

    int nRooms = 1;
    if (json['numberOfRooms'] != null) {
      nRooms = int.tryParse(json['numberOfRooms'].toString()) ?? 1;
    }

    String pStatus = json['paymentStatus']?.toString() ?? 'PAID';

    return BookingModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      bookingCode: json['bookingCode'] ?? 'BK-DEFAULT',
      title: title,
      providerName: provider,
      locationAddress: loc,
      bookingDate: json['bookingDate'] ?? json['checkIn'] ?? '',
      bookingTime: json['bookingTime'] ?? '14:00 (Check-in)',
      durationMinutes: json['durationMinutes'] is int ? json['durationMinutes'] : (nights * 24 * 60),
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
      hotelName: hName,
      roomName: rName,
      roomType: rType,
      roomTier: rTier,
      checkIn: json['checkIn']?.toString(),
      checkOut: json['checkOut']?.toString(),
      totalNights: nights,
      numberOfRooms: nRooms,
      amountPaid: amtPaid,
      balanceDue: balDue,
      depositRequired: depReq,
      subtotal: sub,
      tax: tx,
      serviceCharge: sc,
      paymentStatus: pStatus,
    );
  }
}
