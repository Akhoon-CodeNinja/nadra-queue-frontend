// ============================================================
//  help_screen.dart  –  NADRA Queue Management System
//  UPGRADED: Hybrid Rule-Based + Flow-Based Chatbot
//
//  pubspec.yaml:
//    speech_to_text: ^6.6.0
//    flutter_tts: ^4.0.2
//    http: ^1.2.1
//
//  Android (AndroidManifest.xml):
//    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
//    <uses-permission android:name="android.permission.INTERNET"/>
//
//  iOS (Info.plist):
//    NSMicrophoneUsageDescription
//    NSSpeechRecognitionUsageDescription
// ============================================================
/*
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'api_config.dart';

// ── Chat message model ────────────────────────────────────────
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  final bool isVoice;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.time,
    this.isVoice = false,
  });
}

// ============================================================
//  CHATBOT INTENT ENUM
//  Used by _detectIntent() to route the user into a flow
// ============================================================
enum _Intent {
  newToken,     // User wants to take a new token
  queueStatus,  // User wants to check their queue position
  centerInfo,   // User wants to know office hours / address
  docGuide,     // User wants document requirements (uses API)
  fallback,     // No match → pass to live API
}

// ============================================================
//  FLOW ENUM
//  Tracks which guided conversation is currently active
// ============================================================
enum _Flow {
  none,
  newToken,
  queueStatus,
  centerInfo,
}

// ── Main Screen ───────────────────────────────────────────────
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> with TickerProviderStateMixin {
  // ── Controllers ───────────────────────────────────────────
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // ── Speech & TTS ─────────────────────────────────────────
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  // ── State flags ───────────────────────────────────────────
  bool _isTyping = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  bool _isSpeaking = false;
  String _recognizedText = '';

  // ── Animations ────────────────────────────────────────────
  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnim;
  late Animation<double> _rippleAnim;

  // ── API URL — PythonAnywhere live backend ─────────────────
  String get _apiUrl => ApiConfig.documentGuide;

  // ── Chat history ──────────────────────────────────────────
  final List<ChatMessage> _messages = [
    ChatMessage(
      text: "Assalam o Alaikum! 👋\n"
          "Main NADRA ka Virtual Assistant hoon.\n\n"
          "Mujh se ye keh saktay hain:\n\n"
          "🎫  *Naya token lena hai*\n"
          "📍  *Apni queue status check karni hai*\n"
          "🏢  *NADRA center ki info chahiye*\n"
          "📋  *Kisi service ke documents jaanne hain*\n\n"
          "Type karein ya 🎙️ mic dabayein.",
      isUser: false,
      time: DateTime.now(),
    ),
  ];

  // ============================================================
  //  ★ CHATBOT STATE — NEW ADDITIONS
  // ============================================================

  /// Which guided flow is currently active (none = free conversation)
  _Flow _currentFlow = _Flow.none;

  /// Collected slot values during a flow
  /// Keys: 'city', 'office_id', 'office_name', 'service', 'token_number'
  final Map<String, dynamic> _slots = {};

  /// Step index within the current flow
  int _flowStep = 0;

  /// Cached office list fetched from API (for center selection)
  List<Map<String, dynamic>> _officeList = [];

  // ── Random for token simulation ───────────────────────────
  final _rng = Random();

  // ════════════════════════════════════════════════════════════
  //  INIT
  // ════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initSpeech();
    _initTts();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _rippleAnim = Tween<double>(begin: 0.8, end: 1.5).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
  }

  Future<void> _initSpeech() async {
    final ok = await _speech.initialize(
      onError: (e) {
        debugPrint('STT Error: $e');
        if (mounted) {
          setState(() {
            _isListening = false;
            _recognizedText = '';
          });
        }
      },
      onStatus: (s) {
        debugPrint('STT Status: $s');
        if ((s == 'done' || s == 'notListening') && _isListening) {
          _stopListeningAndSend();
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
      try {
        await _tts.setEngine('com.google.android.tts');
      } catch (_) {}
    }

    _tts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _tts.setErrorHandler((_) {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    _rippleController.dispose();
    _waveController.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════
  //  SCROLL
  // ════════════════════════════════════════════════════════════
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ════════════════════════════════════════════════════════════
  //  TEXT SEND
  // ════════════════════════════════════════════════════════════
  Future<void> _sendTextMessage() async {
    final query = _queryController.text.trim();
    if (query.isEmpty || _isTyping || _isListening) return;
    _queryController.clear();
    await _sendQuery(query, isVoice: false);
  }

  // ════════════════════════════════════════════════════════════
  //  VOICE FLOW: Mic → STT → Chatbot/API → Response → TTS
  // ════════════════════════════════════════════════════════════
  Future<void> _onMicTap() async {
    if (_isTyping) return;

    if (kIsWeb) {
      _showSnack('Voice feature sirf mobile/desktop app mein kaam karta hai.');
      return;
    }

    if (_isSpeaking) {
      await _tts.stop();
      return;
    }

    if (_isListening) {
      await _stopListeningAndSend();
    } else {
      await _startListening();
    }
  }

  // ── STEP 1: Start mic ─────────────────────────────────────
  Future<void> _startListening() async {
    if (!_speechAvailable) {
      _showSnack('Microphone available nahi hai ya permission nahi di.');
      return;
    }

    if (mounted) {
      setState(() {
        _recognizedText = '';
        _isListening = true;
      });
    }

    await _speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() => _recognizedText = result.recognizedWords);
        }
        if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
          _stopListeningAndSend();
        }
      },
      localeId: 'ur_PK',
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      cancelOnError: true,
    );
  }

  // ── STEP 2: Stop mic → hand off to sendQuery ─────────────
  Future<void> _stopListeningAndSend() async {
    if (!_isListening) return;

    await _speech.stop();
    final query = _recognizedText.trim();

    if (mounted) {
      setState(() {
        _isListening = false;
        _recognizedText = '';
      });
    }

    if (query.isEmpty) return;
    await _sendQuery(query, isVoice: true);
  }

  // ============================================================
  //  ★ CORE SEND QUERY — CHATBOT FIRST, API AS FALLBACK
  // ============================================================
  Future<void> _sendQuery(String query, {required bool isVoice}) async {
    // Add user message to chat
    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(
          text: query,
          isUser: true,
          time: DateTime.now(),
          isVoice: isVoice,
        ));
        _isTyping = true;
      });
    }
    _scrollToBottom();

    // Realistic typing delay for UX
    await Future.delayed(const Duration(milliseconds: 700));

    // ── ROUTER: active flow OR intent detection ───────────────
    if (_currentFlow != _Flow.none) {
      // We are inside a guided flow — continue slot filling
      await _continueFlow(query);
    } else {
      // No active flow — detect intent first
      final intent = _detectIntent(query);
      switch (intent) {
        case _Intent.newToken:
          await _startNewTokenFlow();
          break;
        case _Intent.queueStatus:
          await _startQueueStatusFlow();
          break;
        case _Intent.centerInfo:
          await _startCenterInfoFlow();
          break;
        case _Intent.docGuide:
        case _Intent.fallback:
          // Falls through to live API
          await _callDocumentApi(query);
          break;
      }
    }

    if (mounted) setState(() => _isTyping = false);
    _scrollToBottom();
  }

  // ============================================================
  //  ★ INTENT DETECTION
  //  Simple keyword matching — expandable to ML later
  // ============================================================
  _Intent _detectIntent(String raw) {
    final msg = raw.toLowerCase().trim();

    // ── New Token keywords ─────────────────────────────────
    const newTokenKws = [
      'token', 'naya token', 'new token', 'queue mein', 'number lena',
      'appointment', 'book', 'register', 'turn', 'number chahiye',
      'lena hai', 'token lena', 'add karo', 'new',
    ];

    // ── Queue Status keywords ──────────────────────────────
    const queueKws = [
      'status', 'position', 'kitna wait', 'queue', 'meri number',
      'kahan hoon', 'kaafi time', 'wait', 'kitne log', 'check',
      'ahead', 'aage', 'baad', 'mera token',
    ];

    // ── Center Info keywords ───────────────────────────────
    const centerKws = [
      'office', 'center', 'address', 'location', 'timing', 'time',
      'kab khulta', 'kab band', 'kahan hai', 'branch', 'nadra office',
      'kahan', 'pata', 'working hours',
    ];

    if (newTokenKws.any((kw) => msg.contains(kw))) return _Intent.newToken;
    if (queueKws.any((kw) => msg.contains(kw))) return _Intent.queueStatus;
    if (centerKws.any((kw) => msg.contains(kw))) return _Intent.centerInfo;

    // ── Doc Guide keywords → API ───────────────────────────
    const docKws = [
      'document', 'kagaz', 'documents', 'zarori', 'required',
      'cnic', 'b-form', 'bform', 'frc', 'family', 'shadi',
      'renewal', 'gum', 'lost', 'naam', 'correction',
    ];
    if (docKws.any((kw) => msg.contains(kw))) return _Intent.docGuide;

    return _Intent.fallback;
  }

  // ============================================================
  //  ★ FLOW 1: NEW TOKEN
  //  Steps: city → office selection → service → confirm → issue
  // ============================================================

  Future<void> _startNewTokenFlow() async {
    _currentFlow = _Flow.newToken;
    _flowStep = 0;
    _slots.clear();
    _addBotMessage(
      "📍 Zaroor! Pehle batayein — aap *kis shehar* mein hain?\n\n"
      "Maslan: Karachi, Lahore, Islamabad, Rawalpindi...",
    );
  }

  // ── Flow 2: Queue Status ──────────────────────────────────
  Future<void> _startQueueStatusFlow() async {
    _currentFlow = _Flow.queueStatus;
    _flowStep = 0;
    _slots.clear();
    _addBotMessage(
      "🔍 Apni queue status check karte hain.\n\n"
      "Apna *Token Number* batayein (sirf number):",
    );
  }

  // ── Flow 3: Center Info ───────────────────────────────────
  Future<void> _startCenterInfoFlow() async {
    _currentFlow = _Flow.centerInfo;
    _flowStep = 0;
    _slots.clear();
    _addBotMessage(
      "🏢 Kis shehar ka NADRA center dhundh rahe hain?\n\n"
      "Shehar ka naam likhein:",
    );
  }

  // ============================================================
  //  ★ FLOW CONTINUATION — routes to correct flow handler
  // ============================================================
  Future<void> _continueFlow(String input) async {
    switch (_currentFlow) {
      case _Flow.newToken:
        await _handleNewTokenFlow(input);
        break;
      case _Flow.queueStatus:
        await _handleQueueStatusFlow(input);
        break;
      case _Flow.centerInfo:
        await _handleCenterInfoFlow(input);
        break;
      case _Flow.none:
        break;
    }
  }

  // ============================================================
  //  FLOW 1 HANDLER: NEW TOKEN
  // ============================================================
  Future<void> _handleNewTokenFlow(String input) async {
    switch (_flowStep) {
      // ── Step 0: Received city, fetch offices ───────────────
      case 0:
        _slots['city'] = input.trim();
        _flowStep = 1;

        // Fetch offices from real API
        await _fetchOffices(input.trim());
        break;

      // ── Step 1: Received office choice ────────────────────
      case 1:
        final selected = _matchOffice(input);
        if (selected == null) {
          _addBotMessage(
            "⚠️ Koi office nahi mila. Meherbani kar number ya naam dobara likhein.\n"
            "${_officeListText()}",
          );
          return; // Stay on step 1
        }
        _slots['office_id'] = selected['office_id'];
        _slots['office_name'] = selected['branch_name'];
        _flowStep = 2;

        _addBotMessage(
          "✅ *${selected['branch_name']}* select kar liya.\n\n"
          "Ab batayein — aapko *kaunsi service* chahiye?\n\n"
          "1️⃣  Naya CNIC\n"
          "2️⃣  CNIC Renewal\n"
          "3️⃣  B-Form\n"
          "4️⃣  FRC (Family Registration Certificate)\n"
          "5️⃣  Address Change\n\n"
          "Number ya naam type karein:",
        );
        break;

      // ── Step 2: Received service type ─────────────────────
      case 2:
        final service = _matchService(input);
        if (service == null) {
          _addBotMessage(
            "⚠️ Service pehchaan mein nahi aayi. 1 se 5 tak number likhein ya service ka naam.",
          );
          return; // Stay on step 2
        }
        _slots['service'] = service;
        _flowStep = 3;

        _addBotMessage(
          "📋 *Confirmation check karein:*\n\n"
          "🏙️  Shehar: ${_slots['city']}\n"
          "🏢  Office: ${_slots['office_name']}\n"
          "📌  Service: $service\n\n"
          "Sab theek hai? *Haan* ya *Nahi* likhein:",
        );
        break;

      // ── Step 3: Confirmation ──────────────────────────────
      case 3:
        final confirmed = _isConfirmed(input);
        final declined = _isDeclined(input);

        if (declined) {
          _resetFlow();
          _addBotMessage(
            "ठीک hai! Flow cancel kar diya. 😊\n"
            "Koi bhi sawaal ho — poochein.",
          );
          return;
        }

        if (!confirmed) {
          _addBotMessage(
            "Please *Haan* ya *Nahi* likhen.",
          );
          return;
        }

        // ── Issue the token ───────────────────────────────
        await _issueToken();
        break;
    }
  }

  // ── Fetch offices from live API ───────────────────────────
  Future<void> _fetchOffices(String city) async {
    try {
      final uri = Uri.parse(ApiConfig.offices);
      final resp = await http.get(uri).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final List<dynamic> data = json.decode(resp.body);
        // Filter by city name (case-insensitive)
        _officeList = data
            .cast<Map<String, dynamic>>()
            .where((o) =>
                (o['city_name'] ?? '').toString().toLowerCase() ==
                city.toLowerCase())
            .toList();
      }
    } catch (e) {
      debugPrint('Fetch offices error: $e');
      _officeList = [];
    }

    if (_officeList.isEmpty) {
      // Graceful fallback — simulated offices
      _officeList = [
        {
          'office_id': 1,
          'branch_name': 'NADRA Office – Main Branch',
          'google_address': '$city – Main Branch',
          'in_queue': _rng.nextInt(8),
          'wait_time': _rng.nextInt(60) + 10,
          'wait_status': 'Moderate',
        },
        {
          'office_id': 2,
          'branch_name': 'NADRA Office – City Centre',
          'google_address': '$city – City Centre',
          'in_queue': _rng.nextInt(5),
          'wait_time': _rng.nextInt(40) + 5,
          'wait_status': 'Low',
        },
      ];
    }

    _addBotMessage(
      "🏢 *${_slots['city']}* mein ye offices available hain:\n\n"
      "${_officeListText()}\n\n"
      "Office ka number ya naam likhein:",
    );
  }

  /// Format office list for display
  String _officeListText() {
    final buf = StringBuffer();
    for (var i = 0; i < _officeList.length; i++) {
      final o = _officeList[i];
      final status = o['wait_status'] ?? 'N/A';
      final inQueue = o['in_queue'] ?? 0;
      final emoji = status == 'Low'
          ? '🟢'
          : status == 'Moderate'
              ? '🟡'
              : '🔴';
      buf.writeln(
          '${i + 1}. ${o['branch_name']}  $emoji $status ($inQueue log queue mein)');
    }
    return buf.toString().trim();
  }

  /// Match user's input to an office by index or name substring
  Map<String, dynamic>? _matchOffice(String input) {
    final trimmed = input.trim();
    // Try numeric index first
    final idx = int.tryParse(trimmed);
    if (idx != null && idx >= 1 && idx <= _officeList.length) {
      return _officeList[idx - 1];
    }
    // Try name substring
    final lower = trimmed.toLowerCase();
    for (final o in _officeList) {
      if ((o['branch_name'] ?? '').toString().toLowerCase().contains(lower)) {
        return o;
      }
    }
    return null;
  }

  /// Map user input to a clean service name
  String? _matchService(String input) {
    final s = input.toLowerCase().trim();
    if (s == '1' || s.contains('naya') || s.contains('new')) return 'Naya CNIC';
    if (s == '2' || s.contains('renew') || s.contains('tajdeed')) {
      return 'CNIC Renewal';
    }
    if (s == '3' || s.contains('b-form') || s.contains('bform') ||
        s.contains('b form')) return 'B-Form';
    if (s == '4' || s.contains('frc') || s.contains('family')) return 'FRC';
    if (s == '5' || s.contains('address') || s.contains('pata')) {
      return 'Address Change';
    }
    return null;
  }

  /// Simulate or call token creation API
  Future<void> _issueToken() async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    final tokenNumber = 100 + _rng.nextInt(900);
    final waitMinutes = 10 + _rng.nextInt(50);
    final peopleAhead = (waitMinutes ~/ 10);

    final reply =
        "🎫 *Aapka Token Successfully Issue Ho Gaya!*\n\n"
        "━━━━━━━━━━━━━━━━━━━━\n"
        "🔢  Token Number : *T-$tokenNumber*\n"
        "🏢  Office       : ${_slots['office_name']}\n"
        "📌  Service      : ${_slots['service']}\n"
        "👥  Aage log     : $peopleAhead\n"
        "⏳  Wait Time    : ~$waitMinutes minutes\n"
        "━━━━━━━━━━━━━━━━━━━━\n\n"
        "Apna token number save kar lein. Waqt par office pahunchein! ✅";

    _addBotMessage(reply);
    await _speakText(
      "Aapka token T $tokenNumber issue ho gaya. "
      "Estimated wait time $waitMinutes minutes hai.",
    );

    _resetFlow();
  }

  // ============================================================
  //  FLOW 2 HANDLER: QUEUE STATUS
  // ============================================================
  Future<void> _handleQueueStatusFlow(String input) async {
    switch (_flowStep) {
      case 0:
        final tokenNum = int.tryParse(input.replaceAll(RegExp(r'[^0-9]'), ''));
        if (tokenNum == null) {
          _addBotMessage(
            "⚠️ Please sirf *token number* likhein (sirf digits).\n"
            "Example: 342",
          );
          return;
        }
        _slots['token_number'] = tokenNum;

        // Simulate API response
        await Future.delayed(const Duration(milliseconds: 800));
        final ahead = _rng.nextInt(10);
        final wait = ahead * 10;

        _addBotMessage(
          "📊 *Queue Status — Token #$tokenNum*\n\n"
          "━━━━━━━━━━━━━━━━━━━━\n"
          "👥  Aage log     : $ahead\n"
          "⏳  Est. Wait    : ~$wait minutes\n"
          "✅  Status       : ${ahead == 0 ? 'Aapki baari aa gayi! 🎉' : 'Waiting...'}\n"
          "━━━━━━━━━━━━━━━━━━━━\n\n"
          "Refresh ke liye dobara poochein.",
        );
        await _speakText(
          ahead == 0
              ? "Aapki baari aa gayi hai. Please counter par jayen."
              : "Aapke aage $ahead log hain. Estimated wait $wait minutes hai.",
        );
        _resetFlow();
        break;
    }
  }

  // ============================================================
  //  FLOW 3 HANDLER: CENTER INFO
  // ============================================================
  Future<void> _handleCenterInfoFlow(String input) async {
    switch (_flowStep) {
      case 0:
        _slots['city'] = input.trim();
        _flowStep = 1;

        // Fetch from API
        await _fetchOffices(input.trim());
        // After _fetchOffices, step 1 asks for office selection

        // Override message — just show info not selection
        if (mounted) {
          // Remove the "likhein" prompt added by _fetchOffices
          // and replace with info-only message
          if (_messages.isNotEmpty && !_messages.last.isUser) {
            _messages.removeLast();
          }
        }

        final buf = StringBuffer();
        buf.writeln("🏢 *${_slots['city']} NADRA Offices:*\n");
        for (final o in _officeList) {
          buf.writeln("📍 *${o['branch_name']}*");
          buf.writeln("   🗺️  ${o['google_address'] ?? 'N/A'}");
          final inQueue = o['in_queue'] ?? '?';
          final wait = o['wait_time'] ?? '?';
          buf.writeln("   👥  Queue: $inQueue log  |  ⏳ ~$wait min");
          buf.writeln();
        }
        buf.write("Koi aur madad chahiye?");
        _addBotMessage(buf.toString());
        _resetFlow();
        break;
    }
  }

  // ============================================================
  //  ★ HELPER: Add bot message to chat (DRY)
  // ============================================================
  void _addBotMessage(String text) {
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: false,
        time: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  // ============================================================
  //  ★ RESET FLOW — Call after any flow completes or is cancelled
  // ============================================================
  void _resetFlow() {
    _currentFlow = _Flow.none;
    _flowStep = 0;
    _slots.clear();
    _officeList.clear();
  }

  // ── Simple yes/no helpers ─────────────────────────────────
  bool _isConfirmed(String input) {
    final s = input.toLowerCase().trim();
    return ['haan', 'han', 'yes', 'yeah', 'ha', 'okay', 'ok', 'theek', '1',
        'confirm', 'bilkul', 'zaroor']
        .any((k) => s.contains(k));
  }

  bool _isDeclined(String input) {
    final s = input.toLowerCase().trim();
    return ['nahi', 'no', 'nope', 'cancel', 'band karo', 'stop', '0', 'quit']
        .any((k) => s.contains(k));
  }

  // ============================================================
  //  ★ DOCUMENT GUIDE API — Existing API logic (unchanged)
  //  Used for fallback / explicit doc queries
  // ============================================================
  Future<void> _callDocumentApi(String query) async {
    String agentReply;

    try {
      debugPrint('→ API: $_apiUrl  |  query: $query');

      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({'query': query}),
          )
          .timeout(const Duration(seconds: 20));

      debugPrint('← Status: ${response.statusCode}');
      debugPrint('← Body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final serviceName = (data['service_name'] ?? '').toString().trim();
        final requiredDocs =
            (data['required_documents'] ?? '').toString().trim();
        final answer =
            (data['answer'] ?? data['documents'] ?? '').toString().trim();

        final parts = <String>[];
        if (serviceName.isNotEmpty) parts.add('📋 *$serviceName*');
        if (requiredDocs.isNotEmpty) parts.add(requiredDocs);
        if (answer.isNotEmpty) parts.add(answer);

        agentReply = parts.join('\n\n');
        if (agentReply.isEmpty) {
          agentReply =
              'Jawab mila lekin content khaali tha. Dobara try karein.';
        }

        if (!kIsWeb) {
          final toSpeak = [
            if (serviceName.isNotEmpty) serviceName,
            if (answer.isNotEmpty)
              answer
            else if (requiredDocs.isNotEmpty)
              requiredDocs,
          ].join('۔ ');
          if (toSpeak.isNotEmpty) await _speakText(toSpeak);
        }
      } else {
        final msg = (data['message'] ?? data['error'] ?? '').toString().trim();
        agentReply = msg.isNotEmpty
            ? msg
            : 'Maaf kijiye, is service ka record nahi mila.\n\n'
                'Aap ye try kar saktay hain:\n'
                '🎫  Naya token lena\n'
                '📍  Queue status check karna\n'
                '🏢  Center ki info';
      }
    } on Exception catch (e) {
      debugPrint('API Exception: $e');
      final err = e.toString();
      if (err.contains('TimeoutException')) {
        agentReply = '⚠️ Server response nahi de raha (timeout).\n\n'
            'Check karein:\n'
            '• Django chal raha hai? → python manage.py runserver\n'
            '• Browser mein khul raha hai? → $_apiUrl\n'
            '• Firewall/antivirus block to nahi?';
      } else if (err.contains('SocketException') || err.contains('refused')) {
        agentReply = '⚠️ Server se connect nahi ho pa raha.\n\n'
            'Check karein:\n'
            '• python manage.py runserver chalu karo\n'
            '• URL: $_apiUrl';
      } else {
        agentReply = '⚠️ Error: $e';
      }
    }

    _addBotMessage(agentReply);
  }

  // ════════════════════════════════════════════════════════════
  //  TTS HELPERS  (unchanged)
  // ════════════════════════════════════════════════════════════
  String _cleanForTts(String text) {
    String clean = text
        .replaceAll('📋', '')
        .replaceAll('⚠️', '')
        .replaceAll('🎫', '')
        .replaceAll('🏢', '')
        .replaceAll('📍', '')
        .replaceAll('🟢', '')
        .replaceAll('🟡', '')
        .replaceAll('🔴', '')
        .replaceAll('━', '')
        .replaceAll('*', '')
        .replaceAll('•', '');

    final lines = clean.split(RegExp(r'[\n،,]'));
    return lines
        .map((line) => line
            .trim()
            .replaceFirst(RegExp(r'^[\d١-٩]+[۔.\-\)]\s*'), '')
            .trim())
        .where((l) => l.isNotEmpty)
        .join('۔ ');
  }

  Future<void> _speakText(String text) async {
    await _tts.stop();
    final cleanText = _cleanForTts(text);
    if (cleanText.isNotEmpty) await _tts.speak(cleanText);
  }

  // ════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════
  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 13)),
        backgroundColor: const Color(0xFF003399),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final h = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour >= 12 ? "PM" : "AM"}';
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD  (UI completely unchanged)
  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildListeningBanner(),
          Expanded(child: _buildChatList()),
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color.fromARGB(250, 48, 125, 13),
      elevation: 1,
      leadingWidth: 48,
      leading: const Padding(
        padding: EdgeInsets.only(left: 10),
        child: CircleAvatar(
          backgroundColor: Color.fromARGB(250, 48, 125, 13),
          child: Icon(Icons.support_agent,
              color: Color.fromARGB(255, 0, 0, 0), size: 22),
        ),
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NADRA Virtual Agent',
              style: TextStyle(
                  color: Color.fromARGB(255, 0, 0, 0),
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          Text('Online',
              style:
                  TextStyle(color: Color.fromARGB(255, 0, 0, 0), fontSize: 12)),
        ],
      ),
      actions: [
        IconButton(
            icon: const Icon(Icons.more_vert,
                color: Color.fromARGB(255, 0, 0, 0)),
            onPressed: () {}),
      ],
    );
  }

  Widget _buildListeningBanner() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _isListening ? 46 : 0,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(color: Color(0xFFE53935)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _waveController,
            builder: (_, __) {
              final bars = [0.5, 0.8, 1.0, 0.8, 0.5];
              return Row(
                children: bars.asMap().entries.map((e) {
                  final v = sin(
                    (_waveController.value * 2 * pi) + e.key * 0.4,
                  ).abs();
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    width: 3,
                    height: 6 + (10 * v * e.value),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              _recognizedText.isEmpty ? 'Sun raha hoon...' : _recognizedText,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _stopListeningAndSend,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isTyping && index == _messages.length) {
          return _buildTypingIndicator();
        }
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 3,
          bottom: 3,
          left: isUser ? 60 : 0,
          right: isUser ? 0 : 60,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFFDCF8C6) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(msg.text,
                  style: const TextStyle(
                      fontSize: 15, color: Colors.black87, height: 1.45)),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isUser && msg.isVoice) ...[
                  const Icon(Icons.mic, size: 11, color: Colors.grey),
                  const SizedBox(width: 3),
                ],
                Text(_formatTime(msg.time),
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                if (isUser) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.done_all,
                      size: 14, color: Color(0xFF34B7F1)),
                ],
                if (!isUser) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _speakText(msg.text),
                    child: Icon(
                      _isSpeaking
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      size: 14,
                      color: const Color.fromARGB(250, 48, 125, 13)
                          .withOpacity(0.55),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 4, right: 60),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 4,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0),
            const SizedBox(width: 4),
            _buildDot(200),
            const SizedBox(width: 4),
            _buildDot(400),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delayMs),
      builder: (context, value, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: Color.lerp(
              Colors.grey[300], const Color.fromARGB(250, 48, 125, 13), value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: const Color(0xFFF0F0F0),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05), blurRadius: 4),
                  ],
                ),
                child: TextField(
                  controller: _queryController,
                  enabled: !_isTyping && !_isListening,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: _isListening
                        ? '🔴  Bol raha hoon...'
                        : _isTyping
                            ? 'Agent typing...'
                            : 'Type a message...',
                    hintStyle: TextStyle(
                      color:
                          _isListening ? const Color(0xFFE53935) : Colors.grey,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _sendTextMessage(),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Mic button
            GestureDetector(
              onTap: _onMicTap,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isListening)
                    AnimatedBuilder(
                      animation: _rippleAnim,
                      builder: (_, __) => Container(
                        width: 52 * _rippleAnim.value,
                        height: 52 * _rippleAnim.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFE53935).withOpacity(
                            0.18 * (1 - _rippleAnim.value + 0.5),
                          ),
                        ),
                      ),
                    ),
                  AnimatedBuilder(
                    animation:
                        _isListening ? _pulseAnim : kAlwaysCompleteAnimation,
                    builder: (_, __) => Transform.scale(
                      scale: _isListening ? _pulseAnim.value : 1.0,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kIsWeb
                              ? Colors.grey.shade400
                              : _isListening
                                  ? const Color(0xFFE53935)
                                  : _isTyping
                                      ? Colors.grey
                                      : const Color.fromARGB(250, 48, 125, 13),
                          boxShadow: [
                            BoxShadow(
                              color: (_isListening
                                      ? Colors.red
                                      : const Color.fromARGB(250, 48, 125, 13))
                                  .withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
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
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Send button
            GestureDetector(
              onTap: _sendTextMessage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (_isTyping || _isListening)
                      ? Colors.grey
                      : const Color.fromARGB(250, 48, 125, 13),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromARGB(250, 48, 125, 13)
                          .withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
*/