import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/hotel_model.dart';
import '../services/room_service.dart';
import '../widgets/interactive_hotel_map.dart';

class HotelInfoScreen extends StatefulWidget {
  final HotelModel? hotel;

  const HotelInfoScreen({super.key, this.hotel});

  @override
  State<HotelInfoScreen> createState() => _HotelInfoScreenState();
}

class _HotelInfoScreenState extends State<HotelInfoScreen> {
  late Future<HotelModel> _hotelFuture;

  @override
  void initState() {
    super.initState();
    if (widget.hotel != null) {
      _hotelFuture = Future.value(widget.hotel);
    } else {
      _hotelFuture = RoomService.getDefaultHotel();
    }
  }

  Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  IconData _getFacilityIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('wifi')) return Icons.wifi_rounded;
    if (lower.contains('pool')) return Icons.pool_rounded;
    if (lower.contains('spa')) return Icons.spa_rounded;
    if (lower.contains('gym') || lower.contains('fitness')) return Icons.fitness_center_rounded;
    if (lower.contains('bar') || lower.contains('sky')) return Icons.local_bar_rounded;
    if (lower.contains('dining') || lower.contains('restaurant') || lower.contains('food')) return Icons.restaurant_rounded;
    if (lower.contains('shuttle') || lower.contains('airport') || lower.contains('transport')) return Icons.airport_shuttle_rounded;
    if (lower.contains('parking')) return Icons.local_parking_rounded;
    if (lower.contains('service') || lower.contains('24/7')) return Icons.room_service_rounded;
    if (lower.contains('coffee') || lower.contains('tea')) return Icons.coffee_rounded;
    if (lower.contains('ac') || lower.contains('climate')) return Icons.ac_unit_rounded;
    return Icons.check_circle_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      body: FutureBuilder<HotelModel>(
        future: _hotelFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF003580)));
          }

          final hotel = snapshot.data ??
              widget.hotel ??
              HotelModel(
                id: 1,
                name: 'Boss_Heng Luxury Hotel',
                description: 'Experience five-star luxury with riverside views and world-class Khmer hospitality.',
                address: 'National Road 2, Ta Khmau, Kandal',
                province: 'Kandal',
                phone: '023888999',
                email: 'info@bosshenghotel.com',
                rating: 4.9,
                mainImage: 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800',
                facilities: 'Free High-speed WiFi, Infinity Swimming Pool, Rooftop Sky Bar, Luxury Spa, Fitness Center, 24/7 Room Service, Airport Shuttle',
                status: 'ACTIVE',
              );

          return CustomScrollView(
            slivers: [
              // 1. App Bar with Hero Image & Hotel Branding
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: const Color(0xFF0F172A),
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Copied link for ${hotel.name}!')),
                        );
                      },
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        RoomService.safeWebUrl(hotel.mainImage),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: const Color(0xFF1E293B),
                          child: const Icon(Icons.hotel_rounded, size: 80, color: Colors.white38),
                        ),
                      ),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.25),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.85),
                            ],
                            stops: const [0.0, 0.4, 1.0],
                          ),
                        ),
                      ),
                      // Hotel Name & Stars at bottom of header
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                ...List.generate(
                                  hotel.starRating.clamp(1, 5),
                                  (index) => const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 18),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAB308),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${hotel.starRating}-STAR HOTEL',
                                    style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 10),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    hotel.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.verified, color: Color(0xFFEAB308), size: 22),
                              ],
                            ),
                            if (hotel.tagline.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                hotel.tagline,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Body Details
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick Action Bar: Call, Email, Map, Website
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF131D32) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? const Color(0xFF22314E) : const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildActionButton(
                              icon: Icons.phone_rounded,
                              label: 'Call',
                              color: const Color(0xFF059669),
                              onTap: () => _openUrl('tel:${hotel.phone}'),
                            ),
                            _buildActionDivider(isDark),
                            _buildActionButton(
                              icon: Icons.mail_rounded,
                              label: 'Email',
                              color: const Color(0xFF2563EB),
                              onTap: () => _openUrl('mailto:${hotel.email}'),
                            ),
                            _buildActionDivider(isDark),
                            _buildActionButton(
                              icon: Icons.map_rounded,
                              label: 'Directions',
                              color: const Color(0xFFDC2626),
                              onTap: () => _openUrl(hotel.mapUrl),
                            ),
                            if (hotel.website.isNotEmpty) ...[
                              _buildActionDivider(isDark),
                              _buildActionButton(
                                icon: Icons.language_rounded,
                                label: 'Website',
                                color: const Color(0xFF7C3AED),
                                onTap: () => _openUrl(hotel.website),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Check-in / Check-out Time Cards
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF131D32) : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: isDark ? const Color(0xFF22314E) : const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.5) : const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.login_rounded, color: Color(0xFF10B981), size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Check-in', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600)),
                                      Text(hotel.checkInTime, style: TextStyle(color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF131D32) : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: isDark ? const Color(0xFF22314E) : const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.5) : const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Check-out', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600)),
                                      Text(hotel.checkOutTime, style: TextStyle(color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Location & Address Card with Interactive Map Launcher
                      Text(
                        'Location & Surroundings',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF131D32) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? const Color(0xFF22314E) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InteractiveHotelMap(
                              mapUrl: hotel.mapUrl,
                              hotelName: hotel.name,
                              locationAddress: '${hotel.address}, ${hotel.province}',
                              height: 190,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Hotel Facilities & Amenities
                      Text(
                        'Hotel Facilities & Amenities',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: hotel.facilityList.map((facility) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF131D32) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isDark ? const Color(0xFF22314E) : const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_getFacilityIcon(facility), size: 16, color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF003580)),
                                const SizedBox(width: 6),
                                Text(
                                  facility,
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Hotel Description
                      Text(
                        'About The Hotel',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF131D32) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? const Color(0xFF22314E) : const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          hotel.description.isNotEmpty
                              ? hotel.description
                              : 'Experience five-star luxury with riverside views, an infinity pool overlooking the Mekong river, and world-class Khmer hospitality.',
                          style: TextStyle(fontSize: 13.5, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155), height: 1.5),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Hotel Policy & House Rules
                      if (hotel.policy.isNotEmpty) ...[
                        Text(
                          'Property Policies & Rules',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.verified_user_outlined, color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  hotel.policy,
                                  style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E), height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],

                      // Explore Rooms Button
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF2563EB) : const Color(0xFF003580),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('View Available Rooms & Suites', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionDivider(bool isDark) {
    return Container(
      height: 28,
      width: 1,
      color: isDark ? const Color(0xFF22314E) : const Color(0xFFE2E8F0),
    );
  }
}
