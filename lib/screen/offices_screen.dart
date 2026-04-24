// ============================================================
//  offices_screen.dart
//  UPDATE: City → District → Office cascading filter added
//
//  Flow:
//  1. Screen khulte hi saari cities fetch hoti hain
//  2. City select karo → us city ke districts load hote hain
//  3. District select karo → sirf us district ke offices dikhte hain
//  4. "Clear" button → filter reset, sab offices wapas
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'api_config.dart';

class OfficesScreen extends StatefulWidget {
  const OfficesScreen({super.key});

  @override
  State<OfficesScreen> createState() => _OfficesScreenState();
}

class _OfficesScreenState extends State<OfficesScreen> {
  // ── App green color ───────────────────────────────────────
  static const _green = Color.fromARGB(250, 48, 125, 13);

  // ── Wait-status filter (existing) ────────────────────────
  String _selectedFilter = 'All';
  final _searchController = TextEditingController();

  // ── All offices (raw from API) ────────────────────────────
  List<Map<String, dynamic>> _allOffices = [];

  // ── Cities & Districts ────────────────────────────────────
  List<Map<String, dynamic>> _cities    = [];
  List<Map<String, dynamic>> _districts = [];

  // ── Selected values (null = not selected) ─────────────────
  Map<String, dynamic>? _selectedCity;
  Map<String, dynamic>? _selectedDistrict;

  // ── Loading states ─────────────────────────────────────────
  bool   _isLoadingOffices   = true;
  bool   _isLoadingCities    = true;
  bool   _isLoadingDistricts = false;
  String? _errorMessage;

