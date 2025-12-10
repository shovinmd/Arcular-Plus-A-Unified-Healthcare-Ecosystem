import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

class ManageNursesScreen extends StatefulWidget {
  const ManageNursesScreen({super.key});

  @override
  State<ManageNursesScreen> createState() => _ManageNursesScreenState();
}

class _ManageNursesScreenState extends State<ManageNursesScreen> {
  bool _loading = true;
  List<UserModel> _nurses = [];
  List<UserModel> _filteredNurses = [];
  final _arcIdController = TextEditingController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _arcIdController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      if (mounted) {
        setState(() => _loading = true);
      }
      final hospitalMongoId = await ApiService.getHospitalMongoId(
          FirebaseAuth.instance.currentUser!.uid);
      if (hospitalMongoId == null) {
        if (mounted) {
          setState(() => _loading = false);
        }
        return;
      }
      final nurses = await ApiService.getAffiliatedNurses(hospitalMongoId);
      if (mounted) {
        setState(() {
          _nurses = nurses;
          _filteredNurses = nurses;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load nurses: $e')));
      }
    }
  }

  void _filterNurses(String query) {
    if (mounted) {
      setState(() {
        if (query.isEmpty) {
          _filteredNurses = _nurses;
        } else {
          _filteredNurses = _nurses.where((nurse) {
            return nurse.fullName.toLowerCase().contains(query.toLowerCase()) ||
                (nurse.role ?? '').toLowerCase().contains(query.toLowerCase());
          }).toList();
        }
      });
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
      await ApiService.associateNurseByArcId(arcId);
      _arcIdController.clear();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Nurse associated successfully!'),
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
                Expanded(child: Text('Failed to associate nurse: $e')),
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
          'Manage Nurses',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.purple[600],
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          // Add Nurse Section
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.purple[600]!.withOpacity(0.1),
                  Colors.purple[600]!.withOpacity(0.05)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.purple[600]!.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_add, color: Colors.purple[600], size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Add Nurse',
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
                          labelText: 'Nurse ARC ID (e.g., NUR12345678)',
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
                      onPressed: _associate,
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

          // Search Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterNurses,
              decoration: InputDecoration(
                hintText: 'Search nurses by name or role...',
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

          // Nurses List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredNurses.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredNurses.length,
                        itemBuilder: (context, index) {
                          final nurse = _filteredNurses[index];
                          return _buildNurseCard(nurse);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medical_services_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No nurses found',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add nurses using their ARC ID to get started',
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

  Widget _buildNurseCard(UserModel nurse) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          // Show nurse details or actions
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Nurse Avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.purple[600]!.withOpacity(0.8),
                      Colors.purple[600]!
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(
                  Icons.medical_services,
                  color: Colors.white,
                  size: 30,
                ),
              ),

              const SizedBox(width: 16),

              // Nurse Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nurse.fullName,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: kPrimaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nurse.role ?? 'Nurse',
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
                            color: Colors.purple[600]!.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.purple[600]!.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.badge,
                                size: 16,
                                color: Colors.purple[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'ARC ID: ${(nurse.arcId ?? '').isNotEmpty ? nurse.arcId : 'N/A'}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.purple[600],
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
                  // Remove Button
                  InkWell(
                    onTap: () => _removeNurseAssociation(nurse),
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

  Future<void> _removeNurseAssociation(UserModel nurse) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove Nurse Association',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to remove ${nurse.fullName} from your hospital?',
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
        final success = await ApiService.removeNurseAssociation(nurse.uid);

        // Hide loading indicator
        Navigator.of(context).pop();

        if (success) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Nurse association removed successfully',
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
          throw Exception('Failed to remove nurse association');
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
              'Failed to remove nurse association: $e',
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
}
