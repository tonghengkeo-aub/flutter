import 'package:flutter/material.dart';
import '../models/service_model.dart';
import '../services/api_service.dart';
import 'service_detail_screen.dart';
import 'booking_form_screen.dart';

class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({super.key});

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  List<ServiceModel> favorites = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    ApiService.favoriteNotifier.addListener(_onFavoritesChanged);
    _loadFavorites();
  }

  @override
  void dispose() {
    ApiService.favoriteNotifier.removeListener(_onFavoritesChanged);
    super.dispose();
  }

  void _onFavoritesChanged() {
    if (mounted) {
      _loadFavorites();
    }
  }

  Future<void> _loadFavorites() async {
    setState(() => isLoading = true);
    final list = await ApiService.getFavoriteRooms();
    if (mounted) {
      setState(() {
        favorites = list;
        isLoading = false;
      });
    }
  }

  void _toggleFavorite(ServiceModel room) {
    setState(() {
      ApiService.toggleFavorite(room.id);
      favorites.removeWhere((r) => r.id == room.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed "${room.name}" from favorites.'),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: const Color(0xFFEAB308),
          onPressed: () {
            setState(() {
              ApiService.toggleFavorite(room.id);
              _loadFavorites();
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Favorite Rooms & Villas',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)),
            onPressed: _loadFavorites,
            tooltip: 'Refresh Favorites',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFEAB308)))
          : favorites.isEmpty
              ? _buildEmptyState(isDark)
              : RefreshIndicator(
                  onRefresh: _loadFavorites,
                  color: const Color(0xFFEAB308),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: favorites.length,
                    itemBuilder: (context, idx) {
                      final room = favorites[idx];
                      return _buildFavoriteCard(room, isDark);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.favorite_border_rounded, size: 40, color: isDark ? const Color(0xFFF87171) : Colors.red.shade300),
            ),
            const SizedBox(height: 20),
            Text(
              'No Saved Rooms Yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            Text(
              'Explore our hotel rooms, suites, and VIP villas and tap the heart icon to save your dream stay.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : Colors.grey, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteCard(ServiceModel room, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D32) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF22314E) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image with Badges
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: room.imageUrl.trim().isNotEmpty
                    ? Image.network(
                        room.imageUrl,
                        height: 170,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 170,
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.bed_outlined, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), size: 40),
                              const SizedBox(height: 6),
                              Text('No photo uploaded', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
                            ],
                          ),
                        ),
                      )
                    : Container(
                        height: 170,
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bed_outlined, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), size: 40),
                            const SizedBox(height: 6),
                            Text('No photo uploaded', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
                          ],
                        ),
                      ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.9) : const Color(0xFF0F172A).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: isDark ? Border.all(color: const Color(0xFF334155)) : null,
                  ),
                  child: Text(
                    room.categoryName,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 12,
                child: GestureDetector(
                  onTap: () => _toggleFavorite(room),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.favorite_rounded,
                      color: Color(0xFFEF4444),
                      size: 26,
                      shadows: [
                        Shadow(
                          color: Colors.black45,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAB308),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '\$${room.price.toStringAsFixed(0)} / night',
                    style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),

          // Content info
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        room.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.star_rounded, color: Color(0xFFEAB308), size: 18),
                    Text(
                      room.rating.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  room.description,
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                    fontSize: 12,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ServiceDetailScreen(service: room)),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A),
                          side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text('View Details', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => BookingFormScreen(service: room)),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text('Book Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
