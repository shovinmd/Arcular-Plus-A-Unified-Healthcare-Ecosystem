import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arcular_plus/models/user_model.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/screens/hospital/patient_assignment_screen.dart';
// import 'package:arcular_plus/constants/colors.dart';

class NurseManagementScreen extends StatefulWidget {
  final String hospitalId;
  final String hospitalName;

  const NurseManagementScreen({
    Key? key,
    required this.hospitalId,
    required this.hospitalName,
  }) : super(key: key);

  @override
  State<NurseManagementScreen> createState() => _NurseManagementScreenState();
}

class _NurseManagementScreenState extends State<NurseManagementScreen>
    with TickerProviderStateMixin {
  List<UserModel> _nurses = [];
  List<UserModel> _filteredNurses = [];
  bool _loading = true;
  String _searchQuery = '';
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nurseArcIdController = TextEditingController();
  late TabController _tabController;

  final List<String> _filterOptions = ['All', 'Active', 'Inactive', 'Pending'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadNurses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nurseArcIdController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNurses() async {
    setState(() => _loading = true);
    try {
      print('🔄 Loading nurses for hospital UID: ${widget.hospitalId}');

      // Get the hospital's MongoDB ID from Firebase UID
      final hospitalMongoId =
          await ApiService.getHospitalMongoId(widget.hospitalId);
      print('🏥 Hospital MongoDB ID: $hospitalMongoId');

      if (hospitalMongoId == null) {
        setState(() => _loading = false);
        _showErrorDialog('Hospital not found');
        return;
      }

      final nurses = await ApiService.getHospitalNurses(hospitalMongoId);
      print('👥 Loaded ${nurses.length} nurses');

      setState(() {
        _nurses = nurses;
        _filteredNurses = nurses;
        _loading = false;
      });
    } catch (e) {
      print('❌ Error loading nurses: $e');
      setState(() => _loading = false);
      _showErrorDialog('Failed to load nurses: $e');
    }
  }

  void _filterNurses() {
    setState(() {
      _filteredNurses = _nurses.where((nurse) {
        final matchesSearch = nurse.fullName
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            nurse.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (nurse.qualification
                    ?.toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ??
                false);

        final matchesFilter = _selectedFilter == 'All' ||
            (_selectedFilter == 'Active' && (nurse.isApproved ?? false)) ||
            (_selectedFilter == 'Inactive' && !(nurse.isApproved ?? false)) ||
            (_selectedFilter == 'Pending' &&
                (nurse.approvalStatus == 'pending'));

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _filterNurses();
  }

  void _onFilterChanged(String? filter) {
    setState(() {
      _selectedFilter = filter ?? 'All';
    });
    _filterNurses();
  }

  Future<void> _associateNurse() async {
    final arcId = _nurseArcIdController.text.trim();
    if (arcId.isEmpty) {
      _showErrorDialog('Please enter nurse ARC ID');
      return;
    }

    try {
      print('🔄 Associating nurse with ARC ID: $arcId');
      final success = await ApiService.associateNurseByArcId(arcId);
      print('✅ Association result: $success');

      if (success) {
        _nurseArcIdController.clear();
        await _loadNurses();
        _showSuccessDialog('Nurse associated successfully!');
      } else {
        _showErrorDialog('Failed to associate nurse. Please try again.');
      }
    } catch (e) {
      print('❌ Error associating nurse: $e');
      _showErrorDialog('Failed to associate nurse: $e');
    }
  }

  void _showNurseDetails(UserModel nurse) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.purple[100],
              child: Text(
                nurse.fullName.split(' ').map((n) => n[0]).join(''),
                style: TextStyle(
                  color: Colors.purple[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                nurse.fullName,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Email', nurse.email),
              _buildDetailRow('Phone', nurse.mobileNumber ?? 'Not provided'),
              _buildDetailRow(
                  'Qualification', nurse.qualification ?? 'Not specified'),
              _buildDetailRow(
                  'Experience', '${nurse.experienceYears ?? 0} years'),
              _buildDetailRow('License', nurse.licenseNumber ?? 'Not provided'),
              _buildDetailRow('Status', _getStatusText(nurse)),
              _buildDetailRow('Joined', _formatDate(nurse.createdAt)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
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

  String _getStatusText(UserModel nurse) {
    if (nurse.isApproved == true) return 'Active';
    if (nurse.approvalStatus == 'pending') return 'Pending';
    return 'Inactive';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not available';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _deleteNurse(UserModel nurse) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Nurse Association'),
        content: Text(
            'Are you sure you want to remove ${nurse.fullName} from this hospital?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _confirmDeleteNurse(nurse),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteNurse(UserModel nurse) async {
    Navigator.of(context).pop(); // Close confirmation dialog

    try {
      final success = await ApiService.removeNurseAssociation(nurse.uid);

      if (success) {
        _showSuccessDialog('Nurse association removed successfully');
        _loadNurses(); // Refresh the list
      } else {
        _showErrorDialog(
            'Failed to remove nurse association. Please try again.');
      }
    } catch (e) {
      _showErrorDialog('Failed to remove nurse association: $e');
    }
  }

  void _showSuccessDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[600],
      ),
    );
  }

  void _showErrorDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
      ),
    );
  }

  void _showInfoDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue[600],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Nurse Management',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.purple[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadNurses,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Container(
            color: Colors.purple[600],
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              unselectedLabelStyle:
                  GoogleFonts.poppins(fontWeight: FontWeight.w400),
              tabs: const [
                Tab(
                  icon: Icon(Icons.people),
                  text: 'Manage',
                ),
                Tab(
                  icon: Icon(Icons.assignment),
                  text: 'Assign',
                ),
                Tab(
                  icon: Icon(Icons.list_alt),
                  text: 'Assigned',
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Manage Tab - Existing nurse management functionality
          Column(
            children: [
              // Header with stats and add button
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.hospitalName} Nurses',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            Text(
                              '${_nurses.length} total nurses',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline, color: Colors.grey[600]),
                              const SizedBox(width: 8),
                              Text(
                                'Nurses join via registration',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Add Nurse Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.purple[600]!.withOpacity(0.1),
                            Colors.purple[600]!.withOpacity(0.05)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.purple[600]!.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person_add,
                                  color: Colors.purple[600], size: 24),
                              const SizedBox(width: 8),
                              Text(
                                'Add Nurse',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _nurseArcIdController,
                                  decoration: InputDecoration(
                                    labelText:
                                        'Nurse ARC ID (e.g., NUR12345678)',
                                    hintText: 'Enter nurse\'s ARC ID',
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
                                onPressed: _associateNurse,
                                icon: const Icon(Icons.add),
                                label: const Text('Add'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple[600],
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

                    const SizedBox(height: 20),

                    // Search and filter bar
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            decoration: InputDecoration(
                              hintText: 'Search nurses...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedFilter,
                            onChanged: _onFilterChanged,
                            underline: const SizedBox(),
                            items: _filterOptions.map((String filter) {
                              return DropdownMenuItem<String>(
                                value: filter,
                                child: Text(filter),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Nurses list
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredNurses.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.medical_services_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _nurses.isEmpty
                                      ? 'No nurses found'
                                      : 'No nurses match your search',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _nurses.isEmpty
                                      ? 'Add nurses to get started'
                                      : 'Try adjusting your search or filter',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredNurses.length,
                            itemBuilder: (context, index) {
                              final nurse = _filteredNurses[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.purple[100],
                                    child: Text(
                                      nurse.fullName
                                          .split(' ')
                                          .map((n) => n[0])
                                          .join(''),
                                      style: TextStyle(
                                        color: Colors.purple[800],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    nurse.fullName,
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          '${nurse.qualification ?? 'Not specified'} • ${nurse.experienceYears ?? 0} years exp'),
                                      Text(
                                          '${nurse.email} • ${nurse.mobileNumber ?? 'No phone'}'),
                                      const SizedBox(height: 4),
                                      // ARC ID Badge (like lab card)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.purple[600],
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.badge,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'ARC ID: ${nurse.arcId ?? 'N/A'}',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      // Status Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(nurse)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _getStatusColor(nurse),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          _getStatusText(nurse),
                                          style: TextStyle(
                                            color: _getStatusColor(nurse),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: PopupMenuButton(
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'view',
                                        child: Row(
                                          children: [
                                            Icon(Icons.visibility, size: 20),
                                            SizedBox(width: 8),
                                            Text('View Details'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.remove_circle_outline,
                                                size: 20, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Remove Association',
                                                style: TextStyle(
                                                    color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                    onSelected: (value) {
                                      switch (value) {
                                        case 'view':
                                          _showNurseDetails(nurse);
                                          break;
                                        case 'delete':
                                          _deleteNurse(nurse);
                                          break;
                                      }
                                    },
                                  ),
                                  onTap: () => _showNurseDetails(nurse),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
          // Assign Tab - New patient assignment functionality
          _buildAssignTab(),
          _buildAssignedTab(),
        ],
      ),
    );
  }

  Widget _buildAssignedTab() {
    return FutureBuilder<List<dynamic>>(
      future: ApiService.getHospitalAssignments(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return Center(
            child: Text('No assignments yet', style: GoogleFonts.poppins()),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final a = items[i] as Map<String, dynamic>;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(
                  a['patientName'] ?? 'Patient',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Doctor: ${a['doctorName'] ?? '-'}  •  Nurse: ${a['nurseName'] ?? '-'}\nWard: ${a['ward'] ?? '-'}  •  Shift: ${a['shift'] ?? '-'}',
                  style: GoogleFonts.poppins(fontSize: 12),
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'delete') {
                      final ok = await ApiService.deleteAssignment(a['_id']);
                      if (ok && mounted) setState(() {});
                    } else if (v == 'reassign') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PatientAssignmentScreen(),
                        ),
                      );
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'reassign', child: Text('Reassign')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(UserModel nurse) {
    if (nurse.isApproved == true) return Colors.green;
    if (nurse.approvalStatus == 'pending') return Colors.orange;
    return Colors.red;
  }

  // Build Assign Tab - Navigate to patient assignment screen
  Widget _buildAssignTab() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.purple[50],
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.assignment, color: Colors.purple[600], size: 28),
              const SizedBox(width: 12),
              Text(
                'Patient Assignment',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Assign patients to doctors and nurses for specific wards and shifts',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 40),

          // Assignment Features Overview
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Feature Cards
                  _buildFeatureCard(
                    icon: Icons.person_search,
                    title: 'Patient Search',
                    description:
                        'Search patients by ARC ID and assign them to specific wards',
                    color: Colors.blue[600]!,
                  ),
                  const SizedBox(height: 20),

                  _buildFeatureCard(
                    icon: Icons.medical_services,
                    title: 'Doctor Assignment',
                    description:
                        'Assign doctors to patients for medical supervision',
                    color: Colors.green[600]!,
                  ),
                  const SizedBox(height: 20),

                  _buildFeatureCard(
                    icon: Icons.local_hospital,
                    title: 'Nurse Assignment',
                    description:
                        'Assign nurses to patients for care and monitoring',
                    color: Colors.orange[600]!,
                  ),
                  const SizedBox(height: 20),

                  _buildFeatureCard(
                    icon: Icons.schedule,
                    title: 'Shift Management',
                    description:
                        'Schedule assignments with specific dates, times, and shifts',
                    color: Colors.purple[600]!,
                  ),
                  const SizedBox(height: 40),

                  // Create Assignment Button
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () {
                        print('🚀 Navigating to PatientAssignmentScreen...');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Opening Patient Assignment Screen...'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const PatientAssignmentScreen(),
                          ),
                        ).then((_) {
                          print('✅ Returned from PatientAssignmentScreen');
                        }).catchError((error) {
                          print(
                              '❌ Error navigating to PatientAssignmentScreen: $error');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $error'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 3,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_turned_in, size: 28),
                          const SizedBox(width: 12),
                          Text(
                            'Create New Assignment',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
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
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
