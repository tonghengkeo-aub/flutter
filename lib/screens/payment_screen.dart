import 'package:flutter/material.dart';
import '../models/provider_model.dart';
import '../models/service_model.dart';
import '../models/hotel_model.dart';
import '../models/room_model.dart';
import '../services/api_service.dart';
import '../widgets/khqr_payment_dialog.dart';
import 'main_nav_screen.dart';

class PaymentScreen extends StatefulWidget {
  final ServiceModel? service;
  final ProviderModel? provider;
  final HotelModel? hotel;
  final RoomModel? room;
  final String bookingDate;
  final String bookingTime;
  final double basePrice;
  final double discountAmount;
  final double finalPrice;
  final String? couponCode;
  final String guestName;
  final String guestPhone;
  final String? guestEmail;
  final String? notes;

  // Legacy compatibility fields if invoked from hotel room flow
  final String? checkInStr;
  final String? checkOutStr;
  final int? totalNights;
  final double? totalPriceUsd;
  final double? totalPriceKhr;
  final String? specialRequests;
  final int unitCount;

  // Money & Deposit Breakdown
  final bool payDepositOnly;
  final double? depositRequired;
  final double? balanceDue;
  final double? serviceCharge;
  final double? tax;
  final List<Map<String, dynamic>> extras;

