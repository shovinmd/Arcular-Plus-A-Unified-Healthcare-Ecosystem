import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/models/user_model.dart';
import 'package:flutter/foundation.dart';

// Green theme colors for lab upload screen
const Color kLabUploadBackground = Color(0xFFF0FDF4);
const Color kLabUploadPrimary = Color(0xFF22C55E);
const Color kLabUploadSecondary = Color(0xFF4ADE80);
const Color kLabUploadAccent = Color(0xFFDCFCE7);
const Color kLabUploadText = Color(0xFF166534);
const Color kLabUploadSecondaryText = Color(0xFF16A34A);
const Color kLabUploadBorder = Color(0xFFBBF7D0);
const Color kLabUploadSuccess = Color(0xFF10B981);
const Color kLabUploadWarning = Color(0xFFF59E0B);
const Color kLabUploadError = Color(0xFFEF4444);

class LabUploadReportScreen extends StatefulWidget {
  const LabUploadReportScreen({super.key});

  @override
  State<LabUploadReportScreen> createState() => _LabUploadReportScreenState();
}

class _LabUploadReportScreenState extends State<LabUploadReportScreen> {
  final TextEditingController _patientArcIdController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  dynamic
      _selectedPdfFile; // Use dynamic to handle both File (mobile) and PlatformFile (web)
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  UserModel? _labUser;
  Map<String, dynamic>? _patientInfo;
  bool _isLoadingPatient = false;
  String _selectedTestType = 'Blood Test';

  final List<String> _testTypes = [
    'Blood Test',
    'X-Ray',
    'MRI',
    'CT Scan',
    'Ultrasound',
    'ECG',
    'Urine Test',
    'Stool Test',
    'Biopsy',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadLabUser();
  }

