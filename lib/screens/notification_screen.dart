import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/api_service.dart';

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
          if (notifications.any((n) => !n.isRead))
            TextButton.icon(
              onPressed: _markAllRead,
              icon: const Icon(Icons.done_all, color: Color(0xFFEAB308), size: 18),
              label: const Text(
                'Mark All Read',
                style: TextStyle(color: Color(0xFFEAB308), fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFEAB308)))
          : RefreshIndicator(
              color: const Color(0xFFEAB308),
              onRefresh: _loadNotifications,
              child: notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 64, color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'No notifications yet',
                            style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your appointment alerts and booking updates will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: isDark ? const Color(0xFF64748B) : Colors.grey.shade500, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final item = notifications[index];
                        return InkWell(
                          onTap: () {
                            if (!item.isRead) _markRead(item.id);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
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
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
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
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              style: TextStyle(
                                                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                                fontSize: 15,
                                                fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          if (!item.isRead)
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFEAB308),
                                                shape: BoxShape.circle,
                                              ),
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

  IconData _getNotificationIcon(String type) {
    switch (type.toUpperCase()) {
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
