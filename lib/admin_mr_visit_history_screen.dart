// ─────────────────────────────────────────────────────────────────────────────
// ADMIN MR VISIT HISTORY SCREEN
// Shows all doctor visits per MR for any month, ordered by date + time.
// Each visit shows: doctor name, hospital, area, tier, division,
//   check-in time, GPS coords, distance from clinic.
// Summary bar at top: total visits, unique doctors, working days.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

final _db = FirebaseFirestore.instance;

class AdminMrVisitHistoryScreen extends StatefulWidget {
  const AdminMrVisitHistoryScreen({super.key});

  @override
  State<AdminMrVisitHistoryScreen> createState() =>
      _AdminMrVisitHistoryScreenState();
}

class _AdminMrVisitHistoryScreenState
    extends State<AdminMrVisitHistoryScreen> {
  // ── Selected MR ──────────────────────────────────────────────────────────
  String? _selectedMrId;
  String _selectedMrName = '';

  // ── Month / year picker ───────────────────────────────────────────────────
  int _year  = DateTime.now().year;
  int _month = DateTime.now().month;

  final _monthNames = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'
  ];

  // ── Doctor metadata cache (id → data) ────────────────────────────────────
  final Map<String, Map<String, dynamic>> _doctorCache = {};

  // ── Visits for current selection ─────────────────────────────────────────
  List<Map<String, dynamic>> _visits = [];
  bool _loading = false;

  String _pad(int n) => n.toString().padLeft(2, '0');

  String get _monthStart => '$_year-${_pad(_month)}-01';
  String get _monthEnd {
    final days = DateUtils.getDaysInMonth(_year, _month);
    return '$_year-${_pad(_month)}-${_pad(days)}';
  }

  // ── Fetch visits ──────────────────────────────────────────────────────────
  Future<void> _fetchVisits() async {
    if (_selectedMrId == null) return;
    setState(() => _loading = true);

    try {
      final snap = await _db
          .collection('visits')
          .where('mrId', isEqualTo: _selectedMrId)
          .where('date', isGreaterThanOrEqualTo: _monthStart)
          .where('date', isLessThanOrEqualTo: _monthEnd)
          .orderBy('date')
          .orderBy('timestamp')
          .get();

      // Collect all unique doctorIds
      final doctorIds = snap.docs
          .map((d) => d.data()['doctorId']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      // Fetch missing doctor details
      for (final id in doctorIds) {
        if (!_doctorCache.containsKey(id)) {
          final doc = await _db.collection('doctors').doc(id).get();
          _doctorCache[id] = doc.exists
              ? (doc.data() ?? {})
              : {};
        }
      }

      if (mounted) {
        setState(() {
          _visits = snap.docs.map((d) {
            final data = Map<String, dynamic>.from(d.data());
            data['_id'] = d.id;
            return data;
          }).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Summary numbers ───────────────────────────────────────────────────────
  int get _totalVisits => _visits.length;

  int get _uniqueDoctors {
    final ids = _visits
        .map((v) => v['doctorId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    return ids.length;
  }

  int get _workingDays {
    final dates = _visits
        .map((v) => v['date']?.toString() ?? '')
        .where((d) => d.isNotEmpty)
        .toSet();
    return dates.length;
  }

  // ── Group visits by date ──────────────────────────────────────────────────
  Map<String, List<Map<String, dynamic>>> get _grouped {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final v in _visits) {
      final date = v['date']?.toString() ?? 'Unknown';
      map.putIfAbsent(date, () => []).add(v);
    }
    return map;
  }

  // ── Open Maps for GPS coords ───────────────────────────────────────────────
  Future<void> _openMap(double lat, double lng) async {
    final uri = Uri.parse('https://maps.google.com/?q=$lat,$lng');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // ── Tier color helper ─────────────────────────────────────────────────────
  Color _tierColor(String tier) {
    switch (tier) {
      case 'Premium':    return Colors.purple;
      case 'Super Core': return Colors.orange;
      case 'Core':       return Colors.teal;
      default:           return Colors.grey;
    }
  }

  Color _divisionColor(String div) {
    switch (div) {
      case 'Osteon': return Colors.blue;
      case 'Ceflon': return Colors.teal;
      default:       return Colors.green;
    }
  }

  // ── Format timestamp ──────────────────────────────────────────────────────
  String _formatTime(dynamic ts) {
    if (ts == null) return 'N/A';
    if (ts is Timestamp) {
      final dt = ts.toDate().toLocal();
      final h  = _pad(dt.hour);
      final m  = _pad(dt.minute);
      return '$h:$m';
    }
    return 'N/A';
  }

  String _formatDateLabel(String dateKey) {
    try {
      final parts = dateKey.split('-');
      final dt    = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      const days  = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      return '${days[dt.weekday - 1]}, ${dt.day} ${_monthNames[dt.month - 1]}';
    } catch (_) {
      return dateKey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MR Visit History'),
        actions: [
          if (_selectedMrId != null && _visits.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Salary summary',
              onPressed: _showSalarySummary,
            ),
        ],
      ),
      body: Column(children: [
        // ── MR selector ──────────────────────────────────────────────────
        _buildMrSelector(),

        // ── Month navigator ───────────────────────────────────────────────
        _buildMonthNavigator(),

        // ── Summary bar ───────────────────────────────────────────────────
        if (_selectedMrId != null && !_loading && _visits.isNotEmpty)
          _buildSummaryBar(),

        // ── Content ───────────────────────────────────────────────────────
        Expanded(child: _buildBody()),
      ]),
    );
  }

  // ── MR Selector ───────────────────────────────────────────────────────────
  Widget _buildMrSelector() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('users')
          .where('role', isEqualTo: 'mr')
          .orderBy('name')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: LinearProgressIndicator(),
          );
        }
        final mrs = snap.data!.docs;
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(children: [
            const Icon(Icons.badge, color: Color(0xFF1565C0), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedMrId,
                  isExpanded: true,
                  hint: const Text('Select MR to view visits',
                      style: TextStyle(color: Colors.grey)),
                  items: mrs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final isActive = data['isActive'] ?? true;
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Row(children: [
                        Expanded(child: Text(data['name'] ?? '')),
                        if (!isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('Inactive',
                                style: TextStyle(
                                    color: Colors.red.shade400, fontSize: 10)),
                          ),
                      ]),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    final doc = mrs.firstWhere((d) => d.id == val);
                    setState(() {
                      _selectedMrId   = val;
                      _selectedMrName = (doc.data() as Map)['name'] ?? '';
                      _visits.clear();
                    });
                    _fetchVisits();
                  },
                ),
              ),
            ),
          ]),
        );
      },
    );
  }

  // ── Month Navigator ───────────────────────────────────────────────────────
  Widget _buildMonthNavigator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(
          onPressed: () {
            setState(() {
              if (_month == 1) { _month = 12; _year--; }
              else _month--;
              _visits.clear();
            });
            _fetchVisits();
          },
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          '${_monthNames[_month - 1]} $_year',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              if (_month == 12) { _month = 1; _year++; }
              else _month++;
              _visits.clear();
            });
            _fetchVisits();
          },
          icon: const Icon(Icons.chevron_right),
        ),
      ]),
    );
  }

  // ── Summary Bar ───────────────────────────────────────────────────────────
  Widget _buildSummaryBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF1E88E5)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _summaryItem('Total Visits',    '$_totalVisits',  Icons.how_to_reg),
        _divider(),
        _summaryItem('Unique Doctors',  '$_uniqueDoctors', Icons.people),
        _divider(),
        _summaryItem('Working Days',    '$_workingDays',  Icons.calendar_today),
      ]),
    );
  }

  Widget _divider() => Container(
    width: 1, height: 40, color: Colors.white24,
  );

  Widget _summaryItem(String label, String value, IconData icon) => Column(
    children: [
      Icon(icon, color: Colors.white70, size: 18),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
      Text(label, style: const TextStyle(
          color: Colors.white70, fontSize: 10)),
    ],
  );

  // ── Main body ─────────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_selectedMrId == null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.touch_app, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Select an MR above to view their visit history',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
        ]),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_visits.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.event_busy, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No visits recorded for $_selectedMrName',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
          Text('in ${_monthNames[_month - 1]} $_year',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
        ]),
      );
    }

    final grouped = _grouped;
    final dates   = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      itemCount: dates.length,
      itemBuilder: (context, i) {
        final date   = dates[i];
        final dayVisits = grouped[date]!;
        return _buildDaySection(date, dayVisits);
      },
    );
  }

  // ── Day section ───────────────────────────────────────────────────────────
  Widget _buildDaySection(String date, List<Map<String, dynamic>> visits) {
    final dt = DateTime.tryParse(date);
    final isSunday = dt?.weekday == DateTime.sunday;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Date header
      Container(
        margin: const EdgeInsets.only(top: 16, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSunday
              ? Colors.orange.shade50
              : const Color(0xFF1565C0).withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isSunday
                  ? Colors.orange.shade200
                  : const Color(0xFF1565C0).withOpacity(0.2)),
        ),
        child: Row(children: [
          Icon(
            isSunday ? Icons.weekend : Icons.calendar_today,
            size: 14,
            color: isSunday ? Colors.orange : const Color(0xFF1565C0),
          ),
          const SizedBox(width: 8),
          Text(
            _formatDateLabel(date),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isSunday ? Colors.orange.shade700 : const Color(0xFF1565C0),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${visits.length} visit${visits.length > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 11,
                color: isSunday ? Colors.orange : const Color(0xFF1565C0),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ]),
      ),

      // Visit cards for this day
      ...visits.asMap().entries.map((entry) {
        final idx   = entry.key;
        final visit = entry.value;
        return _buildVisitCard(idx + 1, visit);
      }),
    ]);
  }

  // ── Visit card ────────────────────────────────────────────────────────────
  Widget _buildVisitCard(int order, Map<String, dynamic> visit) {
    final doctorId = visit['doctorId']?.toString() ?? '';
    final doctor   = _doctorCache[doctorId] ?? {};

    final doctorName = visit['doctorName']?.toString()
        ?? doctor['name']?.toString()
        ?? 'Unknown Doctor';
    final hospital   = doctor['hospital']?.toString() ?? '';
    final area       = doctor['area']?.toString() ?? '';
    final division   = doctor['division']?.toString() ?? '';
    final tier       = doctor['tier']?.toString() ?? 'Normal';
    final spec       = doctor['specialization']?.toString() ?? '';

    final checkInTime   = _formatTime(visit['timestamp']);
    final distanceM     = (visit['distanceMeters'] as num?)?.toInt();
    final mrLat         = (visit['mrLat'] as num?)?.toDouble();
    final mrLng         = (visit['mrLng'] as num?)?.toDouble();

    final divColor  = _divisionColor(division);
    final tierColor = _tierColor(tier);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Order number
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('$order',
                  style: const TextStyle(
                      color: Color(0xFF1565C0),
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ),
          const SizedBox(width: 10),

          // Info
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Doctor name + time
              Row(children: [
                Expanded(
                  child: Text(doctorName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.access_time,
                        size: 11, color: Colors.green),
                    const SizedBox(width: 3),
                    Text(checkInTime,
                        style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ]),
                ),
              ]),

              // Specialization & hospital
              if (spec.isNotEmpty || hospital.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  [spec, hospital].where((s) => s.isNotEmpty).join(' • '),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],

              // Area
              if (area.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.location_on, size: 12,
                      color: Colors.grey.shade500),
                  const SizedBox(width: 3),
                  Text(area,
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 11)),
                ]),
              ],

              const SizedBox(height: 8),

              // Tags row
              Wrap(spacing: 6, runSpacing: 4, children: [
                if (division.isNotEmpty)
                  _tag(division, divColor),
                if (tier != 'Normal')
                  _tag(tier, tierColor, bordered: true),
                if (distanceM != null)
                  _tag('${distanceM}m away',
                      distanceM <= 50
                          ? Colors.green
                          : distanceM <= 200
                          ? Colors.orange
                          : Colors.red),
              ]),

              // GPS coordinates with map link
              if (mrLat != null && mrLng != null) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _openMap(mrLat, mrLng),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.my_location,
                          size: 13, color: Colors.blue.shade700),
                      const SizedBox(width: 5),
                      Text(
                        '${mrLat.toStringAsFixed(5)}, ${mrLng.toStringAsFixed(5)}',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 5),
                      Icon(Icons.open_in_new,
                          size: 11, color: Colors.blue.shade400),
                    ]),
                  ),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _tag(String label, Color color, {bool bordered = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: bordered ? Border.all(color: color.withOpacity(0.4)) : null,
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600)),
      );

  // ── Salary Summary Dialog ─────────────────────────────────────────────────
  void _showSalarySummary() {
    // Count tier visits
    int coreVisits      = 0;
    int superCoreVisits = 0;
    int premiumVisits   = 0;
    int normalVisits    = 0;

    for (final v in _visits) {
      final doctorId = v['doctorId']?.toString() ?? '';
      final tier     = _doctorCache[doctorId]?['tier']?.toString() ?? 'Normal';
      switch (tier) {
        case 'Premium':    premiumVisits++;   break;
        case 'Super Core': superCoreVisits++; break;
        case 'Core':       coreVisits++;      break;
        default:           normalVisits++;
      }
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.account_balance_wallet,
                color: Color(0xFF1565C0), size: 40),
            const SizedBox(height: 8),
            Text(
              '${_monthNames[_month - 1]} $_year Summary',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(_selectedMrName,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 20),
            const Divider(),
            _summaryRow('Working Days',    '$_workingDays days', Colors.blue),
            _summaryRow('Total Visits',    '$_totalVisits',      Colors.blue),
            _summaryRow('Unique Doctors',  '$_uniqueDoctors',    Colors.blue),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('By Doctor Tier',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.grey)),
            ),
            _summaryRow('Normal visits',     '$normalVisits',    Colors.grey),
            _summaryRow('Core visits',       '$coreVisits',      Colors.teal),
            _summaryRow('Super Core visits', '$superCoreVisits', Colors.orange),
            _summaryRow('Premium visits',    '$premiumVisits',   Colors.purple),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Use these numbers alongside the fixed allowance to compute the final salary.',
                    style: TextStyle(fontSize: 11, color: Colors.blue),
                  ),
                ),
              ]),
            ),
          ]),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade700)),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color, fontSize: 15)),
      ],
    ),
  );
}