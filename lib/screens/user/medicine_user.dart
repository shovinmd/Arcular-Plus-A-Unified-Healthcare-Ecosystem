import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/medicine_model.dart';
import '../../services/api_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../widgets/tablet_animation.dart';
import '../../widgets/syrup_animation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:convert';

class MedicineUserScreen extends StatefulWidget {
  const MedicineUserScreen({super.key});

  @override
  State<MedicineUserScreen> createState() => _MedicineUserScreenState();
}

class _MedicineUserScreenState extends State<MedicineUserScreen> {
  final _auth = FirebaseAuth.instance;
  List<MedicineModel> _medications = [];
  bool _loading = true;
  
  // Medicine message display
  String _medicineMessage = '';
  String _medicineMessageType = 'success';
  
  // Filtering variables
  String _searchQuery = '';
  String _selectedFilter = 'all';
  List<MedicineModel> _filteredMedications = [];

  @override
  void initState() {
    super.initState();
    // Initialize timezone
    tz.initializeTimeZones();
    _fetchMedications();
  }

  Future<void> _fetchMedications() async {
    setState(() => _loading = true);
    try {
      final userId = _auth.currentUser?.uid ?? '';
      print('🔍 Fetching medications for user: $userId');
      
      // First, cleanup expired medications
      try {
        final cleanupResult = await ApiService.cleanupExpiredMedications();
        if (cleanupResult['success'] == true) {
          final deletedCount = cleanupResult['data']?['deletedCount'] ?? 0;
          if (deletedCount > 0) {
            print('🧹 Cleaned up $deletedCount expired medications');
            _medicineMessage = 'Cleaned up $deletedCount expired medications';
            _medicineMessageType = 'info';
          }
        }
      } catch (e) {
        print('⚠️ Cleanup failed (non-critical): $e');
      }
      
      // Then fetch the updated medications list
      final meds = await ApiService.getMedications(userId);
      print('🔍 Fetched ${meds.length} medications');
      
      // Debug: Print each medicine's ID
      for (int i = 0; i < meds.length; i++) {
        print('🔍 Medicine $i: ${meds[i].name} - ID: ${meds[i].id} - ID type: ${meds[i].id.runtimeType}');
      }
      
      setState(() {
        _medications = meds;
        _filteredMedications = meds; // Initialize filtered list
        _applyFilters(); // Apply current filters
      });
    } catch (e) {
      print('Error fetching medications: $e');
      setState(() {
        _medications = [];
        _filteredMedications = [];
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleIsTaken(MedicineModel medication, bool? value) async {
    final updatedMed = MedicineModel(
      id: medication.id,
      name: medication.name,
      dose: medication.dose,
      frequency: medication.frequency,
      type: medication.type,
      isTaken: value ?? false,
    );
    await ApiService.updateMedication(updatedMed);
    await _fetchMedications();
  }
  
  // Filter medications based on search query and selected filter
  void _filterMedications(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }
  
  // Apply selected filter
  void _applyFilters() {
    _filteredMedications = _medications.where((med) {
      // Search filter
      bool matchesSearch = _searchQuery.isEmpty || 
          med.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (med.dosage?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      
      // Type filter
      bool matchesType = _selectedFilter == 'all' || med.type == _selectedFilter;
      
      // Status filter - use daily tracking
      bool matchesStatus = _selectedFilter == 'all' || 
          (_selectedFilter == 'active' && !med.isTakenToday) ||
          (_selectedFilter == 'completed' && med.isTakenToday);
      
      return matchesSearch && (matchesType || matchesStatus);
    }).toList();
  }
  
  // Build filter chip
  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.poppins(
          color: isSelected ? Colors.white : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
          _applyFilters();
        });
      },
      backgroundColor: Colors.grey[200],
      selectedColor: const Color(0xFF32CCBC),
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected ? const Color(0xFF32CCBC) : Colors.grey[300]!,
        width: 1,
      ),
    );
  }
  
