import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';
import '../widgets/stay_review_dialog.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _user;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _user = ApiService.currentUser;
    _refreshProfileData();
  }

  Future<void> _refreshProfileData() async {
    try {
      final updated = await ApiService.refreshProfile();
      if (mounted && updated != null) {
        setState(() => _user = updated);
      }
    } catch (_) {}
  }

  String _getUserInitials(String name) {
    if (name.trim().isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return name.trim().substring(0, 1).toUpperCase();
  }

  // ========================================================
  // AVATAR RESOLVER & RENDERING HELPER
  // ========================================================
  Widget _buildAvatarWidget({
    String? avatarUrl,
    Uint8List? localBytes,
    required double size,
    required String initials,
    bool isDark = false,
  }) {
    if (localBytes != null && localBytes.isNotEmpty) {
      return Image.memory(
        localBytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    }

    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      final trimmed = avatarUrl.trim();
      if (trimmed.startsWith('data:image')) {
        try {
          final comma = trimmed.indexOf(',');
          final b64 = comma != -1 ? trimmed.substring(comma + 1) : trimmed;
          final bytes = base64Decode(b64);
          return Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
          );
        } catch (_) {}
      }

      String networkUrl = trimmed;
      if (trimmed.startsWith('/uploads')) {
        networkUrl = 'http://localhost:8080$trimmed';
      }

      return Image.network(
        networkUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Center(
          child: Text(
            initials,
            style: TextStyle(
              fontSize: size * 0.35,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFEAB308),
            ),
          ),
        ),
      );
    }

    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.35,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFEAB308),
        ),
      ),
    );
  }

  // ========================================================
  // 1. CHANGE PROFILE PICTURE (REAL DEVICE UPLOAD ONLY)
  // ========================================================
  void _showAvatarPickerSheet() {
    final isDark = ThemeService.isDarkMode;
    Uint8List? pickedBytes;
    String? pickedFileName;
    bool isSheetUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final hasAnyAvatar = (_user?.avatarUrl != null && _user!.avatarUrl!.isNotEmpty) || pickedBytes != null;

          Future<void> pickFromSource(ImageSource source) async {
            try {
              final picker = ImagePicker();
              final XFile? image = await picker.pickImage(
                source: source,
                maxWidth: 1024,
                maxHeight: 1024,
                imageQuality: 88,
              );
              if (image != null) {
                final bytes = await image.readAsBytes();
                setModalState(() {
                  pickedBytes = bytes;
                  pickedFileName = image.name;
                });
              }
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not select image: $e'), backgroundColor: Colors.redAccent),
              );
            }
          }

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAB308).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.add_a_photo_rounded, color: Color(0xFFEAB308), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Change Profile Photo',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Upload a real photo from your device',
                                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, size: 20),
                        color: Colors.grey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Live Preview Center Circle
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEAB308), Color(0xFFF59E0B), Color(0xFF38BDF8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEAB308).withValues(alpha: 0.35),
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(3.5),
                          child: ClipOval(
                            child: Container(
                              color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                              child: _buildAvatarWidget(
                                avatarUrl: _user?.avatarUrl,
                                localBytes: pickedBytes,
                                size: 104,
                                initials: _getUserInitials(_user?.fullName ?? ''),
                                isDark: isDark,
                              ),
                            ),
                          ),
                        ),
                        if (pickedBytes != null)
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, size: 14, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Real Photo Upload Buttons (Device Gallery & Camera)
                  Text(
                    'Upload Real Photo from Device',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      // Choose from Device Button
                      Expanded(
                        child: InkWell(
                          onTap: isSheetUploading ? null : () => pickFromSource(ImageSource.gallery),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: pickedBytes != null ? const Color(0xFFEAB308) : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                                width: pickedBytes != null ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.photo_library_rounded, color: Color(0xFFEAB308), size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  'Choose from Device',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Camera Button
                      InkWell(
                        onTap: isSheetUploading ? null : () => pickFromSource(ImageSource.camera),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF38BDF8), size: 22),
                        ),
                      ),
                    ],
                  ),

                  // If file is selected from device, show selection badge
                  if (pickedBytes != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Selected: ${pickedFileName ?? 'photo.jpg'} (${(pickedBytes!.lengthInBytes / 1024).toStringAsFixed(1)} KB)',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              setModalState(() {
                                pickedBytes = null;
                                pickedFileName = null;
                              });
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    children: [
                      if (hasAnyAvatar)
                        Expanded(
                          flex: 1,
                          child: OutlinedButton(
                            onPressed: isSheetUploading
                                ? null
                                : () async {
                                    Navigator.pop(ctx);
                                    setState(() => _isLoading = true);
                                    try {
                                      final updated = await ApiService.updateProfile(
                                        fullName: _user?.fullName ?? '',
                                        phone: _user?.phone,
                                        gender: _user?.gender,
                                        address: _user?.address,
                                        avatarUrl: '',
                                      );
                                      setState(() {
                                        _user = updated;
                                        _isLoading = false;
                                      });
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Profile photo removed. Default initials active.'),
                                            backgroundColor: Color(0xFF0F172A),
                                          ),
                                        );
                                      }
                                    } catch (_) {
                                      setState(() => _isLoading = false);
                                    }
                                  },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.redAccent),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Remove', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      if (hasAnyAvatar) const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: isSheetUploading
                              ? null
                              : () async {
                                  if (pickedBytes == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Please choose a photo from your device first')),
                                    );
                                    return;
                                  }

                                  setModalState(() => isSheetUploading = true);
                                  try {
                                    final updatedUser = await ApiService.uploadAvatarFile(
                                      pickedBytes!,
                                      pickedFileName ?? 'avatar.jpg',
                                    );

                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                    }
                                    setState(() {
                                      _user = updatedUser;
                                    });

                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Row(
                                            children: [
                                              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                              SizedBox(width: 10),
                                              Text('Profile photo uploaded successfully!'),
                                            ],
                                          ),
                                          backgroundColor: Color(0xFF059669),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setModalState(() => isSheetUploading = false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Failed to upload photo: $e'), backgroundColor: Colors.redAccent),
                                      );
                                    }
                                  }
                                },
                          icon: isSheetUploading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
                                )
                              : const Icon(Icons.check_circle_outline_rounded, size: 18),
                          label: Text(
                            isSheetUploading ? 'Uploading...' : 'Save Profile Photo',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEAB308),
                            foregroundColor: const Color(0xFF0F172A),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ========================================================
  // 2. CHANGE PASSWORD (MODERN, SECURE & VALIDATED)
  // ========================================================
  void _showChangePasswordSheet() {
    final isDark = ThemeService.isDarkMode;
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();

    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSubmitting = false;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          // Password strength
          int strengthScore = 0;
          final pass = newPassCtrl.text;
          if (pass.length >= 6) strengthScore++;
          if (pass.length >= 8) strengthScore++;
          if (RegExp(r'[0-9]').hasMatch(pass) && RegExp(r'[a-zA-Z]').hasMatch(pass)) strengthScore++;
          if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(pass)) strengthScore++;

          Color strengthColor = Colors.grey;
          String strengthText = 'Too short';
          if (pass.isNotEmpty) {
            if (strengthScore <= 1) {
              strengthColor = Colors.redAccent;
              strengthText = 'Weak';
            } else if (strengthScore <= 3) {
              strengthColor = const Color(0xFFF59E0B);
              strengthText = 'Medium';
            } else {
              strengthColor = const Color(0xFF10B981);
              strengthText = 'Strong (Recommended)';
            }
          }

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.security_rounded, color: Color(0xFF10B981), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Change Account Password',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Protect your booking account with a secure key',
                                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, size: 20),
                        color: Colors.grey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 1. Current Password
                  Text(
                    'Current Password *',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: oldPassCtrl,
                    obscureText: obscureOld,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Enter current password',
                      hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400, fontSize: 13),
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(obscureOld ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                        onPressed: () => setModalState(() => obscureOld = !obscureOld),
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. New Password
                  Text(
                    'New Password * (Min 6 characters)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: newPassCtrl,
                    obscureText: obscureNew,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Create strong new password',
                      hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400, fontSize: 13),
                      prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                        onPressed: () => setModalState(() => obscureNew = !obscureNew),
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
                    ),
                    onChanged: (val) => setModalState(() {}),
                  ),

                  // Password Strength Bar
                  if (pass.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (strengthScore / 4).clamp(0.2, 1.0),
                              backgroundColor: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
                              minHeight: 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          strengthText,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: strengthColor),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),

                  // 3. Confirm New Password
                  Text(
                    'Confirm New Password *',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: confirmPassCtrl,
                    obscureText: obscureConfirm,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Re-enter new password to verify',
                      hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400, fontSize: 13),
                      prefixIcon: const Icon(Icons.verified_user_outlined, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                        onPressed: () => setModalState(() => obscureConfirm = !obscureConfirm),
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final oldP = oldPassCtrl.text.trim();
                              final newP = newPassCtrl.text.trim();
                              final confirmP = confirmPassCtrl.text.trim();

                              if (oldP.isEmpty) {
                                setModalState(() => errorMessage = 'Please enter your current password.');
                                return;
                              }
                              if (newP.length < 6) {
                                setModalState(() => errorMessage = 'New password must be at least 6 characters.');
                                return;
                              }
                              if (newP != confirmP) {
                                setModalState(() => errorMessage = 'New password and confirmation do not match.');
                                return;
                              }
                              if (oldP == newP) {
                                setModalState(() => errorMessage = 'New password must be different from current password.');
                                return;
                              }

                              setModalState(() {
                                isSubmitting = true;
                                errorMessage = null;
                              });

                              try {
                                await ApiService.changePassword(oldP, newP);
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                        SizedBox(width: 10),
                                        Text('Password updated successfully!'),
                                      ],
                                    ),
                                    backgroundColor: Color(0xFF059669),
                                  ),
                                );
                              } catch (e) {
                                setModalState(() {
                                  isSubmitting = false;
                                  errorMessage = e.toString().replaceAll('Exception: ', '');
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text('Update Password Securely', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ========================================================
  // 3. EDIT PROFILE DETAILS
  // ========================================================
  void _showEditProfileSheet() {
    final isDark = ThemeService.isDarkMode;
    final nameCtrl = TextEditingController(text: _user?.fullName ?? '');
    final phoneCtrl = TextEditingController(text: _user?.phone ?? '');
    String selectedProvince = _user?.address != null && AuthScreen.cambodiaProvinces.contains(_user!.address)
        ? _user!.address!
        : 'Phnom Penh';
    String selectedGender = _user?.gender != null && ['Male', 'Female', 'Other', 'Not Specified'].contains(_user!.gender)
        ? _user!.gender!
        : 'Not Specified';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.badge_rounded, color: Color(0xFF2563EB), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Edit Profile Details',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Keep your contact & guest info updated',
                                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, size: 20),
                        color: Colors.grey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Full Name
                  Text(
                    'Full Name *',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'e.g. Sophea Pich',
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Phone Number
                  Text(
                    'Phone Number',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'e.g. 098 111 222',
                      prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Province / City
                  Text(
                    'Province / City',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedProvince,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                    ),
                    items: AuthScreen.cambodiaProvinces
                        .map((p) => DropdownMenuItem(value: p, child: Text(p, style: TextStyle(color: isDark ? Colors.white : Colors.black87))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedProvince = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Gender
                  Text(
                    'Gender',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedGender,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.wc_outlined, size: 20),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                    ),
                    items: ['Not Specified', 'Male', 'Female', 'Other']
                        .map((g) => DropdownMenuItem(value: g, child: Text(g, style: TextStyle(color: isDark ? Colors.white : Colors.black87))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedGender = val);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Save Changes Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Full name cannot be empty')),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        setState(() => _isLoading = true);
                        try {
                          final updated = await ApiService.updateProfile(
                            fullName: nameCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                            gender: selectedGender,
                            address: selectedProvince,
                            avatarUrl: _user?.avatarUrl,
                          );
                          setState(() {
                            _user = updated;
                            _isLoading = false;
                          });
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                    SizedBox(width: 10),
                                    Text('Profile details updated successfully!'),
                                  ],
                                ),
                                backgroundColor: Color(0xFF059669),
                              ),
                            );
                          }
                        } catch (e) {
                          setState(() => _isLoading = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error updating profile: $e'), backgroundColor: Colors.redAccent),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEAB308),
                        foregroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                      child: const Text('Save Profile Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ========================================================
  // 4. SIGN OUT CONFIRMATION DIALOG
  // ========================================================
  void _showSignOutDialog() {
    final isDark = ThemeService.isDarkMode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131D32) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Sign Out',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to sign out from your luxury hotel account?',
          style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : Colors.black87, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              StayReviewDialog.dismissedInThisSession.clear();
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
            child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user ?? ApiService.currentUser;
    final isDark = ThemeService.isDarkMode;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Customer Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            tooltip: 'Refresh Profile',
            onPressed: () async {
              setState(() => _isLoading = true);
              await _refreshProfileData();
              if (!mounted) return;
              setState(() => _isLoading = false);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile refreshed!'), duration: Duration(seconds: 1)),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFEAB308)))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  // ==========================================
                  // 1. LUXURY USER PROFILE HEADER CARD
                  // ==========================================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                            : [const Color(0xFFFFFFFF), const Color(0xFFF8FAFC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Avatar with glowing ring & Camera Floating Button
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFEAB308), Color(0xFFF59E0B), Color(0xFF38BDF8)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFEAB308).withValues(alpha: 0.35),
                                    blurRadius: 14,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(3.5),
                              child: ClipOval(
                                child: Container(
                                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                  child: _buildAvatarWidget(
                                    avatarUrl: user?.avatarUrl,
                                    size: 96,
                                    initials: _getUserInitials(user?.fullName ?? ''),
                                    isDark: isDark,
                                  ),
                                ),
                              ),
                            ),
                            // Camera Edit Floating Button
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _showAvatarPickerSheet,
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAB308),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.25),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 16,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Full Name with Verified Badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              user?.fullName ?? 'Customer',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.verified_rounded, color: Color(0xFFEAB308), size: 18),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Email
                        Text(
                          user?.email ?? 'customer@booking.com',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Phone & Location pill
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (user?.phone != null && user!.phone.isNotEmpty) ...[
                              Icon(Icons.phone_iphone_rounded, size: 14, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                user.phone,
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            if (user?.address != null && user!.address!.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(Icons.location_on_rounded, size: 14, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                user.address!,
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),

                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ==========================================
                  // 2. QUICK STATS RIBBON
                  // ==========================================
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickStatCard(
                          icon: Icons.luggage_rounded,
                          iconColor: const Color(0xFF38BDF8),
                          title: '${BookingService.localBookings.length}',
                          subtitle: 'Stays Booked',
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ValueListenableBuilder<Set<int>>(
                          valueListenable: ApiService.favoriteNotifier,
                          builder: (_, favs, _) {
                            return _buildQuickStatCard(
                              icon: Icons.favorite_rounded,
                              iconColor: Colors.redAccent,
                              title: '${favs.length}',
                              subtitle: 'Wishlist',
                              isDark: isDark,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildQuickStatCard(
                          icon: Icons.stars_rounded,
                          iconColor: const Color(0xFFEAB308),
                          title: '5.0 ★',
                          subtitle: 'Guest Rating',
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ==========================================
                  // 3. SETTINGS & PROFILE ACTIONS
                  // ==========================================
                  Material(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          // 1. Dark Mode Switch
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isDark ? const Color(0xFFFBBF24) : const Color(0xFF8B5CF6)).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ValueListenableBuilder<ThemeMode>(
                                valueListenable: ThemeService.themeModeNotifier,
                                builder: (_, mode, _) => Icon(
                                  mode == ThemeMode.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                  color: mode == ThemeMode.dark ? const Color(0xFFFBBF24) : const Color(0xFF8B5CF6),
                                  size: 20,
                                ),
                              ),
                            ),
                            title: const Text('Dark Mode Appearance', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: ValueListenableBuilder<ThemeMode>(
                              valueListenable: ThemeService.themeModeNotifier,
                              builder: (_, mode, _) => Text(
                                mode == ThemeMode.dark ? 'Enabled (Luxury Dark Theme)' : 'Disabled (Crisp Light Theme)',
                                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
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

                          // 2. Change Profile Photo
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAB308).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.camera_alt_outlined, color: Color(0xFFEAB308), size: 20),
                            ),
                            title: const Text('Update Profile Picture', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text('Change your luxury avatar or image link', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600)),
                            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                            onTap: _showAvatarPickerSheet,
                          ),
                          const Divider(height: 1),

                          // 3. Edit Personal Details
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB), size: 20),
                            ),
                            title: const Text('Edit Personal Details', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text('Update name, phone, province & gender', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600)),
                            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                            onTap: _showEditProfileSheet,
                          ),
                          const Divider(height: 1),

                          // 4. Change Password
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.lock_reset_rounded, color: Color(0xFF10B981), size: 20),
                            ),
                            title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text('Update account security password', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600)),
                            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                            onTap: _showChangePasswordSheet,
                          ),
                          const Divider(height: 1),

                          // 5. Cambodia Support Helpline
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF64748B).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.support_agent_rounded, color: Color(0xFF64748B), size: 20),
                            ),
                            title: const Text('Cambodia Support Helpline', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: const Text('24/7 dedicated guest concierge', style: TextStyle(fontSize: 12)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.call, size: 12, color: Color(0xFF10B981)),
                                  SizedBox(width: 4),
                                  Text(
                                    '095 727 675',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF10B981)),
                                  ),
                                ],
                              ),
                            ),
                            onTap: () async {
                              final uri = Uri.parse('tel:095727675');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ==========================================
                  // 4. SIGN OUT BUTTON
                  // ==========================================
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _showSignOutDialog,
                      icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                      label: const Text('Sign Out of Account', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent, width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Footer info
                  Center(
                    child: Text(
                      'Hotel Booking App v1.0.0 • Cambodia Luxury Stays',
                      style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildQuickStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

// For backwards compatibility
typedef ProfileTab = ProfileScreen;
