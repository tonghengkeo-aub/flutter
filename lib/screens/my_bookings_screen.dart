import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/booking_model.dart';
import '../services/api_service.dart';

class MyBookingsScreen extends StatefulWidget {
  final bool fromBookingSuccess;

  const MyBookingsScreen({super.key, this.fromBookingSuccess = false});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<BookingModel> upcomingBookings = [];
  List<BookingModel> historyBookings = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() => isLoading = true);
    final upcomings = await ApiService.getUpcomingBookings();
    final histories = await ApiService.getHistoryBookings();

    if (mounted) {
      setState(() {
        upcomingBookings = upcomings;
        historyBookings = histories;
        isLoading = false;
      });
    }
  }

  void _showQrPass(BookingModel booking) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF131D32) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 20),
            Text('APPOINTMENT & CHECK-IN PASS', style: TextStyle(color: isDark ? const Color(0xFFFBBF24) : Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 8),
            Text(booking.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('Specialist: ${booking.providerName}', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 2),
            Text('${booking.bookingDate} at ${booking.bookingTime}', style: TextStyle(color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 20),

            // QR Code Voucher Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  Icon(Icons.qr_code_2, size: 140, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  const SizedBox(height: 8),
                  Text(
                    booking.bookingCode,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF38BDF8), letterSpacing: 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Present this QR voucher or booking code upon arrival for instantaneous check-in.',
              style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
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
                child: const Text('Close Pass'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRescheduleModal(BookingModel booking) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    DateTime newDate = DateTime.now().add(const Duration(days: 2));
    String newTime = '10:30 AM';
    final reasonCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF131D32) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final df = DateFormat('EEE, MMM dd, yyyy');

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
                ),
                const SizedBox(height: 16),
                Text('Reschedule Booking', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A))),
                const SizedBox(height: 4),
                Text('Modify date and time slot for #${booking.bookingCode}', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : Colors.grey)),
                const SizedBox(height: 18),

                // Date Picker
                Text('Select New Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A))),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: newDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (picked != null) {
                      setModalState(() => newDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(df.format(newDate), style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                        const Icon(Icons.calendar_today, size: 18, color: Color(0xFFEAB308)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Time Slots
                Text('Select New Time Slot', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    '08:30 AM', '09:30 AM', '10:30 AM', '11:30 AM',
                    '01:30 PM', '02:30 PM', '03:30 PM', '04:30 PM', '05:30 PM', '06:30 PM'
                  ].map((slot) {
                    final isSel = newTime == slot;
                    return ChoiceChip(
                      label: Text(slot, style: TextStyle(fontSize: 12, color: isSel ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : Colors.black87))),
                      selected: isSel,
                      selectedColor: isDark ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                      onSelected: (val) => setModalState(() => newTime = slot),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Reason
                TextField(
                  controller: reasonCtrl,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Reason for rescheduling (Optional)',
                    labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey),
                    border: const OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade400)),
                  ),
                ),
                const SizedBox(height: 20),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final fDate = DateFormat('yyyy-MM-dd').format(newDate);
                      try {
                        await ApiService.rescheduleBooking(
                          bookingId: booking.id,
                          newDate: fDate,
                          newTime: newTime,
                          reason: reasonCtrl.text.trim(),
                        );
                        _loadBookings();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Booking rescheduled to $fDate at $newTime!')),
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
                      backgroundColor: const Color(0xFFEAB308),
                      foregroundColor: const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Confirm Reschedule', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
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
        title: Text('Cancel Booking?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to cancel booking #${booking.bookingCode}?', style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : Colors.black87)),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'Reason for cancellation *',
                labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey),
                hintText: 'e.g. Schedule conflict',
                hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade400)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Keep Booking', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey)),
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
                    const SnackBar(content: Text('Booking has been cancelled')),
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
        title: Text('My Appointments & Bookings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A))),
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        foregroundColor: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
          unselectedLabelColor: isDark ? const Color(0xFF64748B) : Colors.grey,
          indicatorColor: const Color(0xFFEAB308),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            Tab(text: 'Upcoming (${upcomingBookings.length})'),
            Tab(text: 'History (${historyBookings.length})'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFEAB308)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBookingList(upcomingBookings, isUpcoming: true),
                _buildBookingList(historyBookings, isUpcoming: false),
              ],
            ),
    );
  }

  Widget _buildBookingList(List<BookingModel> list, {required bool isUpcoming}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined, size: 64, color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              isUpcoming ? 'No upcoming bookings' : 'No past booking records',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : Colors.grey),
            ),
            const SizedBox(height: 6),
            Text('Explore services on the home screen to make an appointment.', style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF64748B) : Colors.grey)),
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
                      Text(
                        b.bookingCode,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB), letterSpacing: 0.5),
                      ),
                      _buildStatusBadge(b.status),
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
                        child: Image.network(
                          b.imageUrl,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(width: 72, height: 72, color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200),
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
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Specialist: ${b.providerName}',
                              style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.event, size: 13, color: isDark ? const Color(0xFF64748B) : Colors.grey),
                                const SizedBox(width: 4),
                                Text('${b.bookingDate} • ${b.bookingTime}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFCBD5E1) : Colors.black87)),
                              ],
                            ),
                            if (b.cancellationReason != null) ...[
                              const SizedBox(height: 4),
                              Text('Reason: ${b.cancellationReason}', style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontStyle: FontStyle.italic)),
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
                          Text('Total Paid', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey, fontSize: 11)),
                          Text(
                            '\$${b.finalPrice.toStringAsFixed(2)}',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      if (isUpcoming && b.status != 'CANCELLED')
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: () => _showRescheduleModal(b),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: isDark ? const Color(0xFF64748B) : const Color(0xFF0F172A)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text('Reschedule', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () => _showCancelDialog(b),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.redAccent),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Cancel', style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _showQrPass(b),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEAB308),
                                foregroundColor: const Color(0xFF0F172A),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Pass', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: () => _showQrPass(b),
                          icon: const Icon(Icons.qr_code, size: 14),
                          label: const Text('View Pass', style: TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
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
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(status, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
