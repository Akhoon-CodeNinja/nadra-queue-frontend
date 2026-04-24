// ============================================================
//  theme_provider.dart
//  Dark / Light mode state — global ChangeNotifier
//  Usage: Provider.of<ThemeProvider>(context).isDark
// ============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _key = 'is_dark_mode';

  bool _isDark = false;
  bool get isDark => _isDark;

  ThemeProvider() {
    _loadFromPrefs();
  }

  /// Load saved preference on startup
  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool(_key) ?? false;
    notifyListeners();
  }

  /// Toggle and persist
  Future<void> toggle() async {
    _isDark = !_isDark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _isDark);
  }
}