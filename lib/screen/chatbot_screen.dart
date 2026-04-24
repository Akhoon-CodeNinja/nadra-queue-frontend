// ============================================================
//  chatbot_screen.dart
//  NADRA Queue Management — AI Chatbot Assistant
//
//  Conversation Flows:
//  1. 🎫 New Token   → City → District → Office → Confirm
//                    → POST /api/tokens/create/
//  2. 📊 Queue Status → City → District → Office
//                    → GET  /api/offices/?district_id= or ?city_id=
//  3. 📄 Document Guide → free text / voice
//                    → POST /api/document-guide/  (TF-IDF cosine)
//  4. 📍 Find Offices → City → District
//                    → GET  /api/offices/?city_id= or ?district_id=
//  5. ❓ FAQ          → local answers, no API
//
//  Location APIs used:
//    GET /api/cities/
//    GET /api/districts/?city_id=
//
//  Voice:  speech_to_text  (same as help_screen.dart)
//  TTS:    flutter_tts     (same as help_screen.dart)
//
//  pubspec.yaml (already in your project):
//    http: ^1.2.1
//    speech_to_text: ^6.6.0
//    flutter_tts: ^4.0.2
//    shared_preferences: ^2.2.2
//
//  AndroidManifest.xml (already added for help_screen):
//    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
//    <uses-permission android:name="android.permission.INTERNET"/>
// ============================================================

import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart'
    show kIsWeb, kAlwaysCompleteAnimation;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

import 'api_config.dart';

// ── App green — same as all other screens ─────────────────────
const _kGreen = Color.fromARGB(250, 48, 125, 13);

// =============================================================
//  MESSAGE MODEL
// =============================================================
enum _MsgType {
  text,       // plain chat bubble
  options,    // option buttons row
  tokenCard,  // green token success card
  officeList, // list of office summary cards
  queueCard,  // queue status bar card
}

class _ChatMsg {
  final String text;
  final bool isUser;
  final DateTime time;
  final bool isVoice;
  final _MsgType type;
  final Map<String, dynamic>? payload;

  _ChatMsg({
    required this.text,
    required this.isUser,
    DateTime? time,
    this.isVoice = false,
    this.type = _MsgType.text,
    this.payload,
  }) : time = time ?? DateTime.now();
}

// =============================================================
//  FSM STEP
// =============================================================
enum _Step {
  idle,
  awaitCity,
  awaitDistrict,
  awaitOffice,
  awaitDocQuery,
  awaitTokenConfirm,
  awaitFaqChoice,
}

// =============================================================
//  CHATBOT SCREEN
// =============================================================
class ChatbotScreen extends StatefulWidget {
  final int userId;

  const ChatbotScreen({super.key, required this.userId});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen>
    with TickerProviderStateMixin {

  // ── UI controllers ─────────────────────────────────────────
  final _textCtrl   = TextEditingController();
  final _scrollCtrl = ScrollController();

  // ── Speech & TTS ───────────────────────────────────────────
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts        _tts   = FlutterTts();
  bool   _speechAvailable = false;
  bool   _isListening     = false;
  bool   _isSpeaking      = false;
  String _recognizedText  = '';

  // ── Animations (same style as help_screen.dart) ────────────
  late AnimationController _pulseCtrl;
  late AnimationController _rippleCtrl;
  late AnimationController _waveCtrl;
  late Animation<double>   _pulseAnim;
  late Animation<double>   _rippleAnim;

  // ── Chat state ─────────────────────────────────────────────
  final List<_ChatMsg> _msgs    = [];
  bool  _isTyping               = false;
  _Step _step                   = _Step.idle;
  String _intent                = '';  // 'token' | 'queue' | 'offices' | 'doc'

  // ── API data cache ─────────────────────────────────────────
  List<Map<String, dynamic>> _cities    = [];
  List<Map<String, dynamic>> _districts = [];
  List<Map<String, dynamic>> _offices   = [];

  // ── Token flow state ───────────────────────────────────────
  int?   _selCityId;
  int?   _selDistrictId;
  int?   _selOfficeId;
  String _selOfficeName = '';
  Map<String, dynamic> _pendingOffice = {};

  // ===========================================================
  //  LIFECYCLE
  // ===========================================================
  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initSpeech();
    _initTts();
    // Welcome message + main menu
    _postBot(_welcome(), delay: 400);
    Future.delayed(const Duration(milliseconds: 1100), _showMainMenu);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _pulseCtrl.dispose();
    _rippleCtrl.dispose();
    _waveCtrl.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  // ===========================================================
  //  ANIMATIONS
  // ===========================================================
  void _initAnimations() {
    _pulseCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _rippleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))
      ..repeat();
    _waveCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat();

