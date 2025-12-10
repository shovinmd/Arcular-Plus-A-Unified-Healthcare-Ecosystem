import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arcular_plus/models/report_model.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/services/storage_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';

class ReportUserScreen extends StatefulWidget {
  const ReportUserScreen({super.key});

  @override
  State<ReportUserScreen> createState() => _ReportUserScreenState();
}

class _ReportUserScreenState extends State<ReportUserScreen> {
  final _auth = FirebaseAuth.instance;
  final _storageService = StorageService();
  List<ReportModel> _reports = [];
  bool _loading = true;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _uploadStatus;
  String? _selectedCategory;
  String _selectedCategoryFilter = 'All';

  // Report categories
  static const List<Map<String, String>> _reportCategories = [
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
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    try {
      setState(() => _loading = true);
      
      final userId = _auth.currentUser?.uid ?? '';
      if (userId.isEmpty) {
        throw Exception('User not authenticated');
      }

      print('🔍 Fetching reports for userId: $userId');
      final reports = await ApiService.getReportsByUser(userId);
      print('✅ Reports fetched successfully: ${reports.length} reports');
      print('📋 Reports data: ${reports.map((r) => '${r.name} (${r.type})').join(', ')}');

      if (mounted) {
      setState(() {
        _reports = reports;
          _loading = false;
      });
      }
    } catch (e) {
      print('❌ Error fetching reports: $e');
      if (mounted) {
      setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load reports: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _pickAndUploadFile() async {
    // Show category selection first
    final category = await _showCategorySelectionDialog();
    if (category == null) return; // User cancelled
    
    _selectedCategory = category;
    
    try {
      print('🔍 Starting file picker with category: $category');
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null) {
        final file = result.files.first;
        final fileName = file.name;
        final fileBytes = file.bytes!;
        final fileExtension = fileName.split('.').last.toLowerCase();
        
        print('🔍 File picked: $fileName');
        print('🔍 File extension: $fileExtension');
        print('🔍 File size: ${fileBytes.length} bytes');
        print('🔍 File MIME type: ${file.extension}');
        
        // Validate file type - only PDF allowed
        if (fileExtension != 'pdf') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please select only PDF files'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // No local size limit — allow large PDFs as requested

        print('✅ File validation passed, starting upload...');
        await _uploadFile(fileName, fileBytes, fileExtension);
      }
    } catch (e) {
      print('❌ Error in file picker: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _showCategorySelectionDialog() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Select PDF Report Type',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose the category for your PDF medical report:',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                ..._reportCategories.map((category) {
                  return ListTile(
                    leading: Text(
                      category['icon']!,
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(
                      category['label']!,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, category['value']),
                  );
                }).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _uploadFile(String fileName, Uint8List fileBytes, String fileExtension) async {
    print('🚀 Starting file upload: $fileName (${fileExtension})');
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadStatus = 'Preparing upload...';
    });

    try {
      final userId = _auth.currentUser?.uid ?? '';
      if (userId.isEmpty) {
        throw Exception('User not authenticated');
      }

      setState(() => _uploadStatus = 'Uploading to Firebase...');

      final mimeType = _getMimeType(fileExtension);
      print('🔍 MIME type for $fileExtension: $mimeType');

      // Upload to Firebase Storage
      final downloadUrl = await _storageService.uploadReport(
        userId: userId,
        userType: 'patient',
        reportType: 'medical_report',
        fileName: fileName,
        fileBytes: fileBytes,
        contentType: mimeType,
        onProgress: (progress) {
          setState(() {
            _uploadProgress = progress;
            _uploadStatus = 'Uploading... ${(progress * 100).toInt()}%';
          });
        },
      );

      if (downloadUrl != null) {
        print('✅ Firebase upload successful: $downloadUrl');
        setState(() => _uploadStatus = 'Saving to database...');

        // Save report info to backend
        final success = await ApiService.saveReportMetadata(
          name: fileName,
          url: downloadUrl,
          userId: userId,
          type: fileExtension,
          description: 'Medical report uploaded by user',
          category: _selectedCategory ?? 'Other',
          fileSize: fileBytes.length,
          mimeType: mimeType,
          uploadedBy: 'Patient', // User uploads show as "Patient"
        );

        if (success) {
          print('✅ Report metadata saved successfully');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$fileName uploaded successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            await _fetchReports(); // Refresh the list
          }
        } else {
          throw Exception('Failed to save report info to database');
        }
      } else {
        throw Exception('Failed to upload file to Firebase');
      }
    } catch (e) {
      print('❌ Upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
          _uploadStatus = null;
        });
      }
    }
  }

  void _openReport(ReportModel report) async {
    try {
      print('🔍 Opening report: ${report.name}');
      print('🔍 Report URL: ${report.url}');
      
      if (report.url.isEmpty) {
        throw Exception('Report URL is empty');
      }
      
      final url = Uri.parse(report.url);
      print('🔍 Parsed URL: $url');
      
      // Check if URL is valid
      if (!url.hasScheme || !url.hasAuthority) {
        throw Exception('Invalid report URL');
      }
      
      final canExternal = await canLaunchUrl(url);
      print('🔍 Can launch externally: $canExternal');

      if (canExternal) {
        final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
        print('🔍 External launch attempted, success: $launched');
        if (!launched) {
          // Fallback to in-app webview
          final fallback = await launchUrl(url, mode: LaunchMode.inAppBrowserView);
          print('🔍 In-app webview launch attempted, success: $fallback');
          if (!fallback) throw Exception('No app available to open this PDF');
        }
    } else {
        // Directly try in-app webview
        final fallback = await launchUrl(url, mode: LaunchMode.inAppBrowserView);
        print('🔍 In-app webview launch attempted (no external), success: $fallback');
        if (!fallback) throw Exception('No app available to open this PDF');
      }
      print('✅ Report opened successfully');
    } catch (e) {
      print('❌ Error opening report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot open report. Please check the file URL.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deleteReport(ReportModel report) async {
    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Delete Report',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${report.name}"? This action cannot be undone.',
            style: GoogleFonts.poppins(
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: Text(
                'Delete',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    print('🗑️ Starting delete for report: ${report.name} (ID: ${report.id})');

    try {
      setState(() => _loading = true);
      
      print('🔍 Calling ApiService.deleteReport...');
      print('🔍 Report ID being sent: ${report.id}');
      print('🔍 Report name: ${report.name}');
      
      final success = await ApiService.deleteReport(report.id);
      print('✅ Delete result: $success');
      
      if (success) {
        print('🎉 Report deleted successfully, refreshing list...');
        // Remove from local list immediately for better UX
        setState(() {
          _reports.removeWhere((r) => r.id == report.id);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${report.name} deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh the list to sync with backend
          await _fetchReports();
        }
      } else {
        print('❌ Delete failed - success was false');
        throw Exception('Failed to delete report');
      }
    } catch (e) {
      print('❌ Delete error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<ReportModel> get _filteredReports {
    if (_selectedCategoryFilter == 'All') {
      return _reports;
    }
    return _reports.where((report) => report.category == _selectedCategoryFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
              colors: [Color(0xFF32CCBC), Color(0xFF2BBBAD)],
            ),
          ),
        ),
        title: Text(
          'My Reports',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF32CCBC), Color(0xFF90F7EC)],
          ),
        ),
        child: SafeArea(
            child: Column(
              children: [
              // Header with upload button
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Medical Reports',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Upload and manage your PDF medical reports',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Upload button with progress
                    if (_isUploading) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _uploadStatus ?? 'Uploading...',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: _uploadProgress,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        onPressed: _pickAndUploadFile,
                        icon: const Icon(Icons.upload_file),
                        label: Text(
                          'Upload Report',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF2BBBAD),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Reports List
                Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                  child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF32CCBC),
                            ),
                          )
                      : _reports.isEmpty
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
                                      'No reports found',
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Upload your first medical report to get started',
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
                                  // Category Filter Tabs
                                  Container(
                                    height: 50,
                                    margin: const EdgeInsets.only(bottom: 20),
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _reportCategories.length + 1, // +1 for "All"
                              itemBuilder: (context, index) {
                                        if (index == 0) {
                                          // "All" tab
                                          return _buildCategoryTab('All', '📋', index == 0);
                                        }
                                        final category = _reportCategories[index - 1];
                                        return _buildCategoryTab(
                                          category['value']!,
                                          category['icon']!,
                                          _selectedCategoryFilter == category['value']
                                        );
                                      },
                                    ),
                                  ),
                                  // Reports count
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Reports (${_filteredReports.length})',
                                          style: GoogleFonts.poppins(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[800],
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
                                                color: const Color(0xFF2BBBAD),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // Reports list
                                  Expanded(
                                    child: _filteredReports.isEmpty
                                        ? Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.filter_list,
                                                  size: 48,
                                                  color: Colors.grey[400],
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  'No reports in this category',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Try selecting a different category',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 14,
                                                    color: Colors.grey[500],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : ListView.builder(
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getFileTypeIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return '📄';
      case 'doc':
      case 'docx':
      case 'docm':
        return '📝';
      default:
        return '📎';
    }
  }

  Color _getFileTypeColor(String extension) {
    // Only PDF is allowed, so always return red
    return Colors.red;
  }

  IconData _getFileTypeIconData(String extension) {
    // Only PDF is allowed, so always return PDF icon
    return Icons.picture_as_pdf;
  }

  String _getMimeType(String extension) {
    // Only PDF is allowed
    return 'application/pdf';
  }

  // Utils
  String _formatBytes(int bytes, [int decimals = 2]) {
    if (bytes == 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (math.log(bytes) / math.log(k)).floor();
    final value = (bytes / math.pow(k, i)).toStringAsFixed(decimals);
    return '$value ${sizes[i]}';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat.yMMMd().format(date);
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes == 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (math.log(bytes) / math.log(k)).floor();
    final value = (bytes / math.pow(k, i)).toStringAsFixed(2);
    return '$value ${sizes[i]}';
  }

  Widget _buildCategoryTab(String category, String icon, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCategoryFilter = category;
          });
        },
        borderRadius: BorderRadius.circular(25),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF32CCBC), Color(0xFF2BBBAD)],
                  )
                : null,
            color: isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(25),
            border: isSelected
                ? null
                : Border.all(color: const Color(0xFF32CCBC), width: 1),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF2BBBAD).withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                icon,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 8),
              Text(
                category,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF2BBBAD),
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
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
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
              colors: [Color(0xFF32CCBC), Color(0xFF90F7EC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF32CCBC).withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF32CCBC).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    report.category ?? 'Unknown',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF32CCBC),
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
                    Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      'Created: ${_formatDate(report.createdAt)}',
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
                      'By: ${report.uploadedBy ?? 'Patient'}',
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
                    Icon(Icons.insert_drive_file, size: 12, color: Colors.grey[500]),
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: () => _openReport(report),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(
                'Open',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF32CCBC),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _deleteReport(report),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete Report',
            ),
          ],
        ),
      ),
    );
  }
}
