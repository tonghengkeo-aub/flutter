import 'package:flutter/material.dart';

class HotelSurroundingsWidget extends StatefulWidget {
  const HotelSurroundingsWidget({super.key});

  @override
  State<HotelSurroundingsWidget> createState() => _HotelSurroundingsWidgetState();
}

class _HotelSurroundingsWidgetState extends State<HotelSurroundingsWidget> {
  int _selectedTab = 0;

  Widget _buildTab(String title, int index, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF2563EB) : const Color(0xFF003580))
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569))),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String name, String distance, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              name,
              style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B), fontWeight: FontWeight.w500),
            ),
          ),
          Row(
            children: [
              Icon(icon, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                distance,
                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildItems() {
    if (_selectedTab == 0) {
      return [
        _buildRow('Pepper Lunch', '15 min (4,300 ft)', Icons.directions_walk_rounded),
        _buildRow('Space Hair Salon and Bar', '2 min (780 ft)', Icons.directions_walk_rounded),
        _buildRow('Corner 136 Bar', '3 min (880 ft)', Icons.directions_walk_rounded),
        _buildRow('Loco Bar', '4 min (1,200 ft)', Icons.directions_walk_rounded),
      ];
    } else if (_selectedTab == 1) {
      return [
        _buildRow('Sorya Bus Station', '8 min (2,400 ft)', Icons.directions_walk_rounded),
        _buildRow('Phnom Penh Train Station', '12 min (1.2 mi)', Icons.directions_car_rounded),
        _buildRow('Phnom Penh Airport (PNH)', '35 min (6.2 mi)', Icons.directions_car_rounded),
      ];
    } else {
      return [
        _buildRow('Royal Palace & Silver Pagoda', '6 min (1,800 ft)', Icons.directions_walk_rounded),
        _buildRow('National Museum of Cambodia', '5 min (1,500 ft)', Icons.directions_walk_rounded),
        _buildRow('Wat Phnom Historical Hill', '10 min (2,900 ft)', Icons.directions_walk_rounded),
        _buildRow('Riverside Night Market', '3 min (900 ft)', Icons.directions_walk_rounded),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildTab('Restaurants', 0, Icons.restaurant_rounded),
              _buildTab('Public transit', 1, Icons.directions_bus_rounded),
              _buildTab('Attractions', 2, Icons.photo_camera_rounded),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ..._buildItems(),
      ],
    );
  }
}
