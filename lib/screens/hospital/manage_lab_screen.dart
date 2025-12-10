import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

class ManageLabScreen extends StatefulWidget {
  const ManageLabScreen({super.key});

  @override
  State<ManageLabScreen> createState() => _ManageLabScreenState();
}

class _ManageLabScreenState extends State<ManageLabScreen>
    with TickerProviderStateMixin {
  bool _loading = true;
  List<UserModel> _labs = [];
  List<UserModel> _filteredLabs = [];
  List<Map<String, dynamic>> _testRequests = [];
  List<Map<String, dynamic>> _filteredTestRequests = [];
  final _arcIdController = TextEditingController();
  final _searchController = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _arcIdController.dispose();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      if (mounted) {
        setState(() => _loading = true);
      }
      final hospitalMongoId = await ApiService.getHospitalMongoId(
          FirebaseAuth.instance.currentUser!.uid);
      print('🏥 Hospital Mongo ID: $hospitalMongoId');
      if (hospitalMongoId == null) {
        if (mounted) {
          setState(() => _loading = false);
        }
        return;
      }
      // Load labs and test requests in parallel
      print('🏥 Loading affiliated labs...');
      final futures = await Future.wait([
        ApiService.getAffiliatedLabs(hospitalMongoId),
        ApiService.getHospitalTestRequests(hospitalMongoId),
      ]);

      print('🏥 Labs loaded: ${(futures[0] as List<UserModel>).length}');
      print(
          '🏥 Test requests loaded: ${(futures[1] as List<Map<String, dynamic>>).length}');

      if (mounted) {
        setState(() {
          _labs = futures[0] as List<UserModel>;
          _filteredLabs = _labs;
          _testRequests = futures[1] as List<Map<String, dynamic>>;
          _filteredTestRequests = _testRequests;
          _loading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading labs: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load labs: $e')));
      }
    }
  }

  void _filterLabs(String query) {
    if (mounted) {
      setState(() {
        if (query.isEmpty) {
          _filteredLabs = _labs;
        } else {
          _filteredLabs = _labs.where((lab) {
            final displayName = lab.type == 'lab'
                ? (lab.labName ?? lab.fullName)
                : lab.fullName;
            return displayName.toLowerCase().contains(query.toLowerCase()) ||
                (lab.role ?? '').toLowerCase().contains(query.toLowerCase());
          }).toList();
        }
      });
    }
  }

  void _filterTestRequests(String query) {
    if (mounted) {
      setState(() {
        if (query.isEmpty) {
          _filteredTestRequests = _testRequests;
        } else {
          _filteredTestRequests = _testRequests.where((request) {
            return (request['patientName'] ?? '')
                    .toLowerCase()
                    .contains(query.toLowerCase()) ||
                (request['patientArcId'] ?? '')
                    .toLowerCase()
                    .contains(query.toLowerCase()) ||
                (request['testName'] ?? '')
                    .toLowerCase()
                    .contains(query.toLowerCase()) ||
                (request['labName'] ?? '')
                    .toLowerCase()
                    .contains(query.toLowerCase());
          }).toList();
        }
      });
    }
  }

  void _showLabDetails(UserModel lab) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.science, color: Colors.orange[600], size: 24),
            const SizedBox(width: 8),
            Text(
              'Lab Details',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
                'Lab Name',
                lab.type == 'lab'
                    ? (lab.labName ?? lab.fullName)
                    : lab.fullName),
            _buildDetailRow('ARC ID', lab.arcId ?? 'N/A'),
            _buildDetailRow('Role', lab.role ?? 'Laboratory'),
            _buildDetailRow(
                'Specialization', lab.specialization ?? 'General Lab'),
            if (lab.specializations != null && lab.specializations!.isNotEmpty)
              _buildDetailRow(
                  'All Specializations', lab.specializations!.join(', ')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _requestTest(UserModel lab) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _buildTestRequestDialog(lab),
    );

    if (result != null) {
      try {
        final testData = {
          'labId': lab.uid,
          'patientArcId': result['patientId'],
          'testName': result['testName'],
          'testType': result['testType'],
          'testDescription': result['prescription'],
          'urgency': result['urgency'],
          'notes': result['notes'],
          'doctorNotes': result['prescription'],
        };

        await ApiService.createTestRequest(testData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                      'Test request sent to ${lab.type == 'lab' ? (lab.labName ?? lab.fullName) : lab.fullName}'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _load(); // Refresh data
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Failed to send test request: $e'),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _associate() async {
    final arcId = _arcIdController.text.trim();
    if (arcId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter ARC ID')),
      );
      return;
    }

    try {
      print('🏥 Associating lab with ARC ID: $arcId');
      await ApiService.associateLabByArcId(arcId);
      _arcIdController.clear();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Lab associated successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to associate lab: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Lab Management',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.orange[600],
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.science), text: 'Labs'),
            Tab(icon: Icon(Icons.assignment), text: 'Test Requests'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLabsTab(),
          _buildTestRequestsTab(),
        ],
      ),
    );
  }

  Widget _buildLabsTab() {
    return Column(
      children: [
        // Add Lab Section
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange[600]!.withOpacity(0.1),
                Colors.orange[600]!.withOpacity(0.05)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange[600]!.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.person_add, color: Colors.orange[600], size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Add Lab',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: kPrimaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _arcIdController,
                      decoration: InputDecoration(
                        labelText: 'Lab ARC ID (e.g., LAB12345678)',
                        hintText: 'Enter lab\'s ARC ID',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.badge),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _associate,
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Search Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            onChanged: _filterLabs,
            decoration: InputDecoration(
              hintText: 'Search labs by name or role...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Labs List
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filteredLabs.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredLabs.length,
                      itemBuilder: (context, index) {
                        final lab = _filteredLabs[index];
                        return _buildLabCard(lab);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildTestRequestsTab() {
    return Column(
      children: [
        // Search Section
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: _filterTestRequests,
            decoration: InputDecoration(
              hintText: 'Search test requests...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),

        // Test Requests List
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filteredTestRequests.isEmpty
                  ? _buildEmptyTestRequestsState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredTestRequests.length,
                      itemBuilder: (context, index) {
                        final request = _filteredTestRequests[index];
                        return _buildTestRequestCard(request);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.science_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No labs found',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add labs using their ARC ID to get started',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLabCard(UserModel lab) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showLabDetails(lab),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Lab Avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange[600]!.withOpacity(0.8),
                      Colors.orange[600]!
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(
                  Icons.science,
                  color: Colors.white,
                  size: 30,
                ),
              ),

              const SizedBox(width: 16),

              // Lab Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lab.type == 'lab'
                          ? (lab.labName ?? lab.fullName)
                          : lab.fullName,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: kPrimaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lab.role ?? 'Laboratory',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: kSecondaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange[600]!.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.orange[600]!.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.badge,
                                size: 16,
                                color: Colors.orange[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'ARC ID: ${(lab.arcId ?? '').isNotEmpty ? lab.arcId : 'N/A'}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.orange[600],
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

              // Action Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Request Test Button
                  InkWell(
                    onTap: () => _requestTest(lab),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.assignment,
                        color: Colors.orange,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Remove Button
                  InkWell(
                    onTap: () => _removeLabAssociation(lab),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.remove_circle_outline,
                        color: Colors.red,
                        size: 20,
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

  Future<void> _removeLabAssociation(UserModel lab) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove Lab Association',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to remove ${lab.type == 'lab' ? (lab.labName ?? lab.fullName) : lab.fullName} from your hospital?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: kSecondaryText),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Remove',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        // Call API to remove association
        final success = await ApiService.removeLabAssociation(lab.uid);

        // Hide loading indicator
        Navigator.of(context).pop();

        if (success) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Lab association removed successfully',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );

          // Reload the list
          await _load();
        } else {
          throw Exception('Failed to remove lab association');
        }
      } catch (e) {
        // Hide loading indicator if still showing
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to remove lab association: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  Widget _buildEmptyTestRequestsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.science_outlined,
            size: 80,
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
            'Test requests sent to labs will appear here',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTestRequestCard(Map<String, dynamic> request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue[600]!.withOpacity(0.8),
                        Colors.blue[600]!
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Icon(
                    Icons.science,
                    color: Colors.white,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request['testName'] ?? 'Unknown Test',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: kPrimaryText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Patient: ${request['patientName'] ?? 'Unknown'}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: kSecondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getTestRequestStatusColor(request['status'])
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _getTestRequestStatusColor(request['status'])
                            .withOpacity(0.3)),
                  ),
                  child: Text(
                    (request['status'] ?? 'Unknown').toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _getTestRequestStatusColor(request['status']),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Requested: ${_formatTestRequestDate(request['requestedDate'])}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                Icon(Icons.local_hospital, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  request['labName'] ?? 'Unknown Lab',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.badge, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'ARC ID: ${request['patientArcId'] ?? 'Unknown'}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.orange[600],
                  ),
                ),
                const Spacer(),
                Icon(Icons.priority_high, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  request['urgency'] ?? 'Normal',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getTestRequestStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return const Color.fromRGBO(255, 152, 0, 1);
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

  String _formatTestRequestDate(dynamic date) {
    if (date == null) return 'Unknown';
    if (date is DateTime) {
      return DateFormat('MMM dd, yyyy').format(date);
    }
    if (date is String) {
      try {
        final parsedDate = DateTime.parse(date);
        return DateFormat('MMM dd, yyyy').format(parsedDate);
      } catch (e) {
        return 'Invalid Date';
      }
    }
    return 'Unknown';
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: kPrimaryText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(color: kSecondaryText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestRequestDialog(UserModel lab) {
    final patientIdController = TextEditingController();
    final testNameController = TextEditingController();
    final prescriptionController = TextEditingController();
    final notesController = TextEditingController();
    String urgency = 'Normal';
    String testType = 'Blood Test';

    return StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.assignment, color: Colors.orange[600], size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Request Test',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Send test request to ${lab.type == 'lab' ? (lab.labName ?? lab.fullName) : lab.fullName}',
                  style: GoogleFonts.poppins(color: kSecondaryText),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: patientIdController,
                  decoration: InputDecoration(
                    labelText: 'Patient ARC ID *',
                    hintText: 'Enter patient\'s ARC ID',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: testType,
                  decoration: InputDecoration(
                    labelText: 'Test Type *',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.science),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'Blood Test', child: Text('Blood Test')),
                    DropdownMenuItem(
                        value: 'Urine Test', child: Text('Urine Test')),
                    DropdownMenuItem(value: 'X-Ray', child: Text('X-Ray')),
                    DropdownMenuItem(value: 'CT Scan', child: Text('CT Scan')),
                    DropdownMenuItem(value: 'MRI', child: Text('MRI')),
                    DropdownMenuItem(
                        value: 'Ultrasound', child: Text('Ultrasound')),
                    DropdownMenuItem(value: 'ECG', child: Text('ECG')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (value) => setState(() => testType = value!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: testNameController,
                  decoration: InputDecoration(
                    labelText: 'Test Name *',
                    hintText: 'e.g., Complete Blood Count, Chest X-Ray',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.description),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: prescriptionController,
                  decoration: InputDecoration(
                    labelText: 'Prescription Details *',
                    hintText: 'Doctor\'s prescription and instructions',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.description),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: urgency,
                  decoration: InputDecoration(
                    labelText: 'Urgency',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.priority_high),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Low', child: Text('Low')),
                    DropdownMenuItem(value: 'Normal', child: Text('Normal')),
                    DropdownMenuItem(value: 'High', child: Text('High')),
                    DropdownMenuItem(
                        value: 'Emergency', child: Text('Emergency')),
                  ],
                  onChanged: (value) => setState(() => urgency = value!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(
                    labelText: 'Additional Notes',
                    hintText: 'Any additional information',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.note),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (patientIdController.text.isEmpty ||
                  testNameController.text.isEmpty ||
                  prescriptionController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please fill all required fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, {
                'patientId': patientIdController.text,
                'testName': testNameController.text,
                'testType': testType,
                'prescription': prescriptionController.text,
                'urgency': urgency,
                'notes': notesController.text,
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Send Request',
              style: GoogleFonts.poppins(),
            ),
          ),
        ],
      ),
    );
  }
}