  // Update medicine status (taken/not taken)
  Future<void> _updateMedicineStatus(MedicineModel medicine, bool isTaken) async {
    try {
      print('🔄 Updating medicine status: ${medicine.name} - isTaken: $isTaken');
      print('🔍 Medicine ID: ${medicine.id}');
      print('🔍 Medicine ID type: ${medicine.id.runtimeType}');
      print('🔍 Medicine ID length: ${medicine.id.length}');
      
      // Check if medicine ID is valid
      if (medicine.id.isEmpty) {
        print('❌ Medicine ID is empty! Cannot update status.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: Medicine ID is missing'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Call API to update medicine status
      final response = await ApiService.updateMedicationStatus(medicine.id, {
        'isTaken': isTaken,
        'status': isTaken ? 'completed' : 'active',
        'completedAt': isTaken ? DateTime.now().toIso8601String() : null,
        'lastAction': isTaken ? 'taken' : 'skipped',
      });

      if (response['success']) {
        print('✅ Medicine status updated successfully');
        
        // Update local state
        setState(() {
          final index = _medications.indexWhere((m) => m.id == medicine.id);
          if (index != -1) {
            _medications[index] = _medications[index].copyWith(
              isTaken: isTaken,
              completedAt: isTaken ? DateTime.now() : null,
            );
          }
        });

        // Show completion animation if taken
        if (isTaken && mounted) {
          try {
            _showCompletionAnimation(medicine);
          } catch (e) {
            print('⚠️ Error showing completion animation: $e');
          }
        }

        // Refresh data
        if (mounted) {
          _refreshAllData();
        }
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isTaken ? '✅ Medicine marked as taken!' : '⏭️ Medicine marked as skipped!'),
            backgroundColor: isTaken ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        print('❌ Failed to update medicine status: ${response['error']}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to update status: ${response['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Error updating medicine status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error updating status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show completion animation
  void _showCompletionAnimation(MedicineModel medicine) {
    // Safety check for context
    if (!mounted || !Navigator.canPop(context)) {
      print('⚠️ Cannot show completion animation - context not available');
      return;
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated checkmark
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 800),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        size: 50,
                        color: Colors.green,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Medicine Completed!',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${medicine.name} has been marked as taken',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Completed at: ${DateFormat('HH:mm').format(DateTime.now())}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Auto-close after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && Navigator.canPop(context)) {
        try {
          Navigator.of(context).pop();
        } catch (e) {
          print('⚠️ Error closing completion dialog: $e');
        }
      }
    });
  }

  // Show edit medicine dialog
  void _showEditMedicineDialog(MedicineModel medicine) {
    showDialog(
      context: context,
      builder: (context) => EditMedicineDialog(
        medicine: medicine,
        onMedicineUpdated: (updatedMedicine) async {
          // Update the medicine in the list
          setState(() {
            final index = _medications.indexWhere((m) => m.id == updatedMedicine.id);
            if (index != -1) {
              _medications[index] = updatedMedicine;
            }
          });
          
          // Refresh filtered list
          _applyFilters();
          
          // Refresh calendar and notifications
          await _refreshAllData();
          
          // Show success message
          setState(() {
            _medicineMessage = 'Medicine "${updatedMedicine.name}" updated successfully!';
            _medicineMessageType = 'success';
          });
        },
      ),
    );
  }

  // Show delete confirmation dialog
  void _showDeleteConfirmation(MedicineModel medicine) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Medicine'),
        content: Text('Are you sure you want to delete "${medicine.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteMedicine(medicine);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Delete medicine
  Future<void> _deleteMedicine(MedicineModel medicine) async {
    try {
      print('🗑️ Deleting medicine: ${medicine.name}');
      print('🔍 Medicine ID: ${medicine.id}');
      print('🔍 Medicine ID type: ${medicine.id.runtimeType}');
      print('🔍 Medicine ID length: ${medicine.id.length}');
      
      // Check if medicine ID is valid
      if (medicine.id.isEmpty) {
        print('❌ Medicine ID is empty! Cannot delete.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: Medicine ID is missing'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Call API to delete medicine
      final success = await ApiService.deleteMedication(medicine.id);
      if (success) {
        // Remove from local list
        setState(() {
          _medications.removeWhere((m) => m.id == medicine.id);
        });
        
        // Refresh filtered list
        _applyFilters();
        
        // Refresh calendar and notifications
        await _refreshAllData();
        
        // Show success message
        setState(() {
          _medicineMessage = 'Medicine "${medicine.name}" deleted successfully!';
          _medicineMessageType = 'success';
        });
      } else {
        setState(() {
          _medicineMessage = 'Failed to delete medicine. Please try again.';
          _medicineMessageType = 'error';
        });
      }
    } catch (e) {
      setState(() {
        _medicineMessage = 'Error deleting medicine: $e';
        _medicineMessageType = 'error';
      });
    }
  }

  // Refresh all data (calendar, notifications, etc.)
  Future<void> _refreshAllData() async {
    try {
      // Refresh medicines
      await _fetchMedications();
      
      // Refresh calendar events
      // This will be handled by the calendar screen when it rebuilds
      
      // Refresh notification counts
      // This will be handled by the notification screen when it rebuilds
      
      print('✅ All data refreshed after medicine update');
    } catch (e) {
      print('❌ Error refreshing data: $e');
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Medications',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF32CCBC),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _fetchMedications(),
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _showAddMedicineDialog(),
            tooltip: 'Add Medicine',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF32CCBC),
              Color(0xFF90F7EC),
              Color(0xFFE8F5E8)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Column(
        children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF32CCBC), const Color(0xFF90F7EC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Medication Management',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track your medications and dosages',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          'Total',
                          _medications.length.toString(),
                          Icons.medication,
                        ),
                        _buildStatItem(
                          'Taken Today',
                          _medications.where((m) => m.isTakenToday).length.toString(),
                          Icons.check_circle,
                        ),
                        _buildStatItem(
                          'Pending',
                          _medications.where((m) => !m.isTakenToday).length.toString(),
                          Icons.schedule,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Medicine Message Display
            if (_medicineMessage.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _medicineMessageType == 'success' 
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _medicineMessageType == 'success' 
                        ? Colors.green.withOpacity(0.3)
                        : Colors.red.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _medicineMessageType == 'success' 
                          ? Icons.check_circle 
                          : Icons.error,
                      color: _medicineMessageType == 'success' 
                          ? Colors.green 
                          : Colors.red,
                    ),
                    const SizedBox(width: 12),
          Expanded(
                      child: Text(
                        _medicineMessage,
                        style: GoogleFonts.poppins(
                          color: _medicineMessageType == 'success' 
                              ? Colors.green[700] 
                              : Colors.red[700],
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => setState(() => _medicineMessage = ''),
                      color: _medicineMessageType == 'success' 
                          ? Colors.green 
                          : Colors.red,
                    ),
                  ],
                ),
              ),
            
            // Search and Filter Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  // Search Bar
                  TextField(
                    onChanged: (value) => _filterMedications(value),
                    decoration: InputDecoration(
                      hintText: 'Search medicines...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF32CCBC)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF32CCBC), width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All', 'all'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Tablet', 'tablet'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Syrup', 'syrup'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Drops', 'drops'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Active', 'active'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Completed', 'completed'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Medications List
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
            child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF32CCBC),
                        ),
                      )
                    : _filteredMedications.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.medication_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No medications found',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Your prescribed medications will appear here',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                : ListView.builder(
                            itemCount: _filteredMedications.length,
                    itemBuilder: (context, index) {
                              final med = _filteredMedications[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Header with icon and name
                                      Row(
                                        children: [
                                          // Medicine icon (smaller)
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: med.isTaken 
                                                  ? Colors.green.withOpacity(0.1)
                                                  : const Color(0xFF32CCBC).withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Stack(
                                              children: [
                                                Icon(
                                                  med.isTaken ? Icons.check_circle : Icons.medication,
                                                  color: med.isTaken ? Colors.green : const Color(0xFF32CCBC),
                                                  size: 20,
                                                ),
                                                if (med.isTaken)
                                                  Positioned(
                                                    right: 0,
                                                    bottom: 0,
                                                    child: Container(
                                                      padding: const EdgeInsets.all(1),
                                                      decoration: BoxDecoration(
                                                        color: Colors.green,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(
                                                        Icons.check,
                                                        color: Colors.white,
                                                        size: 8,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Medicine name
                                          Expanded(
                                            child: Text(
                                              med.name,
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                                color: med.isTaken ? Colors.grey[600] : Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      
                                      const SizedBox(height: 12),
                                      
                                      // Medicine details in two lines
                                      Row(
                                        children: [
                                          // First line - Dose, Frequency, Type
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _buildCompactDetailRow('Dose', med.dose),
                                                _buildCompactDetailRow('Frequency', med.frequency),
                                                _buildCompactDetailRow('Type', med.type),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          // Second line - Dosage, Duration, Times
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (med.dosage != null && med.dosage!.isNotEmpty)
                                                  _buildCompactDetailRow('Dosage', med.dosage!),
                                                if (med.duration != null && med.duration!.isNotEmpty)
                                                  _buildCompactDetailRow('Duration', med.duration!),
                                                if (med.times != null && med.times!.isNotEmpty)
                                                  _buildCompactDetailRow('Times', med.times!.join(', ')),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      
                                      // Instructions in separate row if available
                                      if (med.instructions != null && med.instructions!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: _buildCompactDetailRow('Instructions', med.instructions!),
                                        ),
                                      
                                      const SizedBox(height: 12),
                                      
                                      // Action buttons row with dropdown
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          // Status indicator
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: med.isTakenToday ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color: med.isTakenToday ? Colors.green : Colors.orange,
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  med.isTakenToday ? Icons.check_circle : Icons.pending,
                                                  size: 16,
                                                  color: med.isTakenToday ? Colors.green : Colors.orange,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  med.isTakenToday ? 'Taken Today' : 'Pending',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                    color: med.isTakenToday ? Colors.green : Colors.orange,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          
                                          // Action dropdown menu
                                          PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_vert, color: Colors.grey),
                                            onSelected: (value) {
                                              switch (value) {
                                                case 'take':
                                                  _updateMedicineStatus(med, true);
                                                  break;
                                                case 'skip':
                                                  _updateMedicineStatus(med, false);
                                                  break;
                                                case 'edit':
                                                  _showEditMedicineDialog(med);
                                                  break;
                                                case 'delete':
                                                  _showDeleteConfirmation(med);
                                                  break;
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              PopupMenuItem(
                                                value: 'take',
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.check, color: Colors.green, size: 20),
                                                    const SizedBox(width: 8),
                                                    Text('Mark as Taken', style: GoogleFonts.poppins(fontSize: 14)),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: 'skip',
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.close, color: Colors.orange, size: 20),
                                                    const SizedBox(width: 8),
                                                    Text('Skip', style: GoogleFonts.poppins(fontSize: 14)),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: 'edit',
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.edit, color: Colors.blue, size: 20),
                                                    const SizedBox(width: 8),
                                                    Text('Edit', style: GoogleFonts.poppins(fontSize: 14)),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: 'delete',
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.delete, color: Colors.red, size: 20),
                                                    const SizedBox(width: 8),
                                                    Text('Delete', style: GoogleFonts.poppins(fontSize: 14)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                        ),
                      );
                    },
                          ),
                  ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ],
    );
  }

  // Build detail item for medicine information
  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 20,
            color: const Color(0xFF32CCBC),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build action button for medicine actions
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: color,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build compact detail row for medicine information
  Widget _buildCompactDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build compact action button for medicine actions
  Widget _buildCompactActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Icon(
            icon,
            size: 18,
            color: color,
          ),
        ),
      ),
    );
  }

  // Show add medicine dialog
  void _showAddMedicineDialog() {
    showDialog(
      context: context,
      builder: (context) => const AddMedicineDialog(),
    );
  }
}

class _EditMedicineDialogState extends State<EditMedicineDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _dosageController;
  late final TextEditingController _instructionsController;
  
  late String _selectedType;
  late String _selectedFrequency;
  late String _selectedDuration;
  late List<String> _selectedTimes;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  
  final List<String> _medicineTypes = ['tablet', 'syrup', 'drops'];
  final List<String> _frequencies = [
    'Once daily',
    'Twice daily', 
    'Three times daily'
  ];
  final List<String> _durations = [
    '3 days', '5 days', '7 days', '10 days', '14 days',
    '1 week', '2 weeks', '3 weeks', '4 weeks'
  ];

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing medicine data
    _nameController = TextEditingController(text: widget.medicine.name);
    _dosageController = TextEditingController(text: widget.medicine.dosage ?? '');
    _instructionsController = TextEditingController(text: widget.medicine.instructions ?? '');
    
    _selectedType = widget.medicine.type;
    _selectedFrequency = widget.medicine.frequency;
    _selectedDuration = widget.medicine.duration ?? '7 days';
    _selectedTimes = List<String>.from(widget.medicine.times ?? ['09:00']);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.edit,
                  color: const Color(0xFF32CCBC),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Edit Medicine',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF32CCBC),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Form
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Medicine Name
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Medicine Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.medication),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter medicine name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Medicine Type
                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: InputDecoration(
                      labelText: 'Medicine Type',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.category),
                    ),
                    items: _medicineTypes.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Row(
                          children: [
                            if (type == 'tablet') 
                              const TabletAnimation(size: 24, color: Colors.blue)
                            else if (type == 'syrup')
                              const SyrupAnimation(size: 24, color: Colors.green)
                            else
                              const Icon(Icons.water_drop, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(type.toUpperCase()),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedType = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Dosage
                  TextFormField(
                    controller: _dosageController,
                    decoration: InputDecoration(
                      labelText: 'Dosage',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.scale),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter dosage';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Frequency
                  DropdownButtonFormField<String>(
                    value: _selectedFrequency,
                    decoration: InputDecoration(
                      labelText: 'Frequency',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.schedule),
                    ),
                    items: _frequencies.map((frequency) {
                      return DropdownMenuItem(
                        value: frequency,
                        child: Text(frequency),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedFrequency = value!;
                        _setTimesBasedOnFrequency();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Duration
                  DropdownButtonFormField<String>(
                    value: _selectedDuration,
                    decoration: InputDecoration(
                      labelText: 'Duration',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.calendar_today),
                    ),
                    items: _durations.map((duration) {
                      return DropdownMenuItem(
                        value: duration,
                        child: Text(duration),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedDuration = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Time Selection
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            'Time Selection',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Time count validation
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getTimeCountColor().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _getTimeCountColor()),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _canAddMoreTimes() ? Icons.check_circle : Icons.warning,
                              color: _getTimeCountColor(),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _getTimeLimitMessage(),
                                style: TextStyle(
                                  color: _getTimeCountColor(),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Selected times display
                      Wrap(
                        spacing: 8,
                        children: _selectedTimes.map((time) {
                          return Chip(
                            label: Text(time),
                            onDeleted: () {
                              setState(() {
                                _selectedTimes.remove(time);
                              });
                            },
                            deleteIcon: const Icon(Icons.close, size: 18),
                          );
                        }).toList(),
                      ),
                      
                      // Add time button
                      if (_canAddMoreTimes())
                        TextButton.icon(
                          onPressed: _showTimePickerDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Time'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Instructions
                  TextFormField(
                    controller: _instructionsController,
                    decoration: InputDecoration(
                      labelText: 'Instructions (Optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.note),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _saveMedicine,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF32CCBC),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Update Medicine'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Auto-set times based on frequency
  void _setTimesBasedOnFrequency() {
    setState(() {
      _selectedTimes.clear();
      
      switch (_selectedFrequency) {
        case 'Once daily':
          break;
        case 'Twice daily':
          break;
        case 'Three times daily':
          break;
      }
    });
  }

  // Show time picker dialog
  void _showTimePickerDialog() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        final timeString = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        if (!_selectedTimes.contains(timeString)) {
          _selectedTimes.add(timeString);
        }
      });
    }
  }

  // Hourly frequency flow: two sequential native pickers (no custom dialog)
  Future<void> _showHourlyTimeDialog() async {
    final TimeOfDay? start = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (start == null) return;
    final TimeOfDay? end = await showTimePicker(
      context: context,
      initialTime: _endTime ?? const TimeOfDay(hour: 20, minute: 0),
    );
    if (end == null) return;
    setState(() {
      _startTime = start;
      _endTime = end;
    });
    _calculateHourlyTimes();
  }

  // Calculate hourly times
  void _calculateHourlyTimes() {
    // Hourly options removed
  }

  // Calculate hourly intervals
  List<String> _calculateHourlyIntervals(TimeOfDay start, TimeOfDay end) {
    return [];
  }

  // Time validation helpers
  Color _getTimeCountColor() {
    final required = _getRequiredTimeCount();
    if (_selectedTimes.length == required) return Colors.green;
    if (_selectedTimes.length < required) return Colors.orange;
    return Colors.red;
  }

  bool _canAddMoreTimes() {
    return _selectedTimes.length < _getRequiredTimeCount();
  }

  int _getRequiredTimeCount() {
    switch (_selectedFrequency) {
      case 'Once daily':
        return 1;
      case 'Twice daily':
        return 2;
      case 'Three times daily':
        return 3;
      default:
        return 1;
    }
  }

  String _getTimeLimitMessage() {
    final required = _getRequiredTimeCount();
    final current = _selectedTimes.length;
    
    if (current == required) {
      return 'Perfect! You have selected the correct number of times.';
    } else if (current < required) {
      return 'Please select ${required - current} more time(s).';
    } else {
      return 'You have selected too many times. Please remove ${current - required} time(s).';
    }
  }

  // Save medicine
  Future<void> _saveMedicine() async {
    if (_formKey.currentState!.validate()) {
      // Create updated medicine data
      final updatedMedicine = widget.medicine.copyWith(
        name: _nameController.text,
        type: _selectedType,
        dosage: _dosageController.text,
        frequency: _selectedFrequency,
        duration: _selectedDuration,
        times: _selectedTimes,
        instructions: _instructionsController.text.isNotEmpty ? _instructionsController.text : null,
      );
      
      try {
        // Call API to update medicine
        final success = await ApiService.updateMedication(updatedMedicine);
        if (success) {
          // Notify parent about update
          widget.onMedicineUpdated(updatedMedicine);
          
          // Close dialog
          Navigator.pop(context);
        } else {
          // Show error
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to update medicine. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating medicine: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Time variables for hourly calculation
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  // Show success popup
  void _showSuccessPopup(String medicineName) {
    // Safety check for context
    if (!mounted || !Navigator.canPop(context)) {
      print('⚠️ Cannot show success popup - context not available');
      return;
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success icon with animation
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 600),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        size: 50,
                        color: Colors.green,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Medicine Added!',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$medicineName has been added successfully',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 15),
              Text(
                'Notifications will be sent at scheduled times',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_active,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Reminders Active',
                      style: GoogleFonts.poppins(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Auto-close after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && Navigator.canPop(context)) {
        try {
          Navigator.of(context).pop();
        } catch (e) {
          print('⚠️ Error closing completion dialog: $e');
        }
      }
    });
  }

  // Show error popup
  void _showErrorPopup(String errorMessage) {
    // Safety check for context
    if (!mounted || !Navigator.canPop(context)) {
      print('⚠️ Cannot show error popup - context not available');
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Error',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        content: Text(
          errorMessage,
          style: GoogleFonts.poppins(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: GoogleFonts.poppins(
                color: const Color(0xFF32CCBC),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Add Medicine Dialog
class AddMedicineDialog extends StatefulWidget {
  const AddMedicineDialog({super.key});

  @override
  State<AddMedicineDialog> createState() => _AddMedicineDialogState();
}

// Edit Medicine Dialog
class EditMedicineDialog extends StatefulWidget {
  final MedicineModel medicine;
  final Function(MedicineModel) onMedicineUpdated;

  const EditMedicineDialog({
    Key? key,
    required this.medicine,
    required this.onMedicineUpdated,
  }) : super(key: key);

  @override
  State<EditMedicineDialog> createState() => _EditMedicineDialogState();
}

class _AddMedicineDialogState extends State<AddMedicineDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _instructionsController = TextEditingController();
  
  String _selectedType = 'tablet';
  String _selectedFrequency = 'Once daily';
  String _selectedDuration = '7 days';
  List<String> _selectedTimes = ['09:00'];
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  
  final List<String> _medicineTypes = ['tablet', 'syrup', 'drops'];
  final List<String> _frequencies = [
    'Once daily',
    'Twice daily', 
    'Three times daily'
  ];
  final List<String> _durations = [
    '3 days', '5 days', '7 days', '10 days', '14 days',
    '1 week', '2 weeks', '3 weeks', '4 weeks'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.medication,
                  color: const Color(0xFF32CCBC),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Add New Medicine',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF32CCBC),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Form
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Medicine Name
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Medicine Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.medication),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter medicine name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Medicine Type
                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: InputDecoration(
                      labelText: 'Medicine Type',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.category),
                    ),
                    items: _medicineTypes.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Row(
                          children: [
                            if (type == 'tablet')
                              const TabletAnimation(size: 24, color: Color(0xFF32CCBC))
                            else if (type == 'syrup')
                              const SyrupAnimation(size: 24, color: Color(0xFF32CCBC))
                            else
                              Icon(
                                Icons.opacity,
                                color: const Color(0xFF32CCBC),
                              ),
                            const SizedBox(width: 8),
                            Text(type.toUpperCase()),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedType = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Dosage
                  TextFormField(
                    controller: _dosageController,
                    decoration: InputDecoration(
                      labelText: 'Dosage (e.g., 500mg, 10ml)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.science),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter dosage';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Frequency
                  DropdownButtonFormField<String>(
                    value: _selectedFrequency,
                    decoration: InputDecoration(
                      labelText: 'Frequency',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.schedule),
                    ),
                    items: _frequencies.map((frequency) {
                      return DropdownMenuItem(
                        value: frequency,
                        child: Text(frequency),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedFrequency = value!;
                        _setTimesBasedOnFrequency();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Duration
                  DropdownButtonFormField<String>(
                    value: _selectedDuration,
                    decoration: InputDecoration(
                      labelText: 'Duration',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.calendar_today),
                    ),
                    items: _durations.map((duration) {
                      return DropdownMenuItem(
                        value: duration,
                        child: Text(duration),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedDuration = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Time Selection
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Reminder Times:',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getTimeCountColor(),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_selectedTimes.length} time(s)',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedTimes.map((time) {
                          return Chip(
                            label: Text(time),
                            backgroundColor: const Color(0xFF32CCBC).withOpacity(0.1),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () {
                              setState(() {
                                _selectedTimes.remove(time);
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      if (_canAddMoreTimes())
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: _selectedTime ?? TimeOfDay.now(),
                                  );
                                  if (time != null) {
                                    setState(() {
                                      _selectedTime = time;
                                      final timeString = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                                      if (!_selectedTimes.contains(timeString)) {
                                        _selectedTimes.add(timeString);
                                      }
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[400]!),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.add, color: Color(0xFF32CCBC)),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Add Time',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          color: const Color(0xFF32CCBC),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (!_canAddMoreTimes())
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Text(
                            _getTimeLimitMessage(),
                            style: TextStyle(color: Colors.orange, fontSize: 12),
                          ),
                        ),
                      // Special message for hourly frequency
                      if (_selectedFrequency.contains('Every') && _selectedFrequency.contains('hours'))
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue),
                          ),
                          child: Text(
                            'For ${_selectedFrequency}, set start and end time. Times will be calculated automatically.',
                            style: TextStyle(color: Colors.blue, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Instructions
                  TextFormField(
                    controller: _instructionsController,
                    decoration: InputDecoration(
                      labelText: 'Instructions (e.g., after food)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.info),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                  
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saveMedicine,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF32CCBC),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Save Medicine',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveMedicine() async {
    if (_formKey.currentState!.validate()) {
      // Create medicine data with all new fields
      final medicineData = {
        'name': _nameController.text,
        'type': _selectedType,
        'dosage': _dosageController.text,
        'frequency': _selectedFrequency,
        'duration': _selectedDuration,
        'times': _selectedTimes,
        'instructions': _instructionsController.text.isNotEmpty ? _instructionsController.text : null,
        'startDate': DateTime.now().toIso8601String(),
        'endDate': _calculateEndDate().toIso8601String(), // Convert DateTime to string
      };
      
      print('✅ Saving medicine: ${_nameController.text}');
      print('📊 Medicine data: $medicineData');
      
      // Call API to save medicine
      try {
        final success = await ApiService.addMedication(medicineData);
        if (success) {
          // Schedule both local notifications and FCM for medicine reminders
          await _scheduleMedicineNotifications(medicineData);
          
          // Show success popup message
          if (mounted) {
            _showSuccessPopup(medicineData['name'] as String);
          }
          
          // Navigate back to medicine screen after popup
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.pop(context);
              
              // Show success message in parent screen
              final parentState = context.findAncestorStateOfType<_MedicineUserScreenState>();
              if (parentState != null) {
                parentState.setState(() {
                  parentState._medicineMessage = 'Medicine "${medicineData['name']}" added successfully!';
                  parentState._medicineMessageType = 'success';
                });
                // Refresh medicines
                parentState._fetchMedications();
                print('✅ Medicine screen refreshed after adding medicine');
              }
            }
          });
        } else {
          // Show error popup
          if (mounted) {
            _showErrorPopup('Failed to save medicine. Please try again.');
          }
        }
      } catch (e) {
        print('❌ Error saving medicine: $e');
        // Show error message in parent screen instead of SnackBar
        if (context.mounted) {
          final parentState = context.findAncestorStateOfType<_MedicineUserScreenState>();
          if (parentState != null) {
            parentState.setState(() {
              parentState._medicineMessage = 'Error: $e';
              parentState._medicineMessageType = 'error';
            });
          }
        }
      }
    }
  }
  
  DateTime _calculateEndDate() {
    final now = DateTime.now();
    if (_selectedDuration.contains('days')) {
      final days = int.tryParse(_selectedDuration.split(' ')[0]) ?? 7;
      return now.add(Duration(days: days));
    } else if (_selectedDuration.contains('week')) {
      final weeks = int.tryParse(_selectedDuration.split(' ')[0]) ?? 1;
      return now.add(Duration(days: weeks * 7));
    }
    return now.add(const Duration(days: 7));
  }
  
  // Auto-set times based on frequency
  void _setTimesBasedOnFrequency() {
    setState(() {
      _selectedTimes.clear();
      
      switch (_selectedFrequency) {
        case 'Once daily':
          // User will select 1 time
          break;
        case 'Twice daily':
          // User will select 2 times
          break;
        case 'Three times daily':
          // User will select 3 times
          break;
        case 'Every 8 hours':
        case 'Every 12 hours':
        case 'Every 6 hours':
        case 'Every 4 hours':
          // For hourly frequencies, user sets start and end time
          _showHourlyTimeDialog();
          break;
      }
    });
  }
  
  // Show dialog for hourly frequency time selection
  void _showHourlyTimeDialog() {
    // Removed: hourly-based scheduling not supported
  }
  
  // Get time count color based on frequency
  Color _getTimeCountColor() {
    int requiredTimes = _getRequiredTimeCount();
    if (_selectedTimes.length == requiredTimes) {
      return Colors.green;
    } else if (_selectedTimes.length > requiredTimes) {
      return Colors.red;
    } else {
      return Colors.orange;
    }
  }
  
  // Check if user can add more times
  bool _canAddMoreTimes() {
    int requiredTimes = _getRequiredTimeCount();
    return _selectedTimes.length < requiredTimes;
  }
  
  // Get required time count based on frequency
  int _getRequiredTimeCount() {
    switch (_selectedFrequency) {
      case 'Once daily':
        return 1;
      case 'Twice daily':
        return 2;
      case 'Three times daily':
        return 3;
      case 'Every 4 hours':
      case 'Every 6 hours':
      case 'Every 8 hours':
      case 'Every 12 hours':
        return 6; // Maximum for hourly frequencies
      default:
        return 1;
    }
  }
  
  // Get time limit message
  String _getTimeLimitMessage() {
    int requiredTimes = _getRequiredTimeCount();
    if (_selectedTimes.length == requiredTimes) {
      return 'Perfect! You have selected the required number of times.';
    } else if (_selectedTimes.length > requiredTimes) {
      return 'You have selected too many times. Please remove some.';
    } else {
      return 'Please select ${requiredTimes - _selectedTimes.length} more time(s).';
    }
  }
  
  // Schedule FCM notifications for reliable delivery in all app states
  Future<void> _scheduleMedicineNotifications(Map<String, dynamic> medicineData) async {
    try {
      // Primary: Schedule FCM Notifications (works for all app states)
      await _scheduleFCMNotifications(medicineData);
      
      // Secondary: Schedule Local Notifications (for when app is open)
      await _scheduleLocalNotifications(medicineData);
      
      print('✅ Scheduled FCM (primary) and local (secondary) medicine notifications');
    } catch (e) {
      print('❌ Error scheduling medicine notifications: $e');
    }
  }
  
  // Schedule local notifications for when app is open or in background
  Future<void> _scheduleLocalNotifications(Map<String, dynamic> medicineData) async {
    try {
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();
      
      // Request notification permissions
      final bool? result = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      
      print('📱 Local: Notification permission result: $result');
      
      // Initialize notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);
      
      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle notification tap
          print('🔔 Local medicine notification tapped: ${response.payload}');
          _handleNotificationAction(response.payload);
        },
      );
      
      print('📱 Local: Notifications initialized successfully');
      
      // Test notification to verify notifications are working
      await flutterLocalNotificationsPlugin.show(
        999,
        'Medicine Reminder Test',
        'Notifications are working! Medicine: ${medicineData['name']}',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'medicine_reminders',
            'Medicine Reminders',
            channelDescription: 'Notifications for medicine reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
      
      print('📱 Local: Test notification sent');
      
      // Calculate notification times based on frequency
      final List<DateTime> notificationTimes = _calculateNotificationTimes(medicineData);
      
      print('📱 Local: Scheduling ${notificationTimes.length} notifications for ${medicineData['name']}');
      
      // Schedule local notifications for each time
      for (int i = 0; i < notificationTimes.length; i++) {
        final time = notificationTimes[i];
        if (time.isAfter(DateTime.now())) {
          final notificationId = i + 1000; // Unique ID for each notification
          
          // For immediate testing, show notification right away if it's within 1 minute
          final now = DateTime.now();
          final timeDiff = time.difference(now).inMinutes;
          
          if (timeDiff <= 1) {
            // Show immediate notification for testing
            await flutterLocalNotificationsPlugin.show(
              notificationId,
              'Medicine Reminder: ${medicineData['name']}',
              'Time to take ${medicineData['name']} - ${medicineData['dosage']}',
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'medicine_reminders',
                  'Medicine Reminders',
                  channelDescription: 'Reminders to take medicines on time',
                  importance: Importance.high,
                  priority: Priority.high,
                  icon: '@mipmap/ic_launcher',
                  color: Color(0xFF32CCBC),
                  actions: [
                    AndroidNotificationAction('take', 'Take'),
                    AndroidNotificationAction('skip', 'Skip'),
                    AndroidNotificationAction('snooze', 'Snooze (15min)'),
                  ],
                  category: AndroidNotificationCategory.reminder,
                  fullScreenIntent: true,
                  visibility: NotificationVisibility.public,
                ),
                iOS: DarwinNotificationDetails(
                  categoryIdentifier: 'medicine_reminder',
                  presentAlert: true,
                  presentBadge: true,
                  presentSound: true,
                ),
              ),
              payload: json.encode({
                'medicineId': medicineData['name'],
                'action': 'reminder',
                'time': time.toIso8601String(),
              }),
            );
            print('📱 Immediate notification shown for ${medicineData['name']}');
          } else {
            // Schedule future notification using zonedSchedule
            final scheduledDate = tz.TZDateTime.from(time, tz.local);
            
            await flutterLocalNotificationsPlugin.zonedSchedule(
              notificationId,
              'Medicine Reminder: ${medicineData['name']}',
              'Time to take ${medicineData['name']} - ${medicineData['dosage']}',
              scheduledDate,
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'medicine_reminders',
                  'Medicine Reminders',
                  channelDescription: 'Reminders to take medicines on time',
                  importance: Importance.high,
                  priority: Priority.high,
                  icon: '@mipmap/ic_launcher',
                  color: Color(0xFF32CCBC),
                  actions: [
                    AndroidNotificationAction('take', 'Take'),
                    AndroidNotificationAction('skip', 'Skip'),
                    AndroidNotificationAction('snooze', 'Snooze (15min)'),
                  ],
                  category: AndroidNotificationCategory.reminder,
                  fullScreenIntent: true,
                  visibility: NotificationVisibility.public,
                ),
                iOS: DarwinNotificationDetails(
                  categoryIdentifier: 'medicine_reminder',
                  presentAlert: true,
                  presentBadge: true,
                  presentSound: true,
                ),
              ),
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              payload: json.encode({
                'medicineId': medicineData['name'],
                'action': 'reminder',
                'time': time.toIso8601String(),
              }),
            );
            print('📱 Scheduled notification for ${medicineData['name']} at ${time}');
          }
        }
      }
      
      print('✅ Scheduled ${notificationTimes.length} local notifications');
    } catch (e) {
      print('❌ Error scheduling local notifications: $e');
    }
  }
  
  // Handle notification actions
  void _handleNotificationAction(String? payload) {
    if (payload == null) return;
    
    try {
      final data = json.decode(payload);
      final action = data['action'];
      final medicineId = data['medicineId'];
      
      switch (action) {
        case 'take':
          // Mark medicine as taken
          print('✅ Medicine marked as taken via notification');
          break;
        case 'skip':
          // Mark medicine as skipped
          print('⏭️ Medicine marked as skipped via notification');
          break;
        case 'snooze':
          // Snooze for 15 minutes
          print('⏰ Medicine reminder snoozed for 15 minutes');
          break;
      }
    } catch (e) {
      print('❌ Error handling notification action: $e');
    }
  }
  
    // Schedule FCM notifications for reliable delivery in all app states
  Future<void> _scheduleFCMNotifications(Map<String, dynamic> medicineData) async {
    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;
      
      // Request notification permissions
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      
      print('📱 FCM: Permission status: ${settings.authorizationStatus}');
      
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        print('⚠️ FCM: Notifications not authorized - status: ${settings.authorizationStatus}');
        return;
      }
      
      // Get FCM token
      final String? token = await messaging.getToken();
      print('📱 FCM: Token obtained: ${token?.substring(0, 20)}...');
      
      if (token == null) {
        print('⚠️ FCM token not available - notifications may not work when app is closed');
        return;
      }

      // Calculate notification times based on frequency
      final List<DateTime> notificationTimes = _calculateNotificationTimes(medicineData);
      
      print('📱 FCM: Scheduling ${notificationTimes.length} notifications for ${medicineData['name']}');
      
      // Send each notification time to backend for FCM scheduling
      for (int i = 0; i < notificationTimes.length; i++) {
        final time = notificationTimes[i];
        if (time.isAfter(DateTime.now())) {
          try {
            // Send to backend for FCM scheduling
            await _sendFCMScheduleMessage(medicineData, time, token);
            print('📱 FCM: Scheduled notification ${i + 1}/${notificationTimes.length} for ${time}');
          } catch (e) {
            print('❌ FCM: Failed to schedule notification ${i + 1}: $e');
          }
        }
      }
      
      print('✅ FCM: Successfully scheduled ${notificationTimes.length} notifications via backend');
    } catch (e) {
      print('❌ FCM: Error scheduling notifications: $e');
    }
  }
  
  // Send FCM message to schedule notification
  Future<void> _sendFCMScheduleMessage(Map<String, dynamic> medicineData, DateTime time, String token) async {
    try {
      // Send to backend to schedule FCM notification
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/notifications/schedule-medicine'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await FirebaseAuth.instance.currentUser?.getIdToken()}',
        },
        body: json.encode({
          'medicineData': medicineData,
          'scheduledTime': time.toIso8601String(),
          'fcmToken': token,
          'type': 'medicine_reminder',
        }),
      );
      
      if (response.statusCode == 200) {
        print('✅ FCM: Medicine reminder scheduled successfully for ${time}');
      } else {
        print('❌ FCM: Failed to schedule medicine reminder: ${response.body}');
      }
    } catch (e) {
      print('❌ Error sending FCM schedule message: $e');
    }
  }
  
  // Calculate notification times based on frequency
  List<DateTime> _calculateNotificationTimes(Map<String, dynamic> medicineData) {
    final List<DateTime> times = [];
    final now = DateTime.now();
    final endDate = _calculateEndDate();
    
    // Parse the selected time
    final timeParts = _selectedTimes.first.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    
    // Calculate times based on frequency
    switch (_selectedFrequency) {
      case 'Once daily':
        _addDailyNotifications(times, now, endDate, hour, minute);
        break;
      case 'Twice daily':
        _addDailyNotifications(times, now, endDate, hour, minute);
        _addDailyNotifications(times, now, endDate, hour + 12, minute);
        break;
      case 'Three times daily':
        _addDailyNotifications(times, now, endDate, hour, minute);
        _addDailyNotifications(times, now, endDate, hour + 8, minute);
        _addDailyNotifications(times, now, endDate, hour + 16, minute);
        break;
      default:
        _addDailyNotifications(times, now, endDate, hour, minute);
    }
    
    return times;
  }
  
  void _addDailyNotifications(List<DateTime> times, DateTime start, DateTime end, int hour, int minute) {
    DateTime current = DateTime(start.year, start.month, start.day, hour, minute);
    
    // If today's time has passed, start from tomorrow
    if (current.isBefore(DateTime.now())) {
      current = current.add(const Duration(days: 1));
    }
    
    while (current.isBefore(end)) {
      times.add(current);
      current = current.add(const Duration(days: 1));
    }
  }
  
  void _addHourlyNotifications(List<DateTime> times, DateTime start, DateTime end, int hour, int minute, int interval) {
    // Removed hourly scheduling
  }

  // Show success popup
  void _showSuccessPopup(String medicineName) {
    // Safety check for context
    if (!mounted || !Navigator.canPop(context)) {
      print('⚠️ Cannot show success popup - context not available');
      return;
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success icon with animation
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 600),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        size: 50,
                        color: Colors.green,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Medicine Added!',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '$medicineName has been added successfully',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 15),
              Text(
                'Notifications will be sent at scheduled times',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_active,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Reminders Active',
                      style: GoogleFonts.poppins(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Auto-close after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && Navigator.canPop(context)) {
        try {
          Navigator.of(context).pop();
        } catch (e) {
          print('⚠️ Error closing completion dialog: $e');
        }
      }
    });
  }

  // Show error popup
  void _showErrorPopup(String errorMessage) {
    // Safety check for context
    if (!mounted || !Navigator.canPop(context)) {
      print('⚠️ Cannot show error popup - context not available');
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Error',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        content: Text(
          errorMessage,
          style: GoogleFonts.poppins(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: GoogleFonts.poppins(
                color: const Color(0xFF32CCBC),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 