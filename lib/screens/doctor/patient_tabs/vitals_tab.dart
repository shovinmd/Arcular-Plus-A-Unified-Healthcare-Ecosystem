import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arcular_plus/services/api_service.dart';

class VitalsTab extends StatefulWidget {
  final String patientId;
  const VitalsTab({super.key, required this.patientId});

  @override
  State<VitalsTab> createState() => _VitalsTabState();
}

class _VitalsTabState extends State<VitalsTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _vitals = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await ApiService.getPatientVitals(widget.patientId);
    if (!mounted) return;
    setState(() {
      _vitals = data;
      _loading = false;
    });
  }

  // Editing disabled here; nurses handle edits

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_vitals.isEmpty) {
      return Center(
        child: Text('No vitals recorded yet', style: GoogleFonts.poppins()),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _vitals.length,
        itemBuilder: (context, i) {
          final v = _vitals[i];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (v['recordedAt'] ?? v['createdAt'] ?? '').toString(),
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _chip('Temp', '${v['temperature']} °C'),
                      _chip('HR', '${v['heartRate']} bpm'),
                      _chip('RR', '${v['respiratoryRate']} /min'),
                      _chip('BP', '${v['systolic']}/${v['diastolic']}'),
                      _chip('SpO₂', '${v['spo2']}%'),
                      if (v['bmi'] != null) _chip('BMI', '${v['bmi']}'),
                      if (v['weightKg'] != null)
                        _chip('Weight', '${v['weightKg']} kg'),
                      if (v['heightCm'] != null)
                        _chip('Height', '${v['heightCm']} cm'),
                    ],
                  ),
                  // Extended vitals
                  if ((v['glucoseRandom'] ??
                          v['glucoseFasting'] ??
                          v['glucosePostMeal'] ??
                          v['painLevel'] ??
                          v['menstrualNote'] ??
                          v['hydrationMl'] ??
                          v['sleepHours'] ??
                          v['sleepQuality']) !=
                      null) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        if (v['glucoseRandom'] != null)
                          _chip('GR', '${v['glucoseRandom']} mg/dL'),
                        if (v['glucoseFasting'] != null)
                          _chip('GF', '${v['glucoseFasting']} mg/dL'),
                        if (v['glucosePostMeal'] != null)
                          _chip('GPM', '${v['glucosePostMeal']} mg/dL'),
                        if (v['painLevel'] != null)
                          _chip('Pain', '${v['painLevel']}/10'),
                        if (v['hydrationMl'] != null)
                          _chip('Hydration', '${v['hydrationMl']} ml'),
                        if (v['sleepHours'] != null)
                          _chip('Sleep', '${v['sleepHours']} hrs'),
                        if (v['sleepQuality'] != null)
                          _chip('Quality', '${v['sleepQuality']}'),
                      ],
                    ),
                  ],
                  // Critical vitals
                  if ((v['ecgSummary'] ??
                          v['ventilatorFlow'] ??
                          v['infusionNotes'] ??
                          v['gcsScore'] ??
                          v['neuroNotes']) !=
                      null) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        if (v['ecgSummary'] != null)
                          _chip('ECG', '${v['ecgSummary']}'),
                        if (v['ventilatorFlow'] != null)
                          _chip('Vent', '${v['ventilatorFlow']}'),
                        if (v['gcsScore'] != null)
                          _chip('GCS', '${v['gcsScore']}'),
                        if (v['infusionNotes'] != null)
                          _chip('IV', '${v['infusionNotes']}'),
                      ],
                    ),
                  ],
                  // Notes
                  if ((v['menstrualNote'] ?? v['neuroNotes'] ?? v['notes']) !=
                      null) ...[
                    const SizedBox(height: 8),
                    if (v['menstrualNote'] != null)
                      Text('Menstrual: ${v['menstrualNote']}',
                          style: GoogleFonts.poppins(fontSize: 12)),
                    if (v['neuroNotes'] != null)
                      Text('Neuro: ${v['neuroNotes']}',
                          style: GoogleFonts.poppins(fontSize: 12)),
                    if (v['notes'] != null)
                      Text('Notes: ${v['notes']}',
                          style: GoogleFonts.poppins(fontSize: 12)),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        final ok = await ApiService.deleteVital(v['_id']);
                        if (ok && mounted) _load();
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                    ),
                  )
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
      label: Text('$label: $value', style: GoogleFonts.poppins(fontSize: 12)),
    );
  }
}
