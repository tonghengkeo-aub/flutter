import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../models/booking_model.dart';
import '../services/api_service.dart';
import '../widgets/stay_review_dialog.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<NotificationModel> notifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => isLoading = true);
    final list = await ApiService.getNotifications();
    if (mounted) {
      setState(() {
        notifications = list;
        isLoading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    await ApiService.markAllNotificationsRead();
    _loadNotifications();
  }

  Future<void> _markRead(int id) async {
    await ApiService.markNotificationRead(id);
    _loadNotifications();
  }

  Future<void> _deleteNotification(NotificationModel item) async {
    setState(() {
      notifications.removeWhere((n) => n.id == item.id);
    });
    await ApiService.deleteNotification(item.id);
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed: '),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _confirmClearAll() async {
    if (notifications.isEmpty) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131D32) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFDC2626), size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'Clear All?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to remove all notifications? This action cannot be undone.',
          style: TextStyle(
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade700, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        notifications.clear();
      });
      await ApiService.clearAllNotifications();
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('All notifications cleared'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (notifications.isNotEmpty) ...[
            if (notifications.any((n) => !n.isRead))
              IconButton(
                icon: const Icon(Icons.done_all, color: Color(0xFFEAB308), size: 22),
                tooltip: 'Mark All Read',
                onPressed: _markAllRead,
              ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFEF4444), size: 22),
              tooltip: 'Clear All Notifications',
              onPressed: _confirmClearAll,
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: isDark ? Colors.white70 : Colors.black87),
              tooltip: 'More options',
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onSelected: (val) {
                if (val == 'mark_all') {
                  _markAllRead();
                } else if (val == 'clear_all') {
                  _confirmClearAll();
                }
              },
              itemBuilder: (ctx) => [
                if (notifications.any((n) => !n.isRead))
                  const PopupMenuItem(
                    value: 'mark_all',
                    child: Row(
                      children: [
                        Icon(Icons.done_all, size: 18, color: Color(0xFFEAB308)),
                        SizedBox(width: 10),
                        Text('Mark all as read', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep_rounded, size: 18, color: Color(0xFFDC2626)),
                      SizedBox(width: 10),
                      Text('Clear all notifications', style: TextStyle(fontSize: 13, color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFEAB308)))
          : RefreshIndicator(
              color: const Color(0xFFEAB308),
              onRefresh: _loadNotifications,
              child: notifications.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF131D32) : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: isDark ? const Color(0xFF1F2937) : Colors.grey.shade200),
                              ),
                              child: Icon(Icons.notifications_off_outlined, size: 48, color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'No notifications yet',
                              style: TextStyle(color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A), fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your booking updates, approvals, and reminders will appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600, fontSize: 13, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final item = notifications[index];
                        return Dismissible(
                          key: ValueKey('notif_${item.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            alignment: Alignment.centerRight,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Icon(Icons.delete_outline, color: Colors.white, size: 22),
                                SizedBox(width: 6),
                                Text(
                                  'Remove',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          onDismissed: (_) => _deleteNotification(item),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? (item.isRead ? const Color(0xFF131D32) : const Color(0xFF1E293B))
                                  : (item.isRead ? Colors.white : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark
                                    ? (item.isRead ? const Color(0xFF22314E) : const Color(0xFFEAB308).withValues(alpha: 0.4))
                                    : (item.isRead ? Colors.grey.shade200 : const Color(0xFFEAB308).withValues(alpha: 0.5)),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark ? Colors.black26 : Colors.black12,
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _getNotificationColor(item.type).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _getNotificationIcon(item.type),
                                    color: _getNotificationColor(item.type),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              style: TextStyle(
                                                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                                fontSize: 14.5,
                                                fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                                                height: 1.25,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          if (!item.isRead)
                                            Container(
                                              margin: const EdgeInsets.only(top: 4, right: 6),
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFEAB308),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          PopupMenuButton<String>(
                                            icon: Icon(
                                              Icons.more_vert,
                                              size: 18,
                                              color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade400,
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            tooltip: 'Options',
                                            onSelected: (val) {
                                              if (val == 'read') {
                                                _markRead(item.id);
                                              } else if (val == 'delete') {
                                                _deleteNotification(item);
                                              }
                                            },
                                            itemBuilder: (ctx) => [
                                              if (!item.isRead)
                                                const PopupMenuItem(
                                                  value: 'read',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.check, size: 16, color: Color(0xFFEAB308)),
                                                      SizedBox(width: 8),
                                                      Text('Mark as read', style: TextStyle(fontSize: 13)),
                                                    ],
                                                  ),
                                                ),
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                                                    SizedBox(width: 8),
                                                    Text('Remove', style: TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        item.message,
                                        style: TextStyle(
                                          color: isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade600,
                                          fontSize: 13,
                                          height: 1.4,
                                        ),
                                      ),
                                      if (item.type.toUpperCase() == 'REVIEW_INVITATION' ||
                                          item.title.toLowerCase().contains('rate') ||
                                          item.title.toLowerCase().contains('review')) ...[
                                        const SizedBox(height: 10),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF003580),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            elevation: 0,
                                          ),
                                          icon: const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFBBF24)),
                                          label: const Text(
                                            'Rate & Write Review',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                          onPressed: () => _showReviewDialog(item),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Future<void> _showReviewDialog(NotificationModel notifItem) async {
    final histories = await ApiService.getHistoryBookings();
    BookingModel? targetBooking;
    if (histories.isNotEmpty) {
      targetBooking = histories.firstWhere(
        (b) => b.status == 'COMPLETED' || b.status == 'CHECKED_OUT',
        orElse: () => histories.first,
      );
    }

    targetBooking ??= BookingModel(
      id: 0,
      bookingCode: 'STAY-COMPLETED',
      title: 'Luxury Hotel Room Stay',
      providerName: 'Boss_Heng Luxury Hotel',
      locationAddress: 'National Road 2, Ta Khmau, Kandal',
      bookingDate: 'Completed Stay',
      bookingTime: 'Check-out',
      durationMinutes: 1440,
      totalPrice: 0.0,
      discountAmount: 0.0,
      finalPrice: 0.0,
      finalPriceKhr: 0.0,
      guestName: ApiService.currentUser?.fullName ?? 'Verified Guest',
      guestPhone: ApiService.currentUser?.phone ?? '',
      status: 'COMPLETED',
      imageUrl: 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=600',
    );

    if (mounted) {
      await StayReviewDialog.show(context, targetBooking, onReviewed: () {
        _markRead(notifItem.id);
        _loadNotifications();
      });
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type.toUpperCase()) {
      case 'REVIEW_INVITATION':
      case 'REVIEW_SUBMITTED':
        return Icons.star_rounded;
      case 'BOOKING_CONFIRMED':
        return Icons.check_circle_outline;
      case 'BOOKING_RESCHEDULED':
        return Icons.update_rounded;
      case 'BOOKING_CANCELLED':
        return Icons.cancel_outlined;
      case 'PROMOTION':
        return Icons.local_offer_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type.toUpperCase()) {
      case 'REVIEW_INVITATION':
        return const Color(0xFFF59E0B);
      case 'REVIEW_SUBMITTED':
        return const Color(0xFF10B981);
      case 'BOOKING_CONFIRMED':
        return const Color(0xFF4ADE80);
      case 'BOOKING_RESCHEDULED':
        return const Color(0xFF38BDF8);
      case 'BOOKING_CANCELLED':
        return const Color(0xFFF87171);
      case 'PROMOTION':
        return const Color(0xFFEAB308);
      default:
        return const Color(0xFF94A3B8);
    }
  }
}
