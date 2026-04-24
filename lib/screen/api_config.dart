// ============================================================
//  api_config.dart
//  Single source of truth for API base URL.
// ============================================================

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  // ── Change this for real device testing ───────────────────
  static const String _lanIp = '192.168.1.100'; // your PC LAN IP

  // ── Auto-detected base URL ────────────────────────────────
  static String get baseUrl {
    if (kIsWeb) return 'http://127.0.0.1:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
    // Real Android device ke liye Android line ko ye se replace karein:
    // if (Platform.isAndroid) return 'http://$_lanIp:8000';
  }

  // ── Endpoints ─────────────────────────────────────────────
  static String get register       => '$baseUrl/api/register/';
  static String get login          => '$baseUrl/api/login/';
  static String get offices        => '$baseUrl/api/offices/';
  static String get tokensCreate   => '$baseUrl/api/tokens/create/';
  static String get documentGuide  => '$baseUrl/api/document-guide/';
  static String get forgotPassword => '$baseUrl/api/forgot-password/'; // ← NEW
  static String get cities         => '$baseUrl/api/cities/';
  static String get districts      => '$baseUrl/api/districts/';

  static String profile(int uid)    => '$baseUrl/api/profile/$uid/';
  static String myTokens(int uid)   => '$baseUrl/api/my-tokens/$uid/';
  static String cancelToken(int id) => '$baseUrl/api/token/$id/cancel/';
}