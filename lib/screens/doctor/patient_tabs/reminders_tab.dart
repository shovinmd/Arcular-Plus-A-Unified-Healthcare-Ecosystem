import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arcular_plus/services/api_service.dart';

class RemindersTab extends StatefulWidget {
  final String patientId; // not used for ARC-based creation, kept for context
  const RemindersTab({super.key, required this.patientId});

  @override
  State<RemindersTab> createState() => _RemindersTabState();
}

class _RemindersTabState extends State<RemindersTab> {
  final TextEditingController _arcCtrl = TextEditingController();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  DateTime? _dueAt;
  bool _submitting = false;
  bool _loading = false;
  List<Map<String, dynamic>> _reminders = [];

  Future<void> _fetchReminders() async {
    final arc = _arcCtrl.text.trim();
    if (arc.isEmpty) return;
    setState(() => _loading = true);
    final items = await ApiService.getRemindersByArcId(arc);
    if (!mounted) return;
    setState(() {
      _reminders = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Create reminder for nurse (by Patient ARC ID)',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        TextField(
          controller: _arcCtrl,
          decoration: InputDecoration(
            labelText: 'Patient ARC ID',
            prefixIcon: const Icon(Icons.qr_code_2),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onSubmitted: (_) => _fetchReminders(),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _fetchReminders,
            child: const Text('Load reminders'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _titleCtrl,
          decoration: InputDecoration(
            labelText: 'Task / Reminder Title',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Notes (optional)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(_dueAt == null
                  ? 'No due date'
                  : 'Due: ${_dueAt!.toLocal().toString().substring(0, 16)}'),
            ),
            TextButton(
              onPressed: () async {
                final now = DateTime.now();
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: _dueAt ?? now,
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 365)),
                );
                if (pickedDate != null) {
                  final pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_dueAt ?? now),
                  );
                  if (pickedTime != null) {
                    setState(() {
                      _dueAt = DateTime(pickedDate.year, pickedDate.month,
                          pickedDate.day, pickedTime.hour, pickedTime.minute);
                    });
                  }
                }
              },
              child: const Text('Pick due date/time'),
            )
          ],
        ),
        const SizedBox(height: 16),
        // Existing reminders list
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_reminders.isNotEmpty) ...[
          Text('Existing reminders',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _reminders.length,
            itemBuilder: (context, i) {
              final r = _reminders[i];
              final nurse =
                  (r['nurseId'] is Map) ? (r['nurseId']['fullName'] ?? '') : '';
              final status = (r['status'] ?? '').toString();
              final due = (r['dueAt'] ?? r['dueTime'])?.toString() ?? '';
              return Card(
                elevation: 1,
                child: ListTile(
                  leading: const Icon(Icons.event_note),
                  title: Text((r['title'] ?? 'Reminder').toString(),
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (nurse.isNotEmpty)
                        Text('Nurse: $nurse', style: GoogleFonts.poppins()),
                      if (due.isNotEmpty)
                        Text(due,
                            style: GoogleFonts.poppins(color: Colors.black54)),
                      Text('Status: $status',
                          style: GoogleFonts.poppins(color: Colors.black54)),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
        // End list

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _submitting
                ? null
                : () async {
                    final arc = _arcCtrl.text.trim();
                    final title = _titleCtrl.text.trim();
                    if (arc.isEmpty || title.isEmpty) return;
                    setState(() => _submitting = true);
                    final ok = await ApiService.createReminderByArcId(
                      patientArcId: arc,
                      title: title,
                      notes: _notesCtrl.text.trim().isEmpty
                          ? null
                          : _notesCtrl.text.trim(),
                      dueAtIso: _dueAt?.toUtc().toIso8601String(),
                    );
                    setState(() => _submitting = false);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok
                            ? 'Reminder created'
                            : 'Failed to create reminder')));
                    if (ok) {
                      _titleCtrl.clear();
                      _notesCtrl.clear();
                      setState(() => _dueAt = null);
                      _fetchReminders();
                    }
                  },
            child: _submitting
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Create Reminder'),
          ),
        )
      ],
    );
  }
}
