import 'package:flutter/material.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'dart:async';
import '../services/api_service.dart';

class HospitalAffiliationSelector extends StatefulWidget {
  final List<Map<String, dynamic>> selectedHospitals;
  final Function(List<Map<String, dynamic>>) onChanged;
  final String? userType; // 'doctor', 'lab', 'nurse', 'pharmacy'
  final Color? primaryColor;

  const HospitalAffiliationSelector({
    super.key,
    required this.selectedHospitals,
    required this.onChanged,
    this.userType,
    this.primaryColor,
  });

  @override
  State<HospitalAffiliationSelector> createState() =>
      _HospitalAffiliationSelectorState();
}

class _HospitalAffiliationSelectorState
    extends State<HospitalAffiliationSelector> {
  List<Map<String, dynamic>> _availableHospitals = [];
  bool _isLoading = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  String _selectedCity = '';
  String _selectedState = '';
  List<String> _availableCities = [];
  List<String> _availableStates = [];

  @override
  void initState() {
    super.initState();
    _loadHospitals();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadHospitals() async {
    setState(() => _isLoading = true);
    try {
      print('🏥 Loading hospitals for affiliation...');
      final hospitals = await ApiService.getApprovedHospitalsForAffiliation();
      print('🏥 Loaded ${hospitals.length} hospitals');

      // Extract unique cities and states
      final cities = <String>{};
      final states = <String>{};

      for (final hospital in hospitals) {
        if (hospital['city'] != null &&
            hospital['city'].toString().isNotEmpty) {
          cities.add(hospital['city'].toString());
        }
        if (hospital['state'] != null &&
            hospital['state'].toString().isNotEmpty) {
          states.add(hospital['state'].toString());
        }
      }

      setState(() {
        _availableHospitals = hospitals;
        _availableCities = cities.toList()..sort();
        _availableStates = states.toList()..sort();
        _isLoading = false;
      });

      if (hospitals.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No hospitals available for affiliation. Please try again later.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Error loading hospitals: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load hospitals: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _searchHospitals() async {
    if (_searchQuery.trim().isEmpty &&
        _selectedCity.isEmpty &&
        _selectedState.isEmpty) {
      _loadHospitals();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final hospitals = await ApiService.searchHospitalsForAffiliation(
        query: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
        city: _selectedCity.isEmpty ? null : _selectedCity,
        state: _selectedState.isEmpty ? null : _selectedState,
      );
      setState(() {
        _availableHospitals = hospitals;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to search hospitals: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);

    // Cancel previous timer
    _debounceTimer?.cancel();

    // Set new timer for debounced search (reduced from 500ms to 200ms)
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        _searchHospitals();
      }
    });
  }

  void _onFilterChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) {
        _searchHospitals();
      }
    });
  }

  void _addHospital(Map<String, dynamic> hospital) {
    // Check if hospital is already selected
    final isAlreadySelected = widget.selectedHospitals.any(
      (selected) => selected['id'] == hospital['id'],
    );

    if (!isAlreadySelected) {
      final newHospital = {
        'hospitalId': hospital['id'],
        'hospitalName': hospital['name'],
        'role': _getDefaultRole(),
        'startDate': DateTime.now().toIso8601String(),
        'isActive': true,
      };

      final updatedList = [...widget.selectedHospitals, newHospital];
      widget.onChanged(updatedList);
    }
  }

  void _removeHospital(Map<String, dynamic> hospital) {
    final updatedList = widget.selectedHospitals
        .where(
          (selected) => selected['hospitalId'] != hospital['hospitalId'],
        )
        .toList();
    widget.onChanged(updatedList);
  }

  void _updateHospitalRole(Map<String, dynamic> hospital, String newRole) {
    final updatedList = widget.selectedHospitals.map((selected) {
      if (selected['hospitalId'] == hospital['hospitalId']) {
        return {...selected, 'role': newRole};
      }
      return selected;
    }).toList();
    widget.onChanged(updatedList);
  }

  String _getDefaultRole() {
    switch (widget.userType) {
      case 'doctor':
        return 'Consultant';
      case 'lab':
        return 'Partner';
      case 'nurse':
        return 'Staff';
      case 'pharmacy':
        return 'Partner';
      default:
        return 'Partner';
    }
  }

  List<String> _getAvailableRoles() {
    switch (widget.userType) {
      case 'doctor':
        return ['Primary', 'Secondary', 'Consultant', 'Visiting', 'Emergency'];
      case 'lab':
        return ['Primary', 'Secondary', 'Partner', 'Emergency'];
      case 'nurse':
        return ['Primary', 'Secondary', 'Staff', 'Senior', 'Emergency', 'ICU'];
      case 'pharmacy':
        return ['Primary', 'Secondary', 'Partner', 'Emergency', 'Contract'];
      default:
        return ['Primary', 'Secondary', 'Partner'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.primaryColor ?? const Color(0xFF2196F3);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withOpacity(0.7)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(EvaIcons.homeOutline, color: primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Hospital Affiliations',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Search bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search hospitals by name, city, or state...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _loadHospitals();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primaryColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 12),

            // Filter dropdowns
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCity.isEmpty ? null : _selectedCity,
                    decoration: InputDecoration(
                      labelText: 'Filter by City',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primaryColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('All Cities'),
                      ),
                      ..._availableCities
                          .map((city) => DropdownMenuItem<String>(
                                value: city,
                                child: Text(city),
                              )),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedCity = value ?? '');
                      _onFilterChanged();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedState.isEmpty ? null : _selectedState,
                    decoration: InputDecoration(
                      labelText: 'Filter by State',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primaryColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('All States'),
                      ),
                      ..._availableStates
                          .map((state) => DropdownMenuItem<String>(
                                value: state,
                                child: Text(state),
                              )),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedState = value ?? '');
                      _onFilterChanged();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Clear filters button
            if (_selectedCity.isNotEmpty || _selectedState.isNotEmpty)
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedCity = '';
                        _selectedState = '';
                      });
                      _onFilterChanged();
                    },
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('Clear Filters'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_availableHospitals.length} hospitals found',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),

            // Selected hospitals
            if (widget.selectedHospitals.isNotEmpty) ...[
              Text(
                'Selected Hospitals (${widget.selectedHospitals.length})',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              ...widget.selectedHospitals.map((hospital) =>
                  _buildSelectedHospitalCard(hospital, primaryColor)),
              const SizedBox(height: 12),
            ],

            // Available hospitals
            Text(
              'Available Hospitals',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 8),

            // Hospital list
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_availableHospitals.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_hospital,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No hospitals found',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try refreshing or check your connection',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadHospitals,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _availableHospitals.length,
                  itemBuilder: (context, index) {
                    final hospital = _availableHospitals[index];
                    final isSelected = widget.selectedHospitals.any(
                      (selected) => selected['hospitalId'] == hospital['id'],
                    );

                    return ListTile(
                      leading: Icon(
                        Icons.local_hospital,
                        color: isSelected ? Colors.grey : primaryColor,
                      ),
                      title: Text(
                        hospital['name'] ?? 'Unknown Hospital',
                        style: TextStyle(
                          color: isSelected ? Colors.grey : Colors.black,
                          decoration:
                              isSelected ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      subtitle: Text(
                        '${hospital['city'] ?? ''}, ${hospital['state'] ?? ''}',
                        style: TextStyle(
                          color:
                              isSelected ? Colors.grey : Colors.grey.shade600,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => _addHospital(hospital),
                            ),
                      onTap: isSelected ? null : () => _addHospital(hospital),
                    );
                  },
                ),
              ),

            const SizedBox(height: 8),
            Text(
              'Select hospitals you are affiliated with. This helps patients find you easily.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedHospitalCard(
      Map<String, dynamic> hospital, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hospital['hospitalName'] ?? 'Unknown Hospital',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: hospital['role'] ?? _getDefaultRole(),
                  decoration: InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    isDense: true,
                  ),
                  items: _getAvailableRoles().map((role) {
                    return DropdownMenuItem<String>(
                      value: role,
                      child: Text(role, style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                  onChanged: (newRole) {
                    if (newRole != null) {
                      _updateHospitalRole(hospital, newRole);
                    }
                  },
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle, color: Colors.red),
            onPressed: () => _removeHospital(hospital),
          ),
        ],
      ),
    );
  }
}
