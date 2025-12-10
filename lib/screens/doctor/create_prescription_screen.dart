import 'package:flutter/material.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/models/user_model.dart';
import 'package:google_fonts/google_fonts.dart';

// Color constants for doctor theme (purple gradient)
const Color kDoctorBackground = Color(0xFFF9FAFB);
const Color kDoctorPrimary = Color(0xFF6A11CB); // Purple
const Color kDoctorSecondary = Color(0xFF2575FC); // Blue-purple
const Color kDoctorAccent = Color(0xFFF3E8FF);
const Color kDoctorPrimaryText = Color(0xFF2E2E2E);
const Color kDoctorSecondaryText = Color(0xFF6B7280);
const Color kDoctorBorder = Color(0xFFE5E7EB);
const Color kDoctorSuccess = Color(0xFF34D399);
const Color kDoctorWarning = Color(0xFFFFD54F);
const Color kDoctorError = Color(0xFFEF4444);

class CreatePrescriptionScreen extends StatefulWidget {
  final UserModel doctor;
  final VoidCallback onPrescriptionCreated;
  final bool isEdit;
  final Map<String, dynamic>? existingPrescription; // normalized backend doc

  const CreatePrescriptionScreen({
    super.key,
    required this.doctor,
    required this.onPrescriptionCreated,
    this.isEdit = false,
    this.existingPrescription,
  });

  @override
  State<CreatePrescriptionScreen> createState() =>
      _CreatePrescriptionScreenState();
}

