import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

// Nurse theme colors - Orange gradient to match the Vitals tile
const Color kNursePrimary = Color(0xFFFF7A45); // Vibrant orange
const Color kNurseSecondary = Color(0xFFFFA26B); // Soft orange
const Color kNurseAccent = Color(0xFFFFD2B3); // Peach accent
const Color kNurseBackground = Color(0xFFFFF7F0); // Warm light background
const Color kNurseSurface = Color(0xFFFFFFFF);
const Color kNurseText = Color(0xFF2E2E2E);
const Color kNurseTextSecondary = Color(0xFFFF8C5A);
const Color kNurseSuccess = Color(0xFF4CAF50);
const Color kNurseWarning = Color(0xFFFF9800);
const Color kNurseError = Color(0xFFF44336);

class VitalMonitoringScreen extends StatefulWidget {
  const VitalMonitoringScreen({super.key});

  @override
  State<VitalMonitoringScreen> createState() => _VitalMonitoringScreenState();
}

class _VitalMonitoringScreenState extends State<VitalMonitoringScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, String>> _assignedPatients = [];
  Map<String, String>? _selectedPatient;
  bool _isLoading = false;
  bool _isRecording = false;
  late TabController _tabController;
  bool _loadingHistory = false;
  List<Map<String, dynamic>> _history = [];

  // Vital signs data
  final Map<String, TextEditingController> _vitalControllers = {
    // Basic (required)
    'temperature': TextEditingController(),
    'heartRate': TextEditingController(),
    'respiratoryRate': TextEditingController(),
    'systolic': TextEditingController(),
    'diastolic': TextEditingController(),
    'spo2': TextEditingController(),
    'weightKg': TextEditingController(),
    'heightCm': TextEditingController(),
    'bmi': TextEditingController(),
    // Extended (optional)
    'glucoseRandom': TextEditingController(),
    'glucoseFasting': TextEditingController(),
    'glucosePostMeal': TextEditingController(),
    'painLevel': TextEditingController(),
    'menstrualNote': TextEditingController(),
    'hydrationMl': TextEditingController(),
    'sleepHours': TextEditingController(),
    'sleepQuality': TextEditingController(),
    // Critical (optional)
    'ecgSummary': TextEditingController(),
    'ventilatorFlow': TextEditingController(),
    'infusionNotes': TextEditingController(),
    'gcsScore': TextEditingController(),
    'neuroNotes': TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAssignedPatients();
  }

  @override
  void dispose() {
    _vitalControllers.values.forEach((controller) => controller.dispose());
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAssignedPatients() async {
    setState(() => _isLoading = true);
    try {
      // Load assignments for this nurse and map to minimal patient objects
      final assignments = await ApiService.getNurseAssignments();
      final patients = assignments.map<Map<String, String>>((a) {
        final p = a['patientId'] is Map ? a['patientId'] : null;
        final id = p != null
            ? (p['_id']?.toString() ?? '')
            : (a['patientId']?.toString() ?? '');
        final name = a['patientName'] ??
            (p != null ? (p['fullName'] ?? 'Patient') : 'Patient');
        return {'id': id, 'name': name};
      }).toList();
      setState(() {
        _assignedPatients = patients;
        if (patients.isNotEmpty) {
          _selectedPatient = patients.first;
          _loadHistory();
        }
      });
    } catch (e) {
      print('❌ Error loading assigned patients: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load assigned patients: $e'),
          backgroundColor: kNurseError,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadHistory() async {
    if (_selectedPatient == null) return;
    setState(() => _loadingHistory = true);
    final data = await ApiService.getPatientVitals(_selectedPatient!['id']!);
    if (!mounted) return;
    setState(() {
      _history = data;
      _loadingHistory = false;
    });
  }

  Future<void> _recordVitals() async {
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a patient first'),
          backgroundColor: kNurseWarning,
        ),
      );
      return;
    }

    // Required fields validation
    final requiredKeys = [
      'temperature',
      'heartRate',
      'respiratoryRate',
      'systolic',
      'diastolic',
      'spo2',
      'weightKg',
      'heightCm'
    ];
    for (final key in requiredKeys) {
      if (_vitalControllers[key]!.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enter $key'),
            backgroundColor: kNurseWarning,
          ),
        );
        return;
      }
    }

    // Calculate BMI if empty
    if (_vitalControllers['bmi']!.text.trim().isEmpty) {
      final hCm =
          double.tryParse(_vitalControllers['heightCm']!.text.trim()) ?? 0;
      final wKg =
          double.tryParse(_vitalControllers['weightKg']!.text.trim()) ?? 0;
      if (hCm > 0) {
        final bmi = wKg / ((hCm / 100) * (hCm / 100));
        _vitalControllers['bmi']!.text = bmi.toStringAsFixed(1);
      }
    }

    // Build payload
    final payload = <String, dynamic>{
      'patientId': _selectedPatient!['id'],
      'patientName': _selectedPatient!['name'],
      'temperature':
          double.tryParse(_vitalControllers['temperature']!.text.trim()) ?? 0,
      'heartRate':
          int.tryParse(_vitalControllers['heartRate']!.text.trim()) ?? 0,
      'respiratoryRate':
          int.tryParse(_vitalControllers['respiratoryRate']!.text.trim()) ?? 0,
      'systolic': int.tryParse(_vitalControllers['systolic']!.text.trim()) ?? 0,
      'diastolic':
          int.tryParse(_vitalControllers['diastolic']!.text.trim()) ?? 0,
      'spo2': int.tryParse(_vitalControllers['spo2']!.text.trim()) ?? 0,
      'weightKg':
          double.tryParse(_vitalControllers['weightKg']!.text.trim()) ?? 0,
      'heightCm':
          double.tryParse(_vitalControllers['heightCm']!.text.trim()) ?? 0,
      'bmi': double.tryParse(_vitalControllers['bmi']!.text.trim()),
      // Optional extended
      'glucoseRandom':
          double.tryParse(_vitalControllers['glucoseRandom']!.text.trim()),
      'glucoseFasting':
          double.tryParse(_vitalControllers['glucoseFasting']!.text.trim()),
      'glucosePostMeal':
          double.tryParse(_vitalControllers['glucosePostMeal']!.text.trim()),
      'painLevel': int.tryParse(_vitalControllers['painLevel']!.text.trim()),
      'menstrualNote': _vitalControllers['menstrualNote']!.text.trim(),
      'hydrationMl':
          int.tryParse(_vitalControllers['hydrationMl']!.text.trim()),
      'sleepHours':
          double.tryParse(_vitalControllers['sleepHours']!.text.trim()),
      'sleepQuality': _vitalControllers['sleepQuality']!.text.trim(),
      // Critical
      'ecgSummary': _vitalControllers['ecgSummary']!.text.trim(),
      'ventilatorFlow': _vitalControllers['ventilatorFlow']!.text.trim(),
      'infusionNotes': _vitalControllers['infusionNotes']!.text.trim(),
      'gcsScore': int.tryParse(_vitalControllers['gcsScore']!.text.trim()),
      'neuroNotes': _vitalControllers['neuroNotes']!.text.trim(),
      'notes': '',
    };

    setState(() => _isRecording = true);

    try {
      final success = await ApiService.recordVitalSigns(payload);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vital signs recorded successfully'),
            backgroundColor: kNurseSuccess,
          ),
        );

        // Clear form
        _vitalControllers.values.forEach((controller) => controller.clear());
        // Refresh history
        await _loadHistory();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record vital signs'),
            backgroundColor: kNurseError,
          ),
        );
      }
    } catch (e) {
      print('❌ Error recording vitals: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error recording vital signs: $e'),
          backgroundColor: kNurseError,
        ),
      );
    } finally {
      setState(() => _isRecording = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Vital Monitoring',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: kNurseSecondary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kNursePrimary.withOpacity(0.15), kNurseBackground],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildPatientSelector(),
                  TabBar(
                    controller: _tabController,
                    labelColor: kNursePrimary,
                    unselectedLabelColor: Colors.grey[600],
                    tabs: const [
                      Tab(text: 'Add Vitals', icon: Icon(Icons.add)),
                      Tab(text: 'History', icon: Icon(Icons.history)),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _buildVitalSignsForm(),
                            const SizedBox(height: 20),
                            _buildRecordButton(),
                          ],
                        ),
                        _buildHistoryList(),
                      ],
                    ),
                  )
                ],
              ),
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_selectedPatient == null) {
      return Center(
        child: Text('Select a patient first', style: GoogleFonts.poppins()),
      );
    }
    if (_history.isEmpty) {
      return Center(
        child: Text('No vitals yet', style: GoogleFonts.poppins()),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _history.length,
        itemBuilder: (context, i) {
          final v = _history[i];
          final chips = <Widget>[];
          if (v['temperature'] != null)
            chips.add(_chip('Temp', '${v['temperature']} °C'));
          if (v['heartRate'] != null)
            chips.add(_chip('HR', '${v['heartRate']} bpm'));
          if (v['respiratoryRate'] != null)
            chips.add(_chip('RR', '${v['respiratoryRate']} /min'));
          if (v['systolic'] != null && v['diastolic'] != null)
            chips.add(_chip('BP', '${v['systolic']}/${v['diastolic']}'));
          if (v['spo2'] != null) chips.add(_chip('SpO₂', '${v['spo2']}%'));
          if (v['bmi'] != null) chips.add(_chip('BMI', '${v['bmi']}'));
          if (v['glucoseRandom'] != null)
            chips.add(_chip('GR', '${v['glucoseRandom']}'));
          if (v['glucoseFasting'] != null)
            chips.add(_chip('GF', '${v['glucoseFasting']}'));
          if (v['glucosePostMeal'] != null)
            chips.add(_chip('GPM', '${v['glucosePostMeal']}'));

          return Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatTimestamp(v['recordedAt'] ?? v['createdAt']),
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, runSpacing: 8, children: chips),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (val) async {
                      if (val == 'delete') {
                        final ok = await ApiService.deleteVital(v['_id']);
                        if (ok) _loadHistory();
                      } else if (val == 'edit') {
                        _showEditDialog(v);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Chip(
      labelPadding: const EdgeInsets.symmetric(horizontal: 10),
      backgroundColor: kNurseAccent.withOpacity(0.25),
      label: Text('$label: $value',
          style: GoogleFonts.poppins(fontSize: 12, color: kNurseText)),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: kNurseSecondary.withOpacity(0.4))),
    );
  }

  String _formatTimestamp(dynamic ts) {
    try {
      final dt = DateTime.tryParse(ts.toString())?.toLocal();
      if (dt == null) return ts.toString();
      final two = (int n) => n.toString().padLeft(2, '0');
      return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return ts.toString();
    }
  }

  void _showEditDialog(Map<String, dynamic> v) {
    final tCtrl =
        TextEditingController(text: (v['temperature'] ?? '').toString());
    final hrCtrl =
        TextEditingController(text: (v['heartRate'] ?? '').toString());
    final rrCtrl =
        TextEditingController(text: (v['respiratoryRate'] ?? '').toString());
    final sysCtrl =
        TextEditingController(text: (v['systolic'] ?? '').toString());
    final diaCtrl =
        TextEditingController(text: (v['diastolic'] ?? '').toString());
    final spCtrl = TextEditingController(text: (v['spo2'] ?? '').toString());
    final weightCtrl =
        TextEditingController(text: (v['weightKg'] ?? '').toString());
    final heightCtrl =
        TextEditingController(text: (v['heightCm'] ?? '').toString());
    final bmiCtrl = TextEditingController(text: (v['bmi'] ?? '').toString());
    // Extended
    final grCtrl =
        TextEditingController(text: (v['glucoseRandom'] ?? '').toString());
    final gfCtrl =
        TextEditingController(text: (v['glucoseFasting'] ?? '').toString());
    final gpmCtrl =
        TextEditingController(text: (v['glucosePostMeal'] ?? '').toString());
    final painCtrl =
        TextEditingController(text: (v['painLevel'] ?? '').toString());
    final mensCtrl =
        TextEditingController(text: (v['menstrualNote'] ?? '').toString());
    final hydCtrl =
        TextEditingController(text: (v['hydrationMl'] ?? '').toString());
    final sleepHCtrl =
        TextEditingController(text: (v['sleepHours'] ?? '').toString());
    final sleepQCtrl =
        TextEditingController(text: (v['sleepQuality'] ?? '').toString());
    // Critical
    final ecgCtrl =
        TextEditingController(text: (v['ecgSummary'] ?? '').toString());
    final ventCtrl =
        TextEditingController(text: (v['ventilatorFlow'] ?? '').toString());
    final infCtrl =
        TextEditingController(text: (v['infusionNotes'] ?? '').toString());
    final gcsCtrl =
        TextEditingController(text: (v['gcsScore'] ?? '').toString());
    final neuroCtrl =
        TextEditingController(text: (v['neuroNotes'] ?? '').toString());
    final notesCtrl =
        TextEditingController(text: (v['notes'] ?? '').toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Vitals'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                  controller: tCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Temperature (°C)'),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: hrCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Heart Rate (bpm)'),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: rrCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Respiratory Rate (/min)'),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: sysCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Systolic (mmHg)'),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: diaCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Diastolic (mmHg)'),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: spCtrl,
                  decoration: const InputDecoration(labelText: 'SpO₂ (%)'),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: weightCtrl,
                  decoration: const InputDecoration(labelText: 'Weight (kg)'),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: heightCtrl,
                  decoration: const InputDecoration(labelText: 'Height (cm)'),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: bmiCtrl,
                  decoration: const InputDecoration(labelText: 'BMI'),
                  keyboardType: TextInputType.number),
              const Divider(),
              Text('Extended',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              TextField(
                  controller: grCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Glucose Random (mg/dL)'),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: gfCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Glucose Fasting (mg/dL)'),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: gpmCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Glucose Post-Meal (mg/dL)'),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: painCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Pain Level (1-10)'),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: mensCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Menstrual/Pregnancy Notes')),
              TextField(
                  controller: hydCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Hydration (ml)'),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: sleepHCtrl,
                  decoration: const InputDecoration(labelText: 'Sleep Hours'),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: sleepQCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Sleep Quality')),
              const Divider(),
              Text('Critical',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              TextField(
                  controller: ecgCtrl,
                  decoration:
                      const InputDecoration(labelText: 'ECG/Rhythm Summary')),
              TextField(
                  controller: ventCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Ventilator / O₂ Flow')),
              TextField(
                  controller: infCtrl,
                  decoration:
                      const InputDecoration(labelText: 'IV/Infusion Notes')),
              TextField(
                  controller: gcsCtrl,
                  decoration: const InputDecoration(labelText: 'GCS Score'),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: neuroCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Neurological Notes')),
              const Divider(),
              TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final payload = {
                'temperature': double.tryParse(tCtrl.text),
                'heartRate': int.tryParse(hrCtrl.text),
                'respiratoryRate': int.tryParse(rrCtrl.text),
                'systolic': int.tryParse(sysCtrl.text),
                'diastolic': int.tryParse(diaCtrl.text),
                'spo2': int.tryParse(spCtrl.text),
                'weightKg': double.tryParse(weightCtrl.text),
                'heightCm': double.tryParse(heightCtrl.text),
                'bmi': double.tryParse(bmiCtrl.text),
                // Extended
                'glucoseRandom': double.tryParse(grCtrl.text),
                'glucoseFasting': double.tryParse(gfCtrl.text),
                'glucosePostMeal': double.tryParse(gpmCtrl.text),
                'painLevel': int.tryParse(painCtrl.text),
                'menstrualNote': mensCtrl.text,
                'hydrationMl': int.tryParse(hydCtrl.text),
                'sleepHours': double.tryParse(sleepHCtrl.text),
                'sleepQuality': sleepQCtrl.text,
                // Critical
                'ecgSummary': ecgCtrl.text,
                'ventilatorFlow': ventCtrl.text,
                'infusionNotes': infCtrl.text,
                'gcsScore': int.tryParse(gcsCtrl.text),
                'neuroNotes': neuroCtrl.text,
                'notes': notesCtrl.text,
              };
              final ok = await ApiService.updateVital(v['_id'], payload);
              if (ok && mounted) {
                Navigator.pop(context);
                _loadHistory();
              }
            },
            child: const Text('Save'),
          )
        ],
      ),
    );
  }

  Widget _buildPatientSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Patient',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: kNurseText,
            ),
          ),
          const SizedBox(height: 12),
          if (_assignedPatients.isEmpty)
            Text(
              'No patients assigned',
              style: GoogleFonts.poppins(
                color: kNurseTextSecondary,
                fontSize: 14,
              ),
            )
          else
            DropdownButtonFormField<Map<String, String>>(
              value: _selectedPatient,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.person),
              ),
              items: _assignedPatients.map((patient) {
                return DropdownMenuItem<Map<String, String>>(
                  value: patient,
                  child: Text(
                    patient['name'] ?? 'Patient',
                    style: GoogleFonts.poppins(),
                  ),
                );
              }).toList(),
              onChanged: (patient) {
                setState(() => _selectedPatient = patient);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildVitalSignsForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vital Signs',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: kNurseText,
            ),
          ),
          const SizedBox(height: 20),
          // Basic vitals
          _buildTwoInputs('Temperature', 'temperature', '°C', Icons.thermostat,
              'Heart Rate', 'heartRate', 'bpm', Icons.favorite),
          const SizedBox(height: 12),
          _buildTwoInputs('Respiratory Rate', 'respiratoryRate', 'breaths/min',
              Icons.air, 'SpO₂', 'spo2', '%', Icons.monitor_heart),
          const SizedBox(height: 12),
          _buildTwoInputs('BP Systolic', 'systolic', 'mmHg', Icons.bloodtype,
              'BP Diastolic', 'diastolic', 'mmHg', Icons.bloodtype_outlined),
          const SizedBox(height: 12),
          _buildTwoInputs('Weight', 'weightKg', 'kg', Icons.scale, 'Height',
              'heightCm', 'cm', Icons.height),
          const SizedBox(height: 12),
          _buildVitalInput('BMI (auto)', 'bmi', '', Icons.monitor_weight,
              enabled: false),
          const SizedBox(height: 12),
          // Extended
          Divider(height: 32),
          Text('Extended (optional)',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _buildTwoInputs(
              'Glucose Random',
              'glucoseRandom',
              'mg/dL',
              Icons.bloodtype,
              'Glucose Fasting',
              'glucoseFasting',
              'mg/dL',
              Icons.bloodtype),
          const SizedBox(height: 12),
          _buildTwoInputs(
              'Glucose Post-Meal',
              'glucosePostMeal',
              'mg/dL',
              Icons.bloodtype,
              'Pain Level (1-10)',
              'painLevel',
              '',
              Icons.scale),
          const SizedBox(height: 12),
          _buildVitalInput('Menstrual/Pregnancy Notes', 'menstrualNote', '',
              Icons.pregnant_woman),
          const SizedBox(height: 12),
          _buildTwoInputs('Hydration', 'hydrationMl', 'ml', Icons.local_drink,
              'Sleep Hours', 'sleepHours', 'h', Icons.bedtime),
          const SizedBox(height: 12),
          _buildVitalInput(
              'Sleep Quality', 'sleepQuality', '', Icons.bedtime_outlined),
          // Critical
          Divider(height: 32),
          Text('Critical Monitoring (optional)',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _buildVitalInput(
              'ECG/Rhythm Summary', 'ecgSummary', '', Icons.monitor_heart),
          const SizedBox(height: 12),
          _buildVitalInput(
              'Ventilator / O₂ Flow', 'ventilatorFlow', '', Icons.air),
          const SizedBox(height: 12),
          _buildVitalInput(
              'IV/Infusion Notes', 'infusionNotes', '', Icons.medical_services),
          const SizedBox(height: 12),
          _buildVitalInput('GCS Score', 'gcsScore', '', Icons.psychology),
          const SizedBox(height: 12),
          _buildVitalInput(
              'Neurological Notes', 'neuroNotes', '', Icons.psychology_alt),
        ],
      ),
    );
  }

  Widget _buildVitalInput(String label, String key, String unit, IconData icon,
      {bool enabled = true}) {
    return Row(
      children: [
        Tooltip(
          message: label,
          child: Icon(icon, color: kNursePrimary, size: 20),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: _vitalControllers[key],
            enabled: enabled,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: label,
              labelStyle: GoogleFonts.poppins(fontSize: 12),
              hintText: 'Enter $label',
              hintStyle: GoogleFonts.poppins(fontSize: 12),
              // Show unit only when there is input so it won't obscure typed text
              suffixText:
                  (_vitalControllers[key]?.text.trim().isNotEmpty ?? false)
                      ? (unit.isNotEmpty ? unit : null)
                      : null,
              suffixStyle:
                  GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              isDense: true,
            ),
            style: GoogleFonts.poppins(color: kNurseText, fontSize: 14),
            cursorColor: kNursePrimary,
            textAlign: TextAlign.left,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }

  Widget _buildTwoInputs(
      String label1,
      String key1,
      String unit1,
      IconData icon1,
      String label2,
      String key2,
      String unit2,
      IconData icon2) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // If screen width is less than 600px, stack vertically
        if (constraints.maxWidth < 600) {
          return Column(
            children: [
              _buildVitalInput(label1, key1, unit1, icon1),
              const SizedBox(height: 12),
              _buildVitalInput(label2, key2, unit2, icon2),
            ],
          );
        }
        // Otherwise, use horizontal layout
        return Row(
          children: [
            Expanded(child: _buildVitalInput(label1, key1, unit1, icon1)),
            const SizedBox(width: 16),
            Expanded(child: _buildVitalInput(label2, key2, unit2, icon2)),
          ],
        );
      },
    );
  }

  Widget _buildRecordButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isRecording ? null : _recordVitals,
        style: ElevatedButton.styleFrom(
          backgroundColor: kNursePrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
        ),
        child: _isRecording
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Recording...',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.save),
                  const SizedBox(width: 8),
                  Text(
                    'Record Vital Signs',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
