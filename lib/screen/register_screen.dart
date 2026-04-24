// ============================================================
//  register_screen.dart
//  FIX: Uses ApiConfig.register instead of hardcoded 127.0.0.1
//       Works correctly on Android emulator, PC, and real device
// ============================================================

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_config.dart';
import 'login_screen.dart';

// ── App green — consistent with all other screens ─────────────
const _kGreen = Color.fromARGB(250, 48, 125, 13);

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _cnicController = TextEditingController();
  final _dobController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _cnicController.dispose();
    _dobController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // FIXED: uses ApiConfig.register — correct URL on all platforms
      final response = await http
          .post(
            Uri.parse(ApiConfig.register),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'full_name': _nameController.text.trim(),
              'CNIC': _cnicController.text.trim(),
              'password': _passwordController.text,
              'DOB': _dobController.text.trim(),
              'Mobile_number': _mobileController.text.trim(),
              'email': _emailController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Registration Successful! Please login.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Registration Failed: ${errorData['message'] ?? errorData}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Network Error: Make sure backend is running. ($e)')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    String hint = '',
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? toggleObscure,
    TextInputType keyboard = TextInputType.text,
    bool isOptional = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
            if (isOptional)
              const Text('  (Optional)',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword ? obscure : false,
          keyboardType: keyboard,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: toggleObscure,
                  )
                : null,
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: _kGreen),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 8),
                    const Text('Create Account',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _kGreen)),
                  ],
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _nameController,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Full name is required';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                      hintText: 'Enter your full name'),
                ),
                const SizedBox(height: 14),

                _buildField(
                  'CNIC Number',
                  _cnicController,
                  hint: 'XXXXX-XXXXXXX-X',
                  keyboard: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'CNIC is required';
                    if (!RegExp(r'^\d{5}-\d{7}-\d{1}$').hasMatch(v)) {
                      return 'Format must be XXXXX-XXXXXXX-X';
                    }
                    return null;
                  },
                ),

                _buildField(
                  'Date of Birth',
                  _dobController,
                  hint: 'YYYY-MM-DD',
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Date of Birth is required';
                    }
                    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) {
                      return 'Format must be YYYY-MM-DD';
                    }
                    return null;
                  },
                ),

                _buildField(
                  'Mobile Number',
                  _mobileController,
                  hint: '03XXXXXXXXX',
                  keyboard: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Mobile number is required';
                    }
                    if (!RegExp(r'^03\d{9}$').hasMatch(v)) {
                      return 'Format must be 03XXXXXXXXX (11 digits)';
                    }
                    return null;
                  },
                ),

                _buildField(
                  'Email Address',
                  _emailController,
                  hint: 'your.email@example.com',
                  keyboard: TextInputType.emailAddress,
                  isOptional: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    if (!RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(v)) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),

                _buildField(
                  'Password',
                  _passwordController,
                  hint: 'Create a password',
                  isPassword: true,
                  obscure: _obscurePassword,
                  toggleObscure: () => setState(
                      () => _obscurePassword = !_obscurePassword),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Password is required';
                    }
                    if (v.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),

                _buildField(
                  'Confirm Password',
                  _confirmPasswordController,
                  hint: 'Re-enter your password',
                  isPassword: true,
                  obscure: _obscureConfirm,
                  toggleObscure: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (v != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text('Register',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account? ',
                        style: TextStyle(color: Colors.grey)),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LoginScreen()),
                      ),
                      child: const Text('Login',
                          style: TextStyle(
                              color: _kGreen,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}