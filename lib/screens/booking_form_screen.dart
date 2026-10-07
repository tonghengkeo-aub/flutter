import 'package:flutter/material.dart';
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

  const BookingFormScreen({
    super.key,
    this.service,
    this.provider,
    this.hotel,
    this.room,
  });

  @override
  State<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
  String selectedTime = '10:30 AM';
  ProviderModel? selectedProvider;
  List<ProviderModel> allProviders = [];

  List<String> availableSlots = [
    '08:30 AM', '09:30 AM', '10:30 AM', '11:30 AM',
    '01:30 PM', '02:30 PM', '03:30 PM', '04:30 PM', '05:30 PM', '06:30 PM'
  ];
  List<String> bookedSlots = [];
  bool isCheckingSlots = false;

  final guestNameCtrl = TextEditingController();
  final guestPhoneCtrl = TextEditingController();
  final guestEmailCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final couponCtrl = TextEditingController();

  double discountAmount = 0.0;
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

    selectedProvider = widget.provider;
    _initProvidersAndAvailability();
  }

  Future<void> _initProvidersAndAvailability() async {
    final list = await ApiService.getProviders();
    if (mounted) {
      setState(() {
        allProviders = list;
        if (selectedProvider == null && allProviders.isNotEmpty) {
          selectedProvider = allProviders.first;
        }
      });
      _fetchAvailability();
    }
  }

  Future<void> _fetchAvailability() async {
    if (selectedProvider == null) return;
    setState(() => isCheckingSlots = true);

    final df = DateFormat('yyyy-MM-dd');
    final res = await ApiService.checkAvailability(
      providerId: selectedProvider!.id,
      date: df.format(selectedDate),
    );

    if (mounted) {
      setState(() {
        isCheckingSlots = false;
        if (res['availableSlots'] != null) {
          availableSlots = List<String>.from(res['availableSlots']);
        }
        if (res['bookedSlots'] != null) {
          bookedSlots = List<String>.from(res['bookedSlots']);
        }
        if (!availableSlots.contains(selectedTime) && availableSlots.isNotEmpty) {
          selectedTime = availableSlots.first;
        }
      });
    }
  }

  double get basePrice {
    if (widget.service != null) return widget.service!.price;
    if (widget.room != null) return widget.room!.priceUsd;
    return 45.0;
  }

  double get finalPrice {
    return (basePrice - discountAmount).clamp(0.0, double.infinity);
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.isBefore(DateTime.now()) ? DateTime.now() : selectedDate,
      firstDate: DateTime.now(), // Past dates disabled
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );

    if (picked != null) {
      setState(() => selectedDate = picked);
      _fetchAvailability();
    }
  }

  Future<void> _applyCoupon() async {
    final code = couponCtrl.text.trim();
    if (code.isEmpty) return;

    setState(() => isApplyingCoupon = true);
    final res = await ApiService.validateCoupon(code, basePrice);

    if (mounted) {
      setState(() {
        isApplyingCoupon = false;
        if (res['valid'] == true) {
          appliedCoupon = res['code'];
          discountAmount = (res['discountAmount'] as num).toDouble();
          couponMessage = res['message'];
        } else {
          appliedCoupon = null;
          discountAmount = 0.0;
          couponMessage = res['message'];
        }
      });
    }
  }

  void proceedToPayment() {
    if (guestNameCtrl.text.trim().isEmpty || guestPhoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter guest name and phone number')),
      );
      return;
    }

    if (bookedSlots.contains(selectedTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The selected time slot is already booked. Please choose an available slot.')),
      );
      return;
    }

    final df = DateFormat('yyyy-MM-dd');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          service: widget.service,
          provider: selectedProvider,
          hotel: widget.hotel,
          room: widget.room,
          bookingDate: df.format(selectedDate),
          bookingTime: selectedTime,
          basePrice: basePrice,
          discountAmount: discountAmount,
          finalPrice: finalPrice,
          couponCode: appliedCoupon,
          guestName: guestNameCtrl.text.trim(),
          guestPhone: guestPhoneCtrl.text.trim(),
          guestEmail: guestEmailCtrl.text.trim(),
          notes: notesCtrl.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final df = DateFormat('EEE, MMM dd, yyyy');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Schedule & Booking Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A))),
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        foregroundColor: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131D32) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF22314E) : Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.service?.imageUrl ?? widget.hotel?.mainImage ?? 'https://images.unsplash.com/photo-1540555700478-4be289fbecef?w=400',
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(width: 70, height: 70, color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.service?.name ?? widget.hotel?.name ?? 'Booking Service',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.service?.locationName ?? 'Phnom Penh, Cambodia',
                          style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${basePrice.toStringAsFixed(2)}',
                          style: TextStyle(color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Provider / Specialist Selection
            Text('Select Specialist / Provider', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A))),
            const SizedBox(height: 10),
            if (allProviders.isNotEmpty)
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: allProviders.length,
                  itemBuilder: (context, idx) {
                    final p = allProviders[idx];
                    final isSel = selectedProvider?.id == p.id;
                    return GestureDetector(
                      onTap: () {
                        setState(() => selectedProvider = p);
                        _fetchAvailability();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel
                              ? (isDark ? const Color(0xFF2563EB) : const Color(0xFF0F172A))
                              : (isDark ? const Color(0xFF131D32) : Colors.white),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSel
                                ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A))
                                : (isDark ? const Color(0xFF22314E) : Colors.grey.shade300),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: NetworkImage(p.avatarUrl ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200'),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  p.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isSel ? Colors.white : (isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)),
                                  ),
                                ),
                                Text(
                                  p.title,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSel ? Colors.white70 : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 24),

            // Date Picker (Past dates disabled)
            Text('Appointment Date', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A))),
            const SizedBox(height: 10),
            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131D32) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? const Color(0xFF22314E) : Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF854D0E).withValues(alpha: 0.3) : const Color(0xFFFEF9C3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.calendar_month, color: Color(0xFFCA8A04), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Selected Date', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey, fontSize: 11, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(df.format(selectedDate), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A))),
                        ],
                      ),
                    ),
                    Text('Change', style: TextStyle(color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Time Slots Grid with Real-Time Conflict Checking
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Available Time Slots', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A))),
                if (isCheckingSlots)
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEAB308))),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                '08:30 AM', '09:30 AM', '10:30 AM', '11:30 AM',
                '01:30 PM', '02:30 PM', '03:30 PM', '04:30 PM', '05:30 PM', '06:30 PM'
              ].map((slot) {
                final isBooked = bookedSlots.contains(slot);
                final isSelected = selectedTime == slot && !isBooked;

                return GestureDetector(
                  onTap: isBooked ? null : () => setState(() => selectedTime = slot),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isBooked
                          ? (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100)
                          : isSelected
                              ? const Color(0xFFEAB308)
                              : (isDark ? const Color(0xFF131D32) : Colors.white),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isBooked
                            ? (isDark ? const Color(0xFF334155) : Colors.grey.shade300)
                            : isSelected
                                ? const Color(0xFFCA8A04)
                                : (isDark ? const Color(0xFF22314E) : Colors.grey.shade300),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isBooked ? Icons.lock_clock : Icons.access_time,
                          size: 14,
                          color: isBooked
                              ? (isDark ? const Color(0xFF64748B) : Colors.grey)
                              : isSelected
                                  ? const Color(0xFF0F172A)
                                  : (isDark ? const Color(0xFF94A3B8) : Colors.black87),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          slot,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isBooked
                                ? (isDark ? const Color(0xFF64748B) : Colors.grey)
                                : isSelected
                                    ? const Color(0xFF0F172A)
                                    : (isDark ? const Color(0xFFCBD5E1) : Colors.black87),
                            decoration: isBooked ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Guest Information Form
            Text('Guest Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A))),
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
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Guest Full Name *',
                      labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700),
                      prefixIcon: Icon(Icons.person_outline, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                      enabledBorder: isDark ? const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))) : null,
                      focusedBorder: isDark ? const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF38BDF8))) : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: guestPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Contact Phone Number *',
                      labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700),
                      prefixIcon: Icon(Icons.phone_outlined, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
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
                      labelText: 'Email Address',
                      labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700),
                      prefixIcon: Icon(Icons.email_outlined, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
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
                      labelText: 'Special Requests / Instructions',
                      labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700),
                      prefixIcon: Icon(Icons.note_alt_outlined, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                      enabledBorder: isDark ? const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))) : null,
                      focusedBorder: isDark ? const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF38BDF8))) : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Coupon Code Section
            Text('Coupons & Discounts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A))),
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
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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

            // Price Breakdown Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131D32) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF22314E) : Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Subtotal', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey)),
                      Text('\$${basePrice.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFF8FAFC) : Colors.black87)),
                    ],
                  ),
                  if (discountAmount > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Discount ($appliedCoupon)', style: const TextStyle(color: Colors.green)),
                        Text('-\$${discountAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  ],
                  Divider(height: 20, color: isDark ? const Color(0xFF22314E) : Colors.grey.shade300),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Final Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? const Color(0xFFF8FAFC) : Colors.black87)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('\$${finalPrice.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF0F172A))),
                          Text('≈ ${(finalPrice * 4100).toStringAsFixed(0)} KHR', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Continue to Payment Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: proceedToPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEAB308),
                  foregroundColor: const Color(0xFF0F172A),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Proceed to Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
