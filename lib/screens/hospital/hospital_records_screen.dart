import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/utils/constants.dart';
import 'package:intl/intl.dart';

class HospitalRecordsScreen extends StatefulWidget {
  const HospitalRecordsScreen({super.key});

  @override
  State<HospitalRecordsScreen> createState() => _HospitalRecordsScreenState();
}

class _HospitalRecordsScreenState extends State<HospitalRecordsScreen> {
  bool _loading = true;
  List<dynamic> _records = [];
  String _searchQuery = '';
  String _selectedStatus = 'all';
  int _currentPage = 1;
  int _totalPages = 1;
  Map<String, dynamic>? _stats;

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRecords();
    _loadStats();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    try {
      setState(() => _loading = true);

      final records = await ApiService.getHospitalRecords(
        page: _currentPage,
        limit: 10,
        search: _searchQuery,
        status: _selectedStatus,
      );

      if (mounted) {
        setState(() {
          _records = records;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading records: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadStats() async {
    try {
      final stats = await ApiService.getHospitalRecordsStats();
      if (mounted) {
        setState(() {
          _stats = stats;
        });
      }
    } catch (e) {
      print('Error loading stats: $e');
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _currentPage = 1;
    });
    _loadRecords();
  }

  void _onStatusChanged(String status) {
    setState(() {
      _selectedStatus = status;
      _currentPage = 1;
    });
    _loadRecords();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Text(
          'Hospital Records',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [kHospitalGreen, Color(0xFF2E7D32)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateRecordDialog,
            tooltip: 'Add New Record',
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Cards
          if (_stats != null) _buildStatsCards(),

          // Search and Filter
          _buildSearchAndFilter(),

          // Records List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                    ? _buildEmptyState()
                    : _buildRecordsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Records',
              '${_stats!['totalRecords'] ?? 0}',
              Icons.folder,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Today',
              '${_stats!['todayRecords'] ?? 0}',
              Icons.today,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Active',
              '${_stats!['activeRecords'] ?? 0}',
              Icons.assignment,
              Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: kPrimaryText,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: kSecondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search by patient name, ARC ID, or diagnosis...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
          ),
          const SizedBox(height: 12),
          // Status Filter
          Row(
            children: [
              Text(
                'Status: ',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  color: kPrimaryText,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusChip('all', 'All'),
                      const SizedBox(width: 8),
                      _buildStatusChip('active', 'Active'),
                      const SizedBox(width: 8),
                      _buildStatusChip('completed', 'Completed'),
                      const SizedBox(width: 8),
                      _buildStatusChip('cancelled', 'Cancelled'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, String label) {
    final isSelected = _selectedStatus == status;
    return GestureDetector(
      onTap: () => _onStatusChanged(status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? kHospitalGreen : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: isSelected ? Colors.white : kSecondaryText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildRecordsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _records.length,
      itemBuilder: (context, index) {
        final record = _records[index];
        return _buildRecordCard(record);
      },
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    final visitDate = DateTime.parse(record['visitDate']);
    final status = record['status'] ?? 'active';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    record['patientName'] ?? 'Unknown Patient',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: kPrimaryText,
                    ),
                  ),
                ),
                _buildStatusBadge(status),
              ],
            ),
            const SizedBox(height: 8),

            // Patient Info
            Row(
              children: [
                Icon(Icons.badge, size: 16, color: kSecondaryText),
                const SizedBox(width: 4),
                Text(
                  'ARC ID: ${record['patientArcId'] ?? 'N/A'}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: kSecondaryText,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.calendar_today, size: 16, color: kSecondaryText),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM dd, yyyy').format(visitDate),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: kSecondaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Chief Complaint
            if (record['chiefComplaint'] != null) ...[
              Text(
                'Chief Complaint:',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: kPrimaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                record['chiefComplaint'],
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: kSecondaryText,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
            ],

            // Diagnosis
            if (record['diagnosis'] != null) ...[
              Text(
                'Diagnosis:',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: kPrimaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                record['diagnosis'],
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: kSecondaryText,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'active':
        color = Colors.orange;
        break;
      case 'completed':
        color = Colors.green;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No Records Found',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: kPrimaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start by adding a new patient record',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: kSecondaryText,
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateRecordDialog() {
    showDialog(
      context: context,
      builder: (context) => const CreateRecordDialog(),
    ).then((_) {
      _loadRecords();
      _loadStats();
    });
  }
}

class CreateRecordDialog extends StatefulWidget {
  const CreateRecordDialog({super.key});

  @override
  State<CreateRecordDialog> createState() => _CreateRecordDialogState();
}

class _CreateRecordDialogState extends State<CreateRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _arcIdController = TextEditingController();
  final _chiefComplaintController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _treatmentController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedVisitType = 'appointment';
  String _selectedStatus = 'active';
  bool _followUpRequired = false;
  DateTime? _followUpDate;
  Map<String, dynamic>? _patientData;
  bool _loading = false;

  @override
  void dispose() {
    _arcIdController.dispose();
    _chiefComplaintController.dispose();
    _diagnosisController.dispose();
    _treatmentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _lookupPatient() async {
    if (_arcIdController.text.isEmpty) return;

    setState(() => _loading = true);
    try {
      final patient =
          await ApiService.getPatientByArcId(_arcIdController.text.trim());
      if (mounted) {
        setState(() {
          _patientData = patient;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Patient not found: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createRecord() async {
    if (!_formKey.currentState!.validate()) return;
    if (_patientData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please lookup patient first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final recordData = {
        'patientArcId': _arcIdController.text.trim(),
        'visitType': _selectedVisitType,
        'chiefComplaint': _chiefComplaintController.text.trim(),
        'diagnosis': _diagnosisController.text.trim(),
        'treatment': _treatmentController.text.trim(),
        'notes': _notesController.text.trim(),
        'followUpRequired': _followUpRequired,
        if (_followUpDate != null)
          'followUpDate': _followUpDate!.toIso8601String(),
      };

      await ApiService.createHospitalRecord(recordData);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Record created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating record: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [kHospitalGreen, Color(0xFF2E7D32)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_circle, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Create New Record',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ARC ID Lookup
                      Text(
                        'Patient ARC ID',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                          color: kPrimaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _arcIdController,
                              decoration: InputDecoration(
                                hintText: 'Enter patient ARC ID',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter ARC ID';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _lookupPatient,
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text('Lookup'),
                          ),
                        ],
                      ),

                      // Patient Info Display
                      if (_patientData != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Patient Found:',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green[800],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_patientData!['fullName']} (${_patientData!['email']})',
                                style: GoogleFonts.poppins(
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Visit Type
                      Text(
                        'Visit Type',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                          color: kPrimaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedVisitType,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items:
                            ['appointment', 'emergency', 'walk-in', 'follow-up']
                                .map((type) => DropdownMenuItem(
                                      value: type,
                                      child: Text(type.toUpperCase()),
                                    ))
                                .toList(),
                        onChanged: (value) {
                          setState(() => _selectedVisitType = value!);
                        },
                      ),

                      const SizedBox(height: 16),

                      // Chief Complaint
                      Text(
                        'Chief Complaint *',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                          color: kPrimaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _chiefComplaintController,
                        decoration: InputDecoration(
                          hintText: 'Enter chief complaint',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        maxLines: 2,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter chief complaint';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Diagnosis
                      Text(
                        'Diagnosis',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                          color: kPrimaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _diagnosisController,
                        decoration: InputDecoration(
                          hintText: 'Enter diagnosis',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        maxLines: 2,
                      ),

                      const SizedBox(height: 16),

                      // Treatment
                      Text(
                        'Treatment',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                          color: kPrimaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _treatmentController,
                        decoration: InputDecoration(
                          hintText: 'Enter treatment details',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        maxLines: 2,
                      ),

                      const SizedBox(height: 16),

                      // Notes
                      Text(
                        'Notes',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                          color: kPrimaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _notesController,
                        decoration: InputDecoration(
                          hintText: 'Additional notes',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        maxLines: 3,
                      ),

                      const SizedBox(height: 16),

                      // Follow-up
                      Row(
                        children: [
                          Checkbox(
                            value: _followUpRequired,
                            onChanged: (value) {
                              setState(() => _followUpRequired = value!);
                            },
                          ),
                          Text(
                            'Follow-up required',
                            style: GoogleFonts.poppins(
                              color: kPrimaryText,
                            ),
                          ),
                        ],
                      ),

                      if (_followUpRequired) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Follow-up Date',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                            color: kPrimaryText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate:
                                  DateTime.now().add(const Duration(days: 7)),
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              setState(() => _followUpDate = date);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today),
                                const SizedBox(width: 8),
                                Text(
                                  _followUpDate != null
                                      ? DateFormat('MMM dd, yyyy')
                                          .format(_followUpDate!)
                                      : 'Select follow-up date',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _loading ? null : _createRecord,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kHospitalGreen,
                        foregroundColor: Colors.white,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Create Record'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
