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

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchCtrl.addListener(_applyFilters);
    ApiService.favoriteNotifier.addListener(_onFavoritesChanged);
  }

  void _onFavoritesChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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

  void _applyFilters() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      filteredRooms = allRooms.where((room) {
        // Query match
        final matchesQuery = query.isEmpty ||
            room.name.toLowerCase().contains(query) ||
            room.description.toLowerCase().contains(query) ||
            room.categoryName.toLowerCase().contains(query);

        // Category match
        final matchesCategory = selectedCategoryId == 0 ||
            room.categoryName.toLowerCase() == _getCategoryNameById(selectedCategoryId).toLowerCase();

        // Price match
        bool matchesPrice = true;
        if (selectedPriceFilter == 'BUDGET') {
          matchesPrice = room.price <= 60.0;
        } else if (selectedPriceFilter == 'MID') {
          matchesPrice = room.price > 60.0 && room.price <= 150.0;
        } else if (selectedPriceFilter == 'LUXURY') {
          matchesPrice = room.price > 150.0;
        }

        return matchesQuery && matchesCategory && matchesPrice;
      }).toList();
    });
  }

  String _getCategoryNameById(int id) {
    final cat = categories.firstWhere((c) => c.id == id, orElse: () => CategoryModel(id: 0, name: '', icon: ''));
    return cat.name;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
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
                if (_searchCtrl.text.isNotEmpty || selectedCategoryId != 0 || selectedPriceFilter != 'ALL')
                  GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() {
                        selectedCategoryId = 0;
                        selectedPriceFilter = 'ALL';
                        _applyFilters();
                      });
                    },
                    child: const Text('Reset Filters', style: TextStyle(color: Color(0xFF60A5FA), fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),

          // Results List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFEAB308)))
                : filteredRooms.isEmpty
                    ? _buildNoResults(isDark)
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredRooms.length,
                        itemBuilder: (context, idx) {
                          final room = filteredRooms[idx];
                          return _buildRoomTile(room, isDark);
                        },
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
                          if (item.isFeatured) ...[
                            const SizedBox(width: 5),
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
}
