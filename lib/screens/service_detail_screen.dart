import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/service_model.dart';
import '../services/api_service.dart';
import 'booking_form_screen.dart';

class ServiceDetailScreen extends StatefulWidget {
  final ServiceModel service;

  const ServiceDetailScreen({super.key, required this.service});

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  bool _isDescriptionExpanded = false;
  bool _showAllReviewCategories = false;
  int _selectedSurroundingTab = 0; // 0 = Eat & Drink, 1 = Transportation, 2 = Attractions

  // Dynamic gallery photos from room data
  late final List<String> _galleryPhotos;

  @override
  void initState() {
    super.initState();
    if (widget.service.images.isNotEmpty) {
      _galleryPhotos = List<String>.from(widget.service.images);
    } else if (widget.service.imageUrl.isNotEmpty) {
      _galleryPhotos = [widget.service.imageUrl];
    } else {
      _galleryPhotos = [
        'https://images.unsplash.com/photo-1590490360182-c33d57733427?w=800',
      ];
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

  Widget _buildImageWidget(String url, {BoxFit fit = BoxFit.cover}) {
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
        height: 200,
        color: Colors.grey.shade100,
        child: const Center(child: Icon(Icons.hotel_rounded, size: 50, color: Colors.grey)),
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
    final double bookingScore = widget.service.rating > 0 ? widget.service.rating : 4.8;
    final int reviewCount = widget.service.reviewCount > 0 ? widget.service.reviewCount : 128;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.service.name,
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
                  // Room Type Badge
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.service.name,
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
                          const Icon(Icons.location_on, size: 16, color: Color(0xFF003580)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.35),
                                children: [
                                  TextSpan(
                                    text: widget.service.locationAddress.isNotEmpty
                                        ? '${widget.service.locationAddress}, ${widget.service.province}, Cambodia'
                                        : '#4&6, Street 148, Sangkat Phsar Kandal I, Daun Penh, Phnom Penh, Cambodia',
                                  ),
                                  const TextSpan(
                                    text: ' • Open in Maps ↗',
                                    style: TextStyle(color: Color(0xFF003580), fontWeight: FontWeight.bold),
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
                  const Text(
                    'Property highlights',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 82,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildHighlightCard(
                          icon: Icons.restaurant_menu_rounded,
                          title: 'Meal Plan',
                          subtitle: widget.service.foodType.isNotEmpty
                              ? widget.service.foodType
                              : 'Breakfast included',
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
            const Divider(height: 36, thickness: 1, color: Color(0xFFF1F5F9)),

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
                          color: const Color(0xFF003580),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          bookingScore.toStringAsFixed(1),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bookingScore >= 4.8 ? 'Wonderful' : (bookingScore >= 4.5 ? 'Superb' : (bookingScore >= 4.0 ? 'Very Good' : 'Good')),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            'See $reviewCount detailed reviews >',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF0284C7), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Rating Bars
                  _buildRatingBar('Cleanliness', 8.7),
                  _buildRatingBar('Comfort', 8.7),
                  _buildRatingBar('Facilities', 8.5),
                  _buildRatingBar('Location', 9.3),
                  if (_showAllReviewCategories) ...[
                    _buildRatingBar('Staff', 9.1),
                    _buildRatingBar('Value for money', 8.6),
                    _buildRatingBar('WiFi', 7.7),
                  ],

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
                        style: const TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Text(
                    'Guests who stayed here loved',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '"The rooftop pool and sunset view over the Mekong were unforgettable. Breakfast was fresh with great variety!"',
                          style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13, color: Color(0xFF334155)),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '— Nicholas, United Kingdom (Couple)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 36, thickness: 1, color: Color(0xFFF1F5F9)),

            // 5. Property Surroundings & Tabs (Screenshot 3)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Property surroundings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 12),

                  // Mini Map Container (Clickable to open in Google Maps)
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
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFF1E293B),
                        image: const DecorationImage(
                          image: NetworkImage('https://images.unsplash.com/photo-1524661135-423995f22d0b?w=600'),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.black.withValues(alpha: 0.4),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on, color: Color(0xFFEF4444), size: 30),
                              const SizedBox(height: 2),
                              Text(
                                widget.service.locationAddress.isNotEmpty
                                    ? widget.service.locationAddress
                                    : 'Phsar Kandal I, Daun Penh',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF003580),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.map, color: Colors.white, size: 12),
                                    SizedBox(width: 4),
                                    Text(
                                      'Open in Google Maps ↗',
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      const Icon(Icons.directions_bus_filled_outlined, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        '4,100 ft from Sorya Bus Station',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Tab Bar: Eat & drink, Transportation, Attractions
                  Row(
                    children: [
                      _buildSurroundingTab('Eat and drink', 0, Icons.restaurant_rounded),
                      _buildSurroundingTab('Transportation', 1, Icons.directions_transit_rounded),
                      _buildSurroundingTab('Attractions', 2, Icons.attractions_rounded),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // List of Surrounding Spots based on Tab
                  ..._buildSurroundingItems(),
                ],
              ),
            ),
            const Divider(height: 36, thickness: 1, color: Color(0xFFF1F5F9)),

            // 6. Most Popular Facilities (Screenshot 4)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Most Popular Facilities',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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
                  const Text(
                    'See all facilities >',
                    style: TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Divider(height: 36, thickness: 1, color: Color(0xFFF1F5F9)),

            // 7. Description & Property Policies (Screenshot 5)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.service.description.isNotEmpty
                        ? widget.service.description
                        : 'Located next to Kandal Market, this property offers premier luxury accommodations in the heart of the Riverside area. At the rooftop, it features 2 outdoor spa swimming pools as well as a panoramic sky restaurant and bar where guests can enjoy gourmet Khmer and international dining.',
                    maxLines: _isDescriptionExpanded ? null : 3,
                    overflow: _isDescriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155), height: 1.45),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isDescriptionExpanded = !_isDescriptionExpanded;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        _isDescriptionExpanded ? 'Read less' : 'Read more',
                        style: const TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
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

      // 8. Sticky Bottom Booking Bar (Screenshots 1, 2, 3, 5)
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
          child: Row(
            children: [
              // Free Cancellation + Price
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.restaurant_rounded, color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669), size: 15),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            widget.service.foodType.isNotEmpty
                                ? widget.service.foodType
                                : 'Breakfast included',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'US\$${widget.service.price.toStringAsFixed(0)} / night',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'You won\'t be charged yet',
                      style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),

              // Blue "Select rooms" Button (matching screenshot)
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingFormScreen(service: widget.service),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006CE4), // Booking.com royal blue
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Select rooms',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
    return Container(
      width: 170,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF0284C7), size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
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

  Widget _buildRatingBar(String label, double score) {
    final double percent = (score / 10.0).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
              Text(score.toStringAsFixed(1), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: const Color(0xFFE2E8F0),
              color: const Color(0xFF003580),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurroundingTab(String title, int index, IconData icon) {
    final isSelected = _selectedSurroundingTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSurroundingTab = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF003580) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : const Color(0xFF475569)),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSurroundingItems() {
    if (_selectedSurroundingTab == 0) {
      return [
        _buildSurroundingRow('Pepper Lunch', '15 min (4,300 ft)', Icons.directions_walk_rounded),
        _buildSurroundingRow('Space Hair Salon and Bar', '2 min (780 ft)', Icons.directions_walk_rounded),
        _buildSurroundingRow('Corner 136 Bar', '3 min (880 ft)', Icons.directions_walk_rounded),
        _buildSurroundingRow('Loco Bar', '4 min (1,200 ft)', Icons.directions_walk_rounded),
      ];
    } else if (_selectedSurroundingTab == 1) {
      return [
        _buildSurroundingRow('Sorya Bus Station', '8 min (2,400 ft)', Icons.directions_walk_rounded),
        _buildSurroundingRow('Phnom Penh Train Station', '12 min (1.2 mi)', Icons.directions_car_rounded),
        _buildSurroundingRow('Phnom Penh Airport (PNH)', '35 min (6.2 mi)', Icons.directions_car_rounded),
      ];
    } else {
      return [
        _buildSurroundingRow('Royal Palace & Silver Pagoda', '6 min (1,800 ft)', Icons.directions_walk_rounded),
        _buildSurroundingRow('National Museum of Cambodia', '5 min (1,500 ft)', Icons.directions_walk_rounded),
        _buildSurroundingRow('Wat Phnom Historical Hill', '10 min (2,900 ft)', Icons.directions_walk_rounded),
        _buildSurroundingRow('Riverside Night Market', '3 min (900 ft)', Icons.directions_walk_rounded),
      ];
    }
  }

  Widget _buildSurroundingRow(String name, String distance, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
            ),
          ),
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                distance,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFacilityItem(IconData icon, String title) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 64) / 2,
      child: Row(
        children: [
          Icon(icon, size: 17, color: const Color(0xFF0F172A)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyLink(String title, IconData trailingIcon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          ),
          Icon(trailingIcon, size: 18, color: const Color(0xFF64748B)),
        ],
      ),
    );
  }
}
