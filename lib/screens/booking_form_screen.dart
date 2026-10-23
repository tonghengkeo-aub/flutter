import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/provider_model.dart';
import '../models/service_model.dart';
import '../models/hotel_model.dart';
import '../models/room_model.dart';
import '../services/api_service.dart';
import 'payment_screen.dart';

class BookingFormScreen extends StatefulWidget {
  final ServiceModel? service;
  final ProviderModel? provider;
  final HotelModel? hotel;
  final RoomModel? room;
  final int unitCount;
  final double? customPrice;
  final DateTime? initialCheckIn;
  final DateTime? initialCheckOut;

  const BookingFormScreen({
    super.key,
    this.service,
    this.provider,
    this.hotel,
    this.room,
    this.unitCount = 1,
    this.customPrice,
    this.initialCheckIn,
    this.initialCheckOut,
  });

  @override
  State<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  // Calendar Dates
  late DateTime checkInDate;
  late DateTime checkOutDate;

  // Add-on Extras
  bool addBreakfast = false;
  bool addAirportPickup = false;
  bool addLaundry = false;

  // Payment Selection: Deposit vs Full
  bool payDepositOnly = false;

  // Controllers
  final guestNameCtrl = TextEditingController();
  final guestPhoneCtrl = TextEditingController();
  final guestEmailCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final couponCtrl = TextEditingController();

  // Price Calculation State (Backend Precision)
  bool isCalculating = false;
  int nights = 1;
  double pricePerNight = 45.0;
  double roomTotal = 45.0;
  double extrasTotal = 0.0;
  double subtotal = 45.0;
  double discount = 0.0;
  double serviceCharge = 2.25;
  double serviceChargePercent = 5.0;
  double tax = 4.73;
  double taxPercent = 10.0;
  double total = 51.98;
  double totalKhr = 213118.0;
  double depositPercent = 20.0;
  double depositRequired = 10.40;
  double balanceDue = 41.58;
  String cancellationPolicy =
      'Free cancellation up to 48 hours prior to check-in. Cancellations within 48 hours forfeit the deposit.';

  String? appliedCoupon;
  String? couponMessage;
  bool isApplyingCoupon = false;

  @override
  void initState() {
    super.initState();
    final user = ApiService.currentUser;
    if (user != null) {
      guestNameCtrl.text = user.fullName;
      guestPhoneCtrl.text = user.phone;
      guestEmailCtrl.text = user.email;
    }

    final now = DateTime.now();
    checkInDate = widget.initialCheckIn ?? now.add(const Duration(days: 1));
    checkOutDate = widget.initialCheckOut ?? checkInDate.add(const Duration(days: 1));
    if (!checkOutDate.isAfter(checkInDate)) {
      checkOutDate = checkInDate.add(const Duration(days: 1));
    }

    pricePerNight = widget.room?.priceUsd ??
        (widget.customPrice != null ? (widget.customPrice! / (widget.unitCount > 0 ? widget.unitCount : 1)) : 45.0);

    _calculatePrice();
  }

