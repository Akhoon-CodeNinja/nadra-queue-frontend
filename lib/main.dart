// ============================================================
//  main.dart
//  UPDATED: Dark mode support via ThemeProvider + Provider
//
//  pubspec.yaml add karein:
//    provider: ^6.1.2
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screen/login_screen.dart';
import 'screen/theme_provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const NADRAApp(),
    ),
  );
}

class NADRAApp extends StatelessWidget {
  const NADRAApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // ── Shared button style ───────────────────────────────
    final elevatedBtnStyle = ElevatedButton.styleFrom(
      backgroundColor: const Color.fromARGB(250, 48, 125, 13),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      minimumSize: const Size(double.infinity, 52),
    );

    return MaterialApp(
      title: 'NADRA Queue',
      debugShowCheckedModeBanner: false,

      // ── LIGHT THEME ────────────────────────────────────
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color.fromARGB(250, 48, 125, 13),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(250, 48, 125, 13),
          primary: const Color.fromARGB(250, 48, 125, 13),
          brightness: Brightness.light,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(style: elevatedBtnStyle),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
                color: Color.fromARGB(250, 48, 125, 13), width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        cardColor: Colors.white,
        dividerColor: const Color(0xFFE0E0E0),
      ),

      // ── DARK THEME ─────────────────────────────────────
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color.fromARGB(250, 48, 125, 13),
        scaffoldBackgroundColor: const Color(0xFF121212),
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(250, 48, 125, 13),
          primary: const Color.fromARGB(250, 48, 125, 13),
          brightness: Brightness.dark,
          surface: const Color(0xFF1E1E1E),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(style: elevatedBtnStyle),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2C2C2C),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF444444)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF444444)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
                color: Color.fromARGB(250, 48, 125, 13), width: 2),
          ),
          hintStyle: const TextStyle(color: Color(0xFF888888)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        cardColor: const Color(0xFF1E1E1E),
        dividerColor: const Color(0xFF333333),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A1A),
          foregroundColor: Colors.white,
          elevation: 1,
        ),
      ),

      themeMode: themeProvider.isDark ? ThemeMode.dark : ThemeMode.light,
      home: const LoginScreen(),
    );
  }
}