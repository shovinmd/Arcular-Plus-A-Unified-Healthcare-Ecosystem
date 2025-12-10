import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arcular_plus/models/report_model.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LabReportsScreen extends StatefulWidget {
  const LabReportsScreen({super.key});

  @override
  State<LabReportsScreen> createState() => _LabReportsScreenState();
}

class _LabReportsScreenState extends State<LabReportsScreen> {
  List<ReportModel> _reports = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategoryFilter = 'All';

  final List<Map<String, String>> _reportCategories = [
    {'value': 'All', 'label': 'All Reports', 'icon': '📋'},
    {'value': 'Blood Test', 'label': 'Blood Test', 'icon': '🩸'},
    {'value': 'X-Ray', 'label': 'X-Ray', 'icon': '📷'},
    {'value': 'MRI', 'label': 'MRI', 'icon': '🔬'},
    {'value': 'CT Scan', 'label': 'CT Scan', 'icon': '💻'},
    {'value': 'Ultrasound', 'label': 'Ultrasound', 'icon': '🔊'},
    {'value': 'ECG', 'label': 'ECG', 'icon': '❤️'},
    {'value': 'Other', 'label': 'Other', 'icon': '📄'},
  ];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user ARC ID from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final arcId = prefs.getString('user_arc_id');
      final healthQrId = prefs.getString('user_health_qr_id');

      print('🔬 User ARC ID from prefs: $arcId');
      print('🔬 User Health QR ID from prefs: $healthQrId');

      // Try to get ARC ID from user profile if not in prefs
      String? userArcId = arcId ?? healthQrId;