  @override
  void dispose() {
    guestNameCtrl.dispose();
    guestPhoneCtrl.dispose();
    guestEmailCtrl.dispose();
    notesCtrl.dispose();
    couponCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _buildExtrasPayload() {
    final List<Map<String, dynamic>> list = [];
    final currentNights = checkOutDate.difference(checkInDate).inDays.clamp(1, 365);
    final count = widget.unitCount > 0 ? widget.unitCount : 1;

    if (addBreakfast) {
      list.add({
        'serviceName': 'Buffet Breakfast',
        'price': 10.0,
        'quantity': count * currentNights,
      });
    }
    if (addAirportPickup) {
      list.add({
        'serviceName': 'Airport Shuttle Pickup',
        'price': 25.0,
        'quantity': 1,
      });
    }
    if (addLaundry) {
      list.add({
        'serviceName': 'Express Laundry & Pressing',
        'price': 15.0,
        'quantity': 1,
      });
    }
    return list;
  }

  Future<void> _calculatePrice() async {
    setState(() => isCalculating = true);
    final df = DateFormat('yyyy-MM-dd');
    final inStr = df.format(checkInDate);
    final outStr = df.format(checkOutDate);

    try {
      final res = await ApiService.calculatePrice(
        roomId: widget.room?.id ?? 1,
        unitCount: widget.unitCount > 0 ? widget.unitCount : 1,
        checkIn: inStr,
        checkOut: outStr,
        extras: _buildExtrasPayload(),
        couponCode: appliedCoupon ?? couponCtrl.text.trim(),
      );

      if (mounted) {
        setState(() {
          isCalculating = false;
          nights = (res['nights'] as num?)?.toInt() ?? checkOutDate.difference(checkInDate).inDays.clamp(1, 365);
          pricePerNight = (res['pricePerNight'] as num?)?.toDouble() ?? pricePerNight;
          roomTotal = (res['roomTotal'] as num?)?.toDouble() ?? (pricePerNight * nights * widget.unitCount);
          extrasTotal = (res['extrasTotal'] as num?)?.toDouble() ?? 0.0;
          subtotal = (res['subtotal'] as num?)?.toDouble() ?? (roomTotal + extrasTotal);
          discount = (res['discount'] as num?)?.toDouble() ?? 0.0;
          serviceCharge = (res['serviceCharge'] as num?)?.toDouble() ?? (subtotal * 0.05);
          serviceChargePercent = (res['serviceChargePercent'] as num?)?.toDouble() ?? 5.0;
          tax = (res['tax'] as num?)?.toDouble() ?? ((subtotal + serviceCharge) * 0.10);
          taxPercent = (res['taxPercent'] as num?)?.toDouble() ?? 10.0;
          total = (res['total'] as num?)?.toDouble() ?? (subtotal + serviceCharge + tax);
          totalKhr = (res['totalKhr'] as num?)?.toDouble() ?? (total * 4100);
          depositPercent = (res['depositPercent'] as num?)?.toDouble() ?? 20.0;
          depositRequired = (res['depositRequired'] as num?)?.toDouble() ?? (total * 0.20);
          balanceDue = (res['balanceDue'] as num?)?.toDouble() ?? (total - depositRequired);
          cancellationPolicy = res['cancellationPolicy']?.toString() ?? cancellationPolicy;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => isCalculating = false);
      }
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: checkInDate.isBefore(DateTime.now()) ? DateTime.now() : checkInDate,
        end: checkOutDate.isAfter(checkInDate) ? checkOutDate : checkInDate.add(const Duration(days: 1)),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0F172A),
              primary: const Color(0xFF0F172A),
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      DateTime newIn = picked.start;
      DateTime newOut = picked.end;
      if (!newOut.isAfter(newIn)) {
        newOut = newIn.add(const Duration(days: 1));
      }
      setState(() {
        checkInDate = newIn;
        checkOutDate = newOut;
      });
      _calculatePrice();
    }
  }

  Future<void> _applyCoupon() async {
    final code = couponCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() => isApplyingCoupon = true);
    final res = await ApiService.validateCoupon(code, subtotal);

    if (mounted) {
      setState(() {
        isApplyingCoupon = false;
        if (res['valid'] == true) {
          appliedCoupon = res['code'];
          couponMessage = res['message'];
        } else {
          appliedCoupon = null;
          couponMessage = res['message'] ?? 'Invalid coupon code';
        }
      });
      _calculatePrice();
    }
  }

