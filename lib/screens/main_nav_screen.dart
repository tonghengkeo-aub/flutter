import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';
import '../widgets/stay_review_dialog.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'my_bookings_screen.dart';
import 'favorite_screen.dart';
import 'profile_screen.dart';

class MainNavScreen extends StatefulWidget {
  final String? timeoutAlertMessage;

  const MainNavScreen({super.key, this.timeoutAlertMessage});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int currentIndex = 0;
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();

  late final List<Widget> screens;

  @override
  void initState() {
    super.initState();
    screens = [
      HomeScreen(key: _homeKey),
      const SearchScreen(),
      const MyBookingsScreen(),
      const FavoriteScreen(),
      const ProfileScreen(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StayReviewDialog.checkAndShowPendingReview(context);

      if (widget.timeoutAlertMessage != null && widget.timeoutAlertMessage!.isNotEmpty) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.timer_off_rounded, color: Color(0xFFDC2626), size: 28),
                SizedBox(width: 10),
                Text('Payment Expired', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Text(
              widget.timeoutAlertMessage!,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F3E6C),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('OK / Book Again', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).bottomNavigationBarTheme.backgroundColor ?? Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: ThemeService.isDarkMode ? 0.3 : 0.06), blurRadius: 10, offset: const Offset(0, -2)),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (i) {
            if (i == 0) {
              _homeKey.currentState?.resetToHome();
            }
            setState(() => currentIndex = i);
          },
          backgroundColor: Theme.of(context).bottomNavigationBarTheme.backgroundColor ?? Theme.of(context).cardColor,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedItemColor: Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
          unselectedItemColor: Theme.of(context).bottomNavigationBarTheme.unselectedItemColor,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded, color: Theme.of(context).bottomNavigationBarTheme.selectedItemColor),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.search_rounded),
              activeIcon: Icon(Icons.search_rounded, color: Theme.of(context).bottomNavigationBarTheme.selectedItemColor),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month_rounded, color: Theme.of(context).bottomNavigationBarTheme.selectedItemColor),
              label: 'Booking',
            ),
            BottomNavigationBarItem(
              icon: ValueListenableBuilder<Set<int>>(
                valueListenable: ApiService.favoriteNotifier,
                builder: (context, favs, _) {
                  if (favs.isEmpty) {
                    return const Icon(Icons.favorite_border_rounded);
                  }
                  return Badge.count(
                    count: favs.length,
                    backgroundColor: Colors.redAccent,
                    child: const Icon(Icons.favorite_border_rounded),
                  );
                },
              ),
              activeIcon: ValueListenableBuilder<Set<int>>(
                valueListenable: ApiService.favoriteNotifier,
                builder: (context, favs, _) {
                  if (favs.isEmpty) {
                    return const Icon(Icons.favorite_rounded, color: Colors.redAccent);
                  }
                  return Badge.count(
                    count: favs.length,
                    backgroundColor: Colors.redAccent,
                    child: const Icon(Icons.favorite_rounded, color: Colors.redAccent),
                  );
                },
              ),
              label: 'Favorite',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.account_circle_outlined),
              activeIcon: Icon(Icons.account_circle_rounded, color: Theme.of(context).bottomNavigationBarTheme.selectedItemColor),
              label: 'Account',
            ),
          ],
        ),
      ),
    );
  }
}
