import 'package:flutter/material.dart';
import '../models/hotel_model.dart';
import '../models/room_model.dart';
import '../services/api_service.dart';
import 'room_selection_screen.dart';

class HotelDetailScreen extends StatefulWidget {
  final HotelModel hotel;

  const HotelDetailScreen({super.key, required this.hotel});

  @override
  State<HotelDetailScreen> createState() => _HotelDetailScreenState();
}

class _HotelDetailScreenState extends State<HotelDetailScreen> {
  List<RoomModel> rooms = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadRooms();
  }

  Future<void> loadRooms() async {
    final list = await ApiService.getRoomsByHotel(widget.hotel.id);
    if (mounted) {
      setState(() {
        rooms = list;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hotel = widget.hotel;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // Collapsible Image Header
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: const Color(0xFF0F172A),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    hotel.mainImage,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: Colors.grey.shade800,
                      child: const Icon(Icons.hotel, color: Colors.white54, size: 60),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 20,
                    right: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAB308),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star, color: Color(0xFF0F172A), size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '${hotel.rating}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            hotel.province,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hotel.name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.redAccent, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          hotel.address,
                          style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Amenities Chips
                  Text('Hotel Amenities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A))),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: hotel.facilityList.map((f) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF131D32) : const Color(0xFFEEF2F6),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? const Color(0xFF22314E) : Colors.transparent),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 15),
                            const SizedBox(width: 6),
                            Text(f, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? const Color(0xFFE2E8F0) : Colors.black87)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),
                  Text('About Property', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  Text(
                    hotel.description,
                    style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade700, height: 1.4, fontSize: 13),
                  ),

                  const SizedBox(height: 24),
                  Divider(color: isDark ? const Color(0xFF22314E) : Colors.grey.shade300),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Available Rooms', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A))),
                      if (!isLoading)
                        Text('${rooms.length} room type(s)', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (isLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator(color: Color(0xFFEAB308))))
                  else if (rooms.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF131D32) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? const Color(0xFF22314E) : Colors.grey.shade200),
                      ),
                      child: const Center(
                        child: Text('No available rooms for this hotel currently.', style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else
                    ...rooms.map((room) => _buildRoomCard(context, hotel, room, isDark)),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(BuildContext context, HotelModel hotel, RoomModel room, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D32) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: isDark ? const Color(0xFF22314E) : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child: room.firstImageUrl.trim().isNotEmpty
                  ? Image.network(
                      room.firstImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bed_outlined, size: 36, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                            const SizedBox(height: 4),
                            Text('No photo uploaded', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
                          ],
                        ),
                      ),
                    )
                  : Container(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bed_outlined, size: 36, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                          const SizedBox(height: 4),
                          Text('No photo uploaded', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      room.name != null && room.name!.trim().isNotEmpty
                          ? room.name!.trim()
                          : (room.type.isNotEmpty ? '${room.type} Room' : 'Hotel Room'),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Available', style: TextStyle(color: Color(0xFF15803D), fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.bed_outlined, size: 16, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(room.bedType, style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600, fontSize: 12)),
                    const SizedBox(width: 12),
                    Icon(Icons.person_outline, size: 16, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text('Max ${room.maxGuests} Guests', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
                if (room.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(room.description, style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600, fontSize: 12)),
                ],
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\$${room.priceUsd.toStringAsFixed(0)} / night',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF0F172A)),
                        ),
                        Text(
                          '~ ${room.priceKhr.toStringAsFixed(0)} KHR',
                          style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RoomSelectionScreen(hotel: hotel, initialRoom: room),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF006CE4),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                      child: const Text('Select Room', style: TextStyle(fontWeight: FontWeight.bold)),
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
