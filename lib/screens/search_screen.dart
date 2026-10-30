import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/service_model.dart';
import '../models/category_model.dart';
import '../services/api_service.dart';
import 'service_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<ServiceModel> allRooms = [];
  List<ServiceModel> filteredRooms = [];
  List<CategoryModel> categories = [];
  bool isLoading = true;

  int selectedCategoryId = 0;
  String selectedPriceFilter = 'ALL'; // ALL, BUDGET, MID, LUXURY
  bool isGuestFilterActive = false;
  int selectedRooms = 1;
  int selectedAdults = 2;
  int selectedChildren = 0;
  final FocusNode _searchFocusNode = FocusNode();
  bool _showSuggestions = false;

  List<ServiceModel> get _searchSuggestions {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return [];
    return allRooms.where((r) =>
      r.name.toLowerCase().contains(q) ||
      r.roomType.toLowerCase().contains(q) ||
      r.bedType.toLowerCase().contains(q) ||
      r.categoryName.toLowerCase().contains(q)
    ).take(6).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchCtrl.addListener(() {
      if (mounted) {
        setState(() {
          _showSuggestions = _searchCtrl.text.trim().isNotEmpty && _searchFocusNode.hasFocus;
        });
      }
      _applyFilters();
    });
    _searchFocusNode.addListener(() {
      if (mounted) {
        setState(() {
          _showSuggestions = _searchCtrl.text.trim().isNotEmpty && _searchFocusNode.hasFocus;
        });
      }
    });
    ApiService.favoriteNotifier.addListener(_onFavoritesChanged);
  }

  void _onFavoritesChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    ApiService.favoriteNotifier.removeListener(_onFavoritesChanged);
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    final roomsData = await ApiService.getServices();
    final catsData = await ApiService.getCategories();
    if (mounted) {
      setState(() {
        allRooms = roomsData;
        categories = catsData;
        isLoading = false;
        _applyFilters();
      });
    }
  }

  bool _matchesCategory(ServiceModel room, int categoryId) {
    if (categoryId == 0) return true;

    final cat = categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => CategoryModel(id: 0, name: '', icon: ''),
    );
    if (cat.id == 0) return true;

    final targetName = cat.name.toLowerCase().trim();
    final roomCatName = room.categoryName.toLowerCase().trim();
    final rType = room.roomType.toUpperCase().trim();

    // 1. Direct equality or substring match
    if (roomCatName == targetName ||
        targetName.contains(roomCatName) ||
        roomCatName.contains(targetName)) {
      return true;
    }

    // 2. Normalized without trailing 's' (e.g. "single room" vs "single rooms")
    final normTarget = targetName.replaceAll(RegExp(r's$'), '');
    final normRoomCat = roomCatName.replaceAll(RegExp(r's$'), '');
    if (normTarget == normRoomCat || normTarget.contains(normRoomCat) || normRoomCat.contains(normTarget)) {
      return true;
    }

    // 3. Match by category ID or keyword against roomType code
    if (targetName.contains('single') || categoryId == 1) {
      return rType == 'SINGLE' || roomCatName.contains('single') || room.name.toLowerCase().contains('single');
    }
    if (targetName.contains('double') || categoryId == 2) {
      return rType == 'DOUBLE' || roomCatName.contains('double') || room.name.toLowerCase().contains('double');
    }
    if (targetName.contains('twin') || categoryId == 3) {
      return rType == 'TWIN' || roomCatName.contains('twin') || room.name.toLowerCase().contains('twin');
    }
    if (targetName.contains('triple') || categoryId == 4) {
      return rType == 'TRIPLE' || roomCatName.contains('triple') || room.name.toLowerCase().contains('triple');
    }
    if (targetName.contains('family') || categoryId == 5) {
      return rType == 'FAMILY' || roomCatName.contains('family') || room.name.toLowerCase().contains('family');
    }
    if (targetName.contains('suite') || targetName.contains('vip') || categoryId == 6) {
      return rType == 'SUITE' || rType == 'VIP' || roomCatName.contains('suite') || roomCatName.contains('vip') || room.name.toLowerCase().contains('suite');
    }

    return false;
  }

  void _applyFilters() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      filteredRooms = allRooms.where((room) {
        // Query match
        final matchesQuery = query.isEmpty ||
            room.name.toLowerCase().contains(query) ||
            room.description.toLowerCase().contains(query) ||
            room.categoryName.toLowerCase().contains(query) ||
            room.roomType.toLowerCase().contains(query) ||
            room.bedType.toLowerCase().contains(query);

        // Category match
        final matchesCategory = _matchesCategory(room, selectedCategoryId);

        // Price match
        bool matchesPrice = true;
        if (selectedPriceFilter == 'BUDGET') {
          matchesPrice = room.price <= 60.0;
        } else if (selectedPriceFilter == 'MID') {
          matchesPrice = room.price > 60.0 && room.price <= 150.0;
        } else if (selectedPriceFilter == 'LUXURY') {
          matchesPrice = room.price > 150.0;
        }

        // Guest capacity match: 2 Children = 1 Adult
        bool matchesGuests = true;
        if (isGuestFilterActive) {
          final childEquiv = selectedChildren == 0 ? 0 : (selectedChildren + 1) ~/ 2;
          final neededCapacity = selectedAdults + childEquiv;
          matchesGuests = room.maxGuests >= neededCapacity;
        }

        return matchesQuery && matchesCategory && matchesPrice && matchesGuests;
      }).toList();
    });
  }



  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(
          'Search Hotel Rooms',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Search & Filters Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            color: isDark ? const Color(0xFF131D32) : Colors.white,
            child: Column(
              children: [
                // Search Input Field
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: isDark ? Border.all(color: const Color(0xFF334155)) : null,
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocusNode,
                    onSubmitted: (_) {
                      setState(() {
                        _showSuggestions = false;
                      });
                      _searchFocusNode.unfocus();
                    },
                    style: TextStyle(
                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search room, suite, villa or amenity...',
                      hintStyle: TextStyle(
                        color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400,
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                        size: 22,
                      ),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, size: 18, color: isDark ? const Color(0xFF94A3B8) : Colors.grey),
                              onPressed: () => _searchCtrl.clear(),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                if (_showSuggestions && _searchSuggestions.isNotEmpty)
                  _buildSearchSuggestionsDropdown(isDark),
                const SizedBox(height: 12),

                // Category Chips
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildFilterChip('All Rooms', 0, selectedCategoryId == 0, () {
                        setState(() {
                          selectedCategoryId = 0;
                          _applyFilters();
                        });
                      }, isDark),
                      ...categories.map((c) => _buildFilterChip(c.name, c.id, selectedCategoryId == c.id, () {
                            setState(() {
                              selectedCategoryId = c.id;
                              _applyFilters();
                            });
                          }, isDark)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Price Range Pills
                Row(
                  children: [
                    Text(
                      'Price: ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    _buildPricePill('All', 'ALL', isDark),
                    const SizedBox(width: 6),
                    _buildPricePill('Under \$60', 'BUDGET', isDark),
                    const SizedBox(width: 6),
                    _buildPricePill('\$60-\$150', 'MID', isDark),
                    const SizedBox(width: 6),
                    _buildPricePill('\$150+', 'LUXURY', isDark),
                  ],
                ),
                const SizedBox(height: 10),
                // Guest Filter Row (Search by maxGuests)
                Row(
                  children: [
                    Text(
                      'Guests: ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _openGuestsFilterBottomSheet(isDark),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isGuestFilterActive
                              ? const Color(0xFF006CE4).withValues(alpha: 0.15)
                              : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isGuestFilterActive
                                ? const Color(0xFF006CE4)
                                : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.people_outline_rounded,
                              size: 13,
                              color: isGuestFilterActive
                                  ? const Color(0xFF006CE4)
                                  : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isGuestFilterActive
                                  ? '$selectedRooms room · $selectedAdults adults${selectedChildren > 0 ? " · $selectedChildren kids" : ""}'
                                  : 'Select guests ($selectedAdults adults)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isGuestFilterActive ? FontWeight.bold : FontWeight.normal,
                                color: isGuestFilterActive
                                    ? const Color(0xFF006CE4)
                                    : (isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade700),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_drop_down,
                              size: 15,
                              color: isGuestFilterActive
                                  ? const Color(0xFF006CE4)
                                  : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search Results Counter
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Search Results (${filteredRooms.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),

          // Results List
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF006CE4),
              onRefresh: _loadData,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFEAB308)))
                  : filteredRooms.isEmpty
                      ? _buildNoResults(isDark)
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredRooms.length,
                          itemBuilder: (context, idx) {
                            final room = filteredRooms[idx];
                            return _buildRoomTile(room, isDark);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int id, bool isSelected, VoidCallback onTap, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        selectedColor: isDark ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF0F172A)),
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isSelected
                ? (isDark ? const Color(0xFF3B82F6) : const Color(0xFF0F172A))
                : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
          ),
        ),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Widget _buildPricePill(String label, String value, bool isDark) {
    final isSelected = selectedPriceFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedPriceFilter = value;
          _applyFilters();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFEAB308)
              : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: isDark && !isSelected ? Border.all(color: const Color(0xFF334155)) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? const Color(0xFF0F172A)
                : (isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade700),
          ),
        ),
      ),
    );
  }
  Widget _buildNoResults(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 54, color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No Matching Rooms',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try adjusting your search keyword, category, or price range.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomTile(ServiceModel item, bool isDark) {
    // Bed type based on name
    String bedInfo = '1 bed';
    final lowerName = item.name.toLowerCase();
    if (lowerName.contains('suite') || lowerName.contains('villa') || lowerName.contains('family')) {
      bedInfo = 'Hotel room: 2 beds';
    } else if (lowerName.contains('single')) {
      bedInfo = '1 single bed';
    } else if (lowerName.contains('deluxe') || lowerName.contains('king')) {
      bedInfo = '1 king bed';
    }

    // 10-point review score like Booking.com
    final double bookingScore = (item.rating >= 4.9)
        ? 9.0
        : (item.rating >= 4.7)
            ? 8.8
            : (item.rating >= 4.4)
                ? 8.4
                : 8.0;
    final String scoreText = bookingScore >= 9.0 ? 'Wonderful' : 'Very Good';
    final int reviewCount = item.reviewCount > 0 ? item.reviewCount : (item.id * 382 + 430);

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
                child: item.imageUrl.trim().isNotEmpty
                    ? Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.bed_outlined, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), size: 32),
                              const SizedBox(height: 4),
                              Text('No photo', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
                            ],
                          ),
                        ),
                      )
                    : Container(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bed_outlined, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), size: 32),
                            const SizedBox(height: 4),
                            Text('No photo', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
                          ],
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
                      // Title & Favorite Heart
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
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
                          ),
                          const SizedBox(width: 6),
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
                                    size: 21,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Real Stars + Tier Badge + Featured (Responsive Wrap)
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        runSpacing: 3,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              item.starRating,
                              (index) => const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                            ),
                          ),
                          if (item.isFeatured) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'Featured',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Blue Score Box + Reviews Text
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1D4ED8) : const Color(0xFF003580),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              bookingScore.toStringAsFixed(1),
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
                      if (item.hasBreakfast)
                        Text(
                          item.foodType.isNotEmpty && !item.foodType.toLowerCase().contains('room only')
                              ? item.foodType
                              : 'Breakfast included',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
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

  void _openGuestsFilterBottomSheet(bool isDark) {
    int tempRooms = selectedRooms;
    int tempAdults = selectedAdults;
    int tempChildren = selectedChildren;

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
                            const SizedBox(height: 24),

                            // Apply Button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: () async {
                                  setState(() {
                                    selectedRooms = tempRooms;
                                    selectedAdults = tempAdults;
                                    selectedChildren = tempChildren;
                                    isGuestFilterActive = true;
                                    isLoading = true;
                                  });
                                  Navigator.pop(ctx);
                                  final fresh = await ApiService.getServices();
                                  if (mounted) {
                                    setState(() {
                                      allRooms = fresh;
                                      isLoading = false;
                                      _applyFilters();
                                    });
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
            InkWell(
              onTap: canDec ? onDecrement : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: canDec
                        ? const Color(0xFF006CE4)
                        : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                    width: 1.5,
                  ),
                  color: canDec
                      ? const Color(0xFF006CE4).withValues(alpha: 0.1)
                      : Colors.transparent,
                ),
                child: Icon(
                  Icons.remove,
                  size: 18,
                  color: canDec
                      ? const Color(0xFF006CE4)
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
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                ),
              ),
            ),
            InkWell(
              onTap: canInc ? onIncrement : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: canInc
                        ? const Color(0xFF006CE4)
                        : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                    width: 1.5,
                  ),
                  color: canInc
                      ? const Color(0xFF006CE4).withValues(alpha: 0.1)
                      : Colors.transparent,
                ),
                child: Icon(
                  Icons.add,
                  size: 18,
                  color: canInc
                      ? const Color(0xFF006CE4)
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
    final suggestions = _searchSuggestions;
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
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
                      const Icon(Icons.lightbulb_outline, size: 16, color: Color(0xFFF59E0B)),
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
                        _showSuggestions = false;
                        _searchFocusNode.unfocus();
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
                      _searchCtrl.text = room.name;
                      setState(() {
                        _showSuggestions = false;
                        _searchFocusNode.unfocus();
                      });
                      _applyFilters();
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
}