    _pulseAnim  = Tween<double>(begin: 1.0, end: 1.15)
        .animate(CurvedAnimation(parent: _pulseCtrl,  curve: Curves.easeInOut));
    _rippleAnim = Tween<double>(begin: 0.8, end: 1.5)
        .animate(CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut));
  }

  // ===========================================================
  //  SPEECH INIT  (identical to help_screen.dart)
  // ===========================================================
  Future<void> _initSpeech() async {
    final ok = await _speech.initialize(
      onError : (e) {
        if (mounted) setState(() { _isListening = false; _recognizedText = ''; });
      },
      onStatus: (s) {
        if ((s == 'done' || s == 'notListening') && _isListening) {
          _stopAndSend();
        }
      },
    );
    if (mounted) setState(() => _speechAvailable = ok);
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('ur-PK');
    await _tts.setSpeechRate(0.52);
    await _tts.setPitch(1.05);
    await _tts.setVolume(1.0);
    if (!kIsWeb && Platform.isAndroid) {
      try { await _tts.setEngine('com.google.android.tts'); } catch (_) {}
    }
    _tts.setStartHandler     (() { if (mounted) setState(() => _isSpeaking = true);  });
    _tts.setCompletionHandler(() { if (mounted) setState(() => _isSpeaking = false); });
    _tts.setCancelHandler    (() { if (mounted) setState(() => _isSpeaking = false); });
    _tts.setErrorHandler     ((_) { if (mounted) setState(() => _isSpeaking = false); });
  }

  // ===========================================================
  //  SCROLL
  // ===========================================================
  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve   : Curves.easeOut,
        );
      }
    });
  }

  // ===========================================================
  //  MESSAGE HELPERS
  // ===========================================================
  String _welcome() =>
      'Assalam-o-Alaikum! 👋\n'
      'Main NADRA ka Virtual Assistant hoon.\n\n'
      'Mujhe bolein ya option choose karein — main madad karunga:\n'
      '• Token book karna\n'
      '• Queue status check karna\n'
      '• Documents ki guide\n'
      '• Nearby offices dhundhna';

  void _addMsg(_ChatMsg msg) {
    if (!mounted) return;
    setState(() => _msgs.add(msg));
    _scrollBottom();
  }

  /// Add a bot message, optionally after a delay.
  void _postBot(
    String text, {
    int delay          = 0,
    _MsgType type      = _MsgType.text,
    Map<String, dynamic>? payload,
  }) {
    Future.delayed(Duration(milliseconds: delay), () {
      _addMsg(_ChatMsg(
        text   : text,
        isUser : false,
        type   : type,
        payload: payload,
      ));
    });
  }

  void _postUser(String text, {bool isVoice = false}) {
    _addMsg(_ChatMsg(text: text, isUser: true, isVoice: isVoice));
  }

  // ===========================================================
  //  MAIN MENU
  // ===========================================================
  void _showMainMenu() {
    _step   = _Step.idle;
    _intent = '';
    _postBot(
      'Aap kya karna chahte hain?',
      type   : _MsgType.options,
      payload: {
        'options': [
          '🎫  New Token Book Karo',
          '📊  Queue Status Check Karo',
          '📄  Documents Ki Guide',
          '📍  Nearby Offices Dhundho',
          '❓  Help / FAQ',
        ],
      },
    );
  }

  // ===========================================================
  //  OPTION BUTTON TAP HANDLER
  // ===========================================================
  void _onOption(String raw) {
    // Strip emoji prefix for user bubble display
    final display = raw.contains('  ')
        ? raw.substring(raw.indexOf('  ') + 2).trim()
        : raw.trim();

    _postUser(display);

    // ── Main menu ──────────────────────────────────────────
    if (_step == _Step.idle && _intent.isEmpty) {
      if      (raw.contains('Token'))    { _intent = 'token';   _startCityFlow(); }
      else if (raw.contains('Queue'))    { _intent = 'queue';   _startCityFlow(); }
      else if (raw.contains('Documents')){ _intent = 'doc';     _startDocFlow();  }
      else if (raw.contains('Offices'))  { _intent = 'offices'; _startCityFlow(); }
      else if (raw.contains('FAQ') || raw.contains('Help')) { _startFaqFlow(); }
      return;
    }

    // ── Token confirm / cancel ─────────────────────────────
    if (_step == _Step.awaitTokenConfirm) {
      if (raw.contains('Haan') || raw.contains('Book')) {
        _step = _Step.idle;
        _createToken();
      } else {
        _step   = _Step.idle;
        _intent = '';
        _postBot('Theek hai, token book nahi kiya.');
        Future.delayed(const Duration(milliseconds: 600), _showMainMenu);
      }
      return;
    }

    // ── City selection ─────────────────────────────────────
    if (_step == _Step.awaitCity) {
      final city = _cities.firstWhere(
        (c) => c['city_name'] == raw,
        orElse: () => {},
      );
      if (city.isNotEmpty) _onCityPicked(city);
      return;
    }

    // ── District selection ─────────────────────────────────
    if (_step == _Step.awaitDistrict) {
      if (raw == 'Poora city') {
        _onDistrictPicked(null);
      } else {
        final d = _districts.firstWhere(
          (x) => x['district_name'] == raw,
          orElse: () => {},
        );
        _onDistrictPicked(d.isEmpty ? null : d);
      }
      return;
    }

    // ── Office selection ───────────────────────────────────
    if (_step == _Step.awaitOffice) {
      final off = _offices.firstWhere(
        (o) => o['branch_name'] == raw,
        orElse: () => {},
      );
      if (off.isNotEmpty) _onOfficePicked(off);
      return;
    }

    // ── FAQ choice ─────────────────────────────────────────
    if (_step == _Step.awaitFaqChoice) {
      _handleFaqAnswer(raw);
      return;
    }
  }

  // ===========================================================
  //  CITY → DISTRICT → OFFICE  FLOW
  // ===========================================================
  void _startCityFlow() {
    setState(() => _isTyping = true);
    _fetchCities().then((_) {
      setState(() => _isTyping = false);
      if (_cities.isEmpty) {
        _postBot('Cities load nahi ho saki. Apna backend check karein.');
        return;
      }
      _step = _Step.awaitCity;
      _postBot(
        'Apni city select karein:',
        type   : _MsgType.options,
        payload: {'options': _cities.map((c) => c['city_name'] as String).toList()},
      );
    });
  }

  void _onCityPicked(Map<String, dynamic> city) {
    _selCityId = city['city_id'] as int;
    setState(() => _isTyping = true);

    _fetchDistricts(_selCityId!).then((_) {
      setState(() => _isTyping = false);

      final opts = <String>['Poora city'];
      opts.addAll(_districts.map((d) => d['district_name'] as String));

      _step = _Step.awaitDistrict;
      _postBot(
        'District select karein (ya "Poora city" choose karein):',
        type   : _MsgType.options,
        payload: {'options': opts},
      );
    });
  }

  void _onDistrictPicked(Map<String, dynamic>? district) {
    _selDistrictId = district?['district_id'] as int?;
    setState(() => _isTyping = true);

    _fetchOffices(
      cityId    : _selDistrictId == null ? _selCityId : null,
      districtId: _selDistrictId,
    ).then((_) {
      setState(() => _isTyping = false);

      if (_offices.isEmpty) {
        _postBot('Is area mein koi office nahi mila. Dobara try karein.');
        Future.delayed(const Duration(milliseconds: 700), _showMainMenu);
        return;
      }

      if (_intent == 'offices') {
        // Just show the list — no further selection needed
        _step   = _Step.idle;
        _intent = '';
        _postBot(
          '${_offices.length} NADRA office(s) mile! 👇',
          type   : _MsgType.officeList,
          payload: {'offices': _offices},
        );
        Future.delayed(const Duration(milliseconds: 900), _showMainMenu);
      } else {
        _step = _Step.awaitOffice;
        _postBot(
          'Office select karein:',
          type   : _MsgType.options,
          payload: {'options': _offices.map((o) => o['branch_name'] as String).toList()},
        );
      }
    });
  }

  void _onOfficePicked(Map<String, dynamic> office) {
    _selOfficeId   = office['office_id'] as int;
    _selOfficeName = office['branch_name'] as String;
    _pendingOffice = office;

    if (_intent == 'token') {
      _askTokenConfirm(office);
    } else if (_intent == 'queue') {
      _step   = _Step.idle;
      _intent = '';
      _showQueueCard(office);
      Future.delayed(const Duration(milliseconds: 1000), _showMainMenu);
    }
  }

  // ===========================================================
  //  TOKEN FLOW
  // ===========================================================
  void _askTokenConfirm(Map<String, dynamic> office) {
    final inQueue  = office['in_queue']    ?? 0;
    final waitTime = office['wait_time']   ?? 0;
    final status   = office['wait_status'] ?? 'Low';

    _step = _Step.awaitTokenConfirm;
    _postBot(
      'Confirm karein — token book karna hai?\n\n'
      '📍 Office : $_selOfficeName\n'
      '👥 Queue  : $inQueue log\n'
      '⏱ Wait   : ~$waitTime min\n'
      '🟢 Status : $status',
      type   : _MsgType.options,
      payload: {
        'options': [
          '✅  Haan, Token Book Karo',
          '❌  Nahi, Wapas Jao',
        ],
      },
    );
  }

  Future<void> _createToken() async {
    setState(() => _isTyping = true);
    try {
      final resp = await http.post(
        Uri.parse(ApiConfig.tokensCreate),
        headers: {
          'Content-Type': 'application/json',
          'Accept'      : 'application/json',
        },
        body: jsonEncode({
          'user_id'  : widget.userId,
          'office_id': _selOfficeId,
        }),
      ).timeout(const Duration(seconds: 15));

      setState(() => _isTyping = false);
      final data = jsonDecode(resp.body);

      if ((resp.statusCode == 200 || resp.statusCode == 201) &&
          data['success'] == true) {
        final t = data['data'] as Map<String, dynamic>;
        _postBot(
          'Token successfully book ho gaya! ✅',
          type   : _MsgType.tokenCard,
          payload: {
            'token_number' : t['token_number']?.toString()  ?? '—',
            'location_name': t['location_name']             ?? _selOfficeName,
            'status'       : t['status']                    ?? 'Active',
            'people_ahead' : t['people_ahead']?.toString()  ?? '0',
            'est_wait_time': t['est_wait_time']?.toString() ?? '0',
            'date_time'    : t['date_time']                 ?? '',
          },
        );
      } else {
        _postBot(
          'Token book nahi ho saka:\n${data['message'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      setState(() => _isTyping = false);
      _postBot('Network error. Backend chal raha hai?\n$e');
    }

    _intent = '';
    Future.delayed(const Duration(milliseconds: 1000), _showMainMenu);
  }

  // ===========================================================
  //  QUEUE STATUS
  // ===========================================================
  void _showQueueCard(Map<String, dynamic> office) {
    _postBot(
      '',
      type   : _MsgType.queueCard,
      payload: {
        'branch_name': office['branch_name'] ?? '',
        'in_queue'   : office['in_queue']    ?? 0,
        'wait_time'  : office['wait_time']   ?? 0,
        'wait_status': office['wait_status'] ?? 'Low',
        'city_name'  : office['city_name']   ?? '',
      },
    );

    final n = (office['in_queue'] ?? 0) as int;
    final advice = n < 5
        ? 'Queue bilkul khaali hai! Abhi jao 🟢'
        : n < 15
            ? 'Queue moderate hai. Thoda wait ho sakta hai 🟡'
            : 'Queue kaafi busy hai. Thori der baad jana behtar hoga 🔴';
    _postBot(advice, delay: 500);
  }

  // ===========================================================
  //  DOCUMENT GUIDE FLOW
  // ===========================================================
  void _startDocFlow() {
    _step   = _Step.awaitDocQuery;
    _intent = 'doc';
    _postBot(
      'Kaunsi NADRA service ke documents chahiye?\n\n'
      'Type karein ya mic se bolein, maslan:\n'
      '• Naya CNIC\n'
      '• CNIC Renewal\n'
      '• B-Form\n'
      '• FRC\n'
      '• Shadi Certificate\n'
      '• Lost CNIC\n'
      '• Naam / Pata Change',
    );
  }

  Future<void> _sendDocQuery(String query) async {
    _step   = _Step.idle;
    _intent = '';
    setState(() => _isTyping = true);

    try {
      final resp = await http.post(
        Uri.parse(ApiConfig.documentGuide),
        headers: {
          'Content-Type': 'application/json',
          'Accept'      : 'application/json',
        },
        body: jsonEncode({'query': query}),
      ).timeout(const Duration(seconds: 20));

      setState(() => _isTyping = false);
      final data = jsonDecode(resp.body);

      if (resp.statusCode == 200 && data['success'] == true) {
        final svcName = (data['service_name']        ?? '').toString().trim();
        final docs    = (data['required_documents']  ?? '').toString().trim();
        final reply   = '📋 *$svcName*\n\n$docs';
        _postBot(reply);
        if (!kIsWeb) _speakText('$svcName۔ $docs');
      } else {
        _postBot(
          (data['message'] ?? '').toString().isNotEmpty
              ? data['message']
              : 'Maaf kijiye, koi result nahi mila. Doosra keyword try karein.',
        );
      }
    } catch (e) {
      setState(() => _isTyping = false);
      _postBot('Network error:\n$e');
    }

    Future.delayed(const Duration(milliseconds: 800), _showMainMenu);
  }

  // ===========================================================
  //  FAQ FLOW
  // ===========================================================
  void _startFaqFlow() {
    _step = _Step.awaitFaqChoice;
    _postBot(
      'Kaunsa sawaal hai aapka?',
      type   : _MsgType.options,
      payload: {
        'options': [
          'CNIC kitne saal valid hota hai?',
          'Token cancel kaise karen?',
          'NADRA office ki working hours?',
          'B-Form kya hota hai?',
          'Appointment book karna hai',
          '🔙  Wapas Main Menu',
        ],
      },
    );
  }

  void _handleFaqAnswer(String label) {
    _step = _Step.idle;

    if (label.contains('Wapas')) {
      _showMainMenu();
      return;
    }

    const answers = <String, String>{
      'CNIC kitne saal valid hota hai?':
          'Pakistani CNIC 10 saal ke liye valid hota hai. Expiry ke baad '
          'NADRA office se renewal karwana zaroori hai.',

      'Token cancel kaise karen?':
          '"My Token" tab mein jao → apna active token dekho → '
          '"Cancel Token" button press karo. '
          'Sirf Active status wala token cancel ho sakta hai.',

      'NADRA office ki working hours?':
          'NADRA offices aam tor par:\n'
          '• Monday – Thursday: 8:00 AM – 4:00 PM\n'
          '• Friday: 8:00 AM – 1:00 PM, 2:30 PM – 4:00 PM\n'
          '• Saturday: 9:00 AM – 1:00 PM\n'
          '• Sunday: Band',

      'B-Form kya hota hai?':
          'B-Form (Birth Registration Form) 18 saal se kam bachon ka '
          'NADRA registration card hai. CNIC banwane se pehle zaroori hai. '
          'Bachay ke parents ka CNIC aur hospital birth certificate chahiye.',

      'Appointment book karna hai':
          'Is waqt direct appointment system available nahi hai. '
          'App se walk-in token book karein — '
          '"New Token Book Karo" option choose karein. '
          'Token number milte hi aap queue mein aa jaate hain.',
    };

    final answer = answers[label] ?? 'Is sawaal ka jawab abhi available nahi.';
    _postBot(answer);
    Future.delayed(const Duration(milliseconds: 900), _showMainMenu);
  }

  // ===========================================================
  //  FREE TEXT + VOICE HANDLER
  // ===========================================================
  Future<void> _handleFreeText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isTyping || _isListening) return;
    _textCtrl.clear();
    _postUser(trimmed);

    // ── Token confirm intercept ──────────────────────────────
    if (_step == _Step.awaitTokenConfirm) {
      final lower = trimmed.toLowerCase();
      if (lower.contains('haan') || lower.contains('yes') ||
          lower.contains('confirm') || lower.contains('book')) {
        _step = _Step.idle;
        await _createToken();
      } else {
        _step   = _Step.idle;
        _intent = '';
        _postBot('Theek hai, token book nahi kiya.');
        Future.delayed(const Duration(milliseconds: 600), _showMainMenu);
      }
      return;
    }

    // ── Document guide or idle fallback ─────────────────────
    if (_step == _Step.awaitDocQuery || _step == _Step.idle) {
      await _sendDocQuery(trimmed);
    }
  }

  // ===========================================================
  //  VOICE
  // ===========================================================
  Future<void> _onMicTap() async {
    if (kIsWeb) {
      _snack('Voice sirf mobile app mein kaam karta hai.');
      return;
    }
    if (_isSpeaking) { await _tts.stop(); return; }
    if (_isListening) { await _stopAndSend(); return; }
    await _startListening();
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) {
      _snack('Microphone permission nahi mili.');
      return;
    }
    setState(() { _recognizedText = ''; _isListening = true; });
    await _speech.listen(
      onResult: (r) {
        if (mounted) setState(() => _recognizedText = r.recognizedWords);
        if (r.finalResult && r.recognizedWords.trim().isNotEmpty) {
          _stopAndSend();
        }
      },
      localeId      : 'ur_PK',
      listenFor     : const Duration(seconds: 15),
      pauseFor      : const Duration(seconds: 3),
      partialResults: true,
      cancelOnError : true,
    );
  }

  Future<void> _stopAndSend() async {
    if (!_isListening) return;
    await _speech.stop();
    final query = _recognizedText.trim();
    setState(() { _isListening = false; _recognizedText = ''; });
    if (query.isEmpty) return;
    _postUser(query, isVoice: true);
    if (_step == _Step.awaitDocQuery || _step == _Step.idle) {
      await _sendDocQuery(query);
    }
  }

  Future<void> _speakText(String text) async {
    await _tts.stop();
    final clean = text
        .replaceAll(RegExp(r'[📋⚠️•*📍👥⏱🟢🟡🔴]'), '')
        .trim();
    if (clean.isNotEmpty) await _tts.speak(clean);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content        : Text(msg),
      backgroundColor: _kGreen,
      behavior       : SnackBarBehavior.floating,
    ));
  }

  // ===========================================================
  //  API CALLS  (all use ApiConfig — no hardcoded URLs)
  // ===========================================================
  Future<void> _fetchCities() async {
    _cities = [];
    try {
      final r = await http
          .get(Uri.parse(ApiConfig.cities),
               headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        _cities = List<Map<String, dynamic>>.from(d['data'] ?? []);
      }
    } catch (_) {}
  }

  Future<void> _fetchDistricts(int cityId) async {
    _districts = [];
    try {
      final r = await http
          .get(Uri.parse('${ApiConfig.districts}?city_id=$cityId'),
               headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        _districts = List<Map<String, dynamic>>.from(d['data'] ?? []);
      }
    } catch (_) {}
  }

  Future<void> _fetchOffices({int? cityId, int? districtId}) async {
    _offices = [];
    try {
      String url = ApiConfig.offices;
      if (districtId != null) {
        url += '?district_id=$districtId';
      } else if (cityId != null) {
        url += '?city_id=$cityId';
      }
      final r = await http
          .get(Uri.parse(url), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        _offices = List<Map<String, dynamic>>.from(d['data'] ?? []);
      }
    } catch (_) {}
  }

  // ===========================================================
  //  STATUS COLOR  (matches home_screen.dart logic)
  // ===========================================================
  Color _statusColor(String s) {
    switch (s) {
      case 'High':     return Colors.red;
      case 'Moderate': return Colors.orange;
      default:         return Colors.green;
    }
  }

  String _fmtTime(DateTime t) {
    final h = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour >= 12 ? 'PM' : 'AM'}';
  }

  // ===========================================================
  //  BUILD
  // ===========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD), // WhatsApp-like chat bg
      appBar: _buildAppBar(),
      body  : Column(children: [
        _buildListeningBanner(),
        Expanded(child: _buildChatList()),
        if (_isTyping) _buildTypingIndicator(),
        _buildInputBar(),
      ]),
    );
  }

  // ── AppBar ────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: _kGreen,
    elevation      : 1,
    leadingWidth   : 52,
    leading        : IconButton(
      icon   : const Icon(Icons.arrow_back, color: Colors.white),
      tooltip: 'Back',
      onPressed: () => Navigator.pop(context),
    ),
    title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        'NADRA Assistant',
        style: TextStyle(
            color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
      ),
      Text(
        'Online',
        style: TextStyle(color: Colors.white70, fontSize: 12),
      ),
    ]),
    actions: [
      // Reset chat button
      IconButton(
        icon   : const Icon(Icons.refresh, color: Colors.white),
        tooltip: 'New Chat',
        onPressed: () {
          setState(() {
            _msgs.clear();
            _step   = _Step.idle;
            _intent = '';
          });
          _postBot(_welcome(), delay: 100);
          Future.delayed(const Duration(milliseconds: 700), _showMainMenu);
        },
      ),
    ],
  );

  // ── Red listening banner (same style as help_screen.dart) ─
  Widget _buildListeningBanner() => AnimatedContainer(
    duration    : const Duration(milliseconds: 300),
    height      : _isListening ? 48 : 0,
    clipBehavior: Clip.hardEdge,
    decoration  : const BoxDecoration(color: Color(0xFFE53935)),
    child       : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      AnimatedBuilder(
        animation: _waveCtrl,
        builder  : (_, __) => Row(
          children: List.generate(5, (i) {
            final v = sin((_waveCtrl.value * 2 * pi) + i * 0.4).abs();
            return Container(
              margin    : const EdgeInsets.symmetric(horizontal: 1.5),
              width     : 3,
              height    : 6 + 10 * v,
              decoration: BoxDecoration(
                color       : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
      ),
      const SizedBox(width: 10),
      Flexible(child: Text(
        _recognizedText.isEmpty ? 'Sun raha hoon...' : _recognizedText,
        style   : const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
        overflow: TextOverflow.ellipsis,
      )),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: _stopAndSend,
        child: const Padding(
          padding: EdgeInsets.all(8),
          child  : Icon(Icons.send_rounded, color: Colors.white, size: 20),
        ),
      ),
    ]),
  );

  // ── Chat list ─────────────────────────────────────────────
  Widget _buildChatList() => ListView.builder(
    controller : _scrollCtrl,
    padding    : const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    itemCount  : _msgs.length,
    itemBuilder: (_, i) => _buildItem(_msgs[i]),
  );

  Widget _buildItem(_ChatMsg msg) {
    if (msg.isUser) return _buildBubble(msg);
    switch (msg.type) {
      case _MsgType.options:   return _buildOptionsMsg(msg);
      case _MsgType.tokenCard: return _buildTokenCard(msg);
      case _MsgType.officeList:return _buildOfficeListMsg(msg);
      case _MsgType.queueCard: return _buildQueueCard(msg);
      case _MsgType.text:
      default:                 return _buildBubble(msg);
    }
  }

  // ── Plain chat bubble ─────────────────────────────────────
  Widget _buildBubble(_ChatMsg msg) {
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child    : Container(
        margin   : EdgeInsets.only(
          top  : 3, bottom: 3,
          left : isUser ? 55 : 0,
          right: isUser ? 0 : 55,
        ),
        padding  : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFFDCF8C6) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft    : const Radius.circular(16),
            topRight   : const Radius.circular(16),
            bottomLeft : Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color    : Colors.black.withOpacity(0.07),
              blurRadius: 4,
              offset   : const Offset(0, 2),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Align(
            alignment: Alignment.centerLeft,
            child    : Text(
              msg.text,
              style: const TextStyle(
                fontSize: 14.5, color: Colors.black87, height: 1.5),
            ),
          ),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (isUser && msg.isVoice) ...[
              const Icon(Icons.mic, size: 11, color: Colors.grey),
              const SizedBox(width: 3),
            ],
            Text(_fmtTime(msg.time),
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            if (isUser) ...[
              const SizedBox(width: 4),
              const Icon(Icons.done_all, size: 14, color: Color(0xFF34B7F1)),
            ],
            if (!isUser) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _speakText(msg.text),
                child: Icon(
                  _isSpeaking
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  size : 14,
                  color: _kGreen.withOpacity(0.6),
                ),
              ),
            ],
          ]),
        ]),
      ),
    );
  }

  // ── Options message (bubble + option buttons below) ────────
  Widget _buildOptionsMsg(_ChatMsg msg) {
    final opts = List<String>.from(msg.payload?['options'] ?? []);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (msg.text.isNotEmpty)
        _buildBubble(
          _ChatMsg(text: msg.text, isUser: false, time: msg.time),
        ),
      const SizedBox(height: 6),
      Padding(
        padding: const EdgeInsets.only(left: 4, right: 55, bottom: 6),
        child  : Wrap(
          spacing   : 8,
          runSpacing: 8,
          children  : opts.map(_buildOptionButton).toList(),
        ),
      ),
    ]);
  }

  Widget _buildOptionButton(String label) => GestureDetector(
    onTap: () => _onOption(label),
    child: Container(
      padding   : const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color       : Colors.white,
        border      : Border.all(color: _kGreen, width: 1.2),
        borderRadius: BorderRadius.circular(22),
        boxShadow   : [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: _kGreen, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
  );

  // ── Token card ────────────────────────────────────────────
  Widget _buildTokenCard(_ChatMsg msg) {
    final p        = msg.payload!;
    final tokenNum = p['token_number']   ?? '—';
    final office   = p['location_name']  ?? '—';
    final status   = p['status']         ?? 'Active';
    final people   = p['people_ahead']   ?? '0';
    final wait     = p['est_wait_time']  ?? '0';
    final dateTime = p['date_time']      ?? '';

    return Align(
      alignment: Alignment.centerLeft,
      child    : Container(
        margin     : const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration : BoxDecoration(
          gradient    : const LinearGradient(
            colors: [_kGreen, Color(0xFF2E7D0C)],
            begin : Alignment.topLeft,
            end   : Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow   : [
            BoxShadow(
              color     : _kGreen.withOpacity(0.4),
              blurRadius: 12,
              offset    : const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Token number row
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Token Number',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
                Text(
                  tokenNum.toString(),
                  style: const TextStyle(
                    color     : Colors.white,
                    fontSize  : 42,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ]),
              Container(
                padding   : const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color       : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.qr_code_2,
                    color: Colors.white, size: 30),
              ),
            ]),

            const SizedBox(height: 10),
            Container(height: 1, color: Colors.white.withOpacity(0.25)),
            const SizedBox(height: 10),

            // Office + date
            Row(children: [
              const Icon(Icons.location_on_outlined,
                  color: Colors.white70, size: 14),
              const SizedBox(width: 5),
              Expanded(child: Text(office,
                  style: const TextStyle(color: Colors.white, fontSize: 13))),
            ]),
            if (dateTime.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.calendar_today_outlined,
                    color: Colors.white70, size: 13),
                const SizedBox(width: 5),
                Text(dateTime,
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ],

            const SizedBox(height: 12),

            // Stats row
            Row(children: [
              _tStat('Logon Ke Aage', people.toString()),
              const SizedBox(width: 20),
              _tStat('Est. Wait', '~$wait min'),
              const SizedBox(width: 20),
              _tStat('Status', status),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _tStat(String label, String val) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children          : [
      Text(label,
          style: const TextStyle(color: Colors.white60, fontSize: 10)),
      Text(val,
          style: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
    ],
  );

  // ── Queue status card ─────────────────────────────────────
  Widget _buildQueueCard(_ChatMsg msg) {
    final p       = msg.payload!;
    final branch  = p['branch_name']  ?? '';
    final inQueue = (p['in_queue']    ?? 0) as int;
    final wait    = (p['wait_time']   ?? 0) as int;
    final status  = p['wait_status']  ?? 'Low';
    final city    = p['city_name']    ?? '';
    final clr     = _statusColor(status);

    return Align(
      alignment: Alignment.centerLeft,
      child    : Container(
        margin     : const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.85),
        padding    : const EdgeInsets.all(16),
        decoration : BoxDecoration(
          color       : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow   : [
            BoxShadow(
                color: Colors.black.withOpacity(0.07), blurRadius: 8),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Office name + dot
          Row(children: [
            Container(
              width : 10, height: 10,
              decoration: BoxDecoration(
                  color: clr, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(branch,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14))),
          ]),
          if (city.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3, left: 18),
              child  : Text(city,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child       : LinearProgressIndicator(
              value          : (inQueue / 50.0).clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              color          : clr,
              minHeight      : 8,
            ),
          ),
          const SizedBox(height: 10),

          // Stats
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _qStat('Queue Status', status,       clr),
            _qStat('In Queue',     '$inQueue log', Colors.black87),
            _qStat('Wait Time',    '~$wait min',   Colors.black87),
          ]),
        ]),
      ),
    );
  }

  Widget _qStat(String label, String val, Color valClr) =>
      Column(children: [
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 10)),
        const SizedBox(height: 2),
        Text(val,
            style: TextStyle(
                color     : valClr,
                fontSize  : 13,
                fontWeight: FontWeight.bold)),
      ]);

  // ── Office list ───────────────────────────────────────────
  Widget _buildOfficeListMsg(_ChatMsg msg) {
    final offices =
        List<Map<String, dynamic>>.from(msg.payload?['offices'] ?? []);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (msg.text.isNotEmpty)
        _buildBubble(
          _ChatMsg(text: msg.text, isUser: false, time: msg.time),
        ),
      const SizedBox(height: 6),
      ...offices.map((o) {
        final status = (o['wait_status'] ?? 'Low') as String;
        final clr    = _statusColor(status);
        return Container(
          margin    : const EdgeInsets.only(bottom: 8, right: 55),
          padding   : const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color       : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border      : Border.all(color: clr.withOpacity(0.4)),
            boxShadow   : [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05), blurRadius: 6),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Name + badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children        : [
                Expanded(child: Text(o['branch_name'] ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13))),
                Container(
                  padding   : const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color       : clr.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(status,
                      style: TextStyle(
                          color     : clr,
                          fontSize  : 11,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            // District + city
            if ((o['city_name'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                [o['district_name'], o['city_name']]
                    .where((s) => s != null && s.toString().isNotEmpty)
                    .join(', '),
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
            const SizedBox(height: 6),
            // Queue + wait
            Row(children: [
              const Icon(Icons.people_outline,
                  size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Text('${o['in_queue'] ?? 0} in queue',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 14),
              const Icon(Icons.access_time,
                  size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Text('~${o['wait_time'] ?? 0} min',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey)),
            ]),
          ]),
        );
      }),
    ]);
  }

  // ── Typing indicator (3 bouncing dots) ────────────────────
  Widget _buildTypingIndicator() => Align(
    alignment: Alignment.centerLeft,
    child    : Container(
      margin    : const EdgeInsets.only(left: 12, bottom: 6, right: 80),
      padding   : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color       : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft    : Radius.circular(16),
          topRight   : Radius.circular(16),
          bottomLeft : Radius.circular(4),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
              color    : Colors.black.withOpacity(0.07),
              blurRadius: 4,
              offset   : const Offset(0, 2)),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _dot(0),
        const SizedBox(width: 4),
        _dot(200),
        const SizedBox(width: 4),
        _dot(400),
      ]),
    ),
  );

  Widget _dot(int delayMs) => TweenAnimationBuilder<double>(
    tween   : Tween(begin: 0.0, end: 1.0),
    duration: Duration(milliseconds: 600 + delayMs),
    builder : (_, v, __) => AnimatedContainer(
      duration  : const Duration(milliseconds: 300),
      width: 8, height: 8,
      decoration: BoxDecoration(
        color: Color.lerp(Colors.grey.shade300, _kGreen, v),
        shape: BoxShape.circle,
      ),
    ),
  );

  // ── Input bar (text + mic + send) ────────────────────────
  Widget _buildInputBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    color  : const Color(0xFFF0F0F0),
    child  : SafeArea(child: Row(children: [

      // Text field
      Expanded(child: Container(
        decoration: BoxDecoration(
          color       : Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow   : [
            BoxShadow(
                color: Colors.black.withOpacity(0.05), blurRadius: 4),
          ],
        ),
        child: TextField(
          controller        : _textCtrl,
          enabled           : !_isTyping && !_isListening,
          textCapitalization: TextCapitalization.sentences,
          style             : const TextStyle(fontSize: 14.5),
          onSubmitted       : (_) => _handleFreeText(_textCtrl.text),
          decoration        : InputDecoration(
            hintText : _isListening
                ? '🔴  Bol raha hoon...'
                : _isTyping
                    ? 'NADRA Assistant typing...'
                    : 'Message likhein...',
            hintStyle: TextStyle(
              color   : _isListening
                  ? const Color(0xFFE53935)
                  : Colors.grey,
              fontSize: 13.5,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            border: InputBorder.none,
          ),
        ),
      )),

      const SizedBox(width: 8),

      // Mic button  (same animation as help_screen.dart)
      GestureDetector(
        onTap: _onMicTap,
        child: Stack(alignment: Alignment.center, children: [
          if (_isListening)
            AnimatedBuilder(
              animation: _rippleAnim,
              builder  : (_, __) => Container(
                width : 52 * _rippleAnim.value,
                height: 52 * _rippleAnim.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE53935).withOpacity(
                    0.15 * (1 - _rippleAnim.value + 0.5),
                  ),
                ),
              ),
            ),
          AnimatedBuilder(
            animation: _isListening
                ? _pulseAnim
                : kAlwaysCompleteAnimation,
            builder: (_, __) => Transform.scale(
              scale: _isListening ? _pulseAnim.value : 1.0,
              child: Container(
                width : 46, height: 46,
                decoration: BoxDecoration(
                  shape    : BoxShape.circle,
                  color    : kIsWeb
                      ? Colors.grey.shade400
                      : _isListening
                          ? const Color(0xFFE53935)
                          : _isTyping
                              ? Colors.grey
                              : _kGreen,
                  boxShadow: [
                    BoxShadow(
                      color     : (_isListening
                              ? Colors.red
                              : _kGreen)
                          .withOpacity(0.35),
                      blurRadius: 10,
                      offset    : const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  kIsWeb
                      ? Icons.mic_off_rounded
                      : _isListening
                          ? Icons.stop_rounded
                          : _isSpeaking
                              ? Icons.volume_up_rounded
                              : Icons.mic_rounded,
                  color: Colors.white,
                  size : 22,
                ),
              ),
            ),
          ),
        ]),
      ),

      const SizedBox(width: 8),

      // Send button
      GestureDetector(
        onTap: () => _handleFreeText(_textCtrl.text),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width : 46, height: 46,
          decoration: BoxDecoration(
            shape    : BoxShape.circle,
            color    : (_isTyping || _isListening)
                ? Colors.grey
                : _kGreen,
            boxShadow: [
              BoxShadow(
                color     : _kGreen.withOpacity(0.3),
                blurRadius: 8,
                offset    : const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.send, color: Colors.white, size: 20),
        ),
      ),
    ])),
  );
}