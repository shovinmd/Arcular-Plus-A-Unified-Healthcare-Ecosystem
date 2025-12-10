import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

class LabTestRequestScreen extends StatefulWidget {
  const LabTestRequestScreen({super.key});

  @override
  State<LabTestRequestScreen> createState() => _LabTestRequestScreenState();
}

class _LabTestRequestScreenState extends State<LabTestRequestScreen> {
  List<Map<String, dynamic>> _testRequests = [];
  List<Map<String, dynamic>> _filteredTestRequests = [];
  bool _loading = true;
  String _searchQuery = '';
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _filterOptions = [
    'All',
    'Pending',
    'Admitted',
    'Scheduled',
    'Completed',
    'Cancelled'
  ];

  @override
  void initState() {
    super.initState();
    _loadTestRequests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTestRequests() async {
    setState(() => _loading = true);
    try {
      // Get lab's MongoDB ID
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _loading = false);
        return;
      }

      final labMongoId = await ApiService.getLabMongoId(user.uid);
      if (labMongoId == null) {
        setState(() => _loading = false);
        _showErrorDialog('Lab not found');
        return;
      }

      final requests = await ApiService.getLabTestRequests(labMongoId);
      setState(() {
        _testRequests = requests;
        _filteredTestRequests = requests;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showErrorDialog('Failed to load test requests: $e');
    }
  }

  void _filterRequests() {
    setState(() {
      _filteredTestRequests = _testRequests.where((request) {
        final matchesSearch = (request['patientName'] ?? '')
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            (request['patientArcId'] ?? '')
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            (request['testName'] ?? '')
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            (request['hospitalName'] ?? '')
                .toLowerCase()
                .contains(_searchQuery.toLowerCase());

        final matchesFilter = _selectedFilter == 'All' ||
            (request['status'] ?? '').toLowerCase() ==
                _selectedFilter.toLowerCase();

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'admitted':
        return Colors.blue;
      case 'scheduled':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    if (date is DateTime) {
      return '${date.day}/${date.month}/${date.year}';
    }
    if (date is String) {
      try {
        final parsedDate = DateTime.parse(date);
        return '${parsedDate.day}/${parsedDate.month}/${parsedDate.year}';
      } catch (e) {
        return 'Invalid Date';
      }
    }
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Test Requests',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFB923C), Color(0xFFFDBA74)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF7ED), Color(0xFFFFF3E0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Search and Filter Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Column(
                children: [
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                      _filterRequests();
                    },
                    decoration: InputDecoration(
                      hintText:
                          'Search by patient name, ARC ID, test name, or hospital...',
                      prefixIcon:
                          const Icon(Icons.search, color: Color(0xFFFB923C)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.orange[600]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.orange[600]!, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filterOptions.map((filter) {
                        final isSelected = _selectedFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(filter),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() => _selectedFilter = filter);
                              _filterRequests();
                            },
                            backgroundColor: Colors.white,
                            selectedColor: Colors.orange[200],
                            checkmarkColor: Colors.orange[800],
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.orange[800]
                                  : Colors.grey[700],
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            // Test Requests List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredTestRequests.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.science_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No test requests found',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Test requests from hospitals will appear here',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredTestRequests.length,
                          itemBuilder: (context, index) {
                            final request = _filteredTestRequests[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: InkWell(
                                onTap: () => _showRequestDetails(request),
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Header Row
                                      Row(
                                        children: [
                                          // Status Icon
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(
                                                      request['status'])
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: _getStatusColor(
                                                    request['status']),
                                                width: 2,
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.science,
                                              color: _getStatusColor(
                                                  request['status']),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Request Info
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  request['testName'] ??
                                                      'Unknown Test',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.grey[800],
                                                  ),
                                                ),
                                                Text(
                                                  'Patient: ${request['patientName'] ?? 'Unknown'}',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 14,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Status Badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(
                                                      request['status'])
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: _getStatusColor(
                                                    request['status']),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              request['status'] ?? 'Unknown',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: _getStatusColor(
                                                    request['status']),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      // Details Row
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildDetailChip(
                                              Icons.badge,
                                              'ARC ID: ${request['patientArcId'] ?? 'Unknown'}',
                                              Colors.orange[600]!,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _buildDetailChip(
                                              Icons.local_hospital,
                                              request['hospitalName'] ??
                                                  'Unknown Hospital',
                                              Colors.blue[600]!,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // Date Row
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 16,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Requested: ${_formatDate(request['requestedDate'])}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const Spacer(),
                                          Icon(
                                            Icons.priority_high,
                                            size: 16,
                                            color:
                                                request['urgency'] == 'High' ||
                                                        request['urgency'] ==
                                                            'Emergency'
                                                    ? Colors.red
                                                    : Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            request['urgency'] ?? 'Normal',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: request['urgency'] ==
                                                          'High' ||
                                                      request['urgency'] ==
                                                          'Emergency'
                                                  ? Colors.red
                                                  : Colors.grey[600],
                                              fontWeight: request['urgency'] ==
                                                          'High' ||
                                                      request['urgency'] ==
                                                          'Emergency'
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Action Buttons
                                      if (request['status']?.toLowerCase() ==
                                          'pending') ...[
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: () =>
                                                _showAdmitDialog(request),
                                            icon: const Icon(Icons.check_circle,
                                                size: 18),
                                            label: Text(
                                              'Admit Patient',
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.green[600],
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 12),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                      // Complete Button (only for admitted requests)
                                      if (request['status']?.toLowerCase() ==
                                          'admitted') ...[
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: () =>
                                                _showCompleteDialog(request),
                                            icon: const Icon(Icons.task_alt,
                                                size: 18),
                                            label: Text(
                                              'Mark Complete',
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.orange[600],
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 12),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showAdmitDialog(Map<String, dynamic> request) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);
    double billAmount = 0.0;
    List<String> selectedPaymentOptions = ['Cash'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.orange[600], size: 24),
              const SizedBox(width: 8),
              Text(
                'Schedule Lab Visit',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Patient: ${request['patientName'] ?? 'Unknown'}',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),
              // Date Selection
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 20, color: Colors.orange[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Date: ${DateFormat('MMM dd, yyyy').format(selectedDate)}',
                    style: GoogleFonts.poppins(),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (date != null) {
                        setState(() => selectedDate = date);
                      }
                    },
                    child: Text(
                      'Change',
                      style: GoogleFonts.poppins(color: Colors.orange[600]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Time Selection
              Row(
                children: [
                  Icon(Icons.access_time, size: 20, color: Colors.orange[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Time: ${selectedTime.format(context)}',
                    style: GoogleFonts.poppins(),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (time != null) {
                        setState(() => selectedTime = time);
                      }
                    },
                    child: Text(
                      'Change',
                      style: GoogleFonts.poppins(color: Colors.orange[600]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Bill Amount
              Row(
                children: [
                  Icon(Icons.attach_money, size: 20, color: Colors.orange[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Bill Amount:',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Enter amount',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onChanged: (value) {
                        billAmount = double.tryParse(value) ?? 0.0;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Payment Options
              Text(
                'Payment Options:',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  'Cash',
                  'Card',
                  'Insurance',
                  'Online Payment',
                  'Bank Transfer',
                  'UPI',
                  'Wallet',
                ]
                    .map((option) => FilterChip(
                          label: Text(option),
                          selected: selectedPaymentOptions.contains(option),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                selectedPaymentOptions.add(option);
                              } else {
                                selectedPaymentOptions.remove(option);
                              }
                            });
                          },
                          selectedColor: Colors.orange[100],
                          checkmarkColor: Colors.orange[600],
                        ))
                    .toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () => _admitPatient(request, selectedDate,
                  selectedTime, billAmount, selectedPaymentOptions),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Admit Patient',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _admitPatient(Map<String, dynamic> request, DateTime date,
      TimeOfDay time, double billAmount, List<String> paymentOptions) async {
    try {
      Navigator.of(context).pop(); // Close the dialog

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Update test request status to 'Admitted'
      await ApiService.updateTestRequestStatus(
        request['requestId'] ?? '',
        'Admitted',
        scheduledDate: date,
        scheduledTime: time.format(context),
        billAmount: billAmount,
        paymentOptions: paymentOptions,
      );

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('Patient admitted successfully! Email sent to patient.'),
            ],
          ),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Refresh the test requests
      _loadTestRequests();
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      _showErrorDialog('Failed to admit patient: $e');
    }
  }

  void _showCompleteDialog(Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.task_alt, color: Colors.orange[600], size: 24),
            const SizedBox(width: 8),
            Text(
              'Mark Test Complete',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Patient: ${request['patientName'] ?? 'Unknown'}',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Test: ${request['testName'] ?? 'Unknown'}',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Are you sure you want to mark this test as completed? This will notify both the patient and hospital.',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => _completeTest(request),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Mark Complete',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _completeTest(Map<String, dynamic> request) async {
    try {
      Navigator.of(context).pop(); // Close the dialog

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Update test request status to 'Completed'
      await ApiService.updateTestRequestStatus(
        request['requestId'] ?? '',
        'Completed',
      );

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                  'Test marked as completed! Emails sent to patient and hospital.'),
            ],
          ),
          backgroundColor: Colors.orange[600],
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Refresh the test requests
      _loadTestRequests();
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      _showErrorDialog('Failed to complete test: $e');
    }
  }

  void _showRequestDetails(Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.science, color: Colors.orange[600], size: 24),
            const SizedBox(width: 8),
            Text(
              'Test Request Details',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Request ID', request['requestId'] ?? 'Unknown'),
              _buildDetailRow(
                  'Patient Name', request['patientName'] ?? 'Unknown'),
              _buildDetailRow('ARC ID', request['patientArcId'] ?? 'Unknown'),
              _buildDetailRow('Test Name', request['testName'] ?? 'Unknown'),
              _buildDetailRow('Test Type', request['testType'] ?? 'Unknown'),
              _buildDetailRow('Urgency', request['urgency'] ?? 'Normal'),
              _buildDetailRow('Status', request['status'] ?? 'Unknown'),
              _buildDetailRow('Hospital', request['hospitalName'] ?? 'Unknown'),
              _buildDetailRow(
                  'Requested Date', _formatDate(request['requestedDate'])),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(),
            ),
          ),
        ],
      ),
    );
  }
}