  void proceedToPayment() {
    final name = guestNameCtrl.text.trim();
    final rawPhone = guestPhoneCtrl.text.trim();
    final cleanPhone = rawPhone.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    if (name.isEmpty || cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter guest name and phone number'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (RegExp(r'[0-9]').hasMatch(name) || name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guest full name must contain letters only (no numbers)'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (!RegExp(r'^[0-9]{8,12}$').hasMatch(cleanPhone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number must be 8 to 12 digits (numbers only)'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final df = DateFormat('yyyy-MM-dd');
    final inStr = df.format(checkInDate);
    final outStr = df.format(checkOutDate);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          service: widget.service,
          provider: widget.provider,
          hotel: widget.hotel,
          room: widget.room,
          bookingDate: inStr,
          bookingTime: '14:00',
          basePrice: subtotal,
          discountAmount: discount,
          finalPrice: total,
          couponCode: appliedCoupon,
          guestName: name,
          guestPhone: cleanPhone,
          guestEmail: guestEmailCtrl.text.trim(),
          notes: notesCtrl.text.trim(),
          unitCount: widget.unitCount > 0 ? widget.unitCount : 1,
          checkInStr: inStr,
          checkOutStr: outStr,
          totalNights: nights,
          totalPriceUsd: total,
          totalPriceKhr: totalKhr,
          payDepositOnly: payDepositOnly,
          depositRequired: depositRequired,
          balanceDue: balanceDue,
          serviceCharge: serviceCharge,
          tax: tax,
          extras: _buildExtrasPayload(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFmt = DateFormat('EEE, MMM dd, yyyy');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Room Reservation & Dates',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        foregroundColor: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // 1. ROOM SUMMARY CARD
            // ==========================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131D32) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF22314E) : Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Builder(
                    builder: (context) {
                      final photoUrl = (widget.room?.firstImageUrl.trim().isNotEmpty == true)
                          ? widget.room!.firstImageUrl.trim()
                          : (widget.service?.imageUrl.trim().isNotEmpty == true
                              ? widget.service!.imageUrl.trim()
                              : '');

                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: photoUrl.isNotEmpty
                            ? Image.network(
                                photoUrl,
                                width: 76,
                                height: 76,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  width: 76,
                                  height: 76,
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  child: Icon(Icons.bed_outlined,
                                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), size: 28),
                                ),
                              )
                            : Container(
                                width: 76,
                                height: 76,
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                child: Icon(Icons.bed_outlined,
                                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), size: 28),
                              ),
                      );
                    },
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.room != null
                              ? '${widget.room!.name?.isNotEmpty == true ? widget.room!.name : "Room ${widget.room!.roomNumber}"} • ${widget.room!.roomTier}'
                              : (widget.service?.name ?? widget.hotel?.name ?? 'Hotel Room Stay'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${widget.unitCount} ${widget.unitCount > 1 ? "Rooms" : "Room"}',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (widget.room != null && widget.room!.type.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${widget.room!.type} Type',
                                  style: const TextStyle(
                                    color: Color(0xFF0284C7),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${pricePerNight.toStringAsFixed(2)} / night',
                          style: TextStyle(
                            color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ==========================================
            // 2. CHECK-IN & CHECK-OUT CALENDAR SECTION
            // ==========================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Stay Dates (Calendar)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '$nights ${nights > 1 ? "Nights Stay" : "Night Stay"}',
                    style: const TextStyle(
                      color: Color(0xFF2563EB),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Interactive Calendar Selection Card
            InkWell(
              onTap: _selectDateRange,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131D32) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF22314E) : Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Check-in Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.login_rounded, size: 15, color: Colors.blue.shade600),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Check-in',
                                    style: TextStyle(
                                      color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                dateFmt.format(checkInDate),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'From 2:00 PM',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFF64748B) : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Divider Arrow
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                          ),
                        ),
                        // Check-out Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    'Check-out',
                                    style: TextStyle(
                                      color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Icon(Icons.logout_rounded, size: 15, color: Colors.amber.shade700),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                dateFmt.format(checkOutDate),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Until 12:00 PM',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFF64748B) : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_month, size: 16, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Text(
                          'Tap here to change dates on Calendar',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ==========================================
            // 3. BOOKING EXTRAS / ADD-ONS
            // ==========================================
            Text(
              'Add-on Services (Extras)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enhance your stay with daily dining, transport, and laundry.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),

            // Breakfast Extra
            _buildExtraTile(
              title: 'Buffet Breakfast',
              subtitle: '\$10.00 / guest / night (Continental & Asian spread)',
              priceStr: '+\$${(10.0 * widget.unitCount * nights).toStringAsFixed(2)}',
              icon: Icons.restaurant,
              isSelected: addBreakfast,
              onChanged: (val) {
                setState(() => addBreakfast = val ?? false);
                _calculatePrice();
              },
              isDark: isDark,
            ),
            const SizedBox(height: 8),

            // Airport Pickup Extra
            _buildExtraTile(
              title: 'Airport Shuttle Pickup',
              subtitle: '\$25.00 flat (Private VIP air-conditioned transfer)',
              priceStr: '+\$25.00',
              icon: Icons.airport_shuttle,
              isSelected: addAirportPickup,
              onChanged: (val) {
                setState(() => addAirportPickup = val ?? false);
                _calculatePrice();
              },
              isDark: isDark,
            ),
            const SizedBox(height: 8),

            // Laundry Extra
            _buildExtraTile(
              title: 'Express Laundry & Pressing',
              subtitle: '\$15.00 flat (Same-day wash, dry, and iron service)',
              priceStr: '+\$15.00',
              icon: Icons.local_laundry_service,
              isSelected: addLaundry,
              onChanged: (val) {
                setState(() => addLaundry = val ?? false);
                _calculatePrice();
              },
              isDark: isDark,
            ),
            const SizedBox(height: 24),

            // ==========================================
            // 4. COUPONS & DISCOUNTS
            // ==========================================
            Text(
              'Coupons & Discounts',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131D32) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF22314E) : Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: couponCtrl,
                          textCapitalization: TextCapitalization.characters,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            hintText: 'Try WELCOME10 or KH2026',
                            hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400),
                            prefixIcon: const Icon(Icons.local_offer_outlined, color: Color(0xFFEAB308)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isApplyingCoupon ? null : _applyCoupon,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isApplyingCoupon
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                  if (couponMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      couponMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: appliedCoupon != null ? Colors.green.shade500 : Colors.redAccent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ==========================================
            // 5. LIVE PRICE BREAKDOWN (BACKEND PRECISION)
            // ==========================================
            Text(
              'Price Details & Breakdown',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131D32) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF22314E) : Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Room Rate (\$${pricePerNight.toStringAsFixed(2)} × $nights ${nights > 1 ? "nights" : "night"} × ${widget.unitCount} ${widget.unitCount > 1 ? "rooms" : "room"})',
                        style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700, fontSize: 13),
                      ),
                      Text(
                        '\$${roomTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFF8FAFC) : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  if (extrasTotal > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Add-on Extras',
                            style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700, fontSize: 13)),
                        Text('+\$${extrasTotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                      ],
                    ),
                  ],
                  if (discount > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Coupon Discount ($appliedCoupon)',
                            style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('-\$${discount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Service Charge (${serviceChargePercent.toStringAsFixed(0)}%)',
                          style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700, fontSize: 13)),
                      Text('+\$${serviceCharge.toStringAsFixed(2)}',
                          style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : Colors.black87)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Government & City Tax (${taxPercent.toStringAsFixed(0)}%)',
                          style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700, fontSize: 13)),
                      Text('+\$${tax.toStringAsFixed(2)}',
                          style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : Colors.black87)),
                    ],
                  ),
                  Divider(height: 20, color: isDark ? const Color(0xFF22314E) : Colors.grey.shade300),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Grand Total',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDark ? const Color(0xFFF8FAFC) : Colors.black87,
                            ),
                          ),
                          Text(
                            'All taxes and fees included',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${total.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            '≈ ${totalKhr.toStringAsFixed(0)} KHR',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ==========================================
            // 6. PAYMENT OPTIONS (DEPOSIT VS FULL)
            // ==========================================
            Text(
              'Payment Option',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                // Pay Deposit Option
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => payDepositOnly = true),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: payDepositOnly
                            ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF))
                            : (isDark ? const Color(0xFF131D32) : Colors.white),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: payDepositOnly
                              ? const Color(0xFF2563EB)
                              : (isDark ? const Color(0xFF22314E) : Colors.grey.shade300),
                          width: payDepositOnly ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                payDepositOnly ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                size: 18,
                                color: payDepositOnly ? const Color(0xFF2563EB) : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Pay Deposit (20%)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '\$${depositRequired.toStringAsFixed(2)} now',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF16A34A)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Balance \$${balanceDue.toStringAsFixed(2)} due at check-in',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Pay Full Option
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => payDepositOnly = false),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: !payDepositOnly
                            ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF))
                            : (isDark ? const Color(0xFF131D32) : Colors.white),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: !payDepositOnly
                              ? const Color(0xFF2563EB)
                              : (isDark ? const Color(0xFF22314E) : Colors.grey.shade300),
                          width: !payDepositOnly ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                !payDepositOnly ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                size: 18,
                                color: !payDepositOnly ? const Color(0xFF2563EB) : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Pay Full Amount',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '\$${total.toStringAsFixed(2)} now',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '100% fully settled upfront',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ==========================================
            // 7. GUEST INFORMATION FORM
            // ==========================================
            Text(
              'Guest Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131D32) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF22314E) : Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: guestNameCtrl,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\u1780-\u17FF\s\.\-']")),
                      LengthLimitingTextInputFormatter(60),
                    ],
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Primary Guest Full Name * (Letters only)',
                      labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700),
                      prefixIcon: Icon(Icons.person_outline,
                          color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                      enabledBorder: isDark ? const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))) : null,
                      focusedBorder: isDark ? const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF38BDF8))) : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: guestPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d\s\-\+]')),
                      LengthLimitingTextInputFormatter(16),
                    ],
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Contact Phone Number * (Numbers only)',
                      labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700),
                      prefixIcon: Icon(Icons.phone_outlined,
                          color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                      enabledBorder: isDark ? const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))) : null,
                      focusedBorder: isDark ? const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF38BDF8))) : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: guestEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Email Address (For booking confirmation & invoice)',
                      labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700),
                      prefixIcon: Icon(Icons.email_outlined,
                          color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                      enabledBorder: isDark ? const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))) : null,
                      focusedBorder: isDark ? const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF38BDF8))) : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Special Requests / Arrival Notes',
                      labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700),
                      prefixIcon: Icon(Icons.note_alt_outlined,
                          color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                      enabledBorder: isDark ? const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))) : null,
                      focusedBorder: isDark ? const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF38BDF8))) : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ==========================================
            // 8. CANCELLATION POLICY
            // ==========================================
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade300),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined, color: Color(0xFF16A34A), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cancellation Policy',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          cancellationPolicy,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ==========================================
            // 9. PROCEED TO PAYMENT BUTTON
            // ==========================================
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isCalculating ? null : proceedToPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEAB308),
                  foregroundColor: const Color(0xFF0F172A),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: isCalculating
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0F172A)),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            payDepositOnly
                                ? 'Pay Deposit (\$${depositRequired.toStringAsFixed(2)})'
                                : 'Proceed to Pay \$${total.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildExtraTile({
    required String title,
    required String subtitle,
    required String priceStr,
    required IconData icon,
    required bool isSelected,
    required ValueChanged<bool?> onChanged,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF))
            : (isDark ? const Color(0xFF131D32) : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF2563EB)
              : (isDark ? const Color(0xFF22314E) : Colors.grey.shade200),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: onChanged,
        activeColor: const Color(0xFF2563EB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF2563EB).withValues(alpha: 0.15)
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isSelected
                ? const Color(0xFF2563EB)
                : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
            size: 20,
          ),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                ),
              ),
            ),
            Text(
              priceStr,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade800),
              ),
            ),
          ],
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}
