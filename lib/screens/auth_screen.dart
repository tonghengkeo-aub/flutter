import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'main_nav_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  static const List<String> cambodiaProvinces = [
    'Phnom Penh',
    'Banteay Meanchey',
    'Battambang',
    'Kampong Cham',
    'Kampong Chhnang',
    'Kampong Speu',
    'Kampong Thom',
    'Kampot',
    'Kandal',
    'Kep',
    'Koh Kong',
    'Kratie',
    'Mondulkiri',
    'Oddar Meanchey',
    'Pailin',
    'Preah Sihanouk',
    'Preah Vihear',
    'Prey Veng',
    'Pursat',
    'Ratanakiri',
    'Siem Reap',
    'Stung Treng',
    'Svay Rieng',
    'Takeo',
    'Tboung Khmum',
  ];

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool isLoading = false;
  bool obscurePassword = true;

  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  String selectedGender = 'Not Specified';
  String selectedProvince = 'Phnom Penh';

  @override
  void initState() {
    super.initState();
    RoomService.getDefaultHotel().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);
    try {
      if (isLogin) {
        await ApiService.login(emailController.text.trim(), passwordController.text);
      } else {
        await ApiService.register(
          nameController.text.trim(),
          phoneController.text.trim(),
          emailController.text.trim(),
          passwordController.text,
          gender: selectedGender,
          address: selectedProvince,
        );
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEAB308), Color(0xFFCA8A04)],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEAB308).withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.calendar_month_rounded, size: 40, color: Color(0xFF0F172A)),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    RoomService.cachedHotel?.name.isNotEmpty == true
                        ? RoomService.cachedHotel!.name
                        : 'Boss_Heng Luxury Hotel',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Center(
                  child: Text(
                    RoomService.cachedHotel?.tagline.isNotEmpty == true
                        ? RoomService.cachedHotel!.tagline
                        : 'Luxury Hotel Rooms, Suites & Villas Booking',
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),

                // Form Container
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLogin ? 'Customer Sign In' : 'Create New Account',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 18),

                      if (!isLogin) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildLabel('Full Name *'),
                            const Padding(
                              padding: EdgeInsets.only(bottom: 6),
                              child: Text(
                                'Letters only (A-Z)',
                                style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                        TextFormField(
                          controller: nameController,
                          keyboardType: TextInputType.name,
                          textCapitalization: TextCapitalization.words,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          style: const TextStyle(color: Colors.white),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\u1780-\u17FF\s\.\-']")),
                            LengthLimitingTextInputFormatter(60),
                          ],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter your full name';
                            }
                            final trimmed = v.trim();
                            if (trimmed.length < 2) {
                              return 'Full name must be at least 2 letters';
                            }
                            if (RegExp(r'[0-9]').hasMatch(trimmed)) {
                              return 'Full name can only contain letters (no numbers)';
                            }
                            if (!RegExp(r"^[a-zA-Z\u1780-\u17FF\s\.\-']+$").hasMatch(trimmed)) {
                              return 'Full name can only contain valid letters';
                            }
                            return null;
                          },
                          decoration: _inputDecoration('e.g. Sophea Pich', Icons.person_outline),
                        ),
                        const SizedBox(height: 14),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildLabel('Phone Number *'),
                            const Padding(
                              padding: EdgeInsets.only(bottom: 6),

                              child: Text(
                                'Numbers only ',
                                style: TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.w500),
                              ),
                              
                            ),
                          ],
                        ),
                        TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.number,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          style: const TextStyle(color: Colors.white),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(12),
                          ],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter your phone number';
                            }
                            final trimmed = v.trim();
                            if (!RegExp(r'^[0-9]+$').hasMatch(trimmed)) {
                              return 'Phone number can only contain numbers (0-9)';
                            }
                            if (trimmed.length < 8 || trimmed.length > 12) {
                              return 'Phone number must be 8 to 12 digits';
                            }
                            return null;
                          },
                          decoration: _inputDecoration('012345678', Icons.phone_outlined),
                        ),
                        const SizedBox(height: 14),

                        _buildLabel('Gender'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedGender,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF1E293B),
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              items: ['Not Specified', 'Male', 'Female', 'Other']
                                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => selectedGender = val);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        _buildLabel('Province / City (Cambodia)'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on_outlined, color: Colors.white54, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedProvince,
                                    isExpanded: true,
                                    dropdownColor: const Color(0xFF1E293B),
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                                    items: AuthScreen.cambodiaProvinces
                                        .map((p) => DropdownMenuItem(
                                              value: p,
                                              child: Text(p),
                                            ))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => selectedProvince = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      _buildLabel('Email Address *'),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        style: const TextStyle(color: Colors.white),
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Please enter your email';
                          final trimmed = v.trim();
                          if (!RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,}$').hasMatch(trimmed)) {
                            return 'Please enter a valid email address (e.g. user@domain.com)';
                          }
                          return null;
                        },
                        decoration: _inputDecoration('user@domain.com', Icons.email_outlined),
                      ),
                      const SizedBox(height: 14),

                      _buildLabel('Password *'),
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        style: const TextStyle(color: Colors.white),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Please enter password';
                          if (v.length < 6) return 'Password must be at least 6 characters';
                          return null;
                        },
                        decoration: _inputDecoration('••••••••', Icons.lock_outline).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.white54,
                              size: 20,
                            ),
                            onPressed: () => setState(() => obscurePassword = !obscurePassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEAB308),
                            foregroundColor: const Color(0xFF0F172A),
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
                                )
                              : Text(
                                  isLogin ? 'Sign In' : 'Create Account',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),

                      if (isLogin) ...[
                        const SizedBox(height: 18),
                        const Divider(color: Colors.white12),
                        const SizedBox(height: 8),
                        const Text(
                          'Demo Accounts (Tap to auto-fill):',
                          style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    emailController.text = 'customer@booking.com';
                                    passwordController.text = 'password123';
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white24),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                child: const Text(
                                  'Customer Demo',
                                  style: TextStyle(color: Color(0xFFEAB308), fontSize: 11),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    emailController.text = 'dara@booking.com';
                                    passwordController.text = 'password123';
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white24),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                child: const Text(
                                  'Dara Demo',
                                  style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Toggle Auth Mode
                Center(
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        isLogin = !isLogin;
                        _formKey.currentState?.reset();
                      });
                    },
                    child: Text(
                      isLogin
                          ? "Don't have an account? Create one"
                          : 'Already have an account? Sign In',
                      style: const TextStyle(color: Color(0xFFEAB308), fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.white54, size: 20),
      filled: true,
      fillColor: const Color(0xFF0F172A),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEAB308), width: 1.5),
      ),
    );
  }
}
