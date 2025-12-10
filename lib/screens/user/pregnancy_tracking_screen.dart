import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;
import 'package:arcular_plus/models/report_model.dart';
import 'package:arcular_plus/models/user_model.dart';
import 'package:url_launcher/url_launcher.dart';

class PregnancyTrackingScreen extends StatefulWidget {
  const PregnancyTrackingScreen({super.key});

  @override
  State<PregnancyTrackingScreen> createState() =>
      _PregnancyTrackingScreenState();
}

class _PregnancyTrackingScreenState extends State<PregnancyTrackingScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  DateTime? _pregnancyStartDate;
  DateTime? _dueDate;
  int _currentWeek = 0;
  bool _loading = true;
  String? _babyName;
  UserModel? _userModel;
  String _reportSearchQuery = '';
  bool _openingReport = false;

  // Baby measurements
  double? _bpd; // Biparietal Diameter
  double? _hc; // Head Circumference
  double? _ac; // Abdominal Circumference
  double? _fl; // Femur Length

  // Controllers for baby measurements
  final TextEditingController _bpdController = TextEditingController();
  final TextEditingController _hcController = TextEditingController();
  final TextEditingController _acController = TextEditingController();
  final TextEditingController _flController = TextEditingController();

  // Tab controller
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 3, vsync: this, initialIndex: _selectedIndex);
    _tabController.addListener(() {
      setState(() {
        _selectedIndex = _tabController.index;
      });
    });
    _loadUserData();
  }

  // Helper tile widget for grid metrics
  Widget _infoTile(
      {required String title, required String value, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFFF857A6), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Placeholder labels – wire to profile once available
  String _getCurrentWeightLabel() {
    if (_userModel?.weight == null) return 'Calculating...';
    return '${_userModel!.weight} kg';
  }

  String _getWeightGainLabel() {
    if (_userModel?.weight == null || _pregnancyStartDate == null)
      return 'Calculating...';
    // Calculate weight gain based on current week
    final weeksSinceStart = _currentWeek;
    final expectedGain = weeksSinceStart * 0.4; // Average 0.4kg per week
    return '+${expectedGain.toStringAsFixed(1)} kg';
  }

  String _getTargetWeightLabel() {
    if (_userModel?.weight == null || _userModel?.height == null)
      return 'Calculating...';
    // Calculate target weight based on BMI and pregnancy
    final heightInM = (_userModel!.height! / 100);
    final bmi = _userModel!.weight! / (heightInM * heightInM);
    double targetGain;
    if (bmi < 18.5) {
      targetGain = 12.5; // Underweight
    } else if (bmi < 25) {
      targetGain = 11.5; // Normal weight
    } else if (bmi < 30) {
      targetGain = 7.0; // Overweight
    } else {
      targetGain = 5.0; // Obese
    }
    return '${(_userModel!.weight! + targetGain).toStringAsFixed(1)} kg';
  }

  String _getRemainingWeightLabel() {
    if (_userModel?.weight == null || _userModel?.height == null)
      return 'Calculating...';
    final heightInM = (_userModel!.height! / 100);
    final bmi = _userModel!.weight! / (heightInM * heightInM);
    double targetGain;
    if (bmi < 18.5) {
      targetGain = 12.5;
    } else if (bmi < 25) {
      targetGain = 11.5;
    } else if (bmi < 30) {
      targetGain = 7.0;
    } else {
      targetGain = 5.0;
    }
    final weeksSinceStart = _currentWeek;
    final currentGain = weeksSinceStart * 0.4;
    final remaining = targetGain - currentGain;
    return remaining > 0
        ? '${remaining.toStringAsFixed(1)} kg'
        : 'Target reached';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bpdController.dispose();
    _hcController.dispose();
    _acController.dispose();
    _flController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      print('🤰 Loading pregnancy tracking data for UID: ${user.uid}');

      // Use universal getUserInfo method which respects user type
      final userModel = await ApiService.getUserInfo(user.uid);

      if (userModel != null) {
        print(
            '✅ Pregnancy tracking data loaded successfully: ${userModel.fullName}');
        setState(() {
          _userModel = userModel;
          _pregnancyStartDate = userModel.pregnancyStartDate;
          _dueDate = userModel.dueDate ??
              DateTime.now().add(const Duration(days: 120));
          _babyName = userModel.babyName;
          _bpd = userModel.bpd;
          _hc = userModel.hc;
          _ac = userModel.ac;
          _fl = userModel.fl;
          _loading = false;
        });

        // Update controllers with loaded data
        _bpdController.text = _bpd?.toString() ?? '';
        _hcController.text = _hc?.toString() ?? '';
        _acController.text = _ac?.toString() ?? '';
        _flController.text = _fl?.toString() ?? '';
        _calculateCurrentWeek();
      } else {
        print('❌ Pregnancy tracking data not found, using fallback data');
        // Fallback to mock data if no user data
        setState(() {
          _dueDate = DateTime.now().add(const Duration(days: 120));
          _loading = false;
        });
        _calculateCurrentWeek();
      }
    } catch (e) {
      print('❌ Error loading pregnancy tracking data: $e');
      // Fallback to mock data
      setState(() {
        _dueDate = DateTime.now().add(const Duration(days: 120));
        _loading = false;
      });
      _calculateCurrentWeek();
    }
  }

  void _calculateCurrentWeek() {
    if (_pregnancyStartDate != null) {
      final today = DateTime.now();
      final totalDays = today.difference(_pregnancyStartDate!).inDays;
      _currentWeek =
          (totalDays ~/ 7) + 1; // +1 because week 1 starts from day 0
      if (_currentWeek < 1) _currentWeek = 1;
      if (_currentWeek > 42) _currentWeek = 42; // Allow up to 42 weeks
    } else if (_dueDate != null) {
      // Fallback to due date calculation if start date is not available
      final today = DateTime.now();
      final totalDays = _dueDate!.difference(today).inDays;
      _currentWeek = 40 - (totalDays ~/ 7);
      if (_currentWeek < 0) _currentWeek = 0;
      if (_currentWeek > 40) _currentWeek = 40;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pregnancy Tracking'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF857A6), Color(0xFFFF5858)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF857A6)),
              ),
            )
          : Column(
              children: [
                // Progress/Details Header above tabs
                _buildProgressHeader(),
                // Tab Bar
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFFFF6F91),
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: const Color(0xFFFF6F91),
                    tabs: const [
                      Tab(
                          text: 'Weekly Update',
                          icon: Icon(Icons.calendar_today)),
                      Tab(text: 'Baby Details', icon: Icon(Icons.child_care)),
                      Tab(text: 'Reports', icon: Icon(Icons.assignment)),
                    ],
                  ),
                ),
                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildWeeklyTab(),
                      _buildBabyDetailsTab(),
                      _buildReportsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
    });
    await _loadUserData();
  }

  /// Returns a map with efwKg (nullable), efwGrams, log10Efw and debug values.
  /// Assumes inputs are provided in millimetres (mm). If you sometimes accept cm,
  /// add a flag or convert before calling.
  Map<String, dynamic> calculateEFWWithDebug({
    required double bpdMm,
    required double hcMm,
    required double acMm,
    required double flMm,
  }) {
    // Basic validation
    if (bpdMm <= 0 || hcMm <= 0 || acMm <= 0 || flMm <= 0) {
      return {'efwKg': null, 'error': 'All measurements must be > 0'};
    }

    // Convert mm -> cm (Hadlock formula uses cm)
    final bpd = bpdMm / 10.0;
    final hc = hcMm / 10.0;
    final ac = acMm / 10.0;
    final fl = flMm / 10.0;

    // Calculate
    final log10Efw = 1.3596 +
        0.0064 * hc +
        0.0424 * ac +
        0.174 * fl +
        0.00061 * bpd * ac -
        0.00386 * ac * fl;

    // Sanity check: log10Efw should be roughly between ~1.5 and ~4.0 in realistic fetuses
    if (log10Efw.isNaN || log10Efw.isInfinite) {
      return {
        'efwKg': null,
        'error': 'Computed log10Efw not finite',
        'log10Efw': log10Efw
      };
    }
    if (log10Efw < 1.0 || log10Efw > 5.0) {
      // out-of-range — return debug instead of forcing a wrong clamp
      return {
        'efwKg': null,
        'error': 'log10(EFW) out of expected range',
        'log10Efw': log10Efw,
        'hc_cm': hc,
        'ac_cm': ac,
        'fl_cm': fl,
        'bpd_cm': bpd
      };
    }

    final efwGrams = math.pow(10, log10Efw).toDouble();
    if (efwGrams.isNaN || efwGrams.isInfinite) {
      return {
        'efwKg': null,
        'error': 'EFW grams not finite',
        'log10Efw': log10Efw
      };
    }
    final efwKg = efwGrams / 1000.0;

    // Don't blindly clamp to 6.0 — you can clamp to a high safety ceiling if you want:
    final efwKgSafe = efwKg.clamp(0.0, 10.0);

    return {
      'efwKg': efwKgSafe,
      'efwGrams': efwGrams,
      'log10Efw': log10Efw,
      'hc_cm': hc,
      'ac_cm': ac,
      'fl_cm': fl,
      'bpd_cm': bpd
    };
  }

  double? _calculateEFWKg() {
    if (_hc == null || _ac == null || _fl == null || _bpd == null) return null;

    final result = calculateEFWWithDebug(
      bpdMm: _bpd!,
      hcMm: _hc!,
      acMm: _ac!,
      flMm: _fl!,
    );

    return result['efwKg'] as double?;
  }

  // Progress header displayed above the tabs
  Widget _buildProgressHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF857A6), Color(0xFFFF5858)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.pregnant_woman, color: Colors.white, size: 24),
                const SizedBox(width: 8),
                if (_babyName != null && _babyName!.isNotEmpty) ...[
                  Icon(Icons.favorite, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Baby: $_babyName',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ] else ...[
                  const Text(
                    'Pregnancy Tracking',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Start Date (LMP)',
                          style:
                              TextStyle(fontSize: 14, color: Colors.white70)),
                      Text(
                        _pregnancyStartDate != null
                            ? DateFormat('MMM d, y')
                                .format(_pregnancyStartDate!)
                            : 'Not set',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('Due Date',
                          style:
                              TextStyle(fontSize: 14, color: Colors.white70)),
                      Text(
                        _dueDate != null
                            ? DateFormat('MMM d, y').format(_dueDate!)
                            : 'Not set',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Current Week',
                          style:
                              TextStyle(fontSize: 14, color: Colors.white70)),
                      Text('Week $_currentWeek',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Progress'),
                    Text('${(_currentWeek / 40 * 100).round()}%'),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _currentWeek / 40,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 8,
                ),
                const SizedBox(height: 8),
                Text(
                  _pregnancyStartDate != null
                      ? 'Days since LMP: ${DateTime.now().difference(_pregnancyStartDate!).inDays}'
                      : 'Set pregnancy start date for accurate tracking',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Weekly tab content per requested sections
  Widget _buildWeeklyTab() {
    final weeklyData = _getWeeklyData(_currentWeek);
    final efwKg = _calculateEFWKg();
    final weightRangeLow = efwKg != null ? (efwKg * 0.88) : null; // ~±12%
    final weightRangeHigh = efwKg != null ? (efwKg * 1.12) : null;
    final growthRate =
        efwKg != null ? (efwKg * 0.12) : null; // approx weekly growth

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Week card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFF857A6), Color(0xFFFF5858)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.favorite, color: Colors.white),
                const SizedBox(width: 12),
                Text('Week $_currentWeek',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Baby Development header + card
          const Text('Baby Development',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF857A6))),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFF857A6), Color(0xFFFF5858)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  weeklyData['babyDevelopment'] ??
                      'Your baby is continuing to develop and grow.',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, height: 1.4)),
              const SizedBox(height: 8),
              Text('Size: ${weeklyData['babySize']}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ]),
          ),
          const SizedBox(height: 16),
          // Baby Weight Calculation card (from week 13 onwards)
          const Text('Baby Weight Calculation',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF857A6))),
          const SizedBox(height: 8),
          _currentWeek < 13
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFF857A6), Color(0xFFFF5858)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Baby weight and measurements are available starting from week 13. Please check back later.',
                    style: TextStyle(
                        color: Colors.white, fontSize: 14, height: 1.4),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFF857A6), Color(0xFFFF5858)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: const [
                          Icon(Icons.child_friendly, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Estimated Baby Weight',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16))
                        ]),
                        const SizedBox(height: 12),
                        GridView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 2.8),
                          children: [
                            _infoTile(
                                title: 'Current Week',
                                value: '${_currentWeek} weeks',
                                icon: Icons.calendar_today),
                            _infoTile(
                                title: 'Estimated Weight',
                                value: efwKg != null
                                    ? '${efwKg.toStringAsFixed(2)} kg'
                                    : '—',
                                icon: Icons.scale),
                            _infoTile(
                                title: 'Weight Range',
                                value: efwKg != null
                                    ? '${weightRangeLow!.toStringAsFixed(2)} - ${weightRangeHigh!.toStringAsFixed(2)} kg'
                                    : '—',
                                icon: Icons.show_chart),
                            _infoTile(
                                title: 'Growth Rate',
                                value: efwKg != null
                                    ? '+${growthRate!.toStringAsFixed(3)} kg/week'
                                    : '—',
                                icon: Icons.speed),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ]),
                ),
          const SizedBox(height: 16),
          // Mother's Weight Tracking
          const Text('Weight Tracking',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF857A6))),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFF857A6), Color(0xFFFF5858)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: const [
                Icon(Icons.monitor_weight, color: Colors.white),
                SizedBox(width: 8),
                Text('Your Weight This Week',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16))
              ]),
              const SizedBox(height: 12),
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.8),
                children: [
                  _infoTile(
                      title: 'Current Weight',
                      value: _getCurrentWeightLabel(),
                      icon: Icons.trending_up),
                  _infoTile(
                      title: 'Weight Gain',
                      value: _getWeightGainLabel(),
                      icon: Icons.add),
                  _infoTile(
                      title: 'Target Weight',
                      value: _getTargetWeightLabel(),
                      icon: Icons.flag),
                  _infoTile(
                      title: 'Remaining',
                      value: _getRemainingWeightLabel(),
                      icon: Icons.stacked_line_chart),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 16),
          // Tips & Advice
          const Text('Tips & Advice',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF857A6))),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFF857A6), Color(0xFFFF5858)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
            ),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: ApiService.getWeeklyNotes(
                  FirebaseAuth.instance.currentUser!.uid,
                  week: _currentWeek),
              builder: (context, snapshot) {
                final weeklyDataLocal = _getWeeklyData(_currentWeek);
                final doctorNotes = (snapshot.data ?? []);
                final noteText = doctorNotes.isNotEmpty
                    ? (doctorNotes.first['content'] as String? ?? '')
                    : (weeklyDataLocal['tips'] ??
                        'Your doctor will post weekly notes here after your check-up.');
                return Text(noteText,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, height: 1.4));
              },
            ),
          ),
        ],
      ),
    );
  }

  // Build Baby Details Tab
  Widget _buildBabyDetailsTab() {
    if (_currentWeek < 13) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF857A6), Color(0xFFFF5858)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Baby measurements will be available from week 13 onwards. Keep tracking your pregnancy for more details.',
                style:
                    TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baby Measurements Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF857A6), Color(0xFFFF5858)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.child_care, color: Colors.white, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Baby Measurements',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Measurement Input Fields
                _buildMeasurementField(
                    'BPD (Biparietal Diameter)', _bpdController, 'mm'),
                const SizedBox(height: 16),
                _buildMeasurementField(
                    'HC (Head Circumference)', _hcController, 'mm'),
                const SizedBox(height: 16),
                _buildMeasurementField(
                    'AC (Abdominal Circumference)', _acController, 'mm'),
                const SizedBox(height: 16),
                _buildMeasurementField(
                    'FL (Femur Length)', _flController, 'mm'),
                const SizedBox(height: 20),
                // Save & Recalculate Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _saveBabyMeasurements();
                      final efw = _calculateEFWKg();
                      if (efw != null) {
                        // show a brief popup of EFW
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Estimated baby weight: ${efw.toStringAsFixed(2)} kg')),
                        );
                      }
                      setState(() {});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFF857A6),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save & Recalculate',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Builder(builder: (context) {
                  final efw = _calculateEFWKg();
                  if (efw == null) return const SizedBox.shrink();
                  final low = (efw * 0.88);
                  final high = (efw * 1.12);
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Estimated Baby Weight',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text('${efw.toStringAsFixed(2)} kg',
                            style: const TextStyle(color: Colors.white)),
                        Text(
                            'Range: ${low.toStringAsFixed(2)} - ${high.toStringAsFixed(2)} kg',
                            style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Load all pregnancy reports (both user-uploaded and lab-uploaded)
  Future<List<ReportModel>> _loadAllPregnancyReports(String uid) async {
    try {
      List<ReportModel> allReports = [];

      // 1. Get user-uploaded reports
      final userReports = await ApiService.getReportsByUser(uid);
      allReports.addAll(userReports);

      // 2. Get lab-uploaded reports by ARC ID
      try {
        final userInfo = await ApiService.getUserInfo(uid);
        if (userInfo != null) {
          final arcId = userInfo.healthQrId ?? userInfo.arcId;
          if (arcId != null && arcId.isNotEmpty) {
            final labReportsData = await ApiService.getLabReportsByArcId(arcId);

            // Convert lab reports to ReportModel format
            final labReports = labReportsData
                .map((data) => ReportModel(
                      id: data['_id'] ?? data['id'] ?? '',
                      name: data['testName'] ?? 'Lab Report',
                      url: data['reportUrl'] ?? '',
                      type: 'pdf',
                      uploadedAt: data['uploadDate'] != null
                          ? DateTime.parse(data['uploadDate'])
                          : DateTime.now(),
                      category: data['testName'] ?? 'Other',
                      uploadedBy: data['labName'] ?? 'Lab',
                    ))
                .toList();

            allReports.addAll(labReports);
          }
        }
      } catch (e) {
        print('❌ Error loading lab reports for pregnancy tracking: $e');
      }

      return allReports;
    } catch (e) {
      print('❌ Error loading pregnancy reports: $e');
      return [];
    }
  }

  // Build Reports Tab
  Widget _buildReportsTab() {
    final user = FirebaseAuth.instance.currentUser;
    return user == null
        ? const Center(child: Text('Login required'))
        : FutureBuilder<List<ReportModel>>(
            future: _loadAllPregnancyReports(user.uid),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                    child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ));
              }
              final List<ReportModel> all = snapshot.data!;
              // Filter for pregnancy-related reports (ultrasound, sonography, scan, ob, preg, anomaly, hcg, x-ray)
              List<ReportModel> filtered = all.where((ReportModel r) {
                final t = (r.type).toLowerCase();
                final name = r.name.toLowerCase();
                final category = (r.category ?? '').toLowerCase();
                return t.contains('ultrasound') ||
                    t.contains('sonography') ||
                    t.contains('scan') ||
                    t.contains('ob') ||
                    t.contains('preg') ||
                    t.contains('anomaly') ||
                    t.contains('hcg') ||
                    t.contains('x-ray') ||
                    t.contains('xray') ||
                    name.contains('ultrasound') ||
                    name.contains('sonography') ||
                    name.contains('scan') ||
                    name.contains('pregnancy') ||
                    name.contains('prenatal') ||
                    name.contains('obstetric') ||
                    name.contains('x-ray') ||
                    name.contains('xray') ||
                    category.contains('ultrasound') ||
                    category.contains('pregnancy') ||
                    category.contains('obstetric') ||
                    category.contains('x-ray') ||
                    category.contains('xray');
              }).toList();

              filtered.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

              return Column(
                children: [
                  // Search Bar
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search pregnancy reports...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _reportSearchQuery = value;
                        });
                      },
                    ),
                  ),

                  // Reports Count
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_getFilteredPregnancyReports(filtered).length} pregnancy reports found',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Reports List
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _getFilteredPregnancyReports(filtered).isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.description_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _reportSearchQuery.isNotEmpty
                                        ? 'No pregnancy reports match your search'
                                        : 'No pregnancy reports available',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Pregnancy reports will appear here when uploaded by labs or service providers',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount:
                                  _getFilteredPregnancyReports(filtered).length,
                              itemBuilder: (context, index) {
                                final ReportModel r =
                                    _getFilteredPregnancyReports(
                                        filtered)[index];
                                return _buildPregnancyReportCard(r);
                              },
                            ),
                    ),
                  ),
                ],
              );
            },
          );
  }

  // Build measurement input field
  Widget _buildMeasurementField(
      String label, TextEditingController controller, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter $unit',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
            suffixText: unit,
            suffixStyle: const TextStyle(color: Colors.white70),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white, width: 2),
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
          ),
        ),
      ],
    );
  }

  // Save baby measurements
  Future<void> _saveBabyMeasurements() async {
    try {
      final measurements = {
        'bpd': double.tryParse(_bpdController.text),
        'hc': double.tryParse(_hcController.text),
        'ac': double.tryParse(_acController.text),
        'fl': double.tryParse(_flController.text),
      };

      // Update local state
      setState(() {
        _bpd = measurements['bpd'];
        _hc = measurements['hc'];
        _ac = measurements['ac'];
        _fl = measurements['fl'];
      });

      // Save to backend
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await ApiService.updateUserProfile(user.uid, measurements);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Baby measurements saved successfully!'),
          backgroundColor: Color(0xFFF857A6),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving measurements: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildPregnancyReportCard(ReportModel report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        minVerticalPadding: 0,
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF857A6), Color(0xFFFF5858)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.description,
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Text(
          report.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF857A6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    report.category ?? 'Pregnancy Report',
                    style: const TextStyle(
                      color: Color(0xFFF857A6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Compact info display to save space
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today,
                        size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      'Created: ${_formatDate(report.createdAt)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      'By: ${report.uploadedBy ?? 'Healthcare Provider'}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.insert_drive_file,
                        size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      '${report.type.toUpperCase()} • ${_formatFileSize(report.fileSize)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        trailing: _openingReport
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF857A6)),
                ),
              )
            : IconButton(
                onPressed: () => _openPregnancyReport(report),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF857A6), Color(0xFFFF5858)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.open_in_new,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
      ),
    );
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return 'Unknown size';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown date';
    return '${date.day}/${date.month}/${date.year}';
  }

  List<ReportModel> _getFilteredPregnancyReports(List<ReportModel> reports) {
    List<ReportModel> filtered = reports;

    // Filter by search query
    if (_reportSearchQuery.isNotEmpty) {
      final q = _reportSearchQuery.toLowerCase();
      filtered = filtered
          .where((report) =>
              report.name.toLowerCase().contains(q) ||
              (report.category ?? '').toLowerCase().contains(q) ||
              report.type.toLowerCase().contains(q))
          .toList();
    }

    return filtered;
  }

  Future<void> _openPregnancyReport(ReportModel report) async {
    if (_openingReport) return; // Prevent multiple simultaneous attempts

    setState(() {
      _openingReport = true;
    });

    try {
      print('🔍 Opening pregnancy report: ${report.name}');
      print('🔍 Report URL: ${report.url}');

      if (report.url.isEmpty) {
        throw Exception('Report URL is empty');
      }

      final Uri url = Uri.parse(report.url);

      if (await canLaunchUrl(url)) {
        print('✅ Can launch URL, opening in external app');
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        print('⚠️ Cannot launch URL externally, trying in-app webview');
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      print('❌ Error opening pregnancy report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open report: $e'),
            backgroundColor: const Color(0xFFF857A6),
            action: SnackBarAction(
              label: 'Try Again',
              textColor: Colors.white,
              onPressed: () => _openPregnancyReport(report),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _openingReport = false;
        });
      }
    }
  }

  // Get weekly data based on current week
  Map<String, String> _getWeeklyData(int week) {
    final weeklyData = {
      1: {
        'babyDevelopment':
            'Your baby is just a fertilized egg, called a zygote. It\'s about the size of a pinhead and is rapidly dividing.',
        'babySize': 'Pinhead size',
        'motherHealth':
            'You may not feel any different yet, but your body is already starting to prepare for pregnancy.',
        'tips':
            'Start taking prenatal vitamins with folic acid. Avoid alcohol, smoking, and limit caffeine intake.',
      },
      2: {
        'babyDevelopment':
            'The zygote has become a blastocyst and is implanting into your uterine wall. The placenta is beginning to form.',
        'babySize': 'Pinhead size',
        'motherHealth':
            'You might experience light spotting during implantation. Your body is producing pregnancy hormones.',
        'tips':
            'Continue taking prenatal vitamins. Eat a balanced diet rich in fruits, vegetables, and whole grains.',
      },
      3: {
        'babyDevelopment':
            'Your baby\'s neural tube is forming, which will become the brain and spinal cord. The heart is starting to develop.',
        'babySize': 'Poppy seed',
        'motherHealth':
            'You may start feeling early pregnancy symptoms like fatigue, nausea, or breast tenderness.',
        'tips':
            'Stay hydrated and eat small, frequent meals to help with nausea. Get plenty of rest.',
      },
      4: {
        'babyDevelopment':
            'The heart is beating! Your baby\'s arms and legs are beginning to form as tiny buds.',
        'babySize': 'Poppy seed',
        'motherHealth':
            'Morning sickness may begin. Your breasts may feel tender and swollen.',
        'tips':
            'Eat ginger or drink ginger tea for nausea. Wear a supportive bra for breast tenderness.',
      },
      5: {
        'babyDevelopment':
            'Your baby\'s brain, spinal cord, and heart are developing rapidly. The placenta is growing.',
        'babySize': 'Sesame seed',
        'motherHealth':
            'You may feel more tired than usual. Morning sickness might be at its peak.',
        'tips':
            'Take naps when possible. Eat bland foods like crackers or toast to help with nausea.',
      },
      6: {
        'babyDevelopment':
            'Your baby\'s facial features are starting to form. The eyes, nose, and mouth are developing.',
        'babySize': 'Lentil',
        'motherHealth':
            'You might experience mood swings due to hormonal changes. Fatigue continues.',
        'tips':
            'Practice relaxation techniques like deep breathing or gentle yoga. Stay connected with loved ones.',
      },
      7: {
        'babyDevelopment':
            'Your baby\'s arms and legs are growing longer. The hands and feet are forming.',
        'babySize': 'Blueberry',
        'motherHealth':
            'You may start to feel bloated. Your uterus is growing to accommodate your baby.',
        'tips':
            'Wear loose, comfortable clothing. Continue eating small, frequent meals.',
      },
      8: {
        'babyDevelopment':
            'Your baby\'s fingers and toes are forming. The tail is disappearing.',
        'babySize': 'Raspberry',
        'motherHealth':
            'You might feel more emotional. Your sense of smell may be heightened.',
        'tips':
            'Avoid strong smells that trigger nausea. Consider using unscented products.',
      },
      9: {
        'babyDevelopment':
            'Your baby\'s major organs are developing. The heart is fully formed and beating strongly.',
        'babySize': 'Cherry',
        'motherHealth':
            'You may start to show slightly. Your waistline might be expanding.',
        'tips':
            'Start wearing maternity clothes if needed. Continue with gentle exercise.',
      },
      10: {
        'babyDevelopment':
            'Your baby\'s facial features are becoming more defined. The eyes are moving to the front of the face.',
        'babySize': 'Strawberry',
        'motherHealth':
            'You might feel more energetic as morning sickness starts to improve.',
        'tips':
            'Take advantage of increased energy to exercise gently. Eat a variety of nutritious foods.',
      },
      11: {
        'babyDevelopment':
            'Your baby is starting to move around, though you won\'t feel it yet. The fingers and toes are fully formed.',
        'babySize': 'Lime',
        'motherHealth':
            'Your appetite may be returning. You might feel less nauseous.',
        'tips':
            'Focus on eating nutrient-dense foods. Continue taking prenatal vitamins.',
      },
      12: {
        'babyDevelopment':
            'Your baby\'s reflexes are developing. The baby can make a fist and curl toes.',
        'babySize': 'Plum',
        'motherHealth':
            'You\'re entering the second trimester! Morning sickness usually improves now.',
        'tips':
            'Celebrate reaching this milestone! Start planning for your baby\'s arrival.',
      },
      13: {
        'babyDevelopment':
            'Your baby\'s vocal cords are developing. The baby can swallow and make sucking motions.',
        'babySize': 'Peach',
        'motherHealth':
            'You should feel more energetic and less nauseous. Your appetite is likely returning.',
        'tips':
            'Enjoy this more comfortable phase. Start thinking about prenatal classes.',
      },
      14: {
        'babyDevelopment':
            'Your baby\'s facial expressions are developing. The baby can frown and squint.',
        'babySize': 'Lemon',
        'motherHealth':
            'You might start to show more noticeably. Your energy levels should be good.',
        'tips':
            'Wear comfortable, supportive shoes. Consider starting a pregnancy exercise routine.',
      },
      15: {
        'babyDevelopment':
            'Your baby\'s bones are hardening. The baby can move all joints and limbs.',
        'babySize': 'Apple',
        'motherHealth':
            'You might feel your baby\'s first movements (quickening) around this time.',
        'tips':
            'Pay attention to your body and rest when needed. Stay hydrated.',
      },
      16: {
        'babyDevelopment':
            'Your baby\'s eyes can move and the baby can hear your voice.',
        'babySize': 'Avocado',
        'motherHealth':
            'You should be feeling good and energetic. Your baby bump is becoming more visible.',
        'tips':
            'Start talking to your baby - they can hear you! Consider prenatal massage.',
      },
      17: {
        'babyDevelopment':
            'Your baby\'s skeleton is changing from soft cartilage to bone. Fat is starting to accumulate.',
        'babySize': 'Pear',
        'motherHealth':
            'You might experience round ligament pain as your uterus grows.',
        'tips':
            'Use a pregnancy pillow for better sleep. Practice good posture.',
      },
      18: {
        'babyDevelopment':
            'Your baby\'s ears are in their final position. The baby can hear sounds from outside.',
        'babySize': 'Sweet potato',
        'motherHealth':
            'You might feel more baby movements. Your appetite should be good.',
        'tips': 'Play music for your baby. Eat foods rich in iron and calcium.',
      },
      19: {
        'babyDevelopment':
            'Your baby\'s skin is developing a protective coating called vernix.',
        'babySize': 'Mango',
        'motherHealth':
            'You might feel some discomfort as your uterus grows. Back pain may start.',
        'tips':
            'Use a heating pad for back pain. Practice gentle stretching exercises.',
      },
      20: {
        'babyDevelopment':
            'Your baby is halfway through development! The baby can swallow and has taste buds.',
        'babySize': 'Banana',
        'motherHealth':
            'You\'re at the halfway point! You might feel more baby movements.',
        'tips':
            'Celebrate this milestone! Start thinking about baby names and nursery planning.',
      },
      21: {
        'babyDevelopment':
            'Your baby\'s eyebrows and eyelashes are forming. The baby is becoming more active.',
        'babySize': 'Carrot',
        'motherHealth':
            'You might feel more baby kicks and movements. Your energy should be good.',
        'tips':
            'Keep track of baby movements. Continue with regular prenatal checkups.',
      },
      22: {
        'babyDevelopment':
            'Your baby\'s senses are developing rapidly. The baby can feel touch.',
        'babySize': 'Papaya',
        'motherHealth':
            'You might experience some swelling in your feet and ankles.',
        'tips':
            'Elevate your feet when possible. Wear comfortable, supportive shoes.',
      },
      23: {
        'babyDevelopment':
            'Your baby\'s skin is becoming less transparent. The baby is gaining weight rapidly.',
        'babySize': 'Grapefruit',
        'motherHealth':
            'You might feel more tired as your baby grows. Back pain may increase.',
        'tips': 'Get plenty of rest. Use a pregnancy support belt if needed.',
      },
      24: {
        'babyDevelopment':
            'Your baby\'s lungs are developing. The baby can hear and respond to sounds.',
        'babySize': 'Cantaloupe',
        'motherHealth':
            'You might experience more frequent urination. Your belly is growing rapidly.',
        'tips':
            'Stay hydrated but limit fluids before bedtime. Sleep on your side.',
      },
      25: {
        'babyDevelopment':
            'Your baby\'s hands are fully developed. The baby can make a fist and grasp.',
        'babySize': 'Cauliflower',
        'motherHealth':
            'You might feel more baby movements. Your appetite should be good.',
        'tips': 'Eat small, frequent meals. Continue with gentle exercise.',
      },
      26: {
        'babyDevelopment':
            'Your baby\'s eyes are opening and closing. The baby can see light.',
        'babySize': 'Butternut squash',
        'motherHealth':
            'You might experience some shortness of breath as your uterus grows.',
        'tips':
            'Practice deep breathing exercises. Sleep propped up if needed.',
      },
      27: {
        'babyDevelopment':
            'Your baby\'s brain is developing rapidly. The baby can dream.',
        'babySize': 'Cabbage',
        'motherHealth':
            'You\'re entering the third trimester! You might feel more tired.',
        'tips':
            'Prepare for the final stretch. Start packing your hospital bag.',
      },
      28: {
        'babyDevelopment':
            'Your baby\'s eyes can see light filtering through your belly.',
        'babySize': 'Eggplant',
        'motherHealth':
            'You might experience more frequent Braxton Hicks contractions.',
        'tips':
            'Practice relaxation techniques. Stay hydrated to reduce contractions.',
      },
      29: {
        'babyDevelopment':
            'Your baby\'s bones are fully developed but still soft. The baby is gaining weight.',
        'babySize': 'Acorn squash',
        'motherHealth': 'You might feel more uncomfortable as your baby grows.',
        'tips':
            'Use a pregnancy pillow for support. Take warm baths for relaxation.',
      },
      30: {
        'babyDevelopment':
            'Your baby\'s brain is developing rapidly. The baby can recognize your voice.',
        'babySize': 'Large cabbage',
        'motherHealth':
            'You might experience more back pain and difficulty sleeping.',
        'tips':
            'Practice good posture. Consider prenatal massage for back pain.',
      },
      31: {
        'babyDevelopment':
            'Your baby\'s immune system is developing. The baby is gaining weight rapidly.',
        'babySize': 'Coconut',
        'motherHealth':
            'You might feel more tired and uncomfortable. Swelling may increase.',
        'tips': 'Rest when possible. Elevate your feet to reduce swelling.',
      },
      32: {
        'babyDevelopment':
            'Your baby\'s skin is becoming less wrinkled as fat accumulates.',
        'babySize': 'Jicama',
        'motherHealth':
            'You might experience more frequent urination and back pain.',
        'tips':
            'Use a pregnancy support belt. Practice pelvic floor exercises.',
      },
      33: {
        'babyDevelopment':
            'Your baby\'s bones are hardening. The baby is preparing for birth.',
        'babySize': 'Pineapple',
        'motherHealth':
            'You might feel more baby movements. Your belly is quite large now.',
        'tips':
            'Monitor baby movements. Start preparing for labor and delivery.',
      },
      34: {
        'babyDevelopment':
            'Your baby\'s lungs are almost fully developed. The baby is gaining weight rapidly.',
        'babySize': 'Cantaloupe',
        'motherHealth':
            'You might feel more uncomfortable and tired. Sleep may be difficult.',
        'tips':
            'Sleep on your side with a pillow between your knees. Stay hydrated.',
      },
      35: {
        'babyDevelopment':
            'Your baby\'s kidneys are fully developed. The baby is gaining weight rapidly.',
        'babySize': 'Honeydew melon',
        'motherHealth': 'You might experience more Braxton Hicks contractions.',
        'tips':
            'Practice breathing exercises for labor. Stay active but don\'t overexert.',
      },
      36: {
        'babyDevelopment':
            'Your baby\'s brain is developing rapidly. The baby is preparing for birth.',
        'babySize': 'Head of romaine lettuce',
        'motherHealth':
            'You might feel more pressure in your pelvis. Your baby is getting ready.',
        'tips':
            'Practice relaxation techniques. Prepare for the possibility of early labor.',
      },
      37: {
        'babyDevelopment':
            'Your baby is considered full-term! The baby is ready for birth.',
        'babySize': 'Swiss chard',
        'motherHealth':
            'You might feel more pressure and discomfort. Labor could start anytime.',
        'tips':
            'Be ready for labor signs. Have your hospital bag packed and ready.',
      },
      38: {
        'babyDevelopment':
            'Your baby\'s brain is still developing. The baby is gaining weight.',
        'babySize': 'Leek',
        'motherHealth':
            'You might feel more uncomfortable. Your baby is getting ready for birth.',
        'tips': 'Rest as much as possible. Be prepared for labor to start.',
      },
      39: {
        'babyDevelopment':
            'Your baby\'s brain is developing rapidly. The baby is ready for birth.',
        'babySize': 'Mini watermelon',
        'motherHealth':
            'You might feel more pressure and discomfort. Labor could start soon.',
        'tips': 'Stay calm and relaxed. Be ready for labor signs.',
      },
      40: {
        'babyDevelopment': 'Your baby is fully developed and ready for birth!',
        'babySize': 'Small pumpkin',
        'motherHealth':
            'You might feel more uncomfortable. Your baby is ready to meet you!',
        'tips': 'Be patient and stay positive. Your baby will come when ready.',
      },
    };

    return weeklyData[week] ??
        {
          'babyDevelopment': 'Your baby is continuing to develop and grow.',
          'babySize': 'Growing',
          'motherHealth':
              'Continue taking care of yourself and your growing baby.',
          'tips':
              'Stay healthy and positive throughout your pregnancy journey.',
        };
  }
}
