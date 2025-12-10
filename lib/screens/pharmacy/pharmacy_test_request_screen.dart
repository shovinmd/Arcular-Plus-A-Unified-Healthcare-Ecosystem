import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

class PharmacyTestRequestScreen extends StatefulWidget {
  const PharmacyTestRequestScreen({super.key});

  @override
  State<PharmacyTestRequestScreen> createState() =>
      _PharmacyTestRequestScreenState();
}

class _PharmacyTestRequestScreenState extends State<PharmacyTestRequestScreen> {
  List<Map<String, dynamic>> _testRequests = [];
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
      // For now, we'll use mock data since we need to implement the API
      // TODO: Replace with actual API call when backend is ready
      await Future.delayed(const Duration(seconds: 1)); // Simulate API call

      setState(() {
        _testRequests = [
          {
            'requestId': 'TR-001',
            'patientName': 'John Doe',
            'patientArcId': 'PAT12345678',
            'testName': 'Blood Test',
            'testType': 'Blood Test',
            'urgency': 'Normal',
            'status': 'Pending',
            'requestedDate': DateTime.now().subtract(const Duration(days: 1)),
            'hospitalName': 'City General Hospital',
            'labName': 'Metropolis Labs',
          },
          {
            'requestId': 'TR-002',
            'patientName': 'Jane Smith',
            'patientArcId': 'PAT87654321',
            'testName': 'X-Ray Chest',
            'testType': 'X-Ray',
            'urgency': 'High',
            'status': 'Admitted',
            'requestedDate': DateTime.now().subtract(const Duration(days: 2)),
            'hospitalName': 'City General Hospital',
            'labName': 'Metropolis Labs',
          },
        ];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showErrorDialog('Failed to load test requests: $e');
    }
  }

  void _filterRequests() {
    setState(() {
      _testRequests = _testRequests.where((request) {
        final matchesSearch = request['patientName']
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            request['patientArcId']
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            request['testName']
                .toLowerCase()
                .contains(_searchQuery.toLowerCase());

        final matchesFilter = _selectedFilter == 'All' ||
            request['status'].toLowerCase() == _selectedFilter.toLowerCase();

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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not available';
    return '${date.day}/${date.month}/${date.year}';
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
              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
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
            colors: [Color(0xFFFFF8E1), Color(0xFFFFF3C4)],
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
                color: Colors.yellow[50],
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
                          'Search by patient name, ARC ID, or test name...',
                      prefixIcon:
                          const Icon(Icons.search, color: Color(0xFFFFA500)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.yellow[600]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.yellow[600]!, width: 2),
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
                            selectedColor: Colors.yellow[200],
                            checkmarkColor: Colors.yellow[800],
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.yellow[800]
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
                  : _testRequests.isEmpty
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
                          itemCount: _testRequests.length,
                          itemBuilder: (context, index) {
                            final request = _testRequests[index];
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
                                                  request['testName'],
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.grey[800],
                                                  ),
                                                ),
                                                Text(
                                                  'Patient: ${request['patientName']}',
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
                                              request['status'],
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
                                              'ARC ID: ${request['patientArcId']}',
                                              Colors.yellow[600]!,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _buildDetailChip(
                                              Icons.local_hospital,
                                              request['hospitalName'],
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
                                            request['urgency'],
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

  void _showRequestDetails(Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.science, color: Colors.yellow[600], size: 24),
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
              _buildDetailRow('Request ID', request['requestId']),
              _buildDetailRow('Patient Name', request['patientName']),
              _buildDetailRow('ARC ID', request['patientArcId']),
              _buildDetailRow('Test Name', request['testName']),
              _buildDetailRow('Test Type', request['testType']),
              _buildDetailRow('Urgency', request['urgency']),
              _buildDetailRow('Status', request['status']),
              _buildDetailRow('Hospital', request['hospitalName']),
              _buildDetailRow('Lab', request['labName']),
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
