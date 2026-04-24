// ============================================================
//  profile_screen.dart
//  UPDATED:
//  1. Edit Profile bottom sheet — fully functional (PATCH API)
//  2. Dark mode support via Theme.of(context)
//  3. Dark mode toggle switch in Settings
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_config.dart';
import 'login_screen.dart';
import 'theme_provider.dart';

// ── App green ─────────────────────────────────────────────────
const _kGreen = Color.fromARGB(250, 48, 125, 13);

class ProfileScreen extends StatefulWidget {
  final int userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _fullName = 'Loading...';
  String _email    = 'Loading...';
  String _cnic     = 'Loading...';
  String _mobile   = 'Loading...';
  String _dob      = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadUserData().then((_) => _fetchLatestProfileFromBackend());
  }

  // ── Load cached data ────────────────────────────────────
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _fullName = prefs.getString('full_name')     ?? 'Unknown User';
        _email    = prefs.getString('email')          ?? 'No Email Provided';
        _cnic     = prefs.getString('CNIC')            ?? 'Not Available';
        _mobile   = prefs.getString('Mobile_number')   ?? 'Not Available';
        _dob      = prefs.getString('DOB')             ?? 'Not Available';
      });
    }
  }

  // ── Fetch fresh from backend ────────────────────────────
  Future<void> _fetchLatestProfileFromBackend() async {
    final url = Uri.parse(ApiConfig.profile(widget.userId));
    try {
      final response =
          await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _fullName = data['full_name']     ?? _fullName;
            _email    = data['email']          ?? _email;
            _cnic     = data['CNIC']            ?? _cnic;
            _mobile   = data['Mobile_number']   ?? _mobile;
            _dob      = data['DOB']             ?? _dob;
          });
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('full_name',     data['full_name']     ?? '');
          await prefs.setString('email',          data['email']          ?? '');
          await prefs.setString('CNIC',            data['CNIC']            ?? '');
          await prefs.setString('Mobile_number',   data['Mobile_number']   ?? '');
          await prefs.setString('DOB',             data['DOB']             ?? '');
        }
      }
    } catch (e) {
      debugPrint('Profile fetch error: $e');
    }
  }

  // ── Logout ──────────────────────────────────────────────
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // ============================================================
  //  EDIT PROFILE BOTTOM SHEET  ← NEW
  // ============================================================
  void _openEditProfile() {
    final nameCtrl   = TextEditingController(text: _fullName);
    final emailCtrl  = TextEditingController(text: _email);
    final mobileCtrl = TextEditingController(text: _mobile);
    final dobCtrl    = TextEditingController(text: _dob);
    final formKey    = GlobalKey<FormState>();
    bool  saving     = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final labelColor = isDark ? Colors.grey[300]! : Colors.black87;

        return StatefulBuilder(
          builder: (ctx, setModalState) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Handle bar ─────────────────────────
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _kGreen,
                        ),
                      ),
                      Text(
                        'CNIC change nahi ho sakta.',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 12),
                      ),
                      const SizedBox(height: 20),

                      // ── Full Name ──────────────────────────
                      _EditField(
                        label: 'Full Name',
                        controller: nameCtrl,
                        icon: Icons.person_outline,
                        labelColor: labelColor,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Full name required hai';
                          }
                          return null;
                        },
                      ),

                      // ── Email ──────────────────────────────
                      _EditField(
                        label: 'Email Address',
                        controller: emailCtrl,
                        icon: Icons.email_outlined,
                        keyboard: TextInputType.emailAddress,
                        labelColor: labelColor,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email required hai';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                              .hasMatch(v.trim())) {
                            return 'Valid email enter karein';
                          }
                          return null;
                        },
                      ),

                      // ── Mobile ─────────────────────────────
                      _EditField(
                        label: 'Mobile Number',
                        controller: mobileCtrl,
                        icon: Icons.phone_outlined,
                        keyboard: TextInputType.phone,
                        labelColor: labelColor,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Mobile number required hai';
                          }
                          if (!RegExp(r'^03\d{9}$').hasMatch(v.trim())) {
                            return 'Format: 03XXXXXXXXX';
                          }
                          return null;
                        },
                      ),

                      // ── DOB ────────────────────────────────
                      _EditField(
                        label: 'Date of Birth',
                        controller: dobCtrl,
                        icon: Icons.calendar_today_outlined,
                        hint: 'YYYY-MM-DD',
                        labelColor: labelColor,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          if (!RegExp(r'^\d{4}-\d{2}-\d{2}$')
                              .hasMatch(v.trim())) {
                            return 'Format: YYYY-MM-DD';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 8),

                      // ── Save Button ────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) {
                                    return;
                                  }
                                  setModalState(() => saving = true);

                                  final success = await _saveProfile(
                                    fullName: nameCtrl.text.trim(),
                                    email: emailCtrl.text.trim(),
                                    mobile: mobileCtrl.text.trim(),
                                    dob: dobCtrl.text.trim(),
                                  );

                                  setModalState(() => saving = false);
                                  if (!mounted) return;

                                  Navigator.pop(ctx);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                            ? '✅ Profile update ho gaya!'
                                            : '❌ Update fail. Dobara try karein.',
                                      ),
                                      backgroundColor:
                                          success ? _kGreen : Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: saving
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5),
                                )
                              : const Text(
                                  'Save Changes',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── PATCH profile to backend ────────────────────────────
  Future<bool> _saveProfile({
    required String fullName,
    required String email,
    required String mobile,
    required String dob,
  }) async {
    try {
      final url = Uri.parse(ApiConfig.profile(widget.userId));
      final response = await http
          .patch(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'full_name': fullName,
              'email': email,
              'Mobile_number': mobile,
              'DOB': dob,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        // Update local state + cache
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _fullName = data['full_name']   ?? fullName;
            _email    = data['email']        ?? email;
            _mobile   = data['Mobile_number'] ?? mobile;
            _dob      = data['DOB']            ?? dob;
          });
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('full_name',   fullName);
        await prefs.setString('email',        email);
        await prefs.setString('Mobile_number', mobile);
        await prefs.setString('DOB',           dob);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Profile save error: $e');
      return false;
    }
  }

  // ============================================================
  //  BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final bgColor    = isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA);
    final cardColor  = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor  = isDark ? Colors.white : Colors.black87;
    final subColor   = isDark ? Colors.grey[400]! : Colors.grey;
    final iconBg     = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F4FF);
    final divColor   = isDark ? const Color(0xFF333333) : Colors.grey.shade200;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _kGreen),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Profile',
          style: TextStyle(
              color: _kGreen, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 10),

              // ── Avatar ──────────────────────────────────
              Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                    color: _kGreen, shape: BoxShape.circle),
                child: const Icon(Icons.person,
                    color: Colors.white, size: 50),
              ),
              const SizedBox(height: 12),
              Text(_fullName,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textColor)),
              const SizedBox(height: 4),
              Text('Active Member',
                  style: TextStyle(color: subColor, fontSize: 13)),
              const SizedBox(height: 24),

              // ── Personal Information ─────────────────────
              _SectionCard(
                title: 'Personal Information',
                cardColor: cardColor,
                textColor: textColor,
                children: [
                  _InfoTile(
                      icon: Icons.credit_card_outlined,
                      label: 'CNIC Number',
                      value: _cnic,
                      iconBg: iconBg,
                      textColor: textColor,
                      subColor: subColor),
                  Divider(height: 1, indent: 50, color: divColor),
                  _InfoTile(
                      icon: Icons.phone_outlined,
                      label: 'Mobile Number',
                      value: _mobile,
                      iconBg: iconBg,
                      textColor: textColor,
                      subColor: subColor),
                  Divider(height: 1, indent: 50, color: divColor),
                  _InfoTile(
                      icon: Icons.email_outlined,
                      label: 'Email Address',
                      value: _email,
                      iconBg: iconBg,
                      textColor: textColor,
                      subColor: subColor),
                  Divider(height: 1, indent: 50, color: divColor),
                  _InfoTile(
                      icon: Icons.calendar_today_outlined,
                      label: 'Date of Birth',
                      value: _dob,
                      iconBg: iconBg,
                      textColor: textColor,
                      subColor: subColor),
                  const SizedBox(height: 12),

                  // ── EDIT PROFILE BUTTON ← ACTIVATED ───────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openEditProfile,
                      icon: const Icon(Icons.edit_outlined,
                          color: _kGreen, size: 18),
                      label: const Text('Edit Profile',
                          style: TextStyle(
                              color: _kGreen,
                              fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _kGreen),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        minimumSize: const Size(double.infinity, 46),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Settings ────────────────────────────────
              _SectionCard(
                title: 'Settings',
                cardColor: cardColor,
                textColor: textColor,
                children: [
                  // Dark Mode Toggle ← NEW
                  _DarkModeTile(
                    isDark: themeProvider.isDark,
                    iconBg: iconBg,
                    textColor: textColor,
                    subColor: subColor,
                    onToggle: () => themeProvider.toggle(),
                  ),
                  Divider(height: 1, indent: 50, color: divColor),

                  _SettingsTile(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    subtitle: 'Manage alert preferences',
                    iconBg: iconBg,
                    textColor: textColor,
                    subColor: subColor,
                    onTap: () {},
                  ),
                  Divider(height: 1, indent: 50, color: divColor),
                  _SettingsTile(
                    icon: Icons.shield_outlined,
                    label: 'Privacy & Security',
                    subtitle: 'Password and security settings',
                    iconBg: iconBg,
                    textColor: textColor,
                    subColor: subColor,
                    onTap: () {},
                  ),
                  Divider(height: 1, indent: 50, color: divColor),
                  _SettingsTile(
                    icon: Icons.help_outline,
                    label: 'Help & Support',
                    subtitle: 'FAQs and customer service',
                    iconBg: iconBg,
                    textColor: textColor,
                    subColor: subColor,
                    onTap: () {},
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Logout ──────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: cardColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        title: Text('Logout?',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: textColor)),
                        content: Text(
                            'Are you sure you want to logout?',
                            style: TextStyle(color: subColor)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _logout();
                            },
                            child: const Text('Logout',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.logout, color: Colors.red, size: 18),
                  label: const Text('Logout',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(double.infinity, 46),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Edit Field Helper ─────────────────────────────────────────
class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType keyboard;
  final String? hint;
  final Color labelColor;
  final String? Function(String?)? validator;

  const _EditField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.labelColor,
    this.keyboard = TextInputType.text,
    this.hint,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: labelColor)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboard,
          validator: validator,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: _kGreen, size: 20),
            hintText: hint,
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

// ── Section Card ──────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final Color cardColor;
  final Color textColor;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.cardColor,
    required this.textColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textColor)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

// ── Info Tile ─────────────────────────────────────────────────
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconBg;
  final Color textColor;
  final Color subColor;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconBg,
    required this.textColor,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration:
                BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: _kGreen),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(color: subColor, fontSize: 12)),
                Text(value,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: textColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dark Mode Tile ────────────────────────────────────────────
class _DarkModeTile extends StatelessWidget {
  final bool isDark;
  final Color iconBg;
  final Color textColor;
  final Color subColor;
  final VoidCallback onToggle;

  const _DarkModeTile({
    required this.isDark,
    required this.iconBg,
    required this.textColor,
    required this.subColor,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration:
                BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
            child: Icon(
              isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              size: 18,
              color: _kGreen,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dark Mode',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: textColor)),
                Text(isDark ? 'On' : 'Off',
                    style: TextStyle(color: subColor, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: isDark,
            activeColor: _kGreen,
            onChanged: (_) => onToggle(),
          ),
        ],
      ),
    );
  }
}

// ── Settings Tile ─────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color iconBg;
  final Color textColor;
  final Color subColor;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.iconBg,
    required this.textColor,
    required this.subColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 18, color: _kGreen),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: textColor)),
                  Text(subtitle,
                      style: TextStyle(color: subColor, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: subColor),
          ],
        ),
      ),
    );
  }
}