import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'main_nav_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  String _hotelName = RoomService.cachedHotel?.name.isNotEmpty == true
      ? RoomService.cachedHotel!.name
      : 'Boss_Heng Luxury Hotel';
  String _hotelTagline = RoomService.cachedHotel?.tagline.isNotEmpty == true
      ? RoomService.cachedHotel!.tagline
      : 'Unified Appointments & Stays Booking';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    // 1. Instantly restore saved hotel name from SharedPreferences
    SharedPreferences.getInstance().then((prefs) {
      final savedName = prefs.getString('cached_hotel_name');
      final savedTagline = prefs.getString('cached_hotel_tagline');
      if (mounted) {
        if (savedName != null && savedName.isNotEmpty) {
          setState(() => _hotelName = savedName);
        }
        if (savedTagline != null && savedTagline.isNotEmpty) {
          setState(() => _hotelTagline = savedTagline);
        }
      }
    });

    // 2. Fetch live hotel data so changes in Admin Dashboard immediately update the mobile app
    RoomService.getDefaultHotel().then((hotel) async {
      if (mounted && hotel.name.isNotEmpty) {
        setState(() {
          _hotelName = hotel.name;
          if (hotel.tagline.isNotEmpty) {
            _hotelTagline = hotel.tagline;
          }
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_hotel_name', hotel.name);
        await prefs.setString('cached_hotel_tagline', hotel.tagline);
      }
    }).catchError((_) {});

    // Check login state and navigate after 2.2 seconds
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      if (ApiService.authToken != null && ApiService.currentUser != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEAB308), Color(0xFFCA8A04)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEAB308).withValues(alpha: 0.35),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.hotel_rounded, size: 54, color: Colors.white),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _hotelName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _hotelTagline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    backgroundColor: Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEAB308)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
