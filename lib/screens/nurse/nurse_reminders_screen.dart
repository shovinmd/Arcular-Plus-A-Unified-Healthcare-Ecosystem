import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

class NurseRemindersScreen extends StatefulWidget {
  const NurseRemindersScreen({super.key});

  @override
  State<NurseRemindersScreen> createState() => _NurseRemindersScreenState();
}

class _NurseRemindersScreenState extends State<NurseRemindersScreen> {
  // Nurse assigned-patient green theme
  static const Color kNursePrimary = Color(0xFFFFB300);
  static const Color kNurseSecondary = Color(0xFFFFD54F);
  final TextEditingController _arcCtrl = TextEditingController();
  bool _loading = false;
  List<Map<String, dynamic>> _reminders = [];
  List<Map<String, String>> _patients = [];
  Map<String, String>? _selectedPatient;

  @override
  void initState() {
    super.initState();
    _loadAssignedPatients();
  }

  Future<void> _loadAssignedPatients() async {
    setState(() => _loading = true);
    try {
      final assignments = await ApiService.getNurseAssignments();
      final pts = assignments.map<Map<String, String>>((a) {
        final p = a['patientId'] is Map ? a['patientId'] : null;
        final id = p != null
            ? (p['_id']?.toString() ?? '')
            : (a['patientId']?.toString() ?? '');
        final name = a['patientName'] ??
            (p != null ? (p['fullName'] ?? 'Patient') : 'Patient');
        final arc = a['patientArcId'] ??
            (p != null ? (p['healthQrId'] ?? p['arcId'] ?? '') : '');
        return {'id': id, 'name': name, 'arc': arc};
      }).toList();
      setState(() {
        _patients = pts;
        if (pts.isNotEmpty) {
          _selectedPatient = pts.first;
          _arcCtrl.text = pts.first['arc'] ?? '';
          _fetchReminders();
        }
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchReminders() async {
    final arcId = _arcCtrl.text.trim();
    if (arcId.isEmpty) return;
    setState(() => _loading = true);
    try {
      final items = await ApiService.getRemindersByArcId(arcId);
      setState(() => _reminders = items);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _markStatus(String id, String status) async {
    final ok = await ApiService.updateReminderStatus(id, status);
    if (ok) _fetchReminders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kNurseSecondary,
        foregroundColor: Colors.white,
        title: Text('Reminders',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kNursePrimary, kNurseSecondary],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<Map<String, String>>(
                          value: _selectedPatient,
                          items: _patients
                              .map((p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(p['name'] ?? 'Patient',
                                        style: GoogleFonts.poppins()),
                                  ))
                              .toList(),
                          onChanged: (p) {
                            setState(() {
                              _selectedPatient = p;
                              _arcCtrl.text = p?['arc'] ?? '';
                            });
                            _fetchReminders();
                          },
                          decoration: InputDecoration(
                            labelText: 'Select Patient',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _arcCtrl,
                          decoration: InputDecoration(
                            labelText: 'Patient ARC ID',
                            prefixIcon: const Icon(Icons.qr_code_2),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _fetchReminders,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: kNurseSecondary,
                        ),
                        child: const Text('Fetch'),
                      )
                    ],
                  )
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24)),
                ),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _reminders.isEmpty
                        ? Center(
                            child: Text('No reminders',
                                style: GoogleFonts.poppins()),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _reminders.length,
                            itemBuilder: (context, i) {
                              final r = _reminders[i];
                              final status = (r['status'] ?? '').toString();
                              return Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        status.toLowerCase() == 'completed'
                                            ? kNurseSecondary
                                            : kNursePrimary,
                                    child: Icon(
                                      status.toLowerCase() == 'completed'
                                          ? Icons.check
                                          : Icons.schedule,
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(
                                      (r['title'] ?? r['task'] ?? 'Reminder')
                                          .toString(),
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600)),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if ((r['notes'] ?? '')
                                          .toString()
                                          .isNotEmpty)
                                        Text('Notes: ${r['notes']}',
                                            style: GoogleFonts.poppins(
                                                fontSize: 12)),
                                      if ((r['dueAt'] ?? r['dueTime']) != null)
                                        Text(
                                            (r['dueAt'] ?? r['dueTime'])
                                                .toString(),
                                            style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: Colors.grey[700])),
                                    ],
                                  ),
                                  trailing: status.toLowerCase() == 'completed'
                                      ? const Icon(Icons.check_circle,
                                          color: kNurseSecondary)
                                      : TextButton(
                                          onPressed: () => _markStatus(
                                              r['_id'] ?? r['id'], 'completed'),
                                          child: const Text('Mark done'),
                                        ),
                                ),
                              );
                            },
                          ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
