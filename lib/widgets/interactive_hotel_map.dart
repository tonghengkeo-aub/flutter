import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class InteractiveHotelMap extends StatefulWidget {
  final String? mapUrl;
  final String hotelName;
  final String locationAddress;
  final double height;
  final bool showControls;

  const InteractiveHotelMap({
    super.key,
    this.mapUrl,
    required this.hotelName,
    required this.locationAddress,
    this.height = 200,
    this.showControls = true,
  });

  static const String defaultGoogleMapsUrl = 'https://maps.app.goo.gl/HL3kPor7pDvYhUBT8';
  static const LatLng defaultHotelLocation = LatLng(11.485465, 104.941783);

  static LatLng extractCoordinates(String? url) {
    if (url == null || url.trim().isEmpty) {
      return defaultHotelLocation;
    }
    final cleanUrl = url.trim();

    // Check for user's specific hotel shortlink
    if (cleanUrl.contains('HL3kPor7pDvYhUBT8') ||
        cleanUrl.contains('11.485465') ||
        cleanUrl.toLowerCase().contains('takhmau') ||
        cleanUrl.toLowerCase().contains('ta khmau')) {
      return defaultHotelLocation;
    }

    // Try extracting explicit lat,lng in URL (e.g., /@11.485465,104.941783 or q=11.485465,104.941783)
    final regExp = RegExp(r'(-?\d{1,2}\.\d+)[,\s]+(-?\d{1,3}\.\d+)');
    final match = regExp.firstMatch(cleanUrl);
    if (match != null) {
      final lat = double.tryParse(match.group(1) ?? '');
      final lng = double.tryParse(match.group(2) ?? '');
      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
    }

    // City fallback presets
    if (cleanUrl.toLowerCase().contains('siem') || cleanUrl.toLowerCase().contains('angkor')) {
      return const LatLng(13.3633, 103.8564);
    }
    if (cleanUrl.toLowerCase().contains('sihanouk') || cleanUrl.toLowerCase().contains('otres')) {
      return const LatLng(10.6253, 103.5234);
    }

    return defaultHotelLocation;
  }

  @override
  State<InteractiveHotelMap> createState() => _InteractiveHotelMapState();
}

class _InteractiveHotelMapState extends State<InteractiveHotelMap> {
  late final MapController _mapController;
  late LatLng _hotelPoint;
  double _currentZoom = 15.5;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _hotelPoint = InteractiveHotelMap.extractCoordinates(widget.mapUrl);
  }

  @override
  void didUpdateWidget(covariant InteractiveHotelMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mapUrl != widget.mapUrl) {
      _hotelPoint = InteractiveHotelMap.extractCoordinates(widget.mapUrl);
    }
  }

  Future<void> _openGoogleMaps() async {
    final rawUrl = widget.mapUrl?.trim().isNotEmpty == true
        ? widget.mapUrl!.trim()
        : InteractiveHotelMap.defaultGoogleMapsUrl;

    final targetUrl = rawUrl.startsWith('http')
        ? rawUrl
        : 'https://maps.google.com/?q=${_hotelPoint.latitude},${_hotelPoint.longitude}';

    final uri = Uri.parse(targetUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (_) {
      // Fallback direct coordinate URL
      final fallbackUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${_hotelPoint.latitude},${_hotelPoint.longitude}');
      await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    }
  }

  void _zoomIn() {
    setState(() {
      _currentZoom = (_currentZoom + 1).clamp(3.0, 18.0);
      _mapController.move(_hotelPoint, _currentZoom);
    });
  }

  void _zoomOut() {
    setState(() {
      _currentZoom = (_currentZoom - 1).clamp(3.0, 18.0);
      _mapController.move(_hotelPoint, _currentZoom);
    });
  }

  void _recenter() {
    setState(() {
      _currentZoom = 15.5;
      _mapController.move(_hotelPoint, _currentZoom);
    });
  }

  void _openFullScreenMap(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: double.infinity,
            height: MediaQuery.of(ctx).size.height * 0.8,
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: _hotelPoint,
                    initialZoom: 16.0,
                    minZoom: 5.0,
                    maxZoom: 19.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.hotelbooking.customer_mobile_app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _hotelPoint,
                          width: 80,
                          height: 80,
                          child: _buildPinMarker(isDetailed: true),
                        ),
                      ],
                    ),
                  ],
                ),
                // Header bar with Close button
                Positioned(
                  top: 14,
                  left: 14,
                  right: 14,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on, color: Color(0xFFEF4444), size: 18),
                            const SizedBox(width: 6),
                            Text(
                              widget.hotelName.isNotEmpty ? widget.hotelName : 'Hotel Location',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      CircleAvatar(
                        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        radius: 18,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.close, size: 20, color: isDark ? Colors.white : Colors.black87),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ),
                    ],
                  ),
                ),
                // Bottom Button to Open Google Maps
                Positioned(
                  bottom: 18,
                  left: 20,
                  right: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A73E8), Color(0xFF1557B0)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1A73E8).withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _openGoogleMaps();
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.directions_rounded, color: Colors.white, size: 19),
                              SizedBox(width: 8),
                              Text(
                                'Open in Google Maps',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPinMarker({bool isDetailed = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isDetailed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A73E8), Color(0xFF1557B0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
            child: Text(
              widget.hotelName,
              style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
            ],
          ),
          child: const Center(
            child: Icon(Icons.hotel_rounded, color: Colors.white, size: 22),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final addressText = widget.locationAddress.isNotEmpty
        ? widget.locationAddress
        : 'National Road 2, Ta Khmau, Kandal';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The Interactive Map Canvas
          SizedBox(
            height: widget.height,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _hotelPoint,
                    initialZoom: _currentZoom,
                    minZoom: 5.0,
                    maxZoom: 19.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.hotelbooking.customer_mobile_app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _hotelPoint,
                          width: 50,
                          height: 50,
                          child: _buildPinMarker(),
                        ),
                      ],
                    ),
                  ],
                ),

                // Top Right: Controls (Zoom In, Zoom Out, Recenter, Fullscreen)
                if (widget.showControls)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMapActionButton(
                          icon: Icons.fullscreen_rounded,
                          tooltip: 'Full Screen Map',
                          onTap: () => _openFullScreenMap(context),
                          isDark: isDark,
                        ),
                        const SizedBox(height: 6),
                        _buildMapActionButton(
                          icon: Icons.add_rounded,
                          tooltip: 'Zoom In',
                          onTap: _zoomIn,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 6),
                        _buildMapActionButton(
                          icon: Icons.remove_rounded,
                          tooltip: 'Zoom Out',
                          onTap: _zoomOut,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 6),
                        _buildMapActionButton(
                          icon: Icons.my_location_rounded,
                          tooltip: 'Center Hotel',
                          onTap: _recenter,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Bottom Bar with Real Address & "Open in Google Maps" Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  width: 1.2,
                ),
              ),
            ),
            child: Row(
              children: [
                // Location Icon badge + Address text
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              addressText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Tap to navigate with Google Maps',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Premium Google Maps Action Button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _openGoogleMaps,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8.5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1A73E8), Color(0xFF1557B0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1A73E8).withValues(alpha: 0.38),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.directions_rounded, color: Colors.white, size: 15),
                          SizedBox(width: 6),
                          Text(
                            'Open in Google Maps',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: (isDark ? const Color(0xFF1E293B) : Colors.white).withValues(alpha: 0.92),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        elevation: 3,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(
              icon,
              size: 18,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ),
      ),
    );
  }
}