      if (userArcId == null || userArcId.isEmpty) {
        // Try to fetch user info to get ARC ID
        try {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            final userInfo = await ApiService.getUserInfo(currentUser.uid);
            if (userInfo != null) {
              userArcId = userInfo.healthQrId ?? userInfo.arcId;
              print('🔬 User ARC ID from profile: $userArcId');
            }
          }
        } catch (e) {
          print('❌ Error fetching user info: $e');
        }
      }

      if (userArcId == null || userArcId.isEmpty) {
        print('❌ No ARC ID found, falling back to UID method');
        // Fallback to UID method if ARC ID not available
        final userId = prefs.getString('user_uid');
        if (userId == null) {
          throw Exception('User ID not found. Please login again.');
        }
        final reports = await ApiService.getReportsByUser(userId);
        setState(() {
          _reports = reports;
          _isLoading = false;
        });
        return;
      }

      print('🔬 Fetching reports for ARC ID: $userArcId');

      // Fetch reports from BOTH collections
      List<Map<String, dynamic>> allReports = [];

      // 1. Fetch lab reports (uploaded by labs) from labreport collection
      try {
        final labReportsData = await ApiService.getLabReportsByArcId(userArcId);
        print('🔬 Lab reports data received: ${labReportsData.length} reports');
        if (labReportsData.isNotEmpty) {
          print('🔬 Sample lab report data: ${labReportsData.first}');
        }
        allReports.addAll(labReportsData);
      } catch (e) {
        print('❌ Error fetching lab reports: $e');
      }

      // 2. Fetch user uploaded reports from report collection
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          final userReports =
              await ApiService.getReportsByUser(currentUser.uid);
          print('🔬 User reports data received: ${userReports.length} reports');
          if (userReports.isNotEmpty) {
            print('🔬 Sample user report data: ${userReports.first}');
          }
          // Convert ReportModel to Map format for consistency
          final userReportsData = userReports
              .map((report) => {
                    '_id': report.id,
                    'testName': report.name,
                    'reportUrl': report.url,
                    'uploadDate': report.uploadedAt.toIso8601String(),
                    'labName': report.uploadedBy,
                    'category': report.category,
                    'type': 'user_uploaded'
                  })
              .toList();
          allReports.addAll(userReportsData);
        }
      } catch (e) {
        print('❌ Error fetching user reports: $e');
      }

      print('🔬 Total reports found: ${allReports.length}');

      // Convert to ReportModel format
      final reports = allReports.map((data) {
        // Determine uploaded by based on data source
        String uploadedBy;
        if (data['type'] == 'user_uploaded') {
          uploadedBy = data['uploadedBy'] ?? 'Patient';
        } else {
          // For lab reports, try to get lab name from populated data
          if (data['labId'] != null && data['labId'] is Map) {
            uploadedBy = data['labId']['fullName'] ??
                data['labId']['labName'] ??
                data['labName'] ??
                'Lab';
          } else {
            uploadedBy = data['labName'] ?? 'Lab';
          }
        }

        return ReportModel(
          id: data['_id'] ?? data['id'] ?? '',
          name: data['testName'] ?? 'Lab Report',
          url: data['reportUrl'] ?? '',
          type: 'pdf',
          uploadedAt: data['uploadDate'] != null
              ? DateTime.parse(data['uploadDate'])
              : DateTime.now(),
          category: data['testName'] ?? data['category'] ?? 'Other',
          uploadedBy: uploadedBy,
        );
      }).toList();

      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading reports: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load reports: $e')),
      );
    }
  }

  List<ReportModel> get _filteredReports {
    List<ReportModel> filtered = _reports;

    // Filter by category
    if (_selectedCategoryFilter != 'All') {
      filtered = filtered
          .where((report) => report.category == _selectedCategoryFilter)
          .toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((report) =>
              report.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (report.category ?? '')
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()))
          .toList();
    }

    return filtered;
  }

  Future<void> _openReport(ReportModel report) async {
    try {
      print('🔍 Opening report: ${report.name}');
      print('🔍 Report URL: ${report.url}');

      if (report.url.isEmpty) {
        throw Exception('Report URL is empty');
      }

      final Uri url = Uri.parse(report.url);

      if (await canLaunchUrl(url)) {
        print('✅ Can launch URL, opening in external app');
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        print('⚠️ Cannot launch URL externally, trying in-app webview');
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      print('❌ Error opening report: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open report: $e')),
      );
    }
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes == 0) return 'PDF Document';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Recent';
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildCategoryTab(String value, String label, String icon) {
    final isSelected = _selectedCategoryFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategoryFilter = value;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
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
                        'Lab Reports',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: _loadReports,
                    ),
                  ],
                ),
              ),

              // Search Bar
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search reports...',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),

              // Category Tabs
              Container(
                height: 50,
                margin: const EdgeInsets.only(bottom: 16),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _reportCategories
                      .map((category) => _buildCategoryTab(category['value']!,
                          category['label']!, category['icon']!))
                      .toList(),
                ),
              ),

              // Reports Count
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_filteredReports.length} reports found',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_selectedCategoryFilter != 'All')
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedCategoryFilter = 'All';
                          });
                        },
                        child: Text(
                          'Clear Filter',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Reports List
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
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
                      : _filteredReports.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.description_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isNotEmpty ||
                                            _selectedCategoryFilter != 'All'
                                        ? 'No reports match your search'
                                        : 'No lab reports available',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Lab reports will appear here when uploaded by service providers',
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
                              itemCount: _filteredReports.length,
                              itemBuilder: (context, index) {
                                final report = _filteredReports[index];
                                return _buildReportCard(report);
                              },
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard(ReportModel report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        minVerticalPadding: 0,
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
          report.name,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
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
                    color: const Color(0xFF8B5CF6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    report.category ?? 'Unknown',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF8B5CF6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Compact info display to save space
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today,
                        size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      'Created: ${_formatDate(report.uploadedAt)}',
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
                    Icon(Icons.person, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      'By: ${report.uploadedBy ?? 'Lab Provider'}',
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
                    Icon(Icons.insert_drive_file,
                        size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      'PDF • ${_formatFileSize(report.fileSize)}',
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
