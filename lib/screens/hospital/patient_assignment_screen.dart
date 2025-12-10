import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PatientAssignmentScreen extends StatefulWidget {
  const PatientAssignmentScreen({Key? key}) : super(key: key);

  @override
  State<PatientAssignmentScreen> createState() =>
      _PatientAssignmentScreenState();
}

class _PatientAssignmentScreenState extends State<PatientAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _patientArcIdController = TextEditingController();
  final _doctorArcIdController = TextEditingController();

  String _selectedWard = 'General Ward';
  String _selectedShift = 'Morning (6 AM - 2 PM)';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  List<String> _wards = [
    'General Ward',
    'ICU',
    'Emergency Ward',
    'Cardiology Ward',
    'Neurology Ward',
    'Orthopedic Ward',
    'Pediatric Ward',
    'Maternity Ward',
    'Surgery Ward',
    'Oncology Ward',
    'Psychiatric Ward',
    'Dermatology Ward',
    'ENT Ward',
    'Ophthalmology Ward',
    'Urology Ward',
    'Gastroenterology Ward',
    'Pulmonology Ward',
    'Endocrinology Ward',
    'Rheumatology Ward',
    'Hematology Ward',
  ];

  List<String> _shifts = [
    'Morning (6 AM - 2 PM)',
    'Evening (2 PM - 10 PM)',
    'Night (10 PM - 6 AM)',
  ];

  UserModel? _selectedPatient;
  UserModel? _selectedDoctor;
  List<UserModel> _availableNurses = [];
  UserModel? _selectedNurse;

  bool _isLoading = false;
  bool _isSearchingPatient = false;
  bool _isSearchingDoctor = false;
  bool _isLoadingNurses = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableNurses();
  }

  @override
  void dispose() {
    _patientArcIdController.dispose();
    _doctorArcIdController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableNurses() async {
    setState(() {
      _isLoadingNurses = true;
    });

    try {
      // Get hospital ID from current user
      final hospitalId = await _getCurrentHospitalId();
      print('🏥 Hospital ID for nurse loading: $hospitalId');

      if (hospitalId != null) {
        print('👩‍⚕️ Loading nurses for hospital: $hospitalId');
        final nurses = await ApiService.getHospitalNurses(hospitalId);
        print('👩‍⚕️ Found ${nurses.length} nurses');
        setState(() {
          _availableNurses = nurses;
        });
      } else {
        print('❌ No hospital ID found, cannot load nurses');
        _showErrorSnackBar('Unable to identify hospital');
      }
    } catch (e) {
      print('❌ Error loading nurses: $e');
      _showErrorSnackBar('Failed to load available nurses: $e');
    } finally {
      setState(() {
        _isLoadingNurses = false;
      });
    }
  }

  Future<String?> _getCurrentHospitalId() async {
    try {
      // Get current user's Firebase UID
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No authenticated user found');
        return null;
      }

      // Get hospital MongoDB ID from Firebase UID
      final hospitalMongoId = await ApiService.getHospitalMongoId(user.uid);
      print('🏥 Hospital MongoDB ID: $hospitalMongoId');

      return hospitalMongoId;
    } catch (e) {
      print('❌ Error getting current hospital ID: $e');
      return null;
    }
  }

  Future<void> _searchPatient() async {
    final arcId = _patientArcIdController.text.trim();
    print('👤 Patient search called with ARC ID: $arcId');

    if (arcId.isEmpty) {
      _showErrorSnackBar('Please enter patient ARC ID');
      return;
    }

    // Only search if ARC ID is at least 3 characters long
    if (arcId.length < 3) {
      print('👤 Patient ARC ID too short, skipping search');
      return;
    }

    setState(() {
      _isSearchingPatient = true;
    });

    try {
      print('👤 Searching for patient with ARC ID: $arcId');
      final patientData = await ApiService.getUserByArcId(arcId);
      print('👤 Patient response: $patientData');

      if (patientData != null) {
        final patient = UserModel.fromJson(patientData);
        setState(() {
          _selectedPatient = patient;
        });
        _showSuccessSnackBar('Patient found: ${patient.fullName}');
      } else {
        print('👤 No patient found with ARC ID: $arcId');
        _showErrorSnackBar('Patient not found with ARC ID: $arcId');
      }
    } catch (e) {
      print('❌ Error searching patient: $e');
      _showErrorSnackBar('Error searching patient: $e');
    } finally {
      setState(() {
        _isSearchingPatient = false;
      });
    }
  }

  Future<void> _searchDoctor() async {
    final arcId = _doctorArcIdController.text.trim();
    print('🔍 Doctor search called with ARC ID: $arcId');

    if (arcId.isEmpty) {
      _showErrorSnackBar('Please enter doctor ARC ID');
      return;
    }

    // Only search if ARC ID is at least 3 characters long
    if (arcId.length < 3) {
      print('🔍 Doctor ARC ID too short, skipping search');
      return;
    }

    setState(() {
      _isSearchingDoctor = true;
    });

    try {
      print('🔍 Searching for doctor with ARC ID: $arcId');

      // First try direct doctor collection search
      var doctorData = await ApiService.getDoctorByArcIdDirect(arcId);
      print('🔍 Direct doctor collection response: $doctorData');

      // If not found, try QR endpoint
      if (doctorData == null) {
        print('🔍 Not found in direct search, trying QR endpoint...');
        doctorData = await ApiService.getDoctorByArcId(arcId);
        print('🔍 Doctor QR endpoint response: $doctorData');
      }

      // If still not found, try user collection as fallback
      if (doctorData == null) {
        print('🔍 Not found in doctor collection, trying user collection...');
        doctorData = await ApiService.getUserByArcId(arcId);
        print('🔍 User collection response: $doctorData');

        if (doctorData != null) {
          // Check if it's actually a doctor in user collection
          final userType = doctorData['userType'] ??
              doctorData['role'] ??
              doctorData['type'];
          print('🔍 User type found: $userType');

          final doctorTypes = [
            'doctor',
            'Doctor',
            'doc',
            'Doc',
            'DOCTOR',
            'DOC'
          ];
          if (!doctorTypes.contains(userType)) {
            print('🔍 User found but not a doctor. User type: $userType');
            _showErrorSnackBar(
                'User found but not a doctor. User type: $userType');
            return;
          }
        }
      }

      if (doctorData != null) {
        final doctor = UserModel.fromJson(doctorData);
        setState(() {
          _selectedDoctor = doctor;
        });
        _showSuccessSnackBar('Doctor found: ${doctor.fullName}');
      } else {
        print('🔍 No doctor found with ARC ID: $arcId');
        _showErrorSnackBar('Doctor not found with ARC ID: $arcId');
      }
    } catch (e) {
      print('❌ Error searching doctor: $e');
      _showErrorSnackBar('Error searching doctor: $e');
    } finally {
      setState(() {
        _isSearchingDoctor = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _createAssignment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPatient == null) {
      _showErrorSnackBar('Please search and select a patient');
      return;
    }

    if (_selectedDoctor == null) {
      _showErrorSnackBar('Please search and select a doctor');
      return;
    }

    if (_selectedNurse == null) {
      _showErrorSnackBar('Please select a nurse');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.createPatientAssignment(
        patientArcId:
            _selectedPatient!.arcId ?? _patientArcIdController.text.trim(),
        doctorArcId:
            _selectedDoctor!.arcId ?? _doctorArcIdController.text.trim(),
        nurseId: _selectedNurse!.uid ?? '',
        ward: _selectedWard,
        shift: _selectedShift,
        assignmentDate: _selectedDate.toIso8601String(),
        assignmentTime: _selectedTime.format(context),
        notes: '', // TODO: Add notes field to the form
      );

      if (result != null) {
        _showSuccessSnackBar('Assignment created successfully!');
        _resetForm();
      } else {
        _showErrorSnackBar('Failed to create assignment. Please try again.');
      }
    } catch (e) {
      print('Error creating assignment: $e');
      _showErrorSnackBar('Error creating assignment: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _resetForm() {
    _patientArcIdController.clear();
    _doctorArcIdController.clear();
    setState(() {
      _selectedPatient = null;
      _selectedDoctor = null;
      _selectedNurse = null;
      _selectedWard = 'General Ward';
      _selectedShift = 'Morning (6 AM - 2 PM)';
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Patient Assignment',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.purple[600],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple[600]!, Colors.purple[700]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.assignment_turned_in,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Create Patient Assignment',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Assign patients to doctors and nurses for specific wards and shifts',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Patient Search Section
              _buildSearchSection(
                title: 'Patient Information',
                icon: Icons.person,
                controller: _patientArcIdController,
                hintText: 'Enter Patient ARC ID (min 3 characters)',
                onSearch: _searchPatient,
                isLoading: _isSearchingPatient,
                selectedUser: _selectedPatient,
                onClear: () {
                  setState(() {
                    _selectedPatient = null;
                  });
                  _patientArcIdController.clear();
                },
              ),

              const SizedBox(height: 20),

              // Doctor Search Section
              _buildSearchSection(
                title: 'Doctor Information',
                icon: Icons.medical_services,
                controller: _doctorArcIdController,
                hintText: 'Enter Doctor ARC ID (min 3 characters)',
                onSearch: _searchDoctor,
                isLoading: _isSearchingDoctor,
                selectedUser: _selectedDoctor,
                onClear: () {
                  setState(() {
                    _selectedDoctor = null;
                  });
                  _doctorArcIdController.clear();
                },
              ),

              const SizedBox(height: 20),

              // Ward Selection
              _buildDropdownSection(
                title: 'Ward',
                icon: Icons.location_on,
                value: _selectedWard,
                items: _wards,
                onChanged: (value) {
                  setState(() {
                    _selectedWard = value!;
                  });
                },
                helperText: 'Select the ward where patient will be assigned',
              ),

              const SizedBox(height: 20),

              // Shift Selection
              _buildDropdownSection(
                title: 'Shift',
                icon: Icons.access_time,
                value: _selectedShift,
                items: _shifts,
                onChanged: (value) {
                  setState(() {
                    _selectedShift = value!;
                  });
                },
                helperText: 'Select the shift for patient assignment',
              ),

              const SizedBox(height: 20),

              // Date and Time Selection
              Row(
                children: [
                  Expanded(
                    child: _buildDateTimeSection(
                      title: 'Date',
                      icon: Icons.calendar_today,
                      value:
                          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      onTap: _selectDate,
                      helperText: 'Select assignment date',
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildDateTimeSection(
                      title: 'Time',
                      icon: Icons.schedule,
                      value: _selectedTime.format(context),
                      onTap: _selectTime,
                      helperText: 'Select assignment time',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Nurse Selection
              _buildNurseSelection(),

              const SizedBox(height: 30),

              // Create Assignment Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createAssignment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 3,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_turned_in, size: 24),
                            const SizedBox(width: 12),
                            Text(
                              'Create Assignment',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSection({
    required String title,
    required IconData icon,
    required TextEditingController controller,
    required String hintText,
    required VoidCallback onSearch,
    required bool isLoading,
    UserModel? selectedUser,
    required VoidCallback onClear,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.purple[600], size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: hintText,
                    prefixIcon: Icon(Icons.search, color: Colors.purple[600]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: Colors.purple[600]!, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    helperText: 'Enter at least 3 characters to search',
                    helperMaxLines: 1,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : onSearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.search),
                ),
              ),
            ],
          ),
          if (selectedUser != null) ...[
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedUser.fullName ?? 'Unknown',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[800],
                          ),
                        ),
                        Text(
                          'ARC ID: ${selectedUser.arcId ?? 'N/A'}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.green[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onClear,
                    icon: Icon(Icons.close, color: Colors.green[600]),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDropdownSection({
    required String title,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? helperText,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.purple[600], size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: DropdownButton<String>(
              value: value,
              onChanged: onChanged,
              underline: const SizedBox(),
              isExpanded: true,
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                );
              }).toList(),
            ),
          ),
          if (helperText != null) ...[
            const SizedBox(height: 8),
            Text(
              helperText,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateTimeSection({
    required String title,
    required IconData icon,
    required String value,
    required VoidCallback onTap,
    String? helperText,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.purple[600], size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          InkWell(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ),
          if (helperText != null) ...[
            const SizedBox(height: 8),
            Text(
              helperText,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNurseSelection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_hospital, color: Colors.purple[600], size: 24),
              const SizedBox(width: 12),
              Text(
                'Select Nurse',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (_isLoadingNurses)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_availableNurses.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Text(
                'No nurses available for assignment',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.orange[800],
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: DropdownButton<UserModel>(
                value: _selectedNurse,
                onChanged: (UserModel? nurse) {
                  setState(() {
                    _selectedNurse = nurse;
                  });
                },
                underline: const SizedBox(),
                isExpanded: true,
                hint: Text(
                  'Select a nurse',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                items: _availableNurses.map((UserModel nurse) {
                  return DropdownMenuItem<UserModel>(
                    value: nurse,
                    child: Text(
                      nurse.fullName ?? 'Unknown Nurse',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
