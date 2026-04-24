// ============================================================
//  forgot_password_screen.dart
//
//  Flow:
//  1. User enters CNIC + Email
//  2. API call → POST /api/forgot-password/
//  3. Backend verifies both, resets password, sends email
//  4. Success screen dikhayi deti hai
// ============================================================

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_config.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _cnicController  = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading  = false;
  bool _isSuccess  = false;   // success state ke liye

  // ── App ka main green color ───────────────────────────────
  static const _green = Color.fromARGB(250, 48, 125, 13);

  @override
  void dispose() {
    _cnicController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // ── API Call ─────────────────────────────────────────────
  Future<void> _submitForgotPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.forgotPassword),
            headers: {
              'Content-Type': 'application/json',
              'Accept'      : 'application/json',
            },
            body: jsonEncode({
              'CNIC' : _cnicController.text.trim(),
              'email': _emailController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 && data['success'] == true) {
        // ── Success: success UI dikhao ────────────────────
        setState(() => _isSuccess = true);
      } else {
        // ── Error: snackbar dikhao ────────────────────────
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message'] ?? 'Something went wrong. Please try again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network Error: Make sure backend is running.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Success Screen ────────────────────────────────────────
  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Green circle with check icon
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: _green,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mark_email_read_outlined,
                color: Colors.white,
                size: 52,
              ),
            ),
            const SizedBox(height: 28),

            const Text(
              'Email Sent!',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: _green,
              ),
            ),
            const SizedBox(height: 12),

            Text(
              'Aapka naya password\n${_emailController.text.trim()}\npe bhej diya gaya hai.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.grey,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 12),

            const Text(
              'Please check your inbox (and spam folder).',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(
                  'Back to Login',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Form Screen ───────────────────────────────────────────
  Widget _buildFormView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // ── Icon + Heading ──────────────────────────────
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_reset_outlined,
                  size: 42,
                  color: _green,
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Center(
              child: Text(
                'Forgot Password?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _green,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Apna CNIC aur registered email enter karein.\nHum aapko naya password bhej denge.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
              ),
            ),
            const SizedBox(height: 40),

            // ── CNIC Field ──────────────────────────────────
            const Text(
              'CNIC Number',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _cnicController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'XXXXX-XXXXXXX-X',
                prefixIcon: Icon(Icons.credit_card_outlined, color: _green),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'CNIC required hai';
                if (!RegExp(r'^\d{5}-\d{7}-\d{1}$').hasMatch(v.trim())) {
                  return 'Format hona chahiye: XXXXX-XXXXXXX-X';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ── Email Field ─────────────────────────────────
            const Text(
              'Registered Email',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'aapka@email.com',
                prefixIcon: Icon(Icons.email_outlined, color: _green),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email required hai';
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                    .hasMatch(v.trim())) {
                  return 'Valid email address enter karein';
                }
                return null;
              },
            ),
            const SizedBox(height: 36),

            // ── Submit Button ───────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitForgotPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        'Send New Password',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Back to Login ───────────────────────────────
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  '← Back to Login',
                  style: TextStyle(
                    color: _green,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _green),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Reset Password',
          style: TextStyle(
              color: _green, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: _isSuccess ? _buildSuccessView() : _buildFormView(),
      ),
    );
  }
}