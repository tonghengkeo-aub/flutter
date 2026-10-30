import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/hotel_model.dart';
import '../models/room_model.dart';
import '../models/service_model.dart';
import '../services/api_service.dart';
import 'booking_form_screen.dart';

class RoomOptionItem {
  final RoomModel room;
  final String roomName;
  final String roomDescription;
  final String bedDescription;
  final int maxAdults;
  final String sizeFt;
  final double currentPrice;
  final double originalPrice;
  final int availableUnits;
  final String discountTag;
  final String discountOffTag;
  final List<String> amenities;
  final String freeCancellationDate;
  final String thumbnail;
  final bool hasFreeCancellation;
  final bool noPrepayment;
  final bool includesBreakfast;
  final bool includesMassage;

  RoomOptionItem({
    required this.room,
    required this.roomName,
    required this.roomDescription,
    required this.bedDescription,
    required this.maxAdults,
    required this.sizeFt,
    required this.currentPrice,
    required this.originalPrice,
    required this.availableUnits,
    required this.discountTag,
    required this.discountOffTag,
    required this.amenities,
    required this.freeCancellationDate,
    required this.thumbnail,
    this.hasFreeCancellation = true,
    this.noPrepayment = true,
    this.includesBreakfast = false,
    this.includesMassage = false,
  });
}

class RoomSelectionScreen extends StatefulWidget {
  final HotelModel? hotel;
  final ServiceModel? service;
  final RoomModel? initialRoom;

  const RoomSelectionScreen({
    super.key,
    this.hotel,
    this.service,
    this.initialRoom,
  });

  @override
  State<RoomSelectionScreen> createState() => _RoomSelectionScreenState();
}

class _RoomSelectionScreenState extends State<RoomSelectionScreen> {
  bool isLoading = true;
  List<RoomOptionItem> roomOptions = [];
  int? selectedRoomId;
  int selectedUnits = 1;

  late DateTime checkInDate;
  late DateTime checkOutDate;

  @override
  void initState() {
    super.initState();
    checkInDate = DateTime.now().add(const Duration(days: 1));
    checkOutDate = DateTime.now().add(const Duration(days: 2));
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() => isLoading = true);

    int hotelId = widget.hotel?.id ?? widget.service?.hotelId ?? 1;
    List<RoomModel> backendRooms = [];
    try {
      backendRooms = await ApiService.getRoomsByHotel(hotelId);
    } catch (_) {}

    if (backendRooms.isEmpty && hotelId != 1) {
      try {
        backendRooms = await ApiService.getRoomsByHotel(1);
      } catch (_) {}
    }

    // Date strings for policies
    final cancelDateStr = DateFormat('MMM dd').format(checkInDate);

    // 1. Filter real rooms from backend matching this category or room
    List<RoomModel> targetRooms = [];

    if (widget.initialRoom != null) {
      // The user clicked on a specific room (e.g. Sweet Room)
      final sameType = backendRooms.where((r) =>
          r.type.toUpperCase() == widget.initialRoom!.type.toUpperCase() &&
          r.name != null &&
          r.name!.trim().isNotEmpty &&
          r.status == 'AVAILABLE').toList();

      if (sameType.isNotEmpty) {
        targetRooms = sameType;
      } else {
        targetRooms = [widget.initialRoom!];
      }
    } else {
      // User entered screen generally without a preselected room
      final targetType = (widget.service?.roomType ?? 'DOUBLE').toUpperCase();
      final matching = backendRooms.where((r) =>
          r.type.toUpperCase() == targetType &&
          r.name != null &&
          r.name!.trim().isNotEmpty &&
          r.status == 'AVAILABLE').toList();

      if (matching.isNotEmpty) {
        targetRooms = matching;
      } else {
        targetRooms = backendRooms.where((r) =>
            r.name != null &&
            r.name!.trim().isNotEmpty &&
            r.status == 'AVAILABLE').toList();
      }
    }

    if (targetRooms.isEmpty) {
      if (widget.initialRoom != null) {
        targetRooms = [widget.initialRoom!];
      } else if (backendRooms.isNotEmpty) {
        targetRooms = backendRooms.where((r) => r.status == 'AVAILABLE' || (r.availableUnits > 0 && r.status != 'MAINTENANCE' && r.status != 'CLEANING')).toList();
      }
    }

