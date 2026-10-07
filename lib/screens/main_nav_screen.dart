import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'my_bookings_screen.dart';
import 'favorite_screen.dart';
import 'auth_screen.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int currentIndex = 0;

  final List<Widget> screens = [
    const HomeScreen(),
    const SearchScreen(),
    const MyBookingsScreen(),
    const FavoriteScreen(),
    const ProfileTab(),
  ];

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
          onTap: (i) => setState(() => currentIndex = i),
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

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  void _showEditProfileDialog() {
    final isDark = ThemeService.isDarkMode;
    final user = ApiService.currentUser;
    final nameCtrl = TextEditingController(text: user?.fullName ?? '');
    final phoneCtrl = TextEditingController(text: user?.phone ?? '');
    String selectedProvince = 'Phnom Penh';
    String selectedGender = 'Not Specified';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131D32) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Full Name *',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700),
                  prefixIcon: Icon(Icons.person_outline, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Phone Number *',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700),
                  prefixIcon: Icon(Icons.phone_outlined, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedProvince,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Province / City',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700),
                  prefixIcon: Icon(Icons.location_on_outlined, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                ),
                items: AuthScreen.cambodiaProvinces
                    .map((p) => DropdownMenuItem(value: p, child: Text(p, style: TextStyle(color: isDark ? Colors.white : Colors.black87))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) selectedProvince = val;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedGender,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Gender',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700),
                  prefixIcon: Icon(Icons.wc_outlined, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                ),
                items: ['Not Specified', 'Male', 'Female', 'Other']
                    .map((g) => DropdownMenuItem(value: g, child: Text(g, style: TextStyle(color: isDark ? Colors.white : Colors.black87))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) selectedGender = val;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await ApiService.updateProfile(
                fullName: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                gender: selectedGender,
                address: selectedProvince,
              );
              setState(() {});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile updated successfully!')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEAB308),
              foregroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final isDark = ThemeService.isDarkMode;
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131D32) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPassCtrl,
              obscureText: true,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'Current Password *',
                labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700),
                prefixIcon: Icon(Icons.lock_outline, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPassCtrl,
              obscureText: true,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'New Password * (Min 6 chars)',
                labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700),
                prefixIcon: Icon(Icons.lock_reset, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (oldPassCtrl.text.isEmpty || newPassCtrl.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter valid password details')),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await ApiService.changePassword(oldPassCtrl.text, newPassCtrl.text);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password changed successfully!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Update Password'),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog() {
    final isDark = ThemeService.isDarkMode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131D32) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A))),
        content: Text('Are you sure you want to sign out from your account?', style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiService.logout();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const AuthScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ApiService.currentUser;
    final isDark = ThemeService.isDarkMode;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Customer Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // User Profile Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: const Color(0xFFEAB308),
                    child: Text(
                      user != null && user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.fullName ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 2),
                        Text(user?.email ?? 'customer@gmail.com', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.phone_iphone, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(user?.phone ?? '012 xxx xxx', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Profile Actions & Settings
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  // App Theme (Dark Mode / Light Mode) Tile
                  ListTile(
                    leading: ValueListenableBuilder<ThemeMode>(
                      valueListenable: ThemeService.themeModeNotifier,
                      builder: (_, mode, _) => Icon(
                        mode == ThemeMode.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        color: mode == ThemeMode.dark ? const Color(0xFFFBBF24) : const Color(0xFF8B5CF6),
                      ),
                    ),
                    title: const Text('Dark Mode Appearance', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: ValueListenableBuilder<ThemeMode>(
                      valueListenable: ThemeService.themeModeNotifier,
                      builder: (_, mode, _) => Text(
                        mode == ThemeMode.dark ? 'Enabled (Luxury Dark Theme)' : 'Disabled (Crisp Light Theme)',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    trailing: ValueListenableBuilder<ThemeMode>(
                      valueListenable: ThemeService.themeModeNotifier,
                      builder: (ctx, mode, _) {
                        return Switch.adaptive(
                          value: mode == ThemeMode.dark,
                          activeThumbColor: const Color(0xFFFBBF24),
                          activeTrackColor: const Color(0xFF3B82F6),
                          onChanged: (val) {
                            ThemeService.setThemeMode(val ? ThemeMode.dark : ThemeMode.light);
                          },
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),

                  ListTile(
                    leading: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB)),
                    title: const Text('Edit Profile Details', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Update name, phone, address, gender', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: _showEditProfileDialog,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock_reset, color: Color(0xFF10B981)),
                    title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Update account security password', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: _showChangePasswordDialog,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.history, color: Color(0xFFF59E0B)),
                    title: const Text('Activity History', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('View recent profile & booking events', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('All actions are recorded securely on the backend server.')),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.support_agent, color: Color(0xFF64748B)),
                    title: const Text('Cambodia Support Helpline', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    trailing: const Text('023 888 999', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sign out button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _showSignOutDialog,
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                label: const Text('Sign Out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
