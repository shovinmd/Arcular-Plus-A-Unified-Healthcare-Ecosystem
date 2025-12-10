import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class DoctorReportsScreen extends StatefulWidget {
  const DoctorReportsScreen({super.key});

  @override
  State<DoctorReportsScreen> createState() => _DoctorReportsScreenState();
}

class _DoctorReportsScreenState extends State<DoctorReportsScreen> {
  final TextEditingController _arcIdController = TextEditingController();
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _arcIdController.dispose();
    super.dispose();
  }

  Future<void> _searchReports() async {
    final arcId = _arcIdController.text.trim();
    if (arcId.isEmpty) {
      _showSnackBar('Please enter patient ARC ID', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Fetch lab reports by patient ARC ID
      final labReportsData = await ApiService.getLabReportsByArcId(arcId);

      print('🔬 Doctor fetched lab reports: ${labReportsData.length} reports');
      if (labReportsData.isNotEmpty) {
        print('🔬 Sample report data: ${labReportsData.first}');
      }

      setState(() {
        _reports = labReportsData;
        _isLoading = false;
      });

      if (labReportsData.isEmpty) {
        _showSnackBar('No lab reports found for ARC ID: $arcId', Colors.orange);
      } else {
        _showSnackBar(
            'Found ${labReportsData.length} lab reports', Colors.green);
      }
    } catch (e) {
      print('❌ Error fetching lab reports: $e');
      setState(() => _isLoading = false);
      _showSnackBar('Error fetching reports: $e', Colors.red);
    }
  }

  List<Map<String, dynamic>> get _filteredReports {
    return _reports;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
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
                    colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
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
                        'Patient Lab Reports',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: _searchReports,
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
                      'Search Patient Reports',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.purple[800],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _arcIdController,
                      decoration: InputDecoration(
                        labelText: 'Patient ARC ID',
                        hintText: 'Enter patient ARC ID (e.g., ARC-D7159326)',
                        prefixIcon:
                            const Icon(Icons.qr_code, color: Colors.purple),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: Colors.purple.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.purple, width: 2),
                        ),
                      ),
                      onSubmitted: (_) => _searchReports(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _searchReports,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[600],
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
                                'Search Reports',
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
                      : _reports.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Search for Patient Reports',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Enter a patient ARC ID to view their lab reports',
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
                                        '${_filteredReports.length} reports found',
                                        style: GoogleFonts.poppins(
                                          color: Colors.purple[800],
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.1),
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
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.description,
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Text(
          report['testName'] ?? 'Lab Report',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.purple[800],
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
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    report['testName'] ?? 'Unknown',
                    style: GoogleFonts.poppins(
                      color: Colors.purple[600],
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
                    Icon(Icons.business, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      'Lab: ${report['labName'] ?? 'Lab'}',
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
        trailing: IconButton(
          onPressed: () => _openReport(report),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.open_in_new,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