    // 2. Group rooms by tier (STANDARD, DELUXE, PREMIUM) so we never show confusing duplicates!
    // If the hotel has multiple physical rooms of the same tier (e.g. 2 or 3 Standard rooms),
    // we combine their available units so the customer sees "2 or 3 rooms left" as expected!
    final int? targetRoomId = widget.initialRoom?.id ?? widget.service?.id;

    List<RoomModel> sortedRooms = List.from(targetRooms);
    if (targetRoomId != null) {
      sortedRooms.sort((a, b) {
        if (a.id == targetRoomId) return -1;
        if (b.id == targetRoomId) return 1;
        return b.id.compareTo(a.id);
      });
    } else {
      sortedRooms.sort((a, b) => b.id.compareTo(a.id));
    }

    final Map<String, RoomModel> tierMap = {};
    final Map<String, int> tierUnits = {};

    for (final room in sortedRooms) {
      final tier = room.roomTier.toUpperCase();
      if (!tierMap.containsKey(tier)) {
        tierMap[tier] = room;
        tierUnits[tier] = room.availableUnits > 0 ? room.availableUnits : 1;
      } else {
        // Accumulate units from additional physical rooms of this tier
        tierUnits[tier] = (tierUnits[tier] ?? 1) + (room.availableUnits > 0 ? room.availableUnits : 1);
      }
    }

    // Desired tier display order: STANDARD -> DELUXE -> PREMIUM
    final tierOrder = ['STANDARD', 'DELUXE', 'PREMIUM'];
    List<RoomModel> distinctRooms = [];
    for (final t in tierOrder) {
      if (tierMap.containsKey(t)) distinctRooms.add(tierMap[t]!);
    }
    for (final entry in tierMap.entries) {
      if (!tierOrder.contains(entry.key)) distinctRooms.add(entry.value);
    }

    List<RoomOptionItem> items = [];

    for (final room in distinctRooms) {
      final tierKey = room.roomTier.toUpperCase();
      final totalAvail = tierUnits[tierKey] ?? room.availableUnits;
      final double price = room.priceUsd > 0 ? room.priceUsd : 30.0;
      final double orig = (price * 1.35).roundToDouble();
      final int diff = (orig - price).round();

      String tierTitle = tierKey == 'DELUXE'
          ? 'Deluxe Room'
          : (tierKey == 'PREMIUM' ? 'Premium Room' : 'Standard Room');

      // Use the actual custom name created in dashboard (e.g. "Sweet Room")
      String displayName = (room.name != null && room.name!.trim().isNotEmpty)
          ? room.name!.trim()
          : '$tierTitle • ${room.type} (Room ${room.roomNumber})';

      String badge = tierKey == 'DELUXE'
          ? 'Popular Choice • Deluxe Comfort'
          : (tierKey == 'PREMIUM' ? 'VIP All-Inclusive' : 'Standard Comfort • Best Value');

      String desc = room.description.trim().isNotEmpty
          ? room.description.trim()
          : (tierKey == 'DELUXE'
              ? (room.deluxeInfo != null && room.deluxeInfo!.isNotEmpty ? room.deluxeInfo! : 'Deluxe room with Air Conditioning (AC), Balcony & Flat-screen TV.')
              : (tierKey == 'PREMIUM'
                  ? (room.premiumInfo != null && room.premiumInfo!.isNotEmpty ? room.premiumInfo! : 'Executive VIP room with AC, Free Breakfast included & VIP perks.')
                  : (room.standardInfo != null && room.standardInfo!.isNotEmpty ? room.standardInfo! : 'Standard room with essential amenities at original base price.')));

      List<String> amenitiesList = room.amenities
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (amenitiesList.isEmpty) {
        amenitiesList = ['Free WiFi', 'Tea/Coffee maker', 'Balcony', 'Attached bathroom', 'City view'];
      }

      items.add(
        RoomOptionItem(
          room: room,
          roomName: displayName,
          roomDescription: desc,
          bedDescription: room.bedType.isNotEmpty ? room.bedType : '1 King Bed',
          maxAdults: room.maxGuests > 0 ? room.maxGuests : 2,
          sizeFt: room.roomSize.isNotEmpty ? room.roomSize.replaceAll('ft²', 'm²') : '28 m²',
          currentPrice: price,
          originalPrice: orig,
          availableUnits: totalAvail > 0 ? totalAvail : 1,
          discountTag: badge,
          discountOffTag: 'US\$$diff off',
          amenities: amenitiesList,
          freeCancellationDate: '23:59 on $cancelDateStr',
          thumbnail: room.firstImageUrl,
          hasFreeCancellation: room.freeCancellation,
          noPrepayment: room.noPrepayment,
          includesBreakfast: tierKey == 'PREMIUM' || room.includesBreakfast,
          includesMassage: room.includesMassage,
        ),
      );
    }

