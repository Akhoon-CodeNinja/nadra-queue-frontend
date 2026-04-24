import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';

final FlutterTts flutterTts = FlutterTts();


// ======================================================
// INIT TTS
// Windows + Android + Web Compatible
// ======================================================
Future<void> initTTS() async {
  await flutterTts.setSpeechRate(0.45);
  await flutterTts.setPitch(1.0);
  await flutterTts.setVolume(1.0);

  try {
    // ----------------------------
    // WEB
    // ----------------------------
    if (kIsWeb) {
      await flutterTts.setLanguage("en-US");
    }

    // ----------------------------
    // WINDOWS
    // ----------------------------
    else if (Platform.isWindows) {
      try {
        await flutterTts.setLanguage("ur-PK");
      } catch (e) {
        await flutterTts.setLanguage("en-US");
      }
    }

    // ----------------------------
    // ANDROID
    // ----------------------------
    else if (Platform.isAndroid) {
      await flutterTts.setLanguage("ur-PK");
    }

    // ----------------------------
    // OTHER DEVICES
    // ----------------------------
    else {
      await flutterTts.setLanguage("en-US");
    }

  } catch (e) {
    await flutterTts.setLanguage("en-US");
  }
}


// ======================================================
// SPEAK FUNCTION
// ======================================================
Future<void> speakText(String text) async {
  await flutterTts.stop();
  await flutterTts.speak(text);
}


// ======================================================
// STOP FUNCTION
// ======================================================
Future<void> stopSpeaking() async {
  await flutterTts.stop();
}