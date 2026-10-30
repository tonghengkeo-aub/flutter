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
import '../widgets/stay_review_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
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
  final FocusNode searchFocusNode = FocusNode();
  bool showSuggestions = false;

  // Booking.com style Rooms & Guests state (Pic 2 & Pic 3)
  int selectedRooms = 1;
  int selectedAdults = 2;
  int selectedChildren = 0;
  String selectedBedType = 'ALL';
  int selectedRoomId = 0; // 0 = Any room
  bool travelingForWork = false;
  bool travelingWithPets = false;
  bool isGuestFilterActive = false;

  int get effectiveAdultRequirement {
    final childEquiv = selectedChildren == 0 ? 0 : (selectedChildren + 1) ~/ 2;
    return selectedAdults + childEquiv;
  }

  String get guestsSummaryText {
    final roomText = '$selectedRooms ${selectedRooms > 1 ? 'rooms' : 'room'}';
    final adultText = '$selectedAdults ${selectedAdults > 1 ? 'adults' : 'adult'}';
    final childText = selectedChildren == 0
        ? 'No children'
        : (selectedChildren == 1 ? '1 child' : '$selectedChildren children');
    return '$roomText · $adultText · $childText';
  }

  final PageController _bannerController = PageController();
  int _currentBannerIndex = 0;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _startBannerTimer();
    searchFocusNode.addListener(() {
      if (mounted) {
        setState(() {
          showSuggestions = searchFocusNode.hasFocus && searchController.text.trim().isNotEmpty;
        });
      }
    });
  }

  List<ServiceModel> get searchSuggestions {
    final q = searchController.text.trim().toLowerCase();
    if (q.isEmpty) return [];
    return allRooms.where((r) =>
      r.name.toLowerCase().contains(q) ||
      r.roomType.toLowerCase().contains(q) ||
      r.bedType.toLowerCase().contains(q) ||
      r.categoryName.toLowerCase().contains(q)
    ).take(6).toList();
  }

  List<ServiceModel> get newestRooms {
    final list = List<ServiceModel>.from(allRooms.isNotEmpty ? allRooms : services);
    list.sort((a, b) => b.id.compareTo(a.id));
    return list.take(5).toList();
  }

  void resetToHome() {
    setState(() {
      searchController.clear();
      showSuggestions = false;
      isGuestFilterActive = false;
      selectedRooms = 1;
      selectedAdults = 2;
      selectedChildren = 0;
      travelingForWork = false;
      travelingWithPets = false;
      selectedRoomType = 'ALL';
      selectedCategoryId = 0;
    });
    searchFocusNode.unfocus();
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    _applyFilter();
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
    searchFocusNode.dispose();
    searchController.dispose();
    _scrollController.dispose();
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
      StayReviewDialog.checkAndShowPendingReview(context, delay: const Duration(milliseconds: 1000));
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
      if (selectedRoomType == 'SUITE') {
        list = list.where((r) => r.roomType.toUpperCase() == 'SUITE' || r.roomType.toUpperCase() == 'VIP').toList();
      } else {
        list = list.where((r) => r.roomType.toUpperCase() == selectedRoomType.toUpperCase()).toList();
      }
    }

    // Dynamic Rooms & Guests Filter: 2 Children = 1 Adult
    if (isGuestFilterActive) {
      final childEquiv = selectedChildren == 0 ? 0 : (selectedChildren + 1) ~/ 2;
      final neededCapacity = selectedAdults + childEquiv;

      list = list.where((r) {
        return r.maxGuests >= neededCapacity;
      }).toList();
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
          controller: _scrollController,
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
                  focusNode: searchFocusNode,
                  style: TextStyle(
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                    fontSize: 14,
                  ),
                  onChanged: (text) {
                    setState(() {
                      showSuggestions = text.trim().isNotEmpty;
                    });
                    _applyFilter();
                  },
                  onSubmitted: (_) {
                    setState(() {
                      showSuggestions = false;
                    });
                    searchFocusNode.unfocus();
                    _applyFilter();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search room name (e.g. Dog Room, Kitty Room)...',
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
                              setState(() {
                                showSuggestions = false;
                              });
                              searchFocusNode.unfocus();
                              _applyFilter();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              // Auto-Complete Suggestions Dropdown (Like Pic 3 / YouTube)
              if (showSuggestions && searchSuggestions.isNotEmpty)
                _buildSearchSuggestionsDropdown(isDark),

              const SizedBox(height: 14),

              // Booking.com Style Rooms & Guests Search Card
              _buildBookingComSearchCard(isDark),

              // Active search / filter condition
              if (isGuestFilterActive || searchController.text.trim().isNotEmpty) ...[
                // ACTIVE SEARCH MODE: Show Results IMMEDIATELY right below search card!
                const SizedBox(height: 18),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      searchController.text.trim().isNotEmpty
                          ? 'Search Results for "${searchController.text.trim()}" (${services.length})'
                          : 'Search Results (${services.length})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '${services.length} available',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (isLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: Color(0xFF006CE4))))
                else if (services.isEmpty)
                  _buildNoSearchResults(isDark)
                else
                  ...services.map((item) => _buildBookingStyleRoomCard(item, isDark)),
              ] else ...[
                // STANDARD HOMEPAGE MODE: Show Showcase, Slideshow, Categories, Featured & All Rooms
                const SizedBox(height: 18),
                _buildHotelHeaderCard(isDark),
                const SizedBox(height: 18),
                _buildBannerSlideshow(),

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

                if (newestRooms.isNotEmpty) ...[
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
                                      child: item.imageUrl.trim().isNotEmpty
                                          ? Image.network(
                                              item.imageUrl,
                                              height: 120,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) => _buildNoPhotoWidget(isDark, 120),
                                            )
                                          : _buildNoPhotoWidget(isDark, 120),
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
                                    if (item.availableUnits <= 0)
                                      Positioned(
                                        bottom: 8,
                                        left: 10,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDC2626),
                                            borderRadius: BorderRadius.circular(4),
                                            boxShadow: [
                                              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 3, offset: const Offset(0, 1)),
                                            ],
                                          ),
                                          child: const Text(
                                            'Sold Out',
                                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9.5),
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
                                        item.cleanName,
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
                ],

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
              // Left Column: Full Clear Tall Image with Real Inventory Badge
              SizedBox(
                width: 125,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    item.imageUrl.trim().isNotEmpty
                        ? Image.network(
                            item.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _buildNoPhotoWidget(isDark, double.infinity),
                          )
                        : _buildNoPhotoWidget(isDark, double.infinity),
                    if (item.availableUnits <= 0)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.block, color: Colors.white, size: 10),
                              SizedBox(width: 3),
                              Text('Sold Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9.5)),
                            ],
                          ),
                        ),
                      ),
                  ],
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
                        item.cleanName,
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
                                item.locationAddress.isNotEmpty
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.foodType.isNotEmpty ? item.foodType : 'Breakfast included',
                              style: TextStyle(
                                color: (item.foodType.toLowerCase().contains('only') || item.foodType.toLowerCase().contains('no'))
                                    ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
                                    : (isDark ? const Color(0xFF34D399) : const Color(0xFF059669)),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          if (item.availableUnits <= 0)
                            const Text(
                              'Sold Out',
                              style: TextStyle(
                                color: Color(0xFFDC2626),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                        ],
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
    final hAddress = hotel?.address.isNotEmpty == true ? hotel!.address : 'National Road 2, Ta Khmau, Kandal';
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
                          room.imageUrl.trim().isNotEmpty
                              ? Image.network(
                                  room.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: const Color(0xFF1E293B),
                                    child: const Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.bed_outlined, color: Colors.white54, size: 54),
                                          SizedBox(height: 8),
                                          Text('No photo uploaded', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500)),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  color: const Color(0xFF1E293B),
                                  child: const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.bed_outlined, color: Colors.white54, size: 54),
                                        SizedBox(height: 8),
                                        Text('No photo uploaded', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
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
                                  room.cleanName,
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
      'TWIN': allRooms.where((r) => r.roomType.toUpperCase() == 'TWIN').length,
      'TRIPLE': allRooms.where((r) => r.roomType.toUpperCase() == 'TRIPLE').length,
      'FAMILY': allRooms.where((r) => r.roomType.toUpperCase() == 'FAMILY').length,
      'SUITE': allRooms.where((r) => r.roomType.toUpperCase() == 'SUITE' || r.roomType.toUpperCase() == 'VIP').length,
    };

    final List<Map<String, dynamic>> typePills = [
      {'code': 'ALL', 'label': 'All Room Types', 'icon': Icons.grid_view},
      {'code': 'SINGLE', 'label': 'Single Rooms', 'icon': Icons.single_bed_rounded},
      {'code': 'DOUBLE', 'label': 'Double Rooms', 'icon': Icons.king_bed_rounded},
      {'code': 'TWIN', 'label': 'Twin Rooms', 'icon': Icons.hotel_rounded},
      {'code': 'TRIPLE', 'label': 'Triple Rooms', 'icon': Icons.groups_rounded},
      {'code': 'FAMILY', 'label': 'Family Rooms', 'icon': Icons.family_restroom_rounded},
      {'code': 'SUITE', 'label': 'Suite Rooms', 'icon': Icons.meeting_room_rounded},
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

  Widget _buildNoPhotoWidget(bool isDark, double height, {double iconSize = 32}) {
    return Container(
      height: height,
      width: double.infinity,
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bed_outlined,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              size: iconSize,
            ),
            const SizedBox(height: 4),
            Text(
              'No photo uploaded',
              style: TextStyle(
                fontSize: 10.5,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // BOOKING.COM STYLE SEARCH CARD & ROOMS/GUESTS SELECTOR (Pic 2 & Pic 3)
  // ==========================================================================

  Widget _buildBookingComSearchCard(bool isDark) {
    final roomText = '$selectedRooms ${selectedRooms > 1 ? "rooms" : "room"}';
    final adultText = '$selectedAdults ${selectedAdults > 1 ? "adults" : "adult"}';
    final childText = selectedChildren == 0
        ? 'No children'
        : (selectedChildren == 1 ? '1 child' : '$selectedChildren children');
    final mainSummary = '$roomText · $adultText · $childText';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D32) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF59E0B), // Golden yellow border from Pic 2
          width: 2.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.22 : 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Selector Row
          InkWell(
            onTap: () => _openRoomsAndGuestsBottomSheet(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                    size: 26,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mainSummary,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isGuestFilterActive ? 'Filter active · Tap to change' : 'Tap to select rooms and guests',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),

          // Divider
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? const Color(0xFF22314E) : const Color(0xFFE2E8F0),
          ),

          // Search Button (Solid blue like Pic 2)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () async {
                setState(() {
                  isGuestFilterActive = true;
                  isLoading = true;
                });
                final fresh = await ApiService.getServices();
                if (mounted) {
                  setState(() {
                    allRooms = fresh;
                    isLoading = false;
                  });
                  _applyFilter();
                }
                },

              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006CE4), // Signature Booking.com Blue
                foregroundColor: Colors.white,
                elevation: 0,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
                ),
              ),
              child: const Text(
                'Search',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openRoomsAndGuestsBottomSheet(bool isDark) {
    int tempRooms = selectedRooms;
    int tempAdults = selectedAdults;
    int tempChildren = selectedChildren;
    bool tempWork = travelingForWork;
    bool tempPets = travelingWithPets;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131D32) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, -4)),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag Handle
                      Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),

                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Select rooms and guests',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ),

                      Divider(height: 1, color: isDark ? const Color(0xFF22314E) : const Color(0xFFE2E8F0)),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Column(
                          children: [
                            // Rooms Counter
                            _buildCounterRow(
                              title: 'Rooms',
                              subtitle: null,
                              value: tempRooms,
                              minValue: 1,
                              maxValue: 10,
                              isDark: isDark,
                              onDecrement: () => setModalState(() => tempRooms--),
                              onIncrement: () => setModalState(() => tempRooms++),
                            ),
                            const SizedBox(height: 18),

                            // Adults Counter
                            _buildCounterRow(
                              title: 'Adults',
                              subtitle: '18+ years old',
                              value: tempAdults,
                              minValue: 1,
                              maxValue: 20,
                              isDark: isDark,
                              onDecrement: () => setModalState(() => tempAdults--),
                              onIncrement: () => setModalState(() => tempAdults++),
                            ),
                            const SizedBox(height: 18),

                            // Children Counter
                            _buildCounterRow(
                              title: 'Children',
                              subtitle: '0 – 17 years (2 children = 1 adult capacity)',
                              value: tempChildren,
                              minValue: 0,
                              maxValue: 10,
                              isDark: isDark,
                              onDecrement: () => setModalState(() => tempChildren--),
                              onIncrement: () => setModalState(() => tempChildren++),
                            ),
                            const SizedBox(height: 18),

                            // Traveling for work?
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Traveling for work?',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                  ),
                                ),
                                Switch.adaptive(
                                  value: tempWork,
                                  activeTrackColor: const Color(0xFF006CE4),
                                  activeThumbColor: Colors.white,
                                  onChanged: (val) => setModalState(() => tempWork = val),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Traveling with pets?
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Traveling with pets?',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                  ),
                                ),
                                Switch.adaptive(
                                  value: tempPets,
                                  activeTrackColor: const Color(0xFF006CE4),
                                  activeThumbColor: Colors.white,
                                  onChanged: (val) => setModalState(() => tempPets = val),
                                ),
                              ],
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Assistance animals aren't considered pets.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF64748B) : Colors.grey.shade500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Bottom Apply Button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: () async {
                                  setState(() {
                                    selectedRooms = tempRooms;
                                    selectedAdults = tempAdults;
                                    selectedChildren = tempChildren;
                                    travelingForWork = tempWork;
                                    travelingWithPets = tempPets;
                                    isGuestFilterActive = true;
                                    isLoading = true;
                                  });
                                  Navigator.pop(ctx);
                                  final fresh = await ApiService.getServices();
                                  if (mounted) {
                                    setState(() {
                                      allRooms = fresh;
                                      isLoading = false;
                                    });
                                    _applyFilter();
                                  }
                                  },

                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF006CE4),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text(
                                  'Apply',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCounterRow({
    required String title,
    String? subtitle,
    required int value,
    required int minValue,
    required int maxValue,
    required bool isDark,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    final canDec = value > minValue;
    final canInc = value < maxValue;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
        Row(
          children: [
            // Minus Button
            InkWell(
              onTap: canDec ? onDecrement : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: canDec
                        ? const Color(0xFF006CE4)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    width: 1.2,
                  ),
                ),
                child: Icon(
                  Icons.remove,
                  size: 18,
                  color: canDec
                      ? (isDark ? Colors.white : const Color(0xFF006CE4))
                      : (isDark ? const Color(0xFF475569) : Colors.grey.shade400),
                ),
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                ),
              ),
            ),
            // Plus Button
            InkWell(
              onTap: canInc ? onIncrement : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: canInc
                        ? const Color(0xFF006CE4)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    width: 1.2,
                  ),
                ),
                child: Icon(
                  Icons.add,
                  size: 18,
                  color: canInc
                      ? (isDark ? Colors.white : const Color(0xFF006CE4))
                      : (isDark ? const Color(0xFF475569) : Colors.grey.shade400),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
  Widget _buildSearchSuggestionsDropdown(bool isDark) {
    final suggestions = searchSuggestions;
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 180),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, size: 16, color: const Color(0xFFF59E0B)),
                      const SizedBox(width: 6),
                      Text(
                        'ROOM SUGGESTIONS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        showSuggestions = false;
                        searchFocusNode.unfocus();
                      });
                    },
                    child: Icon(Icons.close, size: 18, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: suggestions.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  thickness: 0.5,
                  color: isDark ? const Color(0xFF334155).withValues(alpha: 0.5) : const Color(0xFFF1F5F9),
                ),
                itemBuilder: (context, idx) {
                  final room = suggestions[idx];
                  return InkWell(
                    onTap: () {
                      searchController.text = room.name;
                      setState(() {
                        showSuggestions = false;
                        searchFocusNode.unfocus();
                      });
                      _applyFilter();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF006CE4),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  room.name,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${room.bedType} · Sleeps ${room.maxGuests} · \$${room.price.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.north_west_rounded,
                            size: 15,
                            color: Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSearchResults(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 40,
                color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No matching rooms found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              searchController.text.isNotEmpty
                  ? 'No room found matching "${searchController.text}". Try another room name.'
                  : 'No room can accommodate ${selectedAdults + selectedChildren} guest(s). Try adjusting your guest count or adding higher capacity rooms in the dashboard.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  searchController.clear();
                  showSuggestions = false;
                  isGuestFilterActive = false;
                  selectedRooms = 1;
                  selectedAdults = 2;
                  selectedChildren = 0;
                  selectedRoomType = 'ALL';
                });
                _applyFilter();
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reset & View All Rooms'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006CE4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
