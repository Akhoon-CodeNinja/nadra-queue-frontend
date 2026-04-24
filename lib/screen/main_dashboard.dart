// ============================================================
//  main_dashboard.dart
//  UPDATED: Bottom navigation bar completely removed.
//           App sirf HomeScreen se chalta hai.
//           Sab screens HomeScreen ke quick-action cards se
//           Navigator.push() ke zariye open hoti hain.
// ============================================================

import 'package:flutter/material.dart';
import 'home_screen.dart';

class MainDashboard extends StatelessWidget {
  final int userId;

  const MainDashboard({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return HomeScreen(userId: userId);
  }
}