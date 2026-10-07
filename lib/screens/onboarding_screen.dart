import 'package:flutter/material.dart';
import 'auth_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'Discover Luxury Hotel Rooms',
      'subtitle': 'Explore deluxe rooms, executive suites, and presidential villas in our premier hotel with instant confirmation.',
      'icon': Icons.hotel_rounded,
      'color': const Color(0xFFEAB308),
    },
    {
      'title': 'Real-Time Room Availability',
      'subtitle': 'Select your check-in dates and room preferences backed by live double-booking prevention.',
      'icon': Icons.meeting_room_rounded,
      'color': const Color(0xFF38BDF8),
    },
    {
      'title': 'Instant KHQR Pay & Check-In',
      'subtitle': 'Pay seamlessly with Bakong KHQR / ABA, view your booking pass, and enjoy a five-star hotel experience.',
      'icon': Icons.qr_code_scanner_rounded,
      'color': const Color(0xFF4ADE80),
    },
  ];

  void _finishOnboarding() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            // Top Skip bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'BOOKING PRO',
                    style: TextStyle(
                      color: Color(0xFFEAB308),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  if (_currentPage < _pages.length - 1)
                    TextButton(
                      onPressed: _finishOnboarding,
                      child: const Text('Skip', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    )
                  else
                    const SizedBox(height: 36),
                ],
              ),
            ),

            // PageView content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: (page['color'] as Color).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(color: (page['color'] as Color).withValues(alpha: 0.3), width: 2),
                          ),
                          child: Icon(
                            page['icon'] as IconData,
                            size: 70,
                            color: page['color'] as Color,
                          ),
                        ),
                        const SizedBox(height: 48),
                        Text(
                          page['title'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page['subtitle'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom controls: Page Indicator & Action Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (idx) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == idx ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == idx ? const Color(0xFFEAB308) : Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage < _pages.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          _finishOnboarding();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEAB308),
                        foregroundColor: const Color(0xFF0F172A),
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