    if (mounted) {
      setState(() {
        if (items.isNotEmpty) {
          final int? targetRoomId = widget.initialRoom?.id ?? widget.service?.id;

          RoomOptionItem? preselected;
          if (targetRoomId != null) {
            final byId = items.where((it) => it.room.id == targetRoomId && it.availableUnits > 0);
            if (byId.isNotEmpty) preselected = byId.first;
          }
          preselected ??= items.firstWhere((it) => it.availableUnits > 0, orElse: () => items.first);

          selectedRoomId = preselected.room.id;
          selectedUnits = preselected.availableUnits > 0 ? 1 : 1;

          // Place the preselected room on top
          final selectedIndex = items.indexOf(preselected);
          if (selectedIndex > 0) {
            final selItem = items.removeAt(selectedIndex);
            items.insert(0, selItem);
          }
        }
        roomOptions = items;
        isLoading = false;
      });
    }
  }

  void _showUnitPicker(RoomOptionItem item) {
    if (item.availableUnits <= 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text('Sold Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text('Sorry, ${item.roomName} is completely sold out!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final maxUnits = item.availableUnits.clamp(1, 10);

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131D32) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select number of rooms',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Available: ${item.availableUnits} left at this property',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 12),
                ...List.generate(maxUnits, (index) {
                  final unit = index + 1;
                  final isSelected = selectedUnits == unit;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        selectedUnits = unit;
                      });
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? const Color(0xFF22314E) : Colors.grey.shade100,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$unit ${unit == 1 ? "unit" : "units"} (US\$${(item.currentPrice * unit).toStringAsFixed(0)})',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected
                                  ? const Color(0xFF006CE4)
                                  : (isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check, color: Color(0xFF006CE4), size: 20),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _proceedToReserve(RoomOptionItem selectedItem) {
    if (selectedItem.availableUnits <= 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text('Sold Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text('Sorry, ${selectedItem.roomName} is completely sold out!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    if (selectedUnits > selectedItem.availableUnits) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text('Inventory Alert', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text(
            'Sorry, only ${selectedItem.availableUnits} room${selectedItem.availableUnits > 1 ? "s" : ""} left.',
            style: const TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingFormScreen(
          hotel: widget.hotel,
          service: widget.service,
          room: selectedItem.room,
          unitCount: selectedUnits,
          customPrice: selectedItem.currentPrice * selectedUnits,
          initialCheckIn: checkInDate,
          initialCheckOut: checkOutDate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final propertyTitle = widget.hotel?.name ?? widget.service?.name ?? 'Boss_Heng Luxury Hotel';
    final dateStr =
        '${DateFormat('MMM dd').format(checkInDate)} - ${DateFormat('MMM dd').format(checkOutDate)}';

    RoomOptionItem? selectedItem;
    if (selectedRoomId != null) {
      final matches = roomOptions.where((r) => r.room.id == selectedRoomId);
      if (matches.isNotEmpty) {
        selectedItem = matches.first;
      }
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF003B95), // Booking.com Navy
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              propertyTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              'Select Room Type • $dateStr',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : roomOptions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bed_outlined, size: 56, color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No hotel rooms found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'All rooms have been removed or are currently unavailable.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  itemCount: roomOptions.length,
                  itemBuilder: (context, index) {
                    final item = roomOptions[index];
                    final isSelected = selectedRoomId == item.room.id;

                    return _buildRoomCard(item, isSelected, isDark);
                  },
                ),

      // Sticky Bottom Reserve Bar (Pic 4)
      bottomNavigationBar: selectedItem == null
          ? null
          : Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131D32) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Yellow banner (Pic 4)
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFFEBB02), // Booking.com yellow banner
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: const Center(
                      child: Text(
                        "You won't be charged yet",
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),

                  // Bottom Price & Reserve Button Row
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'US\$${(selectedItem.currentPrice * selectedUnits).toStringAsFixed(0)} • $selectedUnits ${selectedUnits > 1 ? "units" : "unit"}',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Includes taxes and fees',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _proceedToReserve(selectedItem!),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF006CE4), // Booking.com royal blue
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Reserve',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
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
    );
  }

  String _getTypeDisplayName(String? type) {
    switch (type?.toUpperCase()) {
      case 'SINGLE':
        return 'Single Room';
      case 'DOUBLE':
        return 'Double Room';
      case 'TWIN':
        return 'Twin Room';
      case 'TRIPLE':
        return 'Triple Room';
      case 'FAMILY':
        return 'Family Room';
      case 'SUITE':
      case 'VIP':
        return 'Suite Room';
      default:
        return (type != null && type.isNotEmpty) ? '$type Room' : 'Single Room';
    }
  }

  IconData _getRoomTypeIcon(String? type) {
    switch (type?.toUpperCase()) {
      case 'SINGLE':
        return Icons.single_bed_rounded;
      case 'DOUBLE':
        return Icons.king_bed_rounded;
      case 'TWIN':
        return Icons.bed_rounded;
      case 'TRIPLE':
        return Icons.bedroom_parent_rounded;
      case 'FAMILY':
        return Icons.family_restroom_rounded;
      case 'SUITE':
      case 'VIP':
        return Icons.meeting_room_rounded;
      default:
        return Icons.hotel_rounded;
    }
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
        icon = Icons.hotel_class_rounded;
        label = 'Deluxe Room';
        break;
      case 'PREMIUM':
      case 'VIP':
        bg = isDark ? const Color(0xFF4C1D95).withValues(alpha: 0.35) : const Color(0xFFFAF5FF);
        border = isDark ? const Color(0xFFA855F7) : const Color(0xFFD8B4FE);
        fg = isDark ? const Color(0xFFD8B4FE) : const Color(0xFF7E22CE);
        icon = Icons.diamond_rounded;
        label = 'Premium Room';
        break;
      case 'STANDARD':
      default:
        bg = isDark ? const Color(0xFF064E3B).withValues(alpha: 0.35) : const Color(0xFFECFDF5);
        border = isDark ? const Color(0xFF10B981) : const Color(0xFFA7F3D0);
        fg = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857);
        icon = Icons.task_alt_rounded;
        label = 'Standard Room';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
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

  Widget _buildRoomCard(RoomOptionItem item, bool isSelected, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D32) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF22314E) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Room Header & Thumbnail
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Room Type & Room Tier Tags (Pic 1/2/3: e.g. [ 🛏️ Single Room ] [ 🌿 Standard Room ])
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark ? const Color(0xFF3B82F6) : const Color(0xFFBFDBFE),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getRoomTypeIcon(item.room.type),
                                  size: 13,
                                  color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _getTypeDisplayName(item.room.type),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Prominent Room Tier Tag
                          _buildTierBadge(item.room.roomTier, isDark),
                          if (isSelected)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF006CE4),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white, size: 11),
                                  SizedBox(width: 4),
                                  Text(
                                    'SELECTED OPTION',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      Text(
                        item.roomName,
                        style: TextStyle(
                          color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF006CE4),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          height: 1.25,
                        ),
                      ),
                      if (item.roomDescription.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          item.roomDescription,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                            height: 1.35,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      // Specs: Sleeps, Bed, Size
                      Row(
                        children: [
                          Icon(Icons.people_alt_rounded, size: 15, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            'Sleeps ${item.maxAdults} adults',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.bed_outlined, size: 15, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.bedDescription,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.square_foot_rounded, size: 15, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            'Room size: ${item.sizeFt}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: item.thumbnail.trim().isNotEmpty
                          ? Image.network(
                              item.thumbnail,
                              width: 76,
                              height: 76,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 76,
                                height: 76,
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.bed_outlined, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), size: 28),
                                    const SizedBox(height: 2),
                                    Text(
                                      'No photo',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Container(
                              width: 76,
                              height: 76,
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.bed_outlined, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), size: 28),
                                  const SizedBox(height: 2),
                                  Text(
                                    'No photo',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    if (item.availableUnits <= 0)
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Sold Out',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Amenities Tags
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: item.amenities.map((a) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    a,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // Inner Offer Box (Pic 3 & Pic 4)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? const Color(0xFF0F264A) : const Color(0xFFF0F7FF))
                  : (isDark ? const Color(0xFF19243C) : const Color(0xFFF8FAFC)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF006CE4) // Selected royal blue border (Pic 4)
                    : (isDark ? const Color(0xFF2B3A58) : const Color(0xFFE2E8F0)),
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TOP: Price Row, Inventory Badge & Taxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Price for 1 night',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              'US\$${item.originalPrice.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 13,
                                decoration: TextDecoration.lineThrough,
                                color: isDark ? const Color(0xFF64748B) : Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'US\$${item.currentPrice.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
                          ],
                        ),
                        Text(
                          'Includes taxes and fees',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    // Inventory Badge (X rooms left)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: item.availableUnits > 0
                            ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7))
                            : (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2)),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: item.availableUnits > 0
                              ? (isDark ? const Color(0xFF059669) : const Color(0xFF86EFAC))
                              : (isDark ? const Color(0xFFDC2626) : const Color(0xFFFCA5A5)),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.availableUnits > 0 ? Icons.door_front_door_outlined : Icons.block,
                            size: 13,
                            color: item.availableUnits > 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.availableUnits > 0
                                ? '${item.availableUnits} rooms left'
                                : 'Sold Out',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: item.availableUnits > 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // TOP: Selection Controls (Make select stay on top first to easy look!)
                if (item.availableUnits <= 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'Sold Out',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                      ),
                    ),
                  )
                else if (!isSelected)
                  // Unselected State
                  Row(
                    children: [
                      Icon(
                        Icons.radio_button_unchecked,
                        color: isDark ? Colors.white38 : Colors.grey.shade400,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              selectedRoomId = item.room.id;
                              selectedUnits = 1;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF006CE4), // Booking.com royal blue
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Select',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  // Selected State
                  Row(
                    children: [
                      const Icon(
                        Icons.radio_button_checked,
                        color: Color(0xFF006CE4),
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      // Dropdown for Units (e.g. 1 unit, 2 units)
                      Expanded(
                        child: InkWell(
                          onTap: () => _showUnitPicker(item),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? const Color(0xFF3B82F6) : const Color(0xFF006CE4),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$selectedUnits ${selectedUnits == 1 ? "unit" : "units"}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Color(0xFF006CE4),
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Trash button to deselect
                      InkWell(
                        onTap: () {
                          setState(() {
                            selectedRoomId = null;
                            selectedUnits = 1;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? const Color(0xFF475569) : Colors.grey.shade300,
                            ),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Color(0xFFDC2626),
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 12),
                Divider(color: isDark ? const Color(0xFF2B3A58) : const Color(0xFFE2E8F0), height: 1),
                const SizedBox(height: 12),

                // Discount Badges (Genius discount)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 12, color: Colors.amber.shade900),
                          const SizedBox(width: 3),
                          Text(
                            item.discountTag,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.discountOffTag,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Real Perks List from Database
                if (item.hasFreeCancellation) ...[
                  _buildPerkRow(Icons.check, 'Free cancellation before ${item.freeCancellationDate}', const Color(0xFF059669)),
                  const SizedBox(height: 5),
                ],
                if (item.noPrepayment) ...[
                  _buildPerkRow(Icons.check, 'No prepayment needed – pay at the property', const Color(0xFF059669)),
                  const SizedBox(height: 5),
                ],
                if (item.includesBreakfast) ...[
                  _buildPerkRow(Icons.coffee_outlined, 'Breakfast included', const Color(0xFF059669)),
                  const SizedBox(height: 5),
                ],
                if (item.includesMassage) ...[
                  Row(
                    children: [
                      const Icon(Icons.check, color: Color(0xFF059669), size: 15),
                      const SizedBox(width: 6),
                      const Text(
                        'Includes 15-min massage',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF059669),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.info_outline, size: 13, color: Colors.grey.shade500),
                    ],
                  ),
                  const SizedBox(height: 5),
                ],

                if (item.availableUnits <= 0) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFFDC2626),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Sold Out - No units left',
                        style: TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerkRow(IconData icon, String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