  const PaymentScreen({
    super.key,
    this.service,
    this.provider,
    this.hotel,
    this.room,
    this.bookingDate = '',
    this.bookingTime = '10:00 AM',
    this.basePrice = 0.0,
    this.discountAmount = 0.0,
    this.finalPrice = 0.0,
    this.couponCode,
    this.guestName = '',
    this.guestPhone = '',
    this.guestEmail,
    this.notes,
    this.checkInStr,
    this.checkOutStr,
    this.totalNights,
    this.totalPriceUsd,
    this.totalPriceKhr,
    this.specialRequests,
    this.unitCount = 1,
    this.payDepositOnly = false,
    this.depositRequired,
    this.balanceDue,
    this.serviceCharge,
    this.tax,
    this.extras = const [],
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String selectedMethod = 'KHQR';
  bool isProcessing = false;

  double get displayFinalPrice {
    if (widget.payDepositOnly && widget.depositRequired != null && widget.depositRequired! > 0) {
      return widget.depositRequired!;
    }
    if (widget.finalPrice > 0) return widget.finalPrice;
    if (widget.totalPriceUsd != null && widget.totalPriceUsd! > 0) return widget.totalPriceUsd!;
    return 45.0;
  }

  double get displayPriceKhr => displayFinalPrice * 4100;

  String get effectiveDate {
    if (widget.bookingDate.isNotEmpty) return widget.bookingDate;
    if (widget.checkInStr != null && widget.checkInStr!.isNotEmpty) return widget.checkInStr!;
    return '2026-09-28';
  }

  Future<void> handlePay() async {
    setState(() => isProcessing = true);

    try {
      final booking = await ApiService.createBooking(
        serviceId: widget.service?.id ?? 1,
        providerId: widget.provider?.id ?? 1,
        locationId: 1,
        roomId: widget.room?.id,
        hotelId: widget.hotel?.id ?? widget.room?.hotelId,
        numberOfRooms: widget.unitCount > 0 ? widget.unitCount : 1,
        checkIn: widget.checkInStr ?? effectiveDate,
        checkOut: widget.checkOutStr,
        bookingDate: effectiveDate,
        bookingTime: widget.bookingTime,
        guestName: widget.guestName,
        guestPhone: widget.guestPhone,
        guestEmail: widget.guestEmail,
        notes: widget.notes ?? widget.specialRequests,
        couponCode: widget.couponCode,
        paymentMethod: selectedMethod,
        extras: widget.extras,
        payDepositOnly: widget.payDepositOnly,
      );

      if (!mounted) return;

      if (selectedMethod == 'KHQR') {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => KhqrPaymentDialog(
            amountUsd: displayFinalPrice,
            amountKhr: displayPriceKhr,
            billNumber: booking.bookingCode,
            bookingId: booking.id,
            onPaymentSuccess: (successData) {
              showSuccessDialog(booking.bookingCode);
            },
          ),
        );
        return;
      }

      showSuccessDialog(booking.bookingCode);
    } catch (e) {
      if (mounted) {
        final alertMsg = e.toString().replaceAll('Exception: ', '').trim();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
                SizedBox(width: 8),
                Text('Booking Alert', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Text(
              alertMsg.isNotEmpty ? alertMsg : 'Unable to complete booking. Please try again.',
              style: const TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  void showSuccessDialog(String bookingCode) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131D32) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.6) : const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 48),
              ),
              const SizedBox(height: 16),
              Text(
                'Booking Confirmed!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              Text(
                'Reference Code:',
                style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  bookingCode,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF1D4ED8), letterSpacing: 1),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Your room reservation has been confirmed and recorded. You can view your stay details under Bookings.',
                textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                       context,
                      MaterialPageRoute(builder: (_) => const MainNavScreen()),
                      (r) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('View My Bookings', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Secure Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A))),
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        foregroundColor: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total Amount Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark ? [const Color(0xFF131D32), const Color(0xFF1E293B)] : [const Color(0xFF0F172A), const Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.35 : 0.2), blurRadius: 15, offset: const Offset(0, 6)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.payDepositOnly ? 'DEPOSIT AMOUNT DUE NOW (20%)' : 'TOTAL PAYABLE AMOUNT',
                    style: const TextStyle(color: Color(0xFFEAB308), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\$${displayFinalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        '≈ ${displayPriceKhr.toStringAsFixed(0)} ៛',
                        style: const TextStyle(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (widget.payDepositOnly && widget.balanceDue != null && widget.balanceDue! > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Remaining Balance: \$${widget.balanceDue!.toStringAsFixed(2)} (payable at check-in)',
                      style: const TextStyle(color: Color(0xFF86EFAC), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                  const Divider(color: Colors.white24, height: 24),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, color: Colors.white60, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        (widget.checkInStr != null && widget.checkOutStr != null)
                            ? 'Stay: ${widget.checkInStr} ➔ ${widget.checkOutStr} (${widget.totalNights ?? 1} nights)'
                            : '$effectiveDate at ${widget.bookingTime}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Select Payment Gateway
            Text('Payment Method', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A))),
            const SizedBox(height: 12),

            _buildPaymentOption(
              key: 'KHQR',
              title: 'Bakong KHQR (National Bank)',
              subtitle: 'Scan & pay with any Cambodian banking app',
              icon: Icons.qr_code_2,
              badge: 'Instant Zero Fee',
              badgeColor: Colors.green,
              isDark: isDark,
            ),
            const SizedBox(height: 10),

            _buildPaymentOption(
              key: 'ABA_PAYWAY',
              title: 'ABA PayWay',
              subtitle: 'Pay directly via ABA Mobile app',
              icon: Icons.account_balance,
              badge: 'Fast',
              badgeColor: Colors.blue,
              isDark: isDark,
            ),
            const SizedBox(height: 10),

            _buildPaymentOption(
              key: 'WING',
              title: 'Wing Bank',
              subtitle: 'Pay with Wing Money account',
              icon: Icons.send_to_mobile,
              badge: null,
              badgeColor: null,
              isDark: isDark,
            ),
            const SizedBox(height: 10),

            _buildPaymentOption(
              key: 'CREDIT_CARD',
              title: 'Visa / Mastercard / UnionPay',
              subtitle: 'International & local debit/credit cards',
              icon: Icons.credit_card,
              badge: null,
              badgeColor: null,
              isDark: isDark,
            ),
            const SizedBox(height: 10),

            _buildPaymentOption(
              key: 'CASH',
              title: 'Pay Upon Arrival / Cash',
              subtitle: 'Settle directly at hotel reception / front desk',
              icon: Icons.payments_outlined,
              badge: null,
              badgeColor: null,
              isDark: isDark,
            ),
            const SizedBox(height: 24),

            // Confirm & Pay Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isProcessing ? null : handlePay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEAB308),
                  foregroundColor: const Color(0xFF0F172A),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: isProcessing
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)))
                    : Text(
                        'Confirm & Pay \$${displayFinalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required String key,
    required String title,
    required String subtitle,
    required IconData icon,
    String? badge,
    Color? badgeColor,
    required bool isDark,
  }) {
    final isSelected = selectedMethod == key;

    return InkWell(
      onTap: () => setState(() => selectedMethod = key),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131D32) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFEAB308)
                : (isDark ? const Color(0xFF22314E) : Colors.grey.shade300),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? const Color(0xFF854D0E).withValues(alpha: 0.3) : const Color(0xFFFEF9C3))
                    : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isSelected ? const Color(0xFFCA8A04) : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? const Color(0xFFF8FAFC) : Colors.black87)),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor!.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(badge, style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600, fontSize: 11)),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? const Color(0xFFEAB308) : (isDark ? const Color(0xFF64748B) : Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}
