import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../services/api_service.dart';
import '../widgets/stay_review_dialog.dart';

class MyBookingsScreen extends StatefulWidget {
  final bool fromBookingSuccess;

  const MyBookingsScreen({super.key, this.fromBookingSuccess = false});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

enum BookingTabType { upcoming, completed, cancelled }

class _MyBookingsScreenState extends State<MyBookingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<BookingModel> upcomingBookings = [];
  List<BookingModel> completedBookings = [];
  List<BookingModel> cancelledBookings = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() => isLoading = true);
    final all = await ApiService.getMyBookings();

    if (mounted) {
      setState(() {
        upcomingBookings = all.where((b) =>
            b.status != 'CANCELLED' &&
            b.status != 'REJECTED' &&
            (b.status == 'CONFIRMED' ||
             b.status == 'CHECKED_IN' ||
             b.status == 'RESCHEDULED' ||
             (b.status == 'PENDING' && b.paymentStatus == 'PAID'))).toList();
        completedBookings = all.where((b) =>
            b.status == 'COMPLETED' ||
            b.status == 'CHECKED_OUT').toList();
        cancelledBookings = all.where((b) =>
            b.status == 'CANCELLED' ||
            b.status == 'REJECTED' ||
            b.status == 'NO_SHOW').toList();
        isLoading = false;
      });
    }
  }

  void _showQrPass(BookingModel booking) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF131D32) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEAB308).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'HOTEL CHECK-IN & ROOM VOUCHER',
                style: TextStyle(
                  color: Color(0xFFCA8A04),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              booking.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              booking.providerName,
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            // Stay info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.date_range_rounded, size: 16, color: Color(0xFF0284C7)),
                  const SizedBox(width: 6),
                  Text(
                    booking.checkIn != null && booking.checkOut != null
                        ? '${booking.checkIn} ➔ ${booking.checkOut} (${booking.totalNights} nights)'
                        : '${booking.bookingDate} (${booking.bookingTime})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // QR Code Voucher Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(Icons.qr_code_2, size: 140, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  const SizedBox(height: 8),
                  Text(
                    booking.bookingCode,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF38BDF8),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Payment status note
            if (booking.balanceDue > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEA580C).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFFEA580C), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Remaining Balance Due at Front Desk: \$${booking.balanceDue.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                  ],
                ),
              ),

            Text(
              'Present this QR voucher or booking reference to hotel reception for speedy check-in.',
              style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Close Voucher', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(BookingModel booking) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131D32) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
            const SizedBox(width: 8),
            Text(
              'Cancel Reservation?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel reservation #${booking.bookingCode} for ${booking.title}?',
              style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : Colors.black87, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: Color(0xFFD97706), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hotel Policy: Free cancellation up to 48 hours prior to check-in. Cancellations within 48 hours forfeit deposit.',
                      style: TextStyle(color: Color(0xFFB45309), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'Reason for cancellation *',
                labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey),
                hintText: 'e.g. Flight rescheduled, personal reason',
                hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade400),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Keep Stay', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a cancellation reason')),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await ApiService.cancelBooking(
                  bookingId: booking.id,
                  reason: reasonCtrl.text.trim(),
                );
                _loadBookings();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reservation successfully cancelled and room returned to inventory.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'My Hotel Reservations',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        foregroundColor: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
          unselectedLabelColor: isDark ? const Color(0xFF64748B) : Colors.grey,
          indicatorColor: const Color(0xFFEAB308),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(text: 'Upcoming (${upcomingBookings.length})'),
            Tab(text: 'Completed (${completedBookings.length})'),
            Tab(text: 'Cancelled (${cancelledBookings.length})'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFEAB308)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBookingList(upcomingBookings, listType: BookingTabType.upcoming),
                _buildBookingList(completedBookings, listType: BookingTabType.completed),
                _buildBookingList(cancelledBookings, listType: BookingTabType.cancelled),
              ],
            ),
    );
  }

  Widget _buildBookingList(List<BookingModel> list, {required BookingTabType listType}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (list.isEmpty) {
      IconData emptyIcon = Icons.hotel_outlined;
      String emptyTitle = 'No upcoming hotel bookings';
      String emptySubtitle = 'Browse available rooms to plan your next stay.';

      if (listType == BookingTabType.completed) {
        emptyIcon = Icons.history_rounded;
        emptyTitle = 'No completed stays yet';
        emptySubtitle = 'Your past completed stays and checked-out rooms will appear here.';
      } else if (listType == BookingTabType.cancelled) {
        emptyIcon = Icons.event_busy_rounded;
        emptyTitle = 'No cancelled reservations';
        emptySubtitle = 'You have no cancelled hotel stays.';
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 64, color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              emptyTitle,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : Colors.grey),
            ),
            const SizedBox(height: 6),
            Text(
              emptySubtitle,
              style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF64748B) : Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFFEAB308),
      onRefresh: _loadBookings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final b = list[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131D32) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isDark ? const Color(0xFF22314E) : Colors.grey.shade200),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Code & Status
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.confirmation_number_outlined, size: 16, color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB)),
                          const SizedBox(width: 6),
                          Text(
                            b.bookingCode,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          _buildPaymentBadge(b),
                          const SizedBox(width: 6),
                          _buildStatusBadge(b.status),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: isDark ? const Color(0xFF22314E) : Colors.grey.shade200),

                // Main Info
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: b.imageUrl.trim().isNotEmpty
                            ? Image.network(
                                RoomService.safeWebUrl(b.imageUrl),
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  width: 80,
                                  height: 80,
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  child: Icon(Icons.hotel_rounded, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), size: 30),
                                ),
                              )
                            : Container(
                                width: 80,
                                height: 80,
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                child: Icon(Icons.hotel_rounded, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), size: 30),
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              b.providerName,
                              style: TextStyle(
                                color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.calendar_month_outlined, size: 14, color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    b.checkIn != null && b.checkOut != null
                                        ? '${b.checkIn} ➔ ${b.checkOut} (${b.totalNights}n)'
                                        : '${b.bookingDate} • ${b.bookingTime}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? const Color(0xFFCBD5E1) : Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (b.cancellationReason != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Cancellation: ${b.cancellationReason}',
                                style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Total price & actions bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0D1526) : const Color(0xFFF8FAFC),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                    border: Border(top: BorderSide(color: isDark ? const Color(0xFF22314E) : Colors.grey.shade200)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.balanceDue > 0
                                ? 'Paid: \$${b.amountPaid.toStringAsFixed(2)} • Due: \$${b.balanceDue.toStringAsFixed(2)}'
                                : 'Total Amount Paid',
                            style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600, fontSize: 11),
                          ),
                          Text(
                            '\$${b.finalPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      if (listType == BookingTabType.upcoming && b.status != 'CANCELLED')
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (b.status != 'CHECKED_IN') ...[
                              OutlinedButton(
                                onPressed: () => _showCancelDialog(b),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.redAccent),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('Cancel', style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                            ],
                            ElevatedButton.icon(
                              onPressed: () => _showQrPass(b),
                              icon: const Icon(Icons.qr_code, size: 14),
                              label: Text(b.status == 'CHECKED_IN' ? 'Room Key Pass' : 'Pass', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: b.status == 'CHECKED_IN' ? const Color(0xFF10B981) : const Color(0xFFEAB308),
                                foregroundColor: b.status == 'CHECKED_IN' ? Colors.white : const Color(0xFF0F172A),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        )
                      else if (listType == BookingTabType.cancelled)
                        OutlinedButton.icon(
                          onPressed: () => _showQrPass(b),
                          icon: Icon(
                            Icons.receipt_long_outlined,
                            size: 14,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          ),
                          label: Text(
                            'View Details',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            side: BorderSide(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                              width: 1.2,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _showQrPass(b),
                              icon: Icon(
                                Icons.confirmation_number_outlined,
                                size: 14,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                              ),
                              label: Text(
                                'View Pass',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                side: BorderSide(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                  width: 1.2,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            if (b.status == 'COMPLETED' || b.status == 'CHECKED_OUT') ...[
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => StayReviewDialog.show(
                                  context,
                                  b,
                                  onReviewed: () {
                                    if (mounted) _loadBookings();
                                  },
                                ),
                                icon: const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFBBF24)),
                                label: const Text(
                                  'Rate Stay',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.2),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF006CE4),
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  shadowColor: const Color(0xFF006CE4).withValues(alpha: 0.35),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentBadge(BookingModel b) {
    if (b.paymentStatus == 'DEPOSIT') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFF59E0B)),
        ),
        child: Text(
          'Deposit Paid (\$${b.amountPaid.toStringAsFixed(0)})',
          style: const TextStyle(color: Color(0xFFB45309), fontSize: 10, fontWeight: FontWeight.bold),
        ),
      );
    } else if (b.paymentStatus == 'PAID') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Fully Paid',
          style: TextStyle(color: Color(0xFF15803D), fontSize: 10, fontWeight: FontWeight.bold),
        ),
      );
    } else if (b.paymentStatus == 'REFUNDED') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFFF3E8FF),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Refunded',
          style: TextStyle(color: Color(0xFF7E22CE), fontSize: 10, fontWeight: FontWeight.bold),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Unpaid',
        style: TextStyle(color: Color(0xFFB91C1C), fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFDCFCE7);
    Color fg = const Color(0xFF15803D);

    if (status == 'CANCELLED') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
    } else if (status == 'RESCHEDULED') {
      bg = const Color(0xFFE0F2FE);
      fg = const Color(0xFF0369A1);
    } else if (status == 'PENDING') {
      bg = const Color(0xFFFEF9C3);
      fg = const Color(0xFFA16207);
    } else if (status == 'CHECKED_IN') {
      bg = const Color(0xFFD1FAE5);
      fg = const Color(0xFF065F46);
    } else if (status == 'COMPLETED') {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF334155);
    }

    String displayStatus = status;
    if (status == 'CHECKED_IN') {
      displayStatus = 'CHECKED IN (ACTIVE)';
    } else if (status == 'COMPLETED') {
      displayStatus = 'COMPLETED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(displayStatus, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