  @override
  void dispose() {
    _patientArcIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadLabUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final labModel = await ApiService.getUserInfo(user.uid);
      print('🔬 Lab user loaded: ${labModel?.fullName}');
      print('🔬 Lab name: ${labModel?.labName}');
      print('🔬 Lab user type: ${labModel?.type}');

      if (mounted) {
        setState(() {
          _labUser = labModel;
        });
      }
    } catch (e) {
      print('❌ Error loading lab user: $e');
    }
  }

  String _getBestLabName() {
    if (_labUser == null) return 'Lab';

    // Try multiple sources for lab name with better fallback logic
    if (_labUser!.labName != null && _labUser!.labName!.trim().isNotEmpty) {
      print('🔬 Using labName: ${_labUser!.labName}');
      return _labUser!.labName!;
    } else if (_labUser!.fullName.trim().isNotEmpty) {
      print('🔬 Using fullName: ${_labUser!.fullName}');
      return _labUser!.fullName;
    } else if (_labUser!.ownerName != null &&
        _labUser!.ownerName!.trim().isNotEmpty) {
      print('🔬 Using ownerName: ${_labUser!.ownerName}');
      return _labUser!.ownerName!;
    } else {
      print('🔬 Using default: Lab');
      return 'Lab';
    }
  }

  Future<void> _searchPatientByArcId() async {
    final arcId = _patientArcIdController.text.trim();
    if (arcId.isEmpty) {
      _showSnackBar('Please enter patient ARC ID', kLabUploadError);
      return;
    }

    setState(() => _isLoadingPatient = true);

    try {
      // Search for patient by ARC ID
      final patient = await ApiService.getUserByArcId(arcId);

      if (mounted) {
        setState(() {
          _patientInfo = patient;
          _isLoadingPatient = false;
        });

        if (patient != null) {
          _showSnackBar(
              'Patient found: ${patient['fullName']}', kLabUploadSuccess);
        } else {
          _showSnackBar(
              'Patient not found with ARC ID: $arcId', kLabUploadWarning);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPatient = false);
        _showSnackBar('Error searching patient: $e', kLabUploadError);
      }
    }
  }

  Future<void> _pickPdfFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedPdfFile = result.files.first;
        });
        _showSnackBar('PDF file selected', kLabUploadSuccess);
      }
    } catch (e) {
      _showSnackBar('Error picking file: $e', kLabUploadError);
    }
  }

  Future<void> _uploadReport() async {
    if (_selectedPdfFile == null) {
      _showSnackBar('Please select a PDF file', kLabUploadError);
      return;
    }

    final arcId = _patientArcIdController.text.trim();

    if (arcId.isEmpty) {
      _showSnackBar('Please enter patient ARC ID', kLabUploadError);
      return;
    }

    setState(() => _isUploading = true);

    try {
      // Upload PDF to Firebase Storage
      final fileName = '${arcId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final ref = FirebaseStorage.instance.ref().child('lab_reports/$fileName');

      UploadTask uploadTask;

      if (kIsWeb) {
        // Web platform - use bytes
        uploadTask = ref.putData(_selectedPdfFile.bytes!);
      } else {
        // Mobile platform - use file path
        uploadTask = ref.putFile(_selectedPdfFile.path!);
      }

      uploadTask.snapshotEvents.listen((snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Create lab report record in backend
      final reportData = {
        'patientArcId': arcId,
        'patientName': _patientInfo?['fullName'] ?? 'Unknown Patient',
        'labId': _labUser?.uid,
        'labName': _getBestLabName(),
        'testType': _selectedTestType,
        'reportUrl': downloadUrl,
        'fileName': fileName,
        'notes': _notesController.text.trim(),
        'uploadDate': DateTime.now().toIso8601String(),
        'status': 'uploaded',
      };

      final success = await ApiService.createLabReport(reportData);

      if (mounted) {
        setState(() => _isUploading = false);

        if (success) {
          _showSnackBar('Report uploaded successfully!', kLabUploadSuccess);
          _clearForm();
        } else {
          _showSnackBar('Failed to save report data', kLabUploadError);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        _showSnackBar('Upload failed: $e', kLabUploadError);
      }
    }
  }

  void _clearForm() {
    _patientArcIdController.clear();
    _notesController.clear();
    setState(() {
      _selectedPdfFile = null;
      _patientInfo = null;
      _uploadProgress = 0.0;
      _selectedTestType = 'Blood Test';
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLabUploadBackground,
      appBar: AppBar(
        title: Text(
          'Upload Lab Report',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: kLabUploadPrimary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [kLabUploadPrimary, kLabUploadSecondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: kLabUploadPrimary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.upload_file,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Upload Lab Report',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Upload PDF reports for patients using ARC ID',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Patient Search Section
            _buildSectionCard(
              'Patient Information',
              Icons.person_search,
              [
                _buildInputField(
                  'Patient ARC ID',
                  'Enter patient ARC ID',
                  _patientArcIdController,
                  Icons.qr_code,
                  onChanged: (value) {
                    if (value.trim().isNotEmpty) {
                      _searchPatientByArcId();
                    }
                  },
                ),
                const SizedBox(height: 16),
                if (_isLoadingPatient)
                  const Center(
                    child: CircularProgressIndicator(color: kLabUploadPrimary),
                  )
                else if (_patientInfo != null)
                  _buildPatientInfoCard(),
                const SizedBox(height: 16),
                _buildTestTypeDropdown(),
                const SizedBox(height: 16),
                _buildInputField(
                  'Notes (Optional)',
                  'Additional notes about the test',
                  _notesController,
                  Icons.note,
                  maxLines: 3,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // File Upload Section
            _buildSectionCard(
              'Report File',
              Icons.description,
              [
                _buildFileUploadCard(),
              ],
            ),
            const SizedBox(height: 24),

            // Upload Progress
            if (_isUploading) _buildUploadProgress(),
            const SizedBox(height: 24),

            // Upload Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _uploadReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kLabUploadPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: _isUploading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Uploading...',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'Upload Report',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kLabUploadBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: kLabUploadPrimary, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: kLabUploadText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInputField(
    String label,
    String hint,
    TextEditingController controller,
    IconData icon, {
    int maxLines = 1,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: kLabUploadText,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: kLabUploadPrimary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kLabUploadBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kLabUploadPrimary, width: 2),
            ),
            filled: true,
            fillColor: kLabUploadAccent.withOpacity(0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildPatientInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kLabUploadAccent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kLabUploadPrimary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kLabUploadPrimary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.person,
              color: kLabUploadPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _patientInfo!['fullName'] ?? 'Unknown Patient',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: kLabUploadText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ARC ID: ${_patientArcIdController.text}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: kLabUploadSecondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileUploadCard() {
    return GestureDetector(
      onTap: _pickPdfFile,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _selectedPdfFile != null ? kLabUploadAccent : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                _selectedPdfFile != null ? kLabUploadPrimary : kLabUploadBorder,
            width: _selectedPdfFile != null ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              _selectedPdfFile != null
                  ? Icons.check_circle
                  : Icons.cloud_upload,
              color: _selectedPdfFile != null
                  ? kLabUploadSuccess
                  : kLabUploadPrimary,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              _selectedPdfFile != null ? 'PDF Selected' : 'Select PDF File',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: kLabUploadText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _selectedPdfFile != null
                  ? _getFileName()
                  : 'Tap to choose a PDF file',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: kLabUploadSecondaryText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getFileName() {
    if (_selectedPdfFile == null) return '';

    if (kIsWeb) {
      // Web platform - use name property
      return _selectedPdfFile.name;
    } else {
      // Mobile platform - use path
      return _selectedPdfFile.path.split('/').last;
    }
  }

  Widget _buildTestTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kLabUploadBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedTestType,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: kLabUploadPrimary),
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: kLabUploadText,
          ),
          items: _testTypes.map((String testType) {
            return DropdownMenuItem<String>(
              value: testType,
              child: Row(
                children: [
                  Icon(
                    _getTestTypeIcon(testType),
                    color: kLabUploadPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(testType),
                ],
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedTestType = newValue;
              });
            }
          },
        ),
      ),
    );
  }

  IconData _getTestTypeIcon(String testType) {
    switch (testType) {
      case 'Blood Test':
        return Icons.water_drop;
      case 'X-Ray':
        return Icons.camera_alt;
      case 'MRI':
        return Icons.scanner;
      case 'CT Scan':
        return Icons.computer;
      case 'Ultrasound':
        return Icons.waves;
      case 'ECG':
        return Icons.favorite;
      case 'Urine Test':
        return Icons.science;
      case 'Stool Test':
        return Icons.biotech;
      case 'Biopsy':
        return Icons.science;
      default:
        return Icons.description;
    }
  }

  Widget _buildUploadProgress() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kLabUploadBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.upload, color: kLabUploadPrimary),
              const SizedBox(width: 12),
              Text(
                'Uploading Report...',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: kLabUploadText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _uploadProgress,
            backgroundColor: kLabUploadAccent,
            valueColor: const AlwaysStoppedAnimation<Color>(kLabUploadPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            '${(_uploadProgress * 100).toInt()}%',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: kLabUploadSecondaryText,
            ),
          ),
        ],
      ),
    );
  }
}
