import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../services/api_service.dart';
import 'stay_review_dialog.dart';

class HotelGuestReviewsCard extends StatelessWidget {
  final List<Map<String, dynamic>> reviews;
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback onReviewSubmitted;
  final String hotelName;
  final String hotelAddress;

  const HotelGuestReviewsCard({
    super.key,
    required this.reviews,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.onReviewSubmitted,
    this.hotelName = 'Boss_Heng Luxury Hotel',
    this.hotelAddress = 'National Road 2, Ta Khmau, Kandal',
  });

  void _openReviewDialog(BuildContext context) {
    final fallbackBooking = BookingModel(
      id: 0,
      bookingCode: 'HOTEL-STAY',
      title: 'Luxury Hotel Room',
      providerName: hotelName,
      locationAddress: hotelAddress,
      bookingDate: 'Recent Stay',
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

    StayReviewDialog.show(
      context,
      fallbackBooking,
      onReviewed: onReviewSubmitted,
    );
  }

  List<Widget> _buildReviewHighlights(String comment, bool isDark) {
    final lower = comment.toLowerCase();
    final List<Map<String, dynamic>> detected = [];

    if (lower.contains('pool')) {
      detected.add({'icon': Icons.pool_rounded, 'label': 'Rooftop Pool'});
    }
    if (lower.contains('clean') || lower.contains('sparkling')) {
      detected.add({'icon': Icons.cleaning_services_rounded, 'label': 'Sparkling Clean'});
    }
    if (lower.contains('staff') || lower.contains('friendly') || lower.contains('service')) {
      detected.add({'icon': Icons.sentiment_very_satisfied_rounded, 'label': 'Friendly Staff'});
    }
    if (lower.contains('view') || lower.contains('sunset') || lower.contains('scenery')) {
      detected.add({'icon': Icons.landscape_rounded, 'label': 'Stunning View'});
    }
    if (lower.contains('breakfast') || lower.contains('food') || lower.contains('coffee')) {
      detected.add({'icon': Icons.restaurant_rounded, 'label': 'Delicious Food'});
    }
    if (lower.contains('quiet') || lower.contains('peaceful') || lower.contains('relax')) {
      detected.add({'icon': Icons.spa_rounded, 'label': 'Quiet & Relaxing'});
    }
    if (lower.contains('bed') || lower.contains('comfy') || lower.contains('comfort')) {
      detected.add({'icon': Icons.bed_rounded, 'label': 'Comfy Bed'});
    }
    if (lower.contains('wifi')) {
      detected.add({'icon': Icons.wifi_rounded, 'label': 'Fast WiFi'});
    }
    if (lower.contains('location') || lower.contains('convenient')) {
      detected.add({'icon': Icons.location_on_rounded, 'label': 'Prime Location'});
    }

    if (detected.isEmpty) {
      detected.add({'icon': Icons.thumb_up_alt_rounded, 'label': 'Top Recommendation'});
    }

    return detected.take(4).map((item) {
      return Container(
        margin: const EdgeInsets.only(right: 6, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF334155).withValues(alpha: 0.6) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item['icon'] as IconData, size: 12, color: const Color(0xFFF59E0B)),
            const SizedBox(width: 4),
            Text(
              item['label'] as String,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (reviews.isEmpty) return const SizedBox.shrink();

    final int safeIndex = selectedIndex < reviews.length ? selectedIndex : 0;
    final current = reviews[safeIndex];
    final String author = current['author'] as String? ?? 'Verified Guest';
    final String location = current['location'] as String? ?? 'Cambodia';
    final String tag = current['tag'] as String? ?? 'Couple';
    final String comment = current['comment'] as String? ?? 'Wonderful stay!';
    final double rating = (current['rating'] as num?)?.toDouble() ?? 5.0;
    final String date = current['date'] as String? ?? 'Recent';

    // Parse comment text vs tag lists cleanly
    final String trimmed = comment.trim();
    String quoteText = trimmed;
    final tagMatchCount = ['Helpful Staff', 'Sparkling Clean', 'Peaceful View', 'Comfy Bed', 'Great Food', 'Fast WiFi', 'Rooftop Pool']
        .where((t) => trimmed.contains(t))
        .length;
    if (trimmed.contains('Highlights:')) {
      final parts = trimmed.split('Highlights:');
      quoteText = parts[0].trim();
    } else if (tagMatchCount >= 2) {
      // It's purely a list of highlight emojis/tags
      quoteText = '';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Guests who stayed here loved',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // Write Review pill button
            InkWell(
              onTap: () => _openReviewDialog(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_note_rounded, size: 14, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8)),
                    const SizedBox(width: 3),
                    Text(
                      'Rate Stay',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Prev / Next switcher
            Row(
              children: [
                InkWell(
                  onTap: () {
                    final prev = (safeIndex - 1 + reviews.length) % reviews.length;
                    onIndexChanged(prev);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(3.5),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.chevron_left_rounded, size: 16, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  '${safeIndex + 1}/${reviews.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 3),
                InkWell(
                  onTap: () {
                    final next = (safeIndex + 1) % reviews.length;
                    onIndexChanged(next);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(3.5),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.chevron_right_rounded, size: 16, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Container(
            key: ValueKey('guest_review_${safeIndex}_$author'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withValues(alpha: 0.25) : const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: 5 Golden Stars + Normal Score Pill + Descriptor + Date
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 5 Golden Stars row
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (index) {
                        final double fill = (rating - index).clamp(0.0, 1.0);
                        return Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: Icon(
                            fill >= 0.75
                                ? Icons.star_rounded
                                : (fill >= 0.25 ? Icons.star_half_rounded : Icons.star_border_rounded),
                            color: const Color(0xFFF59E0B),
                            size: 16,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(width: 6),
                    // Normal compact score pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF003580),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Dynamic descriptor
                    Text(
                      rating >= 4.8
                          ? 'Exceptional'
                          : (rating >= 4.5
                              ? 'Superb'
                              : (rating >= 4.0
                                  ? 'Very Good'
                                  : (rating >= 3.0 ? 'Good' : 'Fair'))),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.verified_rounded, size: 12, color: Color(0xFF10B981)),
                    const Spacer(),
                    // Date pill
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                if (quoteText.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  // Review Quote Bubble
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.45) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.format_quote_rounded,
                          color: const Color(0xFF003580).withValues(alpha: 0.4),
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            quoteText,
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 13,
                              height: 1.4,
                              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                // Highlights Badges
                Wrap(
                  children: _buildReviewHighlights(comment, isDark),
                ),
                const SizedBox(height: 10),
                // Guest Profile Row
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF003580),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        author.isNotEmpty ? author[0].toUpperCase() : 'G',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            author,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Icon(Icons.place_outlined, size: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              const SizedBox(width: 2),
                              Text(
                                location,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
