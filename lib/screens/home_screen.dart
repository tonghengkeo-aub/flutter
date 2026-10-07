import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/booking_model.dart';
import '../models/category_model.dart';
import '../models/hotel_model.dart';
import '../models/service_model.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';
import 'hotel_info_screen.dart';
import 'notification_screen.dart';
import 'service_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ServiceModel> allRooms = [];
  List<ServiceModel> services = [];
  List<CategoryModel> categories = [];
  HotelModel? hotel;
  BookingModel? upcomingBooking;
  int unreadNotifications = 0;
  bool isLoading = true;

  String selectedRoomType = 'ALL';
  int selectedCategoryId = 0; // 0 = All
  final searchController = TextEditingController();

  final PageController _bannerController = PageController();
  int _currentBannerIndex = 0;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _startBannerTimer();
  }

  List<ServiceModel> get newestRooms {
    final list = List<ServiceModel>.from(allRooms.isNotEmpty ? allRooms : services);
    list.sort((a, b) => b.id.compareTo(a.id));
    return list.take(5).toList();
  }

  void _startBannerTimer() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final bannerList = newestRooms;
      if (bannerList.length > 1 && _bannerController.hasClients) {
        final next = (_currentBannerIndex + 1) % bannerList.length;
        _bannerController.animateToPage(
          next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => isLoading = true);

    final cats = await ApiService.getCategories();
    final srvs = await ApiService.getServices();
    final upcomings = await ApiService.getUpcomingBookings();
    final unread = await ApiService.getUnreadNotificationCount();
    final hotelData = await RoomService.getDefaultHotel();

    if (mounted) {
      setState(() {
        categories = cats;
        allRooms = srvs;
        upcomingBooking = upcomings.isNotEmpty ? upcomings.first : null;
        unreadNotifications = unread;
        hotel = hotelData;
        isLoading = false;
      });
      _applyFilter();
    }
  }

  void _applyFilter() {
    final query = searchController.text.trim().toLowerCase();
    List<ServiceModel> list = List.from(allRooms);

    if (query.isNotEmpty) {
      list = list.where((r) =>
        r.name.toLowerCase().contains(query) ||
        r.description.toLowerCase().contains(query) ||
        r.categoryName.toLowerCase().contains(query) ||
        r.roomType.toLowerCase().contains(query) ||
        r.bedType.toLowerCase().contains(query) ||
        r.province.toLowerCase().contains(query)
      ).toList();
    }

    if (selectedRoomType != 'ALL') {
      list = list.where((r) => r.roomType.toUpperCase() == selectedRoomType.toUpperCase()).toList();
    }

    setState(() {
      services = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ApiService.currentUser;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user != null ? 'Hello, ${user.fullName.split(' ').first}' : 'Hello, Guest',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontWeight: FontWeight.w600),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => HotelInfoScreen(hotel: hotel)),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      hotel?.name.isNotEmpty == true ? hotel!.name : 'Boss_Heng Luxury Hotel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.verified, color: Color(0xFFEAB308), size: 16),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: ThemeService.isDarkMode ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: ThemeService.isDarkMode ? const Color(0xFF1D4ED8) : const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline, size: 10, color: ThemeService.isDarkMode ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
                        const SizedBox(width: 2),
                        Text(
                          'Hotel Info',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: ThemeService.isDarkMode ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Dark / Light Mode Toggle Button
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeService.themeModeNotifier,
            builder: (context, mode, _) {
              final isDark = mode == ThemeMode.dark;
              return IconButton(
                tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
                  color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF0F172A),
                  size: 22,
                ),
                onPressed: () => ThemeService.toggleTheme(),
              );
            },
          ),

          // Notification Bell with Badge
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.notifications_outlined, color: Theme.of(context).colorScheme.onSurface, size: 24),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationScreen()),
                  );
                  _loadAllData();
                },
              ),
              if (unreadNotifications > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$unreadNotifications',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFFEAB308),
        onRefresh: _loadAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Input Bar
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131D32) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF22314E) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: searchController,
                  style: TextStyle(
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                    fontSize: 14,
                  ),
                  onChanged: (_) => _applyFilter(),
                  onSubmitted: (_) => _applyFilter(),
                  decoration: InputDecoration(
                    hintText: 'Search hotel rooms, suites, or villas...',
                    hintStyle: TextStyle(
                      color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400,
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                      size: 22,
                    ),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 18, color: isDark ? const Color(0xFF94A3B8) : Colors.grey),
                            onPressed: () {
                              searchController.clear();
                              _applyFilter();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Hotel Showcase & Live Details Card
              _buildHotelHeaderCard(isDark),
              const SizedBox(height: 18),

              // Dynamic Hotel Room Banner Slideshow (Picture 2 style)
              _buildBannerSlideshow(),

              // Hotel Room Categories Horizontal Selector
              Text(
                'Hotel Room Categories',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              _buildCategoryPills(isDark),
              const SizedBox(height: 24),

              // New & Featured Hotel Rooms Carousel (Top 4 to 5 Newest Rooms)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'New & Featured Rooms',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    '${newestRooms.length} rooms',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 232,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: newestRooms.length,
                  itemBuilder: (context, idx) {
                    final item = newestRooms[idx];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ServiceDetailScreen(service: item)),
                        );
                      },
                      child: Container(
                        width: 260,
                        margin: const EdgeInsets.only(right: 14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF131D32) : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark ? const Color(0xFF22314E) : Colors.grey.shade200,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                                  child: Image.network(
                                    item.imageUrl,
                                    height: 120,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      height: 120,
                                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                      child: Icon(Icons.hotel_rounded, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), size: 36),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 10,
                                  left: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB),
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 4, offset: const Offset(0, 2)),
                                      ],
                                    ),
                                    child: const Text(
                                      'NEW',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: const Color(0xFFEAB308), borderRadius: BorderRadius.circular(12)),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.star, size: 12, color: Color(0xFF0F172A)),
                                        const SizedBox(width: 2),
                                        Text('${item.rating}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A))),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      _buildRoomTypeBadge(item.roomTypeDisplay, item.roomType, isDark),
                                      const Spacer(),
                                      Text(
                                        '\$${item.price.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 13, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        item.province,
                                        style: TextStyle(
                                          color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
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
              const SizedBox(height: 28),

              // All Available Hotel Rooms List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    selectedRoomType == 'ALL'
                        ? 'All Available Hotel Rooms & Suites'
                        : _getCategoryHeaderTitle(selectedRoomType),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    '${services.length} rooms',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: Color(0xFFEAB308))))
              else if (services.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.bed_outlined, size: 48, color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No hotel rooms found for ${_getCategoryHeaderTitle(selectedRoomType)}.',
                          style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...services.map((item) => _buildBookingStyleRoomCard(item, isDark)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingStyleRoomCard(ServiceModel item, bool isDark) {
    // Real Bed type exactly as submitted in Admin portal (e.g. 2 King Beds, 1 King Bed)
    final String bedInfo = item.bedType.isNotEmpty ? item.bedType : '1 King Bed';

    // Real Rating exactly as entered in Admin portal (e.g. 4.9, 5.0, 4.8)
    final double displayRating = item.rating > 0 ? item.rating : 4.8;
    final String scoreText = displayRating >= 4.8
        ? 'Wonderful'
        : (displayRating >= 4.5
            ? 'Superb'
            : (displayRating >= 4.0 ? 'Very Good' : 'Good'));
    final int reviewCount = item.reviewCount > 0 ? item.reviewCount : 128;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ServiceDetailScreen(service: item)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131D32) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF22314E) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.35)
                  : const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Column: Full Clear Tall Image
              SizedBox(
                width: 125,
                child: Image.network(
                  item.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    child: Icon(Icons.hotel_rounded, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), size: 36),
                  ),
                ),
              ),

              // Right Column: Hotel Room Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Row with Room Type Pill Badge & Favorite Heart
                      Row(
                        children: [
                          _buildRoomTypeBadge(item.roomTypeDisplay, item.roomType, isDark),
                          if (item.isFeatured) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'Featured',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          ValueListenableBuilder<Set<int>>(
                            valueListenable: ApiService.favoriteNotifier,
                            builder: (context, favs, _) {
                              final isFav = favs.contains(item.id);
                              return GestureDetector(
                                onTap: () => ApiService.toggleFavorite(item.id),
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 1),
                                  child: Icon(
                                    isFav ? Icons.favorite : Icons.favorite_border,
                                    color: isFav ? const Color(0xFFEF4444) : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                    size: 20,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Room Title
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 5),

                      // Real Stars + Thumbs up (No Genius)
                      Row(
                        children: [
                          ...List.generate(
                            item.starRating,
                            (index) => const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF78350F).withValues(alpha: 0.35) : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.thumb_up, size: 8.5, color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309)),
                                const SizedBox(width: 1),
                                Icon(Icons.add, size: 8.5, color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Blue Score Box + Reviews Text (Real data)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1D4ED8) : const Color(0xFF003580),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              displayRating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '$scoreText · $reviewCount reviews',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Clickable Location / Map Row
                      GestureDetector(
                        onTap: () async {
                          if (item.mapUrl.isNotEmpty) {
                            final uri = Uri.parse(item.mapUrl);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          }
                        },
                        child: Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 12, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF003580)),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                item.locationAddress.isNotEmpty && item.locationAddress != 'Phnom Penh, Cambodia'
                                    ? item.locationAddress
                                    : (item.province.isNotEmpty ? '${item.province} · In downtown' : 'In downtown'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF003580),
                                  fontSize: 11,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Bed info & Real Food Type / Meal Plan
                      Text(
                        bedInfo,
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        item.foodType.isNotEmpty ? item.foodType : 'Breakfast included',
                        style: TextStyle(
                          color: (item.foodType.toLowerCase().contains('only') || item.foodType.toLowerCase().contains('no'))
                              ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
                              : (isDark ? const Color(0xFF34D399) : const Color(0xFF059669)),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Price and Taxes (Bottom Right)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'US\$${item.price.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF0F172A),
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              'Includes taxes and fees',
                              style: TextStyle(
                                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                fontSize: 9.5,
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildHotelHeaderCard(bool isDark) {
    final hName = hotel?.name.isNotEmpty == true ? hotel!.name : 'Boss_Heng Luxury Hotel';
    final hTagline = hotel?.tagline.isNotEmpty == true ? hotel!.tagline : 'Premier 5-Star Riverside Retreat & Suites';
    final hAddress = hotel?.address.isNotEmpty == true ? hotel!.address : 'Riverside Blvd, Daun Penh, Phnom Penh';
    final hStars = hotel?.starRating ?? 5;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D32) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF22314E) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1D4ED8) : const Color(0xFF003580),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.hotel_rounded, color: Colors.white, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            hName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: Color(0xFFEAB308), size: 16),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        ...List.generate(
                          hStars.clamp(1, 5),
                          (index) => const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF59E0B)),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF78350F).withValues(alpha: 0.35) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$hStars-Star Hotel',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            hTagline,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 14, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF003580)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  hAddress,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontSize: 11.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => HotelInfoScreen(hotel: hotel)),
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'More Info',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_forward_ios_rounded, size: 9, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBannerSlideshow() {
    final displayRooms = newestRooms;

    if (displayRooms.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                // PageView Image Slideshow
                PageView.builder(
                  controller: _bannerController,
                  itemCount: displayRooms.length,
                  onPageChanged: (idx) {
                    setState(() => _currentBannerIndex = idx);
                  },
                  itemBuilder: (context, idx) {
                    final room = displayRooms[idx];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ServiceDetailScreen(service: room)),
                        );
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            room.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: const Color(0xFF1E293B),
                              child: const Icon(Icons.hotel_rounded, color: Colors.white54, size: 60),
                            ),
                          ),
                          // Subtle top & bottom vignette gradient
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withValues(alpha: 0.4),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.75),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0.0, 0.45, 1.0],
                              ),
                            ),
                          ),
                          // Top Badges (like pic 2: [New] [Category])
                          Positioned(
                            top: 14,
                            left: 14,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Text(
                                    'New',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    room.roomTypeDisplay,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Room Title & Price info
                          Positioned(
                            left: 16,
                            right: 64,
                            bottom: 12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  room.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '\$${room.price.toStringAsFixed(0)} / night',
                                  style: const TextStyle(
                                    color: Color(0xFFFDE047),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
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

                // Top Right Floating Pure Heart Favorite Button
                Positioned(
                  top: 12,
                  right: 14,
                  child: ValueListenableBuilder<Set<int>>(
                    valueListenable: ApiService.favoriteNotifier,
                    builder: (context, favs, _) {
                      final safeIndex = _currentBannerIndex < displayRooms.length ? _currentBannerIndex : 0;
                      final currentRoom = displayRooms[safeIndex];
                      final isFav = favs.contains(currentRoom.id);
                      return GestureDetector(
                        onTap: () {
                          ApiService.toggleFavorite(currentRoom.id);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isFav ? const Color(0xFFEF4444) : Colors.white,
                            size: 28,
                            shadows: const [
                              Shadow(
                                color: Colors.black45,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Center Dot Indicators (like pic 2)
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(displayRooms.length, (idx) {
                      final isActive = idx == _currentBannerIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isActive ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
      ],
    );
  }

  Widget _buildCategoryPills(bool isDark) {
    final Map<String, int> counts = {
      'ALL': allRooms.length,
      'SINGLE': allRooms.where((r) => r.roomType.toUpperCase() == 'SINGLE').length,
      'DOUBLE': allRooms.where((r) => r.roomType.toUpperCase() == 'DOUBLE').length,
      'SUITE': allRooms.where((r) => r.roomType.toUpperCase() == 'SUITE').length,
      'VIP': allRooms.where((r) => r.roomType.toUpperCase() == 'VIP').length,
      'FAMILY': allRooms.where((r) => r.roomType.toUpperCase() == 'FAMILY').length,
    };

    final List<Map<String, dynamic>> typePills = [
      {'code': 'ALL', 'label': 'All Room Types', 'icon': Icons.grid_view},
      {'code': 'SINGLE', 'label': 'Single Rooms', 'icon': Icons.single_bed_rounded},
      {'code': 'DOUBLE', 'label': 'Double / King Rooms', 'icon': Icons.king_bed_rounded},
      {'code': 'SUITE', 'label': 'Executive Suites', 'icon': Icons.meeting_room_rounded},
      {'code': 'VIP', 'label': 'VIP Presidential Villas', 'icon': Icons.military_tech_rounded},
      {'code': 'FAMILY', 'label': 'Family Suites', 'icon': Icons.family_restroom_rounded},
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: typePills.length,
        separatorBuilder: (_, index) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final p = typePills[idx];
          final String code = p['code'] as String;
          final String label = p['label'] as String;
          final IconData icon = p['icon'] as IconData;
          final int count = counts[code] ?? 0;
          final bool isSelected = selectedRoomType == code;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedRoomType = code;
                _applyFilter();
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? const Color(0xFF2563EB) : const Color(0xFF0F172A))
                    : (isDark ? const Color(0xFF131D32) : Colors.white),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isSelected
                      ? (isDark ? const Color(0xFF3B82F6) : const Color(0xFF0F172A))
                      : (isDark ? const Color(0xFF22314E) : const Color(0xFFE2E8F0)),
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: (isDark ? const Color(0xFF2563EB) : const Color(0xFF0F172A)).withValues(alpha: isDark ? 0.35 : 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected
                        ? const Color(0xFFFDE047)
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.2)
                          : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? const Color(0xFFFDE047)
                            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getCategoryHeaderTitle(String code) {
    switch (code.toUpperCase()) {
      case 'SINGLE':
        return 'Single Rooms';
      case 'DOUBLE':
        return 'Double / King Rooms';
      case 'SUITE':
        return 'Executive Suites';
      case 'VIP':
        return 'VIP Presidential Villas';
      case 'FAMILY':
        return 'Family Suites';
      default:
        return 'Available Hotel Rooms & Suites';
    }
  }

  Widget _buildRoomTypeBadge(String label, String code, [bool isDark = false]) {
    Color bg;
    Color fg;
    IconData icon;

    switch (code.toUpperCase()) {
      case 'SINGLE':
        bg = isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF);
        fg = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
        icon = Icons.single_bed_rounded;
        break;
      case 'DOUBLE':
        bg = isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : const Color(0xFFFEF3C7);
        fg = isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309);
        icon = Icons.king_bed_rounded;
        break;
      case 'SUITE':
        bg = isDark ? const Color(0xFF581C87).withValues(alpha: 0.4) : const Color(0xFFF3E8FF);
        fg = isDark ? const Color(0xFFD8B4FE) : const Color(0xFF7E22CE);
        icon = Icons.meeting_room_rounded;
        break;
      case 'VIP':
        bg = isDark ? const Color(0xFF7C2D12).withValues(alpha: 0.4) : const Color(0xFFFFFBEB);
        fg = isDark ? const Color(0xFFFDBA74) : const Color(0xFFD97706);
        icon = Icons.military_tech_rounded;
        break;
      case 'FAMILY':
        bg = isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFECFDF5);
        fg = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857);
        icon = Icons.family_restroom_rounded;
        break;
      default:
        bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
        fg = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
        icon = Icons.bedroom_parent_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: isDark ? 0.4 : 0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: fg, fontSize: 10.5, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
