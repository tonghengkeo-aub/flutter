import 'package:flutter/material.dart';

class HotelRatingBreakdownWidget extends StatelessWidget {
  final Map<String, double> ratingScores;

  const HotelRatingBreakdownWidget({
    super.key,
    required this.ratingScores,
  });

  Widget _buildRatingBar(BuildContext context, String label, double score) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double percent = (score / 10.0).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                ),
              ),
              Text(
                score.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              color: isDark ? const Color(0xFF3B82F6) : const Color(0xFF003580),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: ratingScores.entries.map((e) {
        return _buildRatingBar(context, e.key, e.value);
      }).toList(),
    );
  }
}