class _CreatePrescriptionScreenState extends State<CreatePrescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _patientArcIdController = TextEditingController();
  final _hospitalIdController = TextEditingController();
  List<UserModel> _associatedHospitals = [];
  final _diagnosisController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _followUpDate;
  List<Map<String, dynamic>> _medications = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAssociatedHospitals();
    // Pre-fill for edit
    if (widget.isEdit && widget.existingPrescription != null) {
      final p = widget.existingPrescription!;
      _patientArcIdController.text = (p['patientArcId'] ?? '').toString();
      _hospitalIdController.text =
          (p['hospitalId'] ?? p['hospitalUid'] ?? '').toString();
      _diagnosisController.text = (p['diagnosis'] ?? '').toString();
      _instructionsController.text = (p['instructions'] ?? '').toString();
      _notesController.text = (p['notes'] ?? '').toString();
      final fu = p['followUpDate'];
      if (fu != null && fu.toString().isNotEmpty) {
        try {
          _followUpDate = DateTime.parse(fu.toString());
        } catch (_) {}
      }
      final meds =
          (p['medications'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      _medications = meds.map((m) => Map<String, dynamic>.from(m)).toList();
    }
  }

  Future<void> _loadAssociatedHospitals() async {
    try {
      final doc = widget.doctor;
      final ids = doc.affiliatedHospitals ??
          (doc.hospitalId != null ? [doc.hospitalId!] : []);
      final List<UserModel> list = [];
      for (final id in ids) {
        try {
          final h = await ApiService.getHospitalByUid(id) ??
              await ApiService.getHospitalByName(id);
          if (h != null) list.add(h);
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _associatedHospitals = list;
          if (_associatedHospitals.isNotEmpty) {
            _hospitalIdController.text = _associatedHospitals.first.uid;
          }
        });
      }
    } catch (_) {}
  }

  Widget _buildHospitalDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Hospital',
          prefixIcon: const Icon(Icons.local_hospital, color: kDoctorPrimary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kDoctorBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kDoctorPrimary),
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _hospitalIdController.text.isEmpty
                ? null
                : _hospitalIdController.text,
            isExpanded: true,
            hint: Text('Select hospital', style: GoogleFonts.poppins()),
            items: _associatedHospitals.map((h) {
              final name = h.hospitalName ?? h.fullName;
              return DropdownMenuItem<String>(
                value: h.uid,
                child: Text(name, style: GoogleFonts.poppins()),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _hospitalIdController.text = val ?? '';
              });
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _patientArcIdController.dispose();
    _hospitalIdController.dispose();
    _diagnosisController.dispose();
    _instructionsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDoctorBackground,
      appBar: AppBar(
        title: Text(
          widget.isEdit ? 'Edit Prescription' : 'Create Prescription',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: kDoctorPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: kDoctorPrimary,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient Information Card
                    _buildInfoCard(
                      'Patient Information',
                      Icons.person,
                      [
                        _buildTextField(
                          _patientArcIdController,
                          'Patient ARC ID',
                          Icons.qr_code,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter patient ARC ID';
                            }
                            return null;
                          },
                        ),
                        _buildHospitalDropdown(),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Medical Information Card
                    _buildInfoCard(
                      'Medical Information',
                      Icons.medical_services,
                      [
                        _buildTextField(
                          _diagnosisController,
                          'Diagnosis',
                          Icons.health_and_safety,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter diagnosis';
                            }
                            return null;
                          },
                        ),
                        _buildTextField(
                          _instructionsController,
                          'Instructions',
                          Icons.info,
                          maxLines: 3,
                        ),
                        _buildDateField(),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Medications Card
                    _buildMedicationsCard(),

                    const SizedBox(height: 16),

                    // Notes Card
                    _buildInfoCard(
                      'Additional Notes',
                      Icons.note,
                      [
                        _buildTextField(
                          _notesController,
                          'Notes',
                          Icons.edit_note,
                          maxLines: 3,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kDoctorSecondaryText,
                              side: const BorderSide(color: kDoctorBorder),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _createPrescription,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kDoctorPrimary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              widget.isEdit
                                  ? 'Update Prescription'
                                  : 'Create Prescription',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoCard(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kDoctorPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: kDoctorPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: kDoctorPrimaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        validator: validator,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: kDoctorPrimary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kDoctorBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kDoctorPrimary),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kDoctorError),
          ),
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: _selectFollowUpDate,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: kDoctorBorder),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today, color: kDoctorPrimary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _followUpDate == null
                      ? 'Select Follow-up Date (Optional)'
                      : 'Follow-up: ${_followUpDate!.day}/${_followUpDate!.month}/${_followUpDate!.year}',
                  style: GoogleFonts.poppins(
                    color: _followUpDate == null
                        ? kDoctorSecondaryText
                        : kDoctorPrimaryText,
                  ),
                ),
              ),
              if (_followUpDate != null)
                IconButton(
                  onPressed: () {
                    setState(() {
                      _followUpDate = null;
                    });
                  },
                  icon: const Icon(Icons.clear, color: kDoctorError),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedicationsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kDoctorPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.medication,
                    color: kDoctorPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Medications',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: kDoctorPrimaryText,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _addMedication,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kDoctorPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_medications.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: kDoctorAccent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kDoctorPrimary.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.medication,
                      size: 48,
                      color: kDoctorPrimary.withOpacity(0.6),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No medications added yet',
                      style: GoogleFonts.poppins(
                        color: kDoctorPrimaryText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Click "Add" to add medications to this prescription',
                      style: GoogleFonts.poppins(
                        color: kDoctorSecondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._medications.asMap().entries.map((entry) {
                final index = entry.key;
                final medication = entry.value;
                return _buildMedicationTile(index, medication);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationTile(int index, Map<String, dynamic> medication) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kDoctorBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  medication['name'] ?? 'Unknown Medication',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: kDoctorPrimaryText,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _removeMedication(index),
                icon: const Icon(Icons.delete, color: kDoctorError),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Dosage: ${medication['dose'] ?? 'Not specified'}',
                  style: GoogleFonts.poppins(
                    color: kDoctorSecondaryText,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Frequency: ${medication['frequency'] ?? 'Not specified'}',
                  style: GoogleFonts.poppins(
                    color: kDoctorSecondaryText,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (medication['instructions'] != null &&
              medication['instructions'].isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Instructions: ${medication['instructions']}',
                style: GoogleFonts.poppins(
                  color: kDoctorSecondaryText,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _selectFollowUpDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        _followUpDate = date;
      });
    }
  }

  void _addMedication() {
    showDialog(
      context: context,
      builder: (context) => AddMedicationDialog(
        onMedicationAdded: (medication) {
          setState(() {
            _medications.add(medication);
          });
        },
      ),
    );
  }

  void _removeMedication(int index) {
    setState(() {
      _medications.removeAt(index);
    });
  }

  Future<void> _createPrescription() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_medications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please add at least one medication',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: kDoctorError,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prescriptionData = {
        'patientArcId': _patientArcIdController.text.trim(),
        'hospitalId': _hospitalIdController.text.trim(),
        'doctorId': widget.doctor.uid,
        'diagnosis': _diagnosisController.text.trim(),
        'medications': _medications,
        'instructions': _instructionsController.text.trim(),
        'followUpDate': _followUpDate?.toIso8601String(),
        'notes': _notesController.text.trim(),
      };

      Map<String, dynamic>? result;
      if (widget.isEdit &&
          (widget.existingPrescription?['id'] != null ||
              widget.existingPrescription?['_id'] != null)) {
        final id = (widget.existingPrescription?['id'] ??
                widget.existingPrescription?['_id'])
            .toString();
        final ok = await ApiService.updatePrescription(id, prescriptionData);
        if (!ok) throw Exception('Failed to update prescription');
        result = {'_id': id};
      } else {
        result = await ApiService.createPrescription(prescriptionData);
      }

      if (result != null) {
        final String? prescriptionId =
            result['id']?.toString() ?? result['_id']?.toString();

        // Attempt to transform to medicines and add to Order Medicines for the user
        try {
          if (prescriptionId != null && prescriptionId.isNotEmpty) {
            final meds = await ApiService.transformPrescriptionToMedicines(
                prescriptionId);
            for (final m in meds) {
              await ApiService.addMedication(m);
            }
          }
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Prescription created successfully!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: kDoctorSuccess,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        widget.onPrescriptionCreated();
        Navigator.pop(context);
      } else {
        throw Exception('Failed to create prescription');
      }
    } catch (e) {
      print('❌ Error creating prescription: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to create prescription: $e',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: kDoctorError,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

class AddMedicationDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onMedicationAdded;

  const AddMedicationDialog({
    super.key,
    required this.onMedicationAdded,
  });

  @override
  State<AddMedicationDialog> createState() => _AddMedicationDialogState();
}

class _AddMedicationDialogState extends State<AddMedicationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _doseController = TextEditingController();
  final _frequencyController = TextEditingController();
  final _durationController = TextEditingController();
  String? _frequency;
  String? _duration;
  final _instructionsController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _doseController.dispose();
    _frequencyController.dispose();
    _durationController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        'Add Medication',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: kDoctorPrimaryText,
        ),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(
                  _nameController, 'Medication Name', Icons.medication,
                  validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter medication name';
                }
                return null;
              }),
              _buildTextField(_doseController, 'Dosage', Icons.science,
                  validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter dosage';
                }
                return null;
              }),
              _buildFrequencyDropdown(),
              _buildDurationDropdown(),
              _buildTextField(
                  _instructionsController, 'Instructions', Icons.info,
                  maxLines: 2),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.poppins(
              color: kDoctorSecondaryText,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _addMedication,
          style: ElevatedButton.styleFrom(
            backgroundColor: kDoctorPrimary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Add',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        validator: validator,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: kDoctorPrimary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: kDoctorBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: kDoctorPrimary),
          ),
        ),
      ),
    );
  }

  void _addMedication() {
    if (_formKey.currentState!.validate()) {
      final medication = {
        'name': _nameController.text.trim(),
        'dose': _doseController.text.trim(),
        'frequency': _frequency ?? _frequencyController.text.trim(),
        'duration': _duration ?? _durationController.text.trim(),
        'instructions': _instructionsController.text.trim(),
      };

      widget.onMedicationAdded(medication);
      Navigator.pop(context);
    }
  }

  Widget _buildFrequencyDropdown() {
    const options = [
      'Once daily',
      'Twice daily',
      'Thrice daily',
      'Every 6 hours',
      'Every 8 hours',
      'As needed'
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Frequency',
          prefixIcon: const Icon(Icons.schedule, color: kDoctorPrimary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: kDoctorBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: kDoctorPrimary),
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _frequency,
            isExpanded: true,
            hint: Text('Select frequency', style: GoogleFonts.poppins()),
            items: options
                .map((o) => DropdownMenuItem(
                    value: o, child: Text(o, style: GoogleFonts.poppins())))
                .toList(),
            onChanged: (val) {
              setState(() {
                _frequency = val;
                _frequencyController.text = val ?? '';
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDurationDropdown() {
    const options = [
      '3 days',
      '5 days',
      '7 days',
      '10 days',
      '14 days',
      '1 month'
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Duration',
          prefixIcon: const Icon(Icons.timer, color: kDoctorPrimary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: kDoctorBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: kDoctorPrimary),
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _duration,
            isExpanded: true,
            hint: Text('Select duration', style: GoogleFonts.poppins()),
            items: options
                .map((o) => DropdownMenuItem(
                    value: o, child: Text(o, style: GoogleFonts.poppins())))
                .toList(),
            onChanged: (val) {
              setState(() {
                _duration = val;
                _durationController.text = val ?? '';
              });
            },
          ),
        ),
      ),
    );
  }
}
