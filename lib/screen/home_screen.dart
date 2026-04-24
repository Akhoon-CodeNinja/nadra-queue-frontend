// ============================================================
//  home_screen.dart
//  UPDATED: Dark mode support throughout + Fixed Wizard + State Sync
// ============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_config.dart';
import 'my_tokens_screen.dart';
import 'offices_screen.dart';
import 'chatbot_screen.dart';
import 'profile_screen.dart';

const _kGreen = Color.fromARGB(250, 48, 125, 13);

class HomeScreen extends StatefulWidget {
  final int userId;
  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _fullName = '';
  Map<String, dynamic>? _latestToken;
  bool _loadingToken = true;

  List<Map<String, dynamic>> _cities    = [];
  List<Map<String, dynamic>> _districts = [];
  List<Map<String, dynamic>> _offices   = [];

  Map<String, dynamic>? _selCity;
  Map<String, dynamic>? _selDistrict;
  Map<String, dynamic>? _selOffice;

  bool _bookingLoading = false;
  int  _wizardStep     = 0;

  @override
  void initState() {
    super.initState();
    _loadName();
    _fetchLatestToken();
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _fullName = prefs.getString('full_name') ?? 'User');
  }

  Future<void> _fetchLatestToken() async {
    setState(() => _loadingToken = true);
    try {
      final res = await http
          .get(Uri.parse(ApiConfig.myTokens(widget.userId)))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data   = jsonDecode(res.body);
        final List tokens = data['data'] ?? [];
        if (mounted) {
          setState(() {
            _latestToken  = tokens.isNotEmpty ? Map<String, dynamic>.from(tokens.first) : null;
            _loadingToken = false;
          });
        }
      } else {
        if (mounted) setState(() => _loadingToken = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingToken = false);
    }
  }

  // ✅ UPDATED: Refreshes state upon returning to avoid re-login issues
  Future<void> _goTo(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _fetchLatestToken(); 
  }

  // ── Booking fetch ──────────────────────────────────────
  Future<void> _fetchCities() async {
    if (_cities.isNotEmpty) return;
    try {
      final res = await http
          .get(Uri.parse(ApiConfig.cities), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body)['data'] ?? [];
        if (mounted) {
          setState(() {
            _cities = data
                .map<Map<String, dynamic>>(
                    (c) => {'city_id': c['city_id'], 'city_name': c['city_name']})
                .toList();
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchDistricts(int cityId) async {
    try {
      final res = await http
          .get(Uri.parse('${ApiConfig.districts}?city_id=$cityId'),
              headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body)['data'] ?? [];
        if (mounted) {
          setState(() {
            _districts = data
                .map<Map<String, dynamic>>((d) => {
                      'district_id': d['district_id'],
                      'district_name': d['district_name'],
                    })
                .toList();
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchOfficesBooking(int districtId) async {
    try {
      final res = await http
          .get(Uri.parse('${ApiConfig.offices}?district_id=$districtId'),
              headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body)['data'] ?? [];
        if (mounted) {
          setState(() {
            _offices = data
                .map<Map<String, dynamic>>((o) => {
                      'office_id'  : o['office_id'],
                      'office_name': o['office_name'],
                      'address'    : o['address'] ?? '',
                      'wait_time'  : o['estimated_wait_time'] ?? 'N/A',
                    })
                .toList();
          });
        }
      }
    } catch (_) {}
  }

  // ── Submit token ───────────────────────────────────────
  Future<void> _submitToken() async {
    if (_selOffice == null) return;
    setState(() => _bookingLoading = true);
    try {
      final res = await http
          .post(
            Uri.parse(ApiConfig.tokensCreate),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({'user_id': widget.userId, 'office_id': _selOffice!['office_id']}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body);
      if (!mounted) return;
      Navigator.pop(context);

      if ((res.statusCode == 200 || res.statusCode == 201) && data['success'] == true) {
        _fetchLatestToken();
        _showSuccessDialog(data);
      } else {
        _showSnack(data['message'] ?? 'Booking failed. Try again.', isError: true);
      }
    } catch (_) {
      if (mounted) {
        Navigator.pop(context);
        _showSnack('Network error. Backend chal raha hai?', isError: true);
      }
    } finally {
      if (mounted) setState(() => _bookingLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : _kGreen,
    ));
  }

  void _showSuccessDialog(Map<String, dynamic> data) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: _kGreen, size: 64),
            const SizedBox(height: 12),
            const Text('Token Booked!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Token #${data['token_number'] ?? data['token_id'] ?? '—'}\n${_selOffice!['office_name']}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: _kGreen)),
          ),
        ],
      ),
    );
  }

  // ── Booking wizard ─────────────────────────────────────
  void _openBookingWizard() async {
    setState(() {
      _wizardStep   = 0;
      _selCity      = null;
      _selDistrict  = null;
      _selOffice    = null;
      _districts    = [];
      _offices      = [];
    });
    await _fetchCities();
    if (!mounted) return;
    _showWizardSheet();
  }

  void _showWizardSheet() {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final sheetBg   = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _BookingWizard(
        cities: _cities, districts: _districts, offices: _offices,
        selCity: _selCity, selDistrict: _selDistrict, selOffice: _selOffice,
        wizardStep: _wizardStep, bookingLoading: _bookingLoading,
        isDark: isDark,
        onCitySelected: (city) async {
          setState(() { _selCity = city; _selDistrict = null; _selOffice = null;
            _districts = []; _offices = []; _wizardStep = 1; });
          await _fetchDistricts(city['city_id']);
          if (mounted) { Navigator.pop(context); _showWizardSheet(); }
        },
        onDistrictSelected: (district) async {
          setState(() { _selDistrict = district; _selOffice = null;
            _offices = []; _wizardStep = 2; });
          await _fetchOfficesBooking(district['district_id']);
          if (mounted) { Navigator.pop(context); _showWizardSheet(); }
        },
        onOfficeSelected: (office) {
          setState(() { _selOffice = office; _wizardStep = 3; });
          Navigator.pop(context); _showWizardSheet();
        },
        onConfirm: _submitToken,
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final bgColor   = isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor  = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final cardBg    = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final firstName = _fullName.split(' ').first;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: _kGreen,
          onRefresh: _fetchLatestToken,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Assalam-o-Alaikum,',
                              style: TextStyle(color: subColor, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(firstName,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: _kGreen)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _goTo(ProfileScreen(userId: widget.userId)),
                      child: Container(
                        width: 46, height: 46,
                        decoration: const BoxDecoration(
                            color: _kGreen, shape: BoxShape.circle),
                        child: const Icon(Icons.person,
                            color: Colors.white, size: 26),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Latest Token Card ────────────────────────
                _LatestTokenCard(
                  isLoading: _loadingToken,
                  token: _latestToken,
                  onRefresh: _fetchLatestToken,
                ),
                const SizedBox(height: 28),

                // ── Quick Actions ────────────────────────────
                Text('Quick Actions',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor)),
                const SizedBox(height: 14),

                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.25,
                  children: [
                      _QuickCard(
                        icon: Icons.confirmation_number_outlined,
                        label: 'Book Token',
                        urduLabel: 'ٹوکن بک کریں',
                        color: _kGreen,
                        cardBg: cardBg,
                        textColor: textColor,
                        onTap: _openBookingWizard,
                      ),
                      _QuickCard(
                        icon: Icons.article_outlined,
                        label: 'My Tokens',
                        urduLabel: 'میرے ٹوکنز',
                        color: const Color(0xFF1565C0),
                        cardBg: cardBg,
                        textColor: textColor,
                        onTap: () => _goTo(MyTokensScreen(userId: widget.userId)),
                      ),
                      _QuickCard(
                        icon: Icons.location_on_outlined,
                        label: 'Find Office',
                        urduLabel: 'دفتر تلاش کریں',
                        color: const Color(0xFFE65100),
                        cardBg: cardBg,
                        textColor: textColor,
                        onTap: () => _goTo(const OfficesScreen()),
                      ),
                      _QuickCard(
                        icon: Icons.smart_toy_outlined,
                        label: 'AI Assistant',
                        urduLabel: 'اے آئی اسسٹنٹ',
                        color: const Color(0xFF6A1B9A),
                        cardBg: cardBg,
                        textColor: textColor,
                        onTap: () => _goTo(ChatbotScreen(userId: widget.userId)),
                      ),
                    ],
                ),
                const SizedBox(height: 24),

                // ── Info Banner ──────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _kGreen.withOpacity(isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _kGreen.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: _kGreen, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Book your NADRA token online and skip the '
                          'physical queue. Arrive at your scheduled time.',
                          style: TextStyle(
                              fontSize: 13, height: 1.5, color: textColor),
                        ),
                      ),
                    ],
                  ),
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

// ── Latest Token Card ─────────────────────────────────────────
class _LatestTokenCard extends StatelessWidget {
  final bool isLoading;
  final Map<String, dynamic>? token;
  final VoidCallback onRefresh;

  const _LatestTokenCard({
    required this.isLoading,
    required this.token,
    required this.onRefresh,
  });

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'active':    return Colors.greenAccent;
      case 'completed': return Colors.lightBlueAccent;
      case 'cancelled': return Colors.redAccent;
      default:          return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kGreen, Color.fromARGB(255, 34, 90, 9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: _kGreen.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 5)),
        ],
      ),
      child: isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: CircularProgressIndicator(color: Colors.white),
              ))
          : token == null
              ? _noToken()
              : _tokenInfo(),
    );
  }

  Widget _noToken() => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No Active Token',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text('Book a token using the card below.',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      );

  Widget _tokenInfo() {
    final status   = token!['status']       ?? 'Unknown';
    final office   = token!['office_name']  ?? 'NADRA Office';
    final tokenNum = token!['token_number'] ?? token!['token_id'] ?? '—';
    final date     = (token!['created_at']  ?? '').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Latest Token',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(status,
                  style: TextStyle(
                      color: _statusColor(status),
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('#$tokenNum',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 2)),
        const SizedBox(height: 4),
        Text(office,
            style: const TextStyle(color: Colors.white, fontSize: 14)),
        if (date.length >= 10)
          Text(date.substring(0, 10),
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}

// ── Quick Action Card ─────────────────────────────────────────
class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String urduLabel; 
  final Color color;
  final Color cardBg;
  final Color textColor;
  final VoidCallback onTap;

  const _QuickCard({
    required this.icon,
    required this.label,
    required this.urduLabel, 
    required this.color,
    required this.cardBg,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: textColor,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              urduLabel,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl, 
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: textColor.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Booking Wizard ────────────────────────────────────────────
class _BookingWizard extends StatelessWidget {
  final List<Map<String, dynamic>> cities;
  final List<Map<String, dynamic>> districts;
  final List<Map<String, dynamic>> offices;
  final Map<String, dynamic>? selCity;
  final Map<String, dynamic>? selDistrict;
  final Map<String, dynamic>? selOffice;
  final int wizardStep;
  final bool bookingLoading;
  final bool isDark;
  final ValueChanged<Map<String, dynamic>> onCitySelected;
  final ValueChanged<Map<String, dynamic>> onDistrictSelected;
  final ValueChanged<Map<String, dynamic>> onOfficeSelected;
  final VoidCallback onConfirm;

  const _BookingWizard({
    required this.cities, required this.districts, required this.offices,
    required this.selCity, required this.selDistrict, required this.selOffice,
    required this.wizardStep, required this.bookingLoading, required this.isDark,
    required this.onCitySelected, required this.onDistrictSelected,
    required this.onOfficeSelected, required this.onConfirm,
  });

  Color get _textColor => isDark ? Colors.white : Colors.black87;
  Color get _subColor  => isDark ? Colors.grey[400]! : Colors.grey[700]!;
  Color get _divColor  => isDark ? const Color(0xFF333333) : Colors.grey.shade200;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min, // ✅ FIXED: Keeps bottom sheet height dynamic
        children: [
          // ✅ ADDED: Wizard Step Indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StepDot(active: wizardStep >= 0, label: '1'),
              _StepLine(active: wizardStep >= 1),
              _StepDot(active: wizardStep >= 1, label: '2'),
              _StepLine(active: wizardStep >= 2),
              _StepDot(active: wizardStep >= 2, label: '3'),
              _StepLine(active: wizardStep >= 3),
              _StepDot(active: wizardStep >= 3, label: '4'),
            ],
          ),
          const SizedBox(height: 20),
          
          if (wizardStep == 0) ..._cityStep(),
          if (wizardStep == 1) ..._districtStep(),
          if (wizardStep == 2) ..._officeStep(),
          if (wizardStep == 3) ..._confirmStep(context),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<Widget> _cityStep() => [
        Text('Select City',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _textColor)),
        const SizedBox(height: 12),
        if (cities.isEmpty)
          const Center(
              child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(color: _kGreen),
          ))
        else
          SizedBox(
            height: 260,
            child: ListView.separated(
              itemCount: cities.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: _divColor),
              itemBuilder: (_, i) {
                final c = cities[i];
                return ListTile(
                  leading: const Icon(Icons.location_city, color: _kGreen),
                  title: Text(c['city_name'], style: TextStyle(color: _textColor)),
                  trailing: Icon(Icons.arrow_forward_ios, size: 14, color: _subColor),
                  onTap: () => onCitySelected(c),
                );
              },
            ),
          ),
      ];

  List<Widget> _districtStep() => [
        Text('City: ${selCity?['city_name'] ?? ''}',
            style: const TextStyle(color: _kGreen, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Select District',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _textColor)),
        const SizedBox(height: 12),
        if (districts.isEmpty)
          const Center(
              child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: _kGreen)))
        else
          SizedBox(
            height: 260,
            child: ListView.separated(
              itemCount: districts.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: _divColor),
              itemBuilder: (_, i) {
                final d = districts[i];
                return ListTile(
                  leading: const Icon(Icons.map_outlined, color: _kGreen),
                  title: Text(d['district_name'], style: TextStyle(color: _textColor)),
                  trailing: Icon(Icons.arrow_forward_ios, size: 14, color: _subColor),
                  onTap: () => onDistrictSelected(d),
                );
              },
            ),
          ),
      ];

  List<Widget> _officeStep() => [
        Text('District: ${selDistrict?['district_name'] ?? ''}',
            style: const TextStyle(color: _kGreen, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Select Office',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _textColor)),
        const SizedBox(height: 12),
        if (offices.isEmpty)
          const Center(
              child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: _kGreen)))
        else
          SizedBox(
            height: 280,
            child: ListView.separated(
              itemCount: offices.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: _divColor),
              itemBuilder: (_, i) {
                final o = offices[i];
                return ListTile(
                  leading: const Icon(Icons.business, color: _kGreen),
                  title: Text(o['office_name'], style: TextStyle(color: _textColor)),
                  subtitle: Text(o['address'],
                      style: TextStyle(fontSize: 12, color: _subColor)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: _kGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('~${o['wait_time']} min',
                        style: const TextStyle(color: _kGreen, fontSize: 11)),
                  ),
                  onTap: () => onOfficeSelected(o),
                );
              },
            ),
          ),
      ];

  List<Widget> _confirmStep(BuildContext ctx) => [
        Text('Confirm Booking',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _textColor)),
        const SizedBox(height: 16),
        _ConfirmRow(label: 'City',     value: selCity?['city_name']        ?? '—', textColor: _textColor, subColor: _subColor),
        _ConfirmRow(label: 'District', value: selDistrict?['district_name'] ?? '—', textColor: _textColor, subColor: _subColor),
        _ConfirmRow(label: 'Office',   value: selOffice?['office_name']     ?? '—', textColor: _textColor, subColor: _subColor),
        _ConfirmRow(label: 'Wait',     value: '~${selOffice?['wait_time'] ?? 'N/A'} min', textColor: _textColor, subColor: _subColor),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: bookingLoading ? null : onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: bookingLoading
                ? const SizedBox(
                    height: 24, width: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text('Confirm & Book Token',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
      ];
}

class _StepDot extends StatelessWidget {
  final bool active;
  final String label;
  const _StepDot({required this.active, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
            color: active ? _kGreen : Colors.grey[400], shape: BoxShape.circle),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: active ? Colors.white : Colors.grey[700],
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ),
      );
}

class _StepLine extends StatelessWidget {
  final bool active;
  const _StepLine({required this.active});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(height: 3, color: active ? _kGreen : Colors.grey[400]),
      );
}

class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;
  final Color textColor;
  final Color subColor;
  const _ConfirmRow({required this.label, required this.value, required this.textColor, required this.subColor});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            SizedBox(
              width: 70,
              child: Text(label, style: TextStyle(color: subColor, fontSize: 13)),
            ),
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: textColor)),
            ),
          ],
        ),
      );
}