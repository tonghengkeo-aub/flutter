import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/booking_model.dart';
import '../services/api_service.dart';

class StayReviewDialog extends StatefulWidget {
  final BookingModel booking;
  final VoidCallback? onReviewed;

  const StayReviewDialog({
    super.key,
    required this.booking,
    this.onReviewed,
  });

  static final Set<int> dismissedInThisSession = {};
  static bool _isPromptActive = false;

  static Future<void> show(BuildContext context, BookingModel booking, {VoidCallback? onReviewed}) async {
    if (_isPromptActive) return;
    _isPromptActive = true;
    try {
      return await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => StayReviewDialog(booking: booking, onReviewed: onReviewed),
      );
    } finally {
      _isPromptActive = false;
    }
  }

  /// Automatically checks if the admin has checked out this customer.
  /// ONLY shows pop-up if there is an unread REVIEW_INVITATION notification
  /// generated when the admin clicked Check-Out!
  static Future<bool> checkAndShowPendingReview(
    BuildContext context, {
    Duration delay = const Duration(milliseconds: 900),
  }) async {
    if (_isPromptActive) return false;

    try {
      if (delay > Duration.zero) {
        await Future.delayed(delay);
      }
      if (!context.mounted) return false;

      final user = ApiService.currentUser;
      if (user == null && ApiService.authToken == null) return false;

      // 1. Fetch notifications for this customer
      final notifs = await ApiService.getNotifications();

      // 2. Check for an UNREAD REVIEW_INVITATION notification!
      // This is created ONLY when Admin clicks "Check Out" on the dashboard.
      final unreadInvites = notifs.where((n) =>
          !n.isRead &&
          (n.type.toUpperCase() == 'REVIEW_INVITATION' ||
           (n.title.toLowerCase().contains('rate') && n.title.toLowerCase().contains('stay')))
      ).toList();

      if (unreadInvites.isEmpty) {
        // Admin did NOT check out this customer just now. DO NOT SHOW ANY POP-UP!
        return false;
      }

      final invite = unreadInvites.first;

      final bookings = await ApiService.getMyBookings();
      final completed = bookings.where((b) =>
          b.status == 'COMPLETED' || b.status == 'CHECKED_OUT').toList();

      if (completed.isEmpty) return false;

      // Extract specific booking id if present: [CHECKOUT_BOOKING:123]
      BookingModel? targetBooking;
      final match = RegExp(r'\[CHECKOUT_BOOKING:(\d+)\]').firstMatch(invite.message);
      if (match != null) {
        final bId = int.tryParse(match.group(1) ?? '');
        targetBooking = completed.firstWhere((b) => b.id == bId, orElse: () => completed.first);
      } else {
        targetBooking = completed.first;
      }

      final prefs = await SharedPreferences.getInstance();
      final isReviewed = prefs.getBool('reviewed_booking_${targetBooking.id}') ?? false;

      // Mark the invitation notification read so it doesn't trigger again
      await ApiService.markNotificationRead(invite.id);

      if (!isReviewed && !dismissedInThisSession.contains(targetBooking.id)) {
        dismissedInThisSession.add(targetBooking.id);
        if (context.mounted) {
          await show(context, targetBooking);
          return true;
        }
      }
    } catch (e) {
      debugPrint('StayReviewDialog checkAndShowPendingReview error: $e');
    }
    return false;
  }

  @override
  State<StayReviewDialog> createState() => _StayReviewDialogState();
}

class _StayReviewDialogState extends State<StayReviewDialog> {
  int rating = 0; // Starts at 0 stars so the customer chooses their own rating
  final TextEditingController reviewCtrl = TextEditingController();
  bool isSubmitting = false;

  final List<String> quickTags = [
    '✨ Sparkling Clean',
    '🛏️ Comfy Bed',
    '⚡ Fast WiFi',
    '🤝 Helpful Staff',
    '🌅 Peaceful View',
    '🍳 Great Food',
  ];
  final Set<String> selectedTags = {};

  String get ratingLabel {
    switch (rating) {
      case 5:
        return 'Exceptional Stay!';
      case 4:
        return 'Loved It!';
      case 3:
        return 'Good & Comfortable';
      case 2:
        return 'Could Be Better';
      case 1:
        return 'Needs Improvement';
      default:
        return 'Tap a star to rate your stay (1 - 5 stars)';
    }
  }

  String get ratingEmoji {
    switch (rating) {
      case 5:
        return '🤩';
      case 4:
        return '😊';
      case 3:
        return '🙂';
      case 2:
        return '😐';
      case 1:
        return '😞';
      default:
        return '⭐';
    }
  }

  void _toggleTag(String tag) {
    setState(() {
      if (selectedTags.contains(tag)) {
        selectedTags.remove(tag);
      } else {
        selectedTags.add(tag);
      }
    });
  }

