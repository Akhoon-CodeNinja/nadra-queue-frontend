// ============================================================
//  my_tokens_screen.dart
//  FIXES:
//  1. Cancel button now only shown for 'Active' tokens
//     (was shown for Completed tokens too — logic error)
//  2. Uses ApiConfig for URLs — works on all platforms
//  3. Added timeout to both API calls
// ============================================================

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class MyTokensScreen extends StatefulWidget {
  final int userId;

  const MyTokensScreen({super.key, required this.userId});

  @override
  State<MyTokensScreen> createState() => _MyTokensScreenState();
}

class _MyTokensScreenState extends State<MyTokensScreen> {
  List<dynamic> _tokens = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchTokens();
  }

  Future<void> _fetchTokens() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // FIXED: uses ApiConfig, added timeout
      final response = await http
          .get(Uri.parse(ApiConfig.myTokens(widget.userId)))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        setState(() {
          _tokens = decodedData['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load tokens: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error connecting to server. Is Django running?';
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelTokenAPI(int tokenId) async {
    try {
      // FIXED: uses ApiConfig, added timeout
      final response = await http
          .patch(Uri.parse(ApiConfig.cancelToken(tokenId)))
          .timeout(const Duration(seconds: 15));

      if (mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Token cancelled successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchTokens();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Failed to cancel: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Server Error: Could not connect.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('My Tokens',
            style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchTokens,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                    color: Color.fromARGB(250, 48, 125, 13)))
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_errorMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _fetchTokens,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                                minimumSize: const Size(120, 44)),
                          ),
                        ],
                      ),
                    ),
                  )
                : _tokens.isEmpty
                    ? const Center(
                        child: Text(
                            'No active or previous tokens found.'))
                    : ListView.builder(
                        itemCount: _tokens.length,
                        itemBuilder: (context, index) {
                          return _buildTokenUI(_tokens[index]);
                        },
                      ),
      ),
    );
  }

  Widget _buildTokenUI(Map<String, dynamic> token) {
    final int tokenId = token['token_id'] ?? 0;
    final String tokenNumber =
        token['token_number']?.toString() ?? 'N/A';
    final String locationName =
        token['location_name'] ?? 'NADRA — Branch';
    final String dateTime = token['date_time'] ?? 'Time not set';
    final String peopleAhead =
        token['people_ahead']?.toString() ?? '0';
    final String waitTime =
        token['est_wait_time']?.toString() ?? '0';
    final String status = token['status'] ?? 'Active';

    final bool isCancelled = status == 'Cancelled';
    final bool isCompleted = status == 'Completed';
    // FIXED: only Active tokens can be cancelled
    final bool isActive = status == 'Active';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Token header card ────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
          decoration: BoxDecoration(
            color: isCancelled
                ? Colors.grey.shade600
                : isCompleted
                    ? Colors.teal.shade700
                    : const Color.fromARGB(250, 48, 125, 13),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tokenNumber,
                    style: TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.bold,
                      color: isCancelled
                          ? Colors.white70
                          : Colors.white,
                      decoration: isCancelled
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.qr_code_2,
                        color: Colors.white, size: 36),
                  ),
                ],
              ),
              // Status label
              if (isCancelled)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('CANCELLED',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5)),
                ),
              if (isCompleted)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('COMPLETED',
                      style: TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5)),
                ),
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.location_on_outlined,
                    color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Text(locationName,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14)),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.calendar_today_outlined,
                    color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Text(dateTime,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
              ]),
            ],
          ),
        ),

        // ── Queue status (only for Active) ───────────────────
        if (isActive)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Queue Status Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                                Icons.check_circle_outline,
                                color: Colors.green,
                                size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text('Queue Status',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              Text("You're in line!",
                                  style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FA),
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  const Text('People Ahead',
                                      style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12)),
                                  const SizedBox(height: 6),
                                  Text(peopleAhead,
                                      style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              Color.fromARGB(250, 48, 125, 13))),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FA),
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  const Text('Est. Wait Time',
                                      style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12)),
                                  const SizedBox(height: 6),
                                  Text('~$waitTime m',
                                      style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              Color.fromARGB(250, 48, 125, 13))),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Office location card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Office Location',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_outlined,
                              color: Colors.grey, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(locationName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(
                                    token['address'] ??
                                        'Address not found',
                                    style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // FIXED: Cancel button only shown for Active tokens
                // Was: if (!isCancelled) → showed for Completed too
                Center(
                  child: TextButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(16)),
                          title: const Text('Cancel Token?',
                              style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold)),
                          content: Text(
                              'Are you sure you want to cancel token $tokenNumber?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('No')),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _cancelTokenAPI(tokenId);
                              },
                              child: const Text('Yes, Cancel',
                                  style:
                                      TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text(
                      'Cancel Token',
                      style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                          fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
      ],
    );
  }
}