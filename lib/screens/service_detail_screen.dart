import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/service_model.dart';
import '../services/api_service.dart';
import '../widgets/interactive_hotel_map.dart';
import '../widgets/hotel_guest_reviews_card.dart';
import '../widgets/hotel_surroundings_widget.dart';
import '../widgets/hotel_rating_breakdown_widget.dart';
import 'room_selection_screen.dart';

class ServiceDetailScreen extends StatefulWidget {
  final ServiceModel service;

  const ServiceDetailScreen({super.key, required this.service});

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  bool _isDescriptionExpanded = false;
  bool _showAllReviewCategories = false;
  int _selectedGuestReviewIndex = 0;

  static const List<Map<String, dynamic>> _topGuestReviews = [
    {
      'author': 'Sophea Pich',
      'location': 'Phnom Penh, Cambodia',
      'tag': 'Family Stay',
      'rating': 5.0,
      'date': '2 days ago',
      'comment': 'Booking directly through the app was super fast and seamless! The room was sparkling clean, staff was very attentive, and the breakfast buffet was fresh with great variety.',
    },
    {
      'author': 'Nicholas M.',
      'location': 'United Kingdom',
      'tag': 'Couple',
      'rating': 5.0,
      'date': '5 days ago',
      'comment': 'The rooftop pool and peaceful sunset view along the river were unforgettable. Most comfortable bed I have ever slept in, and contactless QR check-in made arrival a breeze!',
    },
    {
      'author': 'Dara Chan',
      'location': 'Kandal, Cambodia',
      'tag': 'Solo Traveler',
      'rating': 5.0,
      'date': '1 week ago',
      'comment': 'Exceptional 5-star hospitality! Super fast WiFi, pristine bathroom, quiet climate AC, and delicious authentic Khmer dishes. Best hotel stay in the area!',
    },
    {
      'author': 'Elena & David',
      'location': 'France',
      'tag': 'Couple',
      'rating': 5.0,
      'date': '2 weeks ago',
      'comment': 'Outstanding experience from booking on the app to check-out. The customer service was world-class, breathtaking river views, and five-star cleanliness throughout.',
    },
  ];

  // Dynamic reviews loaded from database API (all reviews, newest first)
  late List<Map<String, dynamic>> _dynamicReviews;
  double? _dynamicAverageRating;
  int? _dynamicReviewCount;

  // Dynamic gallery photos from room data
  late final List<String> _galleryPhotos;

  @override
  void initState() {
    super.initState();
    _dynamicReviews = List.from(_topGuestReviews);
    _loadHotelReviews();
    if (widget.service.images.isNotEmpty) {
      _galleryPhotos = widget.service.images.where((s) => s.trim().isNotEmpty).toList();
    } else if (widget.service.imageUrl.trim().isNotEmpty) {
      _galleryPhotos = [widget.service.imageUrl.trim()];
    } else {
      _galleryPhotos = [];
    }
  }

  Future<void> _loadHotelReviews() async {
    try {
      final res = await http.get(Uri.parse('${ApiService.baseUrl}/reviews'));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (data.isNotEmpty) {
          // Backend returns reviews newest-first (createdAt DESC).
          // Map all reviews directly so the latest review (e.g. #8 sokleng) is at index 0
          final mapped = data.map((r) {
            final double rating = (r['rating'] as num?)?.toDouble() ?? 5.0;
            final String name = r['guestName']?.toString().isNotEmpty == true
                ? r['guestName'].toString()
                : (r['customer']?['fullName']?.toString() ?? 'Verified Guest');
            final String loc = r['location']?.toString().isNotEmpty == true
                ? r['location'].toString()
                : 'Cambodia';
            final String tag = r['stayType']?.toString().isNotEmpty == true
                ? r['stayType'].toString()
                : 'Verified Stay';
            final String comment = r['comment']?.toString().isNotEmpty == true
                ? r['comment'].toString()
                : 'Wonderful stay!';
            final String dateStr = r['createdAt']?.toString().isNotEmpty == true
                ? _formatReviewDate(r['createdAt'].toString())
                : 'Recently';
            return {
              'id': r['id'],
              'author': name,
              'location': loc,
              'tag': tag,
              'rating': rating,
              'date': dateStr,
              'comment': comment,
            };
          }).toList();

          double totalRating = 0.0;
          for (final item in mapped) {
            totalRating += (item['rating'] as double? ?? 5.0);
          }
          final double avg = mapped.isNotEmpty ? (totalRating / mapped.length) : 4.8;

          if (mounted && mapped.isNotEmpty) {
            setState(() {
              _dynamicReviews = mapped;
              _dynamicAverageRating = double.parse(avg.toStringAsFixed(1));
              _dynamicReviewCount = mapped.length;
              if (_selectedGuestReviewIndex >= _dynamicReviews.length) {
                _selectedGuestReviewIndex = 0;
              }
            });
            return;
          }
        }
      }
    } catch (_) {}
  }

  String _formatReviewDate(String rawDate) {
    try {
      final dt = DateTime.parse(rawDate);
      final diff = DateTime.now().difference(dt);
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return 'Recently';
    }
  }

  Uint8List _decodeBase64(String dataUrl) {
    try {
      final comma = dataUrl.indexOf(',');
      final b64 = (comma != -1) ? dataUrl.substring(comma + 1) : dataUrl;
      return base64Decode(b64);
    } catch (_) {
      return Uint8List(0);
    }
  }

  static String _resolveSafeWebUrl(String raw) {
    if (raw.isEmpty) return raw;
    if (raw.startsWith('data:image')) return raw;
    if (raw.contains('wsrv.nl')) return raw;
    if (kIsWeb || raw.contains('pinimg.com')) {
      if (raw.startsWith('http://') || raw.startsWith('https://')) {
        return 'https://wsrv.nl/?url=${Uri.encodeComponent(raw)}';
      }
    }
    return raw;
  }

  Widget _buildTierBadge(String? tier, bool isDark) {
    final upper = (tier ?? 'STANDARD').toUpperCase();
    Color bg;
    Color border;
    Color fg;
    IconData icon;
    String label;

    switch (upper) {
      case 'DELUXE':
        bg = isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF);
        border = isDark ? const Color(0xFF3B82F6) : const Color(0xFF93C5FD);
        fg = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
        icon = Icons.star_rounded;
        label = 'Deluxe Room';
        break;
      case 'PREMIUM':
      case 'VIP':
        bg = isDark ? const Color(0xFF4C1D95).withValues(alpha: 0.35) : const Color(0xFFFAF5FF);
        border = isDark ? const Color(0xFFA855F7) : const Color(0xFFD8B4FE);
        fg = isDark ? const Color(0xFFD8B4FE) : const Color(0xFF7E22CE);
        icon = Icons.workspace_premium_rounded;
        label = 'Premium Room';
        break;
      case 'STANDARD':
      default:
        bg = isDark ? const Color(0xFF064E3B).withValues(alpha: 0.35) : const Color(0xFFECFDF5);
        border = isDark ? const Color(0xFF10B981) : const Color(0xFFA7F3D0);
        fg = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857);
        icon = Icons.verified_rounded;
        label = 'Standard Room';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWidget(String url, {BoxFit fit = BoxFit.cover}) {
    if (url.trim().isEmpty) {
      return Container(
        color: const Color(0xFF1E293B),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bed_outlined, color: Colors.grey.shade400, size: 44),
              const SizedBox(height: 8),
              Text(
                'No photo uploaded',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    if (url.startsWith('data:image')) {
      final bytes = _decodeBase64(url);
      if (bytes.isNotEmpty) {
        return Image.memory(
          bytes,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey.shade200,
            child: const Icon(Icons.broken_image, color: Colors.grey),
          ),
        );
      }
    }

    final safeUrl = _resolveSafeWebUrl(url);

    return Image.network(
      safeUrl,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        // If first attempt failed (e.g. CORS block), retry with wsrv.nl proxy
        if (!safeUrl.startsWith('https://wsrv.nl/') && (url.startsWith('http://') || url.startsWith('https://'))) {
          return Image.network(
            'https://wsrv.nl/?url=${Uri.encodeComponent(url)}',
            fit: fit,
            errorBuilder: (ctx, err, trace) => Container(
              color: Colors.grey.shade200,
              child: const Icon(Icons.broken_image, color: Colors.grey),
            ),
          );
        }
        return Container(
          color: Colors.grey.shade200,
          child: const Icon(Icons.broken_image, color: Colors.grey),
        );
      },
    );
  }

  void _openPhotoViewer(int initialIndex) {
    showDialog(
      context: context,
      builder: (ctx) {
        int currentIndex = initialIndex;
        final pageController = PageController(initialPage: initialIndex);

        return StatefulBuilder(
          builder: (context, setViewerState) {
            return Dialog.fullscreen(
              backgroundColor: const Color(0xFF0A0F1D),
              child: Stack(
                children: [
                  // 1. Swipeable Fullscreen Images
                  PageView.builder(
                    controller: pageController,
                    itemCount: _galleryPhotos.length,
                    onPageChanged: (idx) {
                      setViewerState(() {
                        currentIndex = idx;
                      });
                    },
                    itemBuilder: (context, idx) {
                      final url = _galleryPhotos[idx];
                      return InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 3.5,
                        child: Center(
                          child: _buildImageWidget(url, fit: BoxFit.contain),
                        ),
                      );
                    },
                  ),

                  // 2. Top Navigation Bar: Dynamic Real Counter Badge ("1 / 10") & Close Button
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 10,
                    left: 16,
                    right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Real dynamic image counter: e.g. "1 / 10"
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.photo_library_outlined, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                '${currentIndex + 1} / ${_galleryPhotos.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Close Button
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3. Left Navigation Arrow Button
                  if (_galleryPhotos.length > 1)
                    Positioned(
                      left: 14,
                      top: 0,
                      bottom: 80,
                      child: Center(
                        child: AnimatedOpacity(
                          opacity: currentIndex > 0 ? 1.0 : 0.25,
                          duration: const Duration(milliseconds: 200),
                          child: GestureDetector(
                            onTap: currentIndex > 0
                                ? () {
                                    pageController.previousPage(
                                      duration: const Duration(milliseconds: 280),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                : null,
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white30, width: 1.5),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 10),
                                ],
                              ),
                              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 4. Right Navigation Arrow Button
                  if (_galleryPhotos.length > 1)
                    Positioned(
                      right: 14,
                      top: 0,
                      bottom: 80,
                      child: Center(
                        child: AnimatedOpacity(
                          opacity: currentIndex < _galleryPhotos.length - 1 ? 1.0 : 0.25,
                          duration: const Duration(milliseconds: 200),
                          child: GestureDetector(
                            onTap: currentIndex < _galleryPhotos.length - 1
                                ? () {
                                    pageController.nextPage(
                                      duration: const Duration(milliseconds: 280),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                : null,
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white30, width: 1.5),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 10),
                                ],
                              ),
                              child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 5. Bottom Thumbnail Strip (Quick Tap to any photo)
                  if (_galleryPhotos.length > 1)
                    Positioned(
                      bottom: 24,
                      left: 0,
                      right: 0,
                      child: SizedBox(
                        height: 58,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: _galleryPhotos.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final isSel = idx == currentIndex;
                            return GestureDetector(
                              onTap: () {
                                pageController.animateToPage(
                                  idx,
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeInOut,
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSel ? const Color(0xFFF59E0B) : Colors.white24,
                                    width: isSel ? 3 : 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: _buildImageWidget(_galleryPhotos[idx], fit: BoxFit.cover),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPhotoMosaic() {
    if (_galleryPhotos.isEmpty) {
      return Container(
        height: 220,
        color: const Color(0xFF1E293B),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bed_outlined, size: 54, color: Colors.grey.shade400),
              const SizedBox(height: 10),
              Text(
                'No photo uploaded',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final total = _galleryPhotos.length;

    Widget content;

    if (total == 1) {
      content = GestureDetector(
        onTap: () => _openPhotoViewer(0),
        child: SizedBox(
          height: 220,
          width: double.infinity,
          child: _buildImageWidget(_galleryPhotos[0]),
        ),
      );
    } else if (total == 2) {
      content = SizedBox(
        height: 180,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _openPhotoViewer(0),
                child: SizedBox(height: 180, child: _buildImageWidget(_galleryPhotos[0])),
              ),
            ),
            const SizedBox(width: 3),
            Expanded(
              child: GestureDetector(
                onTap: () => _openPhotoViewer(1),
                child: SizedBox(height: 180, child: _buildImageWidget(_galleryPhotos[1])),
              ),
            ),
          ],
        ),
      );
    } else if (total == 3) {
      content = Column(
        children: [
          GestureDetector(
            onTap: () => _openPhotoViewer(0),
            child: SizedBox(height: 140, width: double.infinity, child: _buildImageWidget(_galleryPhotos[0])),
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 95,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openPhotoViewer(1),
                    child: SizedBox(height: 95, child: _buildImageWidget(_galleryPhotos[1])),
                  ),
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openPhotoViewer(2),
                    child: SizedBox(height: 95, child: _buildImageWidget(_galleryPhotos[2])),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else if (total == 4) {
      content = Column(
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _openPhotoViewer(0),
                  child: SizedBox(height: 120, child: _buildImageWidget(_galleryPhotos[0])),
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: GestureDetector(
                  onTap: () => _openPhotoViewer(1),
                  child: SizedBox(height: 120, child: _buildImageWidget(_galleryPhotos[1])),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _openPhotoViewer(2),
                  child: SizedBox(height: 120, child: _buildImageWidget(_galleryPhotos[2])),
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: GestureDetector(
                  onTap: () => _openPhotoViewer(3),
                  child: SizedBox(height: 120, child: _buildImageWidget(_galleryPhotos[3])),
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      // 5 or more photos (Dynamic real +N count on the 5th tile)
      final remainingCount = total - 4; // e.g. 10 photos -> shows +6 more photos!

      content = Column(
        children: [
          // Top Row (2 photos)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _openPhotoViewer(0),
                  child: SizedBox(height: 140, child: _buildImageWidget(_galleryPhotos[0])),
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: GestureDetector(
                  onTap: () => _openPhotoViewer(1),
                  child: SizedBox(height: 140, child: _buildImageWidget(_galleryPhotos[1])),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),

          // Bottom Row (3 photos + dynamic count on the 3rd)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _openPhotoViewer(2),
                  child: SizedBox(height: 95, child: _buildImageWidget(_galleryPhotos[2])),
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: GestureDetector(
                  onTap: () => _openPhotoViewer(3),
                  child: SizedBox(height: 95, child: _buildImageWidget(_galleryPhotos[3])),
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: GestureDetector(
                  onTap: () => _openPhotoViewer(4),
                  child: SizedBox(
                    height: 95,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildImageWidget(_galleryPhotos[4]),
                        if (total > 5)
                          Container(
                            color: Colors.black.withValues(alpha: 0.60),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '+$remainingCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const Text(
                                    'photos',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: content,
          ),
          // Total photos badge in bottom-right corner of mosaic
          if (total > 1)
            Positioned(
              bottom: 10,
              right: 10,
              child: GestureDetector(
                onTap: () => _openPhotoViewer(0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white30, width: 1),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.photo_library, color: Colors.white, size: 13),
                      const SizedBox(width: 5),
                      Text(
                        '$total Photos',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double bookingScore = _dynamicAverageRating ?? (widget.service.rating > 0 ? widget.service.rating : 4.8);
    final int reviewCount = _dynamicReviewCount ?? (widget.service.reviewCount > 0 ? widget.service.reviewCount : 8);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.service.cleanName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          ValueListenableBuilder<Set<int>>(
            valueListenable: ApiService.favoriteNotifier,
            builder: (context, favs, _) {
              final isFav = favs.contains(widget.service.id);
              return IconButton(
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? const Color(0xFFEF4444) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF0F172A)),
                  size: 24,
                ),
                onPressed: () async {
                  final added = await ApiService.toggleFavorite(widget.service.id);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(added ? 'Saved to Favorites!' : 'Removed from Favorites.'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.share_outlined, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A), size: 23),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Property link copied to clipboard!')),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Hotel / Room Title & Star Badge Row (Screenshot 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Room Type & Tier Badges
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isDark ? const Color(0xFF2563EB) : const Color(0xFF93C5FD)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.hotel_rounded, size: 13, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
                            const SizedBox(width: 5),
                            Text(
                              widget.service.roomTypeDisplay,
                              style: TextStyle(color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8), fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      _buildTierBadge(widget.service.roomTier, isDark),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.service.cleanName,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Blue Review Score Box (like pic 1)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1D4ED8) : const Color(0xFF003580),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          bookingScore.toStringAsFixed(1),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Dynamic Stars + Thumbs up (Genius removed)
                  Row(
                    children: [
                      ...List.generate(
                        widget.service.starRating.clamp(1, 5),
                        (index) => const Icon(Icons.star_rounded, size: 18, color: Color(0xFFF59E0B)),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.thumb_up, size: 10, color: Color(0xFFB45309)),
                            SizedBox(width: 2),
                            Icon(Icons.add, size: 10, color: Color(0xFFB45309)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Address & Location highlight (Opens Real Google Maps Link)
                  InkWell(
                    onTap: () async {
                      final url = widget.service.mapUrl.isNotEmpty
                          ? widget.service.mapUrl
                          : 'https://maps.google.com/?q=${Uri.encodeComponent('${widget.service.name}, ${widget.service.province}')}';
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, size: 16, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF003580)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569), fontSize: 13, height: 1.35),
                                children: [
                                  TextSpan(
                                    text: widget.service.locationAddress.isNotEmpty
                                        ? (widget.service.locationAddress.toLowerCase().contains(widget.service.province.toLowerCase())
                                            ? '${widget.service.locationAddress}, Cambodia'
                                            : '${widget.service.locationAddress}, ${widget.service.province}, Cambodia')
                                        : 'National Road 2, Ta Khmau, Kandal, Cambodia',
                                  ),
                                  TextSpan(
                                    text: ' • Open in Google Maps',
                                    style: TextStyle(
                                      color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1A73E8),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Mosaic Photo Grid (Dynamic Real Photos, Adaptive Layout & Dynamic Count)
            _buildPhotoMosaic(),
            const SizedBox(height: 20),

            // 3. Property Highlights (Screenshot 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Property highlights',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 82,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildHighlightCard(
                          icon: widget.service.hasBreakfast
                              ? Icons.restaurant_menu_rounded
                              : Icons.no_meals_rounded,
                          title: 'Meal Plan',
                          subtitle: widget.service.hasBreakfast
                              ? (widget.service.foodType.isNotEmpty && !widget.service.foodType.toLowerCase().contains('room only')
                                  ? widget.service.foodType
                                  : 'Breakfast included')
                              : 'Room only',
                        ),
                        _buildHighlightCard(
                          icon: Icons.wifi_rounded,
                          title: 'Free Wifi',
                          subtitle: 'High-speed fiber',
                        ),
                        _buildHighlightCard(
                          icon: Icons.pool_rounded,
                          title: 'Swimming Pool',
                          subtitle: 'Rooftop infinity pool',
                        ),
                        _buildHighlightCard(
                          icon: Icons.local_parking_rounded,
                          title: 'Free Parking',
                          subtitle: 'Secure private parking',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 36, thickness: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),

            // 4. Review Breakdown & Progress Bars (Screenshot 2)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2563EB) : const Color(0xFF003580),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          bookingScore.toStringAsFixed(1),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                bookingScore >= 4.8 ? 'Wonderful' : (bookingScore >= 4.5 ? 'Superb' : (bookingScore >= 4.0 ? 'Very Good' : 'Good')),
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)),
                              ),
                              const SizedBox(width: 6),
                              ...List.generate(5, (i) {
                                final double fill = (bookingScore - i).clamp(0.0, 1.0);
                                return Icon(
                                  fill >= 0.75
                                      ? Icons.star_rounded
                                      : (fill >= 0.25 ? Icons.star_half_rounded : Icons.star_border_rounded),
                                  color: const Color(0xFFF59E0B),
                                  size: 15,
                                );
                              }),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'See $reviewCount detailed reviews >',
                            style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF0284C7), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Rating Bars
                  HotelRatingBreakdownWidget(
                    ratingScores: _showAllReviewCategories
                        ? const {
                            'Cleanliness': 8.7,
                            'Comfort': 8.7,
                            'Facilities': 8.5,
                            'Location': 9.3,
                            'Staff': 9.1,
                            'Value for money': 8.6,
                            'WiFi': 7.7,
                          }
                        : const {
                            'Cleanliness': 8.7,
                            'Comfort': 8.7,
                            'Facilities': 8.5,
                            'Location': 9.3,
                          },
                  ),

                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showAllReviewCategories = !_showAllReviewCategories;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _showAllReviewCategories ? 'Show less' : 'Show more categories',
                        style: TextStyle(color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF0284C7), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  HotelGuestReviewsCard(
                    reviews: _dynamicReviews.isNotEmpty ? _dynamicReviews : _topGuestReviews,
                    selectedIndex: _selectedGuestReviewIndex,
                    onIndexChanged: (idx) => setState(() => _selectedGuestReviewIndex = idx),
                    onReviewSubmitted: _loadHotelReviews,
                    hotelName: widget.service.locationName.isNotEmpty ? widget.service.locationName : widget.service.name,
                    hotelAddress: widget.service.locationAddress.isNotEmpty
                        ? widget.service.locationAddress
                        : 'National Road 2, Ta Khmau, Kandal',
                  ),
                ],
              ),
            ),
            Divider(height: 36, thickness: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),

            // 5. Property Surroundings & Tabs (Screenshot 3)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Property surroundings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 12),

                  // Real Interactive Map (Touch, Pan, Zoom, Fullscreen, Open in Google Maps)
                  InteractiveHotelMap(
                    mapUrl: widget.service.mapUrl,
                    hotelName: widget.service.locationName.isNotEmpty ? widget.service.locationName : widget.service.name,
                    locationAddress: widget.service.locationAddress.isNotEmpty
                        ? widget.service.locationAddress
                        : 'National Road 2, Ta Khmau, Kandal',
                    height: 200,
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      const Icon(Icons.directions_bus_filled_outlined, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        '4,100 ft from Sorya Bus Station',
                        style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Tab Bar & Nearby Spots
                  const HotelSurroundingsWidget(),
                ],
              ),
            ),
            Divider(height: 36, thickness: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),

            // 6. Most Popular Facilities (Screenshot 4)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Most Popular Facilities',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      _buildFacilityItem(Icons.pool_rounded, 'Indoor swimming pool'),
                      _buildFacilityItem(Icons.smoke_free_rounded, 'Non-smoking rooms'),
                      _buildFacilityItem(Icons.room_service_rounded, 'Room service'),
                      _buildFacilityItem(Icons.fitness_center_rounded, 'Fitness center'),
                      _buildFacilityItem(Icons.wifi_rounded, 'High-speed Internet'),
                      _buildFacilityItem(Icons.coffee_maker_rounded, 'Tea/Coffee maker'),
                      _buildFacilityItem(Icons.local_bar_rounded, 'Rooftop Bar'),
                      _buildFacilityItem(Icons.ac_unit_rounded, 'Climate AC'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'See all facilities >',
                    style: TextStyle(color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF0284C7), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
            Divider(height: 36, thickness: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),

            // 7. Description & Property Policies (Screenshot 5)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Description',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final rawDesc = widget.service.description.trim();
                      final String descText;
                      if (rawDesc.isNotEmpty && !rawDesc.startsWith('Spacious and luxury') && !rawDesc.startsWith('Comfortable room')) {
                        descText = '$rawDesc Located next to Kandal Market, this property offers premier luxury accommodations in the heart of the Riverside area. At the rooftop, it features 2 outdoor spa swimming pools as well as a panoramic sky restaurant and bar where guests can enjoy gourmet Khmer and international dining. Each elegantly appointed room includes premium king bedding, high-speed fiber-optic WiFi, smart 4K flat-screen TV, minibar, espresso coffee station, and a private en-suite bathroom with hot rain shower and designer organic toiletries. Guests can enjoy complimentary international breakfast buffet daily, rejuvenate at the full-service wellness spa, or maintain fitness at our 24-hour gym. 24/7 concierge and tour booking services are available at your convenience.';
                      } else {
                        descText = 'Located next to Kandal Market, this property offers premier luxury accommodations in the heart of the Riverside area. At the rooftop, it features 2 outdoor spa swimming pools as well as a panoramic sky restaurant and bar where guests can enjoy gourmet Khmer and international dining. Each elegantly appointed room includes premium king bedding, high-speed fiber-optic WiFi, smart 4K flat-screen TV, minibar, espresso coffee station, and a private en-suite bathroom with hot rain shower and designer organic toiletries. Guests can enjoy complimentary international breakfast buffet daily, rejuvenate at the full-service wellness spa, or maintain fitness at our 24-hour gym. 24/7 concierge and tour booking services are available at your convenience.';
                      }

                      final textStyle = TextStyle(
                        fontSize: 13.5,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                        height: 1.45,
                      );

                      final bool isLongText = descText.length > 150;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isDescriptionExpanded = !_isDescriptionExpanded;
                              });
                            },
                            child: Text(
                              descText,
                              maxLines: _isDescriptionExpanded ? null : 4,
                              overflow: _isDescriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                              style: textStyle,
                            ),
                          ),
                          if (isLongText) ...[
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _isDescriptionExpanded = !_isDescriptionExpanded;
                                });
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _isDescriptionExpanded ? 'See less' : 'See more',
                                      style: TextStyle(
                                        color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF0284C7),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      _isDescriptionExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                      size: 18,
                                      color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF0284C7),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  // Policy Links (Screenshot 5)
                  _buildPolicyLink('Property Policies', Icons.chevron_right_rounded),
                  _buildPolicyLink('Important details', Icons.chevron_right_rounded),
                  _buildPolicyLink('Preferred Partner Program', Icons.chevron_right_rounded),
                  _buildPolicyLink('Share property link', Icons.share_outlined),
                ],
              ),
            ),
            const SizedBox(height: 90), // Bottom padding for sticky action bar
          ],
        ),
      ),

      // 8. Sticky Bottom Booking Bar (Pic 2: No price first, Free cancellation + Select rooms)
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131D32) : Colors.white,
          border: isDark ? const Border(top: BorderSide(color: Color(0xFF22314E))) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Free Cancellation Header & Live Inventory Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check,
                        color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Free cancellation',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  if (widget.service.availableUnits <= 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Sold Out',
                        style: TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                "You won't be charged yet",
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 10),

              // Full-Width Blue "Select rooms" Button (Pic 2)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RoomSelectionScreen(service: widget.service),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006CE4), // Booking.com royal blue
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Select rooms',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 170,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.5) : const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF0284C7), size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacilityItem(IconData icon, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 64) / 2,
      child: Row(
        children: [
          Icon(icon, size: 17, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF0F172A)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyLink(String title, IconData trailingIcon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)),
          ),
          Icon(trailingIcon, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ],
      ),
    );
  }

}