  Future<void> _submitReview() async {
    if (rating <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: const Row(
            children: [
              Icon(Icons.star_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Please tap a star to choose your rating (1 to 5 stars)!',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => isSubmitting = true);

    String comment = reviewCtrl.text.trim();
    if (selectedTags.isNotEmpty) {
      final tagsString = selectedTags.join(', ');
      comment = comment.isEmpty ? tagsString : '$comment\n\nHighlights: $tagsString';
    }
    if (comment.isEmpty) {
      comment = 'Wonderful stay! Highly recommended.';
    }

    final user = ApiService.currentUser;
    final body = {
      'hotelId': 1,
      'customerId': user?.id,
      'guestName': user?.fullName.isNotEmpty == true ? user!.fullName : (widget.booking.guestName.isNotEmpty ? widget.booking.guestName : 'Verified Guest'),
      'rating': rating,
      'comment': comment,
      'stayType': 'Verified Stay',
      'location': widget.booking.locationAddress.isNotEmpty ? widget.booking.locationAddress : 'Kandal, Cambodia',
    };

    try {
      final res = await http.post(
        Uri.parse('${ApiClient.baseUrl}/reviews'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('reviewed_booking_${widget.booking.id}', true);
        await prefs.setBool('dismissed_review_${widget.booking.id}', true);

        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          widget.onReviewed?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text('Thank you! Your review has been published ⭐', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw Exception('Server returned ${res.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not submit review: $e')),
        );
      }
    }
  }

  Future<void> _dismissLater() async {
    StayReviewDialog.dismissedInThisSession.add(widget.booking.id);
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  void dispose() {
    reviewCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roomName = widget.booking.roomName ?? widget.booking.title;
    final imageUrl = RoomService.safeWebUrl(widget.booking.imageUrl);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131D32) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.18),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Header Banner with Sunset Amber Gradient
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 110,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 22),
                        onPressed: _dismissLater,
                      ),
                    ),
                    // Floating Emoji Badge
                    Positioned(
                      top: 48,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? const Color(0xFF131D32) : Colors.white,
                          border: Border.all(
                            color: const Color(0xFFF59E0B),
                            width: 3.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            ratingEmoji,
                            style: const TextStyle(fontSize: 42),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 38),

                // Question & Room Chip
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Column(
                    children: [
                      // Room Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: imageUrl.isNotEmpty
                                  ? Image.network(imageUrl, width: 20, height: 20, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.bed, size: 14, color: Color(0xFFF59E0B)))
                                  : const Icon(Icons.bed, size: 14, color: Color(0xFFF59E0B)),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                roomName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Text(
                        'How was your stay?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your review helps us make your next stay at Boss_Heng Luxury Hotel even more wonderful!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                          height: 1.35,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Interactive 5 Glowing Stars
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (idx) {
                          final starNum = idx + 1;
                          final isFilled = starNum <= rating;
                          return GestureDetector(
                            onTap: () => setState(() => rating = starNum),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                isFilled ? Icons.star_rounded : Icons.star_border_rounded,
                                size: 40,
                                color: isFilled ? const Color(0xFFF59E0B) : (isDark ? const Color(0xFF475569) : Colors.grey.shade300),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ratingLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF59E0B),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Quick Feedback Tags
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'What did you like the most?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: quickTags.map((tag) {
                          final isSelected = selectedTags.contains(tag);
                          return FilterChip(
                            label: Text(tag),
                            selected: isSelected,
                            onSelected: (_) => _toggleTag(tag),
                            selectedColor: const Color(0xFFFEF3C7),
                            checkmarkColor: const Color(0xFFB45309),
                            backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected
                                  ? const Color(0xFFB45309)
                                  : (isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade700),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isSelected
                                    ? const Color(0xFFF59E0B)
                                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 14),

                      // Comment Textarea
                      TextField(
                        controller: reviewCtrl,
                        maxLines: 3,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'We\'d love to hear more details about your stay...',
                          hintStyle: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400,
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDark ? const Color(0xFF22314E) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDark ? const Color(0xFF22314E) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFF59E0B),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Action Buttons (Cancel / Later & Submit)
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 46,
                              child: OutlinedButton(
                                onPressed: _dismissLater,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                  ),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: Text(
                                  'Maybe Later',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: SizedBox(
                              height: 46,
                              child: ElevatedButton.icon(
                                onPressed: isSubmitting ? null : _submitReview,
                                icon: isSubmitting
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.send_rounded, size: 16),
                                label: Text(
                                  isSubmitting ? 'Submitting...' : 'Submit Review',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF006CE4),
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  shadowColor: const Color(0xFF006CE4).withValues(alpha: 0.4),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