  // ═══════════════════════════════════════════════════════════
  //  INIT
  // ═══════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _fetchCities();
    _fetchOffices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  //  FETCH CITIES
  // ═══════════════════════════════════════════════════════════
  Future<void> _fetchCities() async {
    setState(() => _isLoadingCities = true);
    try {
      final res = await http
          .get(Uri.parse(ApiConfig.cities),
              headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        final List<dynamic> data = decoded['data'] ?? [];
        setState(() {
          _cities = data
              .map<Map<String, dynamic>>((c) => {
                    'city_id'  : c['city_id'],
                    'city_name': c['city_name'],
                  })
              .toList();
          _isLoadingCities = false;
        });
      }
    } catch (_) {
      setState(() => _isLoadingCities = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  FETCH DISTRICTS  (city select hone ke baad)
  // ═══════════════════════════════════════════════════════════
  Future<void> _fetchDistricts(int cityId) async {
    setState(() {
      _isLoadingDistricts = true;
      _districts          = [];
      _selectedDistrict   = null;
    });
    try {
      final url = '${ApiConfig.districts}?city_id=$cityId';
      final res = await http
          .get(Uri.parse(url), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        final List<dynamic> data = decoded['data'] ?? [];
        setState(() {
          _districts = data
              .map<Map<String, dynamic>>((d) => {
                    'district_id'  : d['district_id'],
                    'district_name': d['district_name'],
                  })
              .toList();
          _isLoadingDistricts = false;
        });
      }
    } catch (_) {
      setState(() => _isLoadingDistricts = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  FETCH OFFICES  (with optional city_id / district_id)
  // ═══════════════════════════════════════════════════════════
  Future<void> _fetchOffices({int? cityId, int? districtId}) async {
    setState(() {
      _isLoadingOffices = true;
      _errorMessage     = null;
    });

    try {
      // URL build karo — filter params add karo agar hain
      String url = ApiConfig.offices;
      if (districtId != null) {
        url += '?district_id=$districtId';
      } else if (cityId != null) {
        url += '?city_id=$cityId';
      }

      final res = await http
          .get(Uri.parse(url), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final Map<String, dynamic> decoded = json.decode(res.body);
        final List<dynamic> data = decoded['data'] ?? [];

        setState(() {
          _allOffices = data.map<Map<String, dynamic>>((office) {
            // ── Time format helper ─────────────────────────
            String formatTime(String? time) {
              if (time == null || time.isEmpty) return '';
              try {
                final parts  = time.split(':');
                int    hour   = int.parse(parts[0]);
                final  minute = parts[1];
                final  period = hour >= 12 ? 'PM' : 'AM';
                if (hour > 12) hour -= 12;
                if (hour == 0) hour = 12;
                return '$hour:$minute $period';
              } catch (_) {
                return time;
              }
            }

            final openTime  = formatTime(office['open_time']?.toString());
            final closeTime = formatTime(office['close_time']?.toString());
            final hours = (openTime.isNotEmpty && closeTime.isNotEmpty)
                ? '$openTime - $closeTime'
                : 'N/A';

            // ── Services / open_days ───────────────────────
            List<String> services = [];
            final rawServices = office['services'];
            if (rawServices is List) {
              services = rawServices.map((s) => s.toString()).toList();
            } else if (rawServices is String && rawServices.isNotEmpty) {
              services = rawServices.split(',').map((s) => s.trim()).toList();
            }
            if (services.isEmpty && office['open_days'] != null) {
              services = [office['open_days'].toString()];
            }

            final waitStatus  = (office['wait_status'] ?? 'Low').toString();
            final inQueue     = office['in_queue'] ?? 0;
            final waitMins    = office['wait_time'] ?? 0;
            final waitTimeLabel = waitMins > 0 ? '~$waitMins min' : '< 10 min';

            return {
              'name'         : office['branch_name'] ?? 'Unknown Office',
              'address'      : '${office['branch_name'] ?? ''}, '
                               '${office['google_address'] ?? 'No address'}, Pakistan',
              'hours'        : hours,
              'services'     : services,
              'waitTime'     : waitTimeLabel,
              'inQueue'      : inQueue,
              'status'       : waitStatus,
              'capacity'     : office['capacity'] ?? 0,
              'latitude'     : office['latitude'],
              'longitude'    : office['longitude'],
              'city_name'    : office['city_name'] ?? '',
              'district_name': office['district_name'] ?? '',
            };
          }).toList();

          _isLoadingOffices = false;
        });
      } else {
        setState(() {
          _errorMessage     = 'Failed to load offices (${res.statusCode})';
          _isLoadingOffices = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage     = 'Error connecting to server:\n${e.toString()}';
        _isLoadingOffices = false;
      });
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  CITY SELECTED
  // ═══════════════════════════════════════════════════════════
  void _onCitySelected(Map<String, dynamic>? city) {
    setState(() {
      _selectedCity     = city;
      _selectedDistrict = null;
      _districts        = [];
    });
    if (city != null) {
      _fetchDistricts(city['city_id']);
      _fetchOffices(cityId: city['city_id']);
    } else {
      _fetchOffices(); // clear → sab offices
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  DISTRICT SELECTED
  // ═══════════════════════════════════════════════════════════
  void _onDistrictSelected(Map<String, dynamic>? district) {
    setState(() => _selectedDistrict = district);
    if (district != null) {
      _fetchOffices(districtId: district['district_id']);
    } else if (_selectedCity != null) {
      _fetchOffices(cityId: _selectedCity!['city_id']);
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  CLEAR FILTER
  // ═══════════════════════════════════════════════════════════
  void _clearFilter() {
    setState(() {
      _selectedCity     = null;
      _selectedDistrict = null;
      _districts        = [];
      _selectedFilter   = 'All';
    });
    _fetchOffices();
  }

  // ── Wait-status filter on top of location filter ──────────
  List<Map<String, dynamic>> get _filteredOffices {
    final query = _searchController.text.toLowerCase();
    return _allOffices.where((o) {
      final matchSearch = query.isEmpty ||
          o['name'].toString().toLowerCase().contains(query) ||
          o['address'].toString().toLowerCase().contains(query);
      final matchFilter =
          _selectedFilter == 'All' || o['status'] == _selectedFilter;
      return matchSearch && matchFilter;
    }).toList();
  }

  // ── Status → color ─────────────────────────────────────────
  Color _statusColor(String status) {
    switch (status) {
      case 'Low':      return Colors.green;
      case 'Moderate': return Colors.orange;
      case 'High':     return Colors.red;
      default:         return Colors.green;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOffices;
    final hasLocationFilter =
        _selectedCity != null || _selectedDistrict != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _green),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Find Offices',
          style: TextStyle(
              color: _green, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _fetchOffices(
            cityId    : _selectedCity?['city_id'],
            districtId: _selectedDistrict?['district_id'],
          ),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Header ──────────────────────────────────
                const Text(
                  'All Offices',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _green,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Find and book appointments at NADRA offices near you',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 16),

                // ── Search ───────────────────────────────────
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search by name or area...',
                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 16),

                // ════════════════════════════════════════════
                //  LOCATION FILTER CARD  ← NEW
                // ════════════════════════════════════════════
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: _green.withOpacity(0.25)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Section heading ──────────────────
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.location_city,
                                  size: 16, color: _green),
                              SizedBox(width: 6),
                              Text(
                                'Filter by Location',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: _green,
                                ),
                              ),
                            ],
                          ),
                          // Clear button — sirf tab dikhta hai
                          // jab koi filter active ho
                          if (hasLocationFilter)
                            GestureDetector(
                              onTap: _clearFilter,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.08),
                                  borderRadius:
                                      BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Clear Filter',
                                  style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── City Dropdown ────────────────────
                      _isLoadingCities
                          ? const Center(
                              child: SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: _green),
                              ),
                            )
                          : _buildDropdown(
                              hint : 'Select City',
                              icon : Icons.location_city_outlined,
                              value: _selectedCity,
                              items: _cities,
                              labelKey: 'city_name',
                              onChanged: _onCitySelected,
                            ),

                      // ── District Dropdown ────────────────
                      //    Sirf tab dikhao jab city select ho
                      if (_selectedCity != null) ...[
                        const SizedBox(height: 10),
                        _isLoadingDistricts
                            ? const Padding(
                                padding:
                                    EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _green),
                                    ),
                                    SizedBox(width: 10),
                                    Text('Loading districts...',
                                        style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 13)),
                                  ],
                                ),
                              )
                            : _buildDropdown(
                                hint    : 'Select District (Optional)',
                                icon    : Icons.map_outlined,
                                value   : _selectedDistrict,
                                items   : _districts,
                                labelKey: 'district_name',
                                onChanged: _onDistrictSelected,
                              ),
                      ],

                      // ── Active filter badge ──────────────
                      if (hasLocationFilter) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          children: [
                            if (_selectedCity != null)
                              _Badge(
                                  label: _selectedCity!['city_name'],
                                  icon: Icons.location_city),
                            if (_selectedDistrict != null)
                              _Badge(
                                  label: _selectedDistrict![
                                      'district_name'],
                                  icon: Icons.map_outlined),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Wait-status filter chips ──────────────────
                const Row(
                  children: [
                    Icon(Icons.filter_list,
                        size: 18, color: Colors.grey),
                    SizedBox(width: 6),
                    Text(
                      'Filter by queue congestion:',
                      style:
                          TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    _FilterChip(
                      label   : 'All Offices',
                      selected: _selectedFilter == 'All',
                      onTap   : () =>
                          setState(() => _selectedFilter = 'All'),
                    ),
                    _FilterChip(
                      label   : 'Low Wait',
                      selected: _selectedFilter == 'Low',
                      dotColor: Colors.green,
                      onTap   : () =>
                          setState(() => _selectedFilter = 'Low'),
                    ),
                    _FilterChip(
                      label   : 'Moderate',
                      selected: _selectedFilter == 'Moderate',
                      dotColor: Colors.orange,
                      onTap   : () =>
                          setState(() => _selectedFilter = 'Moderate'),
                    ),
                    _FilterChip(
                      label   : 'High Wait',
                      selected: _selectedFilter == 'High',
                      dotColor: Colors.red,
                      onTap   : () =>
                          setState(() => _selectedFilter = 'High'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Content ──────────────────────────────────
                if (_isLoadingOffices)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: _green),
                    ),
                  )
                else if (_errorMessage != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline,
                              size: 48, color: Colors.red),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _fetchOffices(
                              cityId    : _selectedCity?['city_id'],
                              districtId:
                                  _selectedDistrict?['district_id'],
                            ),
                            icon : const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  Text(
                    '${filtered.length} Offices Found',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No offices match your search.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ...filtered.map(
                      (office) => _OfficeListCard(
                        office     : office,
                        statusColor: _statusColor(office['status']),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  DROPDOWN BUILDER  (city & district dono ke liye reusable)
  // ═══════════════════════════════════════════════════════════
  Widget _buildDropdown({
    required String hint,
    required IconData icon,
    required Map<String, dynamic>? value,
    required List<Map<String, dynamic>> items,
    required String labelKey,
    required ValueChanged<Map<String, dynamic>?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFFF8F9FA),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          value      : value,
          hint       : Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(hint,
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 14)),
            ],
          ),
          isExpanded : true,
          icon       : const Icon(Icons.keyboard_arrow_down,
              color: _green),
          items      : items
              .map(
                (item) => DropdownMenuItem<Map<String, dynamic>>(
                  value: item,
                  child: Text(item[labelKey].toString(),
                      style: const TextStyle(fontSize: 14)),
                ),
              )
              .toList(),
          onChanged  : onChanged,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Active filter badge
// ─────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final IconData icon;

  const _Badge({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color.fromARGB(250, 48, 125, 13).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color.fromARGB(250, 48, 125, 13)
                .withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 12,
              color: const Color.fromARGB(250, 48, 125, 13)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color.fromARGB(250, 48, 125, 13),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Google Maps launcher
// ─────────────────────────────────────────────────────────────
Future<void> openInGoogleMaps({
  required String address,
  double? latitude,
  double? longitude,
}) async {
  late Uri uri;
  if (latitude != null && longitude != null) {
    uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
  } else {
    final encoded = Uri.encodeComponent(address);
    uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$encoded');
  }

  final mode = kIsWeb
      ? LaunchMode.platformDefault
      : LaunchMode.externalApplication;

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: mode);
  } else {
    debugPrint('Could not launch: $uri');
  }
}

// ─────────────────────────────────────────────────────────────
//  Wait-status Filter Chip
// ─────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? dotColor;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.dotColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color.fromARGB(250, 48, 125, 13)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color.fromARGB(250, 48, 125, 13)
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Icon(Icons.circle,
                  size: 8,
                  color: selected ? Colors.white : dotColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color:
                    selected ? Colors.white : Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Office Card
// ─────────────────────────────────────────────────────────────
class _OfficeListCard extends StatelessWidget {
  final Map<String, dynamic> office;
  final Color statusColor;

  const _OfficeListCard({
    required this.office,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color.fromARGB(250, 48, 125, 13)
                .withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Name + Status badge ──────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  office['name'],
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.circle,
                        size: 8, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      office['status'],
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // ── City / District badge ────────────────────────
          if ((office['city_name'] as String).isNotEmpty ||
              (office['district_name'] as String).isNotEmpty)
            Row(
              children: [
                const Icon(Icons.location_city,
                    size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  [
                    office['district_name'],
                    office['city_name'],
                  ]
                      .where((s) => (s as String).isNotEmpty)
                      .join(', '),
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          const SizedBox(height: 6),

          // ── Address ──────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  office['address'],
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 13),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => openInGoogleMaps(
                  address  : office['address'],
                  latitude : office['latitude'] != null
                      ? double.tryParse(
                          office['latitude'].toString())
                      : null,
                  longitude: office['longitude'] != null
                      ? double.tryParse(
                          office['longitude'].toString())
                      : null,
                ),
                child: Tooltip(
                  message: 'Open in Google Maps',
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.location_on,
                        size: 16, color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // ── Hours ─────────────────────────────────────────
          Row(children: [
            const Icon(Icons.access_time,
                size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(office['hours'],
                style: const TextStyle(
                    color: Colors.grey, fontSize: 13)),
          ]),
          const SizedBox(height: 10),

          // ── Services ──────────────────────────────────────
          const Text('Services Available:',
              style:
                  TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: (office['services'] as List<String>)
                .map(
                  (s) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(s,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color.fromARGB(
                                250, 48, 125, 13))),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // ── Wait Time | In Queue | Capacity ──────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Wait Time',
                        style: TextStyle(
                            color: Colors.grey, fontSize: 11)),
                    Text(office['waitTime'],
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ],
                ),
              ),
              const VerticalDivider(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('In Queue',
                        style: TextStyle(
                            color: Colors.grey, fontSize: 11)),
                    Text('${office['inQueue']}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ],
                ),
              ),
              const VerticalDivider(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Capacity',
                        style: TextStyle(
                            color: Colors.grey, fontSize: 11)),
                    Text('${office['capacity']}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}