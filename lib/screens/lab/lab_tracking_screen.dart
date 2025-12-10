import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class LabTrackingScreen extends StatefulWidget {
  const LabTrackingScreen({super.key});

  @override
  State<LabTrackingScreen> createState() => _LabTrackingScreenState();
}

class _LabTrackingScreenState extends State<LabTrackingScreen> {
  final TextEditingController _arcIdController = TextEditingController();
  List<Map<String, dynamic>> _uploadedReports = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedStatusFilter = 'All';

  final List<Map<String, String>> _statusFilters = [
    {'value': 'All', 'label': 'All Reports', 'icon': '📋'},
    {'value': 'completed', 'label': 'Completed', 'icon': '✅'},
    {'value': 'pending', 'label': 'Pending', 'icon': '⏳'},
    {'value': 'in_progress', 'label': 'In Progress', 'icon': '🔄'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUploadedReports();
  }

  @override
  void dispose() {
    _arcIdController.dispose();
    super.dispose();
  }

  Future<void> _loadUploadedReports() async {
    setState(() => _isLoading = true);

    try {
      // For now, we'll simulate loading reports
      // In a real implementation, you'd fetch reports uploaded by this lab
      await Future.delayed(const Duration(seconds: 1));

      // TODO: Implement API call to fetch reports uploaded by this lab
      // final reports = await ApiService.getLabReportsByLabId(labId);

      setState(() {
        _uploadedReports = []; // Empty for now
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading uploaded reports: $e');
      setState(() => _isLoading = false);
      _showSnackBar('Error loading reports: $e', Colors.red);
    }
  }

  Future<void> _searchReportsByArcId() async {
    final arcId = _arcIdController.text.trim();
    if (arcId.isEmpty) {
      _showSnackBar('Please enter patient ARC ID', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Fetch lab reports by patient ARC ID
      final labReportsData = await ApiService.getLabReportsByArcId(arcId);

      print(
          '🔬 Lab dashboard fetched reports: ${labReportsData.length} reports');
      if (labReportsData.isNotEmpty) {
        print('🔬 Sample report data: ${labReportsData.first}');
      }

      setState(() {
        _uploadedReports = labReportsData;
        _isLoading = false;
      });

      if (labReportsData.isEmpty) {
        _showSnackBar('No reports found for ARC ID: $arcId', Colors.orange);
      } else {
        _showSnackBar('Found ${labReportsData.length} reports', Colors.green);
      }
    } catch (e) {
      print('❌ Error fetching reports: $e');
      setState(() => _isLoading = false);
      _showSnackBar('Error fetching reports: $e', Colors.red);
    }
  }

  List<Map<String, dynamic>> get _filteredReports {
    var filtered = _uploadedReports;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((report) {
        final testName = (report['testName'] ?? '').toLowerCase();
        final patientName = (report['patientName'] ?? '').toLowerCase();
        final notes = (report['notes'] ?? '').toLowerCase();
        final query = _searchQuery.toLowerCase();

        return testName.contains(query) ||
            patientName.contains(query) ||
            notes.contains(query);
      }).toList();
    }

    // Apply status filter
    if (_selectedStatusFilter != 'All') {
      filtered = filtered.where((report) {
        final status = report['status'] ?? 'pending';
        return status == _selectedStatusFilter;
      }).toList();
    }

    return filtered;
  }

  Future<void> _openReport(Map<String, dynamic> report) async {
    try {
      print('🔍 Opening report: ${report['testName']}');
      print('🔍 Report URL: ${report['reportUrl']}');

      final reportUrl = report['reportUrl'] ?? '';
      if (reportUrl.isEmpty) {
        throw Exception('Report URL is empty');
      }

      final Uri url = Uri.parse(reportUrl);

      if (await canLaunchUrl(url)) {
        print('✅ Can launch URL, opening in external app');
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        print('⚠️ Cannot launch URL externally, trying in-app webview');
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      print('❌ Error opening report: $e');
      _showSnackBar('Could not open report: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown date';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return 'Invalid date';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'pending':
        return Icons.schedule;
      case 'in_progress':
        return Icons.hourglass_empty;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF10B981), Color(0xFF059669)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'Lab Dashboard',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: _loadUploadedReports,
                    ),
                  ],
                ),
              ),

              // Search Section
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Track Patient Reports',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[800],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _arcIdController,
                      decoration: InputDecoration(
                        labelText: 'Patient ARC ID',
                        hintText: 'Enter patient ARC ID to track reports',
                        prefixIcon:
                            const Icon(Icons.qr_code, color: Colors.green),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: Colors.green.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.green, width: 2),
                        ),
                      ),
                      onSubmitted: (_) => _searchReportsByArcId(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _searchReportsByArcId,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Track Reports',
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

              // Status Filter Section
              if (_uploadedReports.isNotEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
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
                      Text(
                        'Filter by Status',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[800],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _statusFilters.map((filter) {
                            final isSelected =
                                _selectedStatusFilter == filter['value'];
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(
                                  filter['label']!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.green[700],
                                  ),
                                ),
                                avatar: Text(
                                  filter['icon']!,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedStatusFilter = filter['value']!;
                                  });
                                },
                                backgroundColor: Colors.green[50],
                                selectedColor: Colors.green[600],
                                checkmarkColor: Colors.white,
                                side: BorderSide(
                                  color: isSelected
                                      ? Colors.green[600]!
                                      : Colors.green[200]!,
                                  width: 1,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

              // Reports List
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _uploadedReports.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.upload_file,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No Reports Tracked Yet',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Search for a patient ARC ID to track their reports',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                // Reports Count
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${_filteredReports.length} reports tracked',
                                        style: GoogleFonts.poppins(
                                          color: Colors.green[800],
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Reports List
                                Expanded(
                                  child: ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 16),
                                    itemCount: _filteredReports.length,
                                    itemBuilder: (context, index) {
                                      final report = _filteredReports[index];
                                      return _buildReportCard(report);
                                    },
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

  Widget _buildReportCard(Map<String, dynamic> report) {
    final status = report['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [statusColor, statusColor.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            statusIcon,
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Text(
          report['testName'] ?? 'Lab Report',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.green[800],
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: GoogleFonts.poppins(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    report['testName'] ?? 'Unknown',
                    style: GoogleFonts.poppins(
                      color: Colors.green[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      'Patient: ${report['patientName'] ?? 'Unknown'}',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today,
                        size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      'Date: ${_formatDate(report['uploadDate'])}',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        trailing: report['reportUrl'] != null && report['reportUrl'].isNotEmpty
            ? IconButton(
                onPressed: () => _openReport(report),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [statusColor, statusColor.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.visibility,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              )
            : Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.block,
                  color: Colors.grey,
                  size: 20,
                ),
              ),
      ),
    );
  }
}
