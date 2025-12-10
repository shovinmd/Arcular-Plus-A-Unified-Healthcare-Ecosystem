import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'inventory_management_screen.dart';
import 'package:arcular_plus/services/auth_service.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/models/user_model.dart';
import 'package:arcular_plus/models/medicine_model.dart';
import 'package:arcular_plus/screens/pharmacy/pharmacy_profile_screen.dart';
import 'package:arcular_plus/screens/auth/login_screen.dart';
import 'package:arcular_plus/screens/auth/approval_pending_screen.dart';
import 'package:arcular_plus/screens/pharmacy/pharmacy_orders_screen.dart';
import 'package:arcular_plus/screens/pharmacy/pharmacy_notifications_screen.dart';
import 'package:arcular_plus/screens/pharmacy/qr_medicine_scanner_screen.dart';
import 'package:arcular_plus/widgets/chatarc_floating_button.dart';
import 'package:arcular_plus/widgets/shaking_bell_notification.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

// CSV download functionality - using share_plus for all platforms

class DashboardPharmacy extends StatefulWidget {
  const DashboardPharmacy({Key? key}) : super(key: key);

  @override
  State<DashboardPharmacy> createState() => _DashboardPharmacyState();
}

class _DashboardPharmacyState extends State<DashboardPharmacy> {
  int _selectedIndex = 0;
  String pharmacyName = '';
  int totalOrders = 0;
  int pendingOrders = 0;
  int completedOrders = 0;
  int totalMedicines = 0;
  double totalRevenue = 0.0;
  UserModel? _pharmacyUser;
  bool _isApproved = false;

  @override
  void initState() {
    super.initState();
    _loadCachedApprovalStatus();
    _checkApprovalStatus();
  }

  Future<void> _loadCachedApprovalStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedApproved = prefs.getBool('pharmacy_is_approved');
      final cachedStatus = prefs.getString('pharmacy_approval_status');
      if (cachedApproved != null || cachedStatus != null) {
        if (!mounted) return;
        setState(() {
          _isApproved = cachedApproved ?? _isApproved;
        });
      }
    } catch (_) {}
  }

  Future<void> _checkApprovalStatus() async {
    try {
      print('🔍 Checking pharmacy approval status...');

      // Get current user's UID
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No Firebase user found');
        return;
      }

      // Check approval status from backend
      final approvalStatus =
          await ApiService.getPharmacyApprovalStatus(user.uid);

      if (approvalStatus != null) {
        final isApproved = approvalStatus['isApproved'] ?? false;
        final status = approvalStatus['approvalStatus'] ?? 'pending';

        print('📊 Pharmacy approval status: $status, isApproved: $isApproved');

        // Update approval status immediately and cache it
        if (mounted) {
          setState(() {
            _isApproved = isApproved && status == 'approved';
          });
        }
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('pharmacy_is_approved', _isApproved);
          await prefs.setString('pharmacy_approval_status', status);
        } catch (_) {}

        if (isApproved && status == 'approved') {
          print('✅ Pharmacy approved, loading dashboard');
          // Defer heavy loads to next frame so badge shows instantly
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadPharmacyData();
            _loadDashboardStats();
          });
        } else {
          print('⏳ Pharmacy not approved, showing approval pending screen');
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const ApprovalPendingScreen(),
              ),
            );
          }
        }
      } else {
        print(
            '❌ Could not fetch pharmacy approval status, loading dashboard anyway');
        // Load dashboard anyway if approval status can't be fetched
        if (mounted) {
          setState(() {
            _isApproved =
                false; // Default to not approved if status can't be fetched
          });
        }
        _loadPharmacyData();
        _loadDashboardStats();
      }
    } catch (e) {
      print('❌ Error checking pharmacy approval status: $e');
      // On error, load dashboard anyway
      _loadPharmacyData();
      _loadDashboardStats();
    }
  }

  void _handleMenuSelection(String value) async {
    switch (value) {
      case 'profile':
        // Instant navigation to profile; profile screen fetches its own data
        final currentUser = AuthService().currentUser;
        if (currentUser != null) {
          final minimal = await ApiService.getUserInfo(currentUser.uid);
          if (!mounted) return;
          if (minimal != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PharmacyProfileScreen(pharmacy: minimal),
              ),
            ).then((_) => _loadPharmacyData());
          }
        }
        break;
      case 'logout':
        _showLogoutDialog();
        break;
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFFD700),
                Color(0xFFFFA500)
              ], // Pharmacy yellow gradient
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logout icon with gradient background
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Logout',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Are you sure you want to logout?',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    // Cancel button
                    Expanded(
                      child: Container(
                        height: 45,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Logout button
                    Expanded(
                      child: Container(
                        height: 45,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await AuthService().signOut();
                            if (mounted) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const LoginScreen()),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: const Color(0xFFFFD700),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Logout',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFFFD700),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadPharmacyData() async {
    try {
      final authService = AuthService();
      final user = authService.currentUser;
      if (user != null) {
        print('💊 Loading pharmacy data for UID: ${user.uid}');

        // Use universal getUserInfo method which respects user type
        final pharmacyUser = await ApiService.getUserInfo(user.uid);

        if (pharmacyUser != null) {
          print(
              '✅ Pharmacy data loaded successfully: ${pharmacyUser.fullName}');

          // Check approval status
          final approvalStatus =
              await ApiService.getPharmacyApprovalStatus(user.uid);
          final isApproved = approvalStatus?['isApproved'] ?? false;

          setState(() {
            _pharmacyUser = pharmacyUser;
            pharmacyName = pharmacyUser.pharmacyName ?? 'Pharmacy';
            _isApproved = isApproved;
          });
        } else {
          print('❌ Pharmacy data not found, using fallback');
          final prefs = await SharedPreferences.getInstance();
          setState(() {
            pharmacyName = prefs.getString('pharmacyName') ?? 'Pharmacy';
          });
        }
      }
    } catch (e) {
      print('❌ Error loading pharmacy data: $e');
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        pharmacyName = prefs.getString('pharmacyName') ?? 'Pharmacy';
      });
    }
  }

  Future<void> _loadDashboardStats() async {
    try {
      // Load real data from backend
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Load orders data
        final orders = await ApiService.getOrdersByPharmacy(user.uid);

        // Load real pharmacy medicines data
        final medicinesResponse =
            await ApiService.getPharmacyMedicines(user.uid);
        final medicines = medicinesResponse['data'] != null
            ? (medicinesResponse['data'] as List)
                .map((json) => MedicineModel.fromJson(json))
                .toList()
            : <MedicineModel>[];

        // Calculate order statistics
        final activeOrders = orders
            .where((order) =>
                order['status'] != 'Delivered' &&
                order['status'] != 'Cancelled')
            .toList();

        final deliveredOrders =
            orders.where((order) => order['status'] == 'Delivered').toList();

        // Calculate total revenue from delivered orders
        double revenue = 0.0;
        for (final order in deliveredOrders) {
          revenue += (order['totalAmount'] ?? 0).toDouble();
        }

        setState(() {
          totalOrders = activeOrders.length; // Only count active orders
          pendingOrders = orders
              .where((order) =>
                  order['status'] == 'Pending' ||
                  order['status'] == 'Confirmed')
              .length;
          completedOrders = deliveredOrders.length;
          totalMedicines = medicines.length;
          totalRevenue = revenue;
        });

        print(
            '📊 Dashboard stats loaded - Orders: $totalOrders, Medicines: $totalMedicines');
      }
    } catch (e) {
      print('❌ Error loading dashboard stats: $e');
      // Fallback to mock data
      setState(() {
        totalOrders = 23;
        pendingOrders = 8;
        completedOrders = 15;
        totalMedicines = 156;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadRecentActivity() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      // Load recent orders
      final orders = await ApiService.getOrdersByPharmacy(user.uid);

      // Load recent medicines
      final medicinesResponse = await ApiService.getPharmacyMedicines(user.uid);
      final medicines = medicinesResponse['data'] != null
          ? (medicinesResponse['data'] as List)
              .map((json) => MedicineModel.fromJson(json))
              .toList()
          : <MedicineModel>[];

      List<Map<String, dynamic>> activities = [];

      // Add recent orders as activities
      for (var order in orders.take(3)) {
        final patientName =
            order['patientName'] ?? order['userName'] ?? 'Unknown Patient';
        activities.add({
          'action': 'New order received',
          'time': _formatTimeAgo(
              order['createdAt'] ?? DateTime.now().toIso8601String()),
          'patient': patientName,
          'type': 'order',
        });
      }

      // Add recent medicine additions as activities
      for (var medicine in medicines.take(2)) {
        activities.add({
          'action': 'Medicine added to inventory',
          'time': _formatTimeAgo(
              medicine.lastUpdated ?? DateTime.now().toIso8601String()),
          'medicine': medicine.name,
          'type': 'medicine',
        });
      }

      // Add low stock alerts
      final lowStockMedicines =
          medicines.where((m) => m.status == 'Low Stock').take(2);
      for (var medicine in lowStockMedicines) {
        activities.add({
          'action': 'Low stock alert',
          'time': 'Just now',
          'medicine': medicine.name,
          'type': 'alert',
        });
      }

      // Sort by time (most recent first)
      activities.sort((a, b) {
        // For now, just return a simple order
        return activities.indexOf(b) - activities.indexOf(a);
      });

      return activities.take(5).toList();
    } catch (e) {
      print('❌ Error loading recent activity: $e');
      return [];
    }
  }

  String _formatTimeAgo(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return 'Recently';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pharmacy Dashboard',
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
        actions: [
          ShakingBellNotification(
            userType: 'pharmacy',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PharmacyNotificationsScreen(),
              ),
            ),
            iconColor: Colors.white,
            iconSize: 24,
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuSelection,
            icon: const Icon(Icons.more_vert, color: Colors.white),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF9800), Color(0xFFE65100)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: const Row(
                    children: [
                      Icon(Icons.person, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFE57373), Color(0xFFEF5350)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: const Row(
                    children: [
                      Icon(Icons.logout, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: [
              _buildOverviewTab(),
              _buildAnalyticsTab(),
            ],
          ),
          // Floating ArcChat Button
          const ChatArcFloatingButton(userType: 'pharmacy'),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: const Color(0xFFFFA500), // Pharmacy orange color
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadPharmacyData();
        await _loadDashboardStats();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section with Stats
            _buildWelcomeSection(),
            const SizedBox(height: 16),

            // Approval Badge
            _buildApprovalBadge(),
            const SizedBox(height: 24),

            // Quick Actions Grid
            _buildQuickActionsGrid(),
            const SizedBox(height: 24),

            // Recent Activity Section
            _buildRecentActivitySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pharmacy Analytics',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Track earnings, orders, and business insights',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),

            // Earnings Overview
            _buildEarningsCard(),
            const SizedBox(height: 16),

            // Orders Overview
            _buildOrdersCard(),
            const SizedBox(height: 16),

            // Data Actions
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2,
                children: [
                  _buildAnalyticsActionCard(
                    'Export Data',
                    'Export pharmacy data to Excel',
                    Icons.download,
                    const Color(0xFF4CAF50),
                    () => _exportData(),
                  ),
                  _buildAnalyticsActionCard(
                    'Generate Report',
                    'Create detailed pharmacy reports',
                    Icons.assessment,
                    const Color(0xFFFF9800),
                    () => _generateReport(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFFD700),
              Color(0xFFFFA500)
            ], // Golden pharmacy theme
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  backgroundImage: (_pharmacyUser?.profileImageUrl != null &&
                          _pharmacyUser!.profileImageUrl!.isNotEmpty)
                      ? NetworkImage(_pharmacyUser!.profileImageUrl!)
                      : null,
                  child: (_pharmacyUser?.profileImageUrl == null ||
                          _pharmacyUser!.profileImageUrl!.isEmpty)
                      ? const Icon(Icons.local_pharmacy,
                          color: Colors.white, size: 30)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back,',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Text(
                        _pharmacyUser?.pharmacyName ?? pharmacyName,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    await _loadPharmacyData();
                    await _loadDashboardStats();
                  },
                  icon:
                      const Icon(Icons.refresh, color: Colors.white, size: 24),
                  tooltip: 'Refresh Dashboard',
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Stats Row
            Row(
              children: [
                _buildStatCard('Active Orders', totalOrders.toString(),
                    Icons.shopping_cart),
                const SizedBox(width: 12),
                _buildStatCard(
                    'Pending', pendingOrders.toString(), Icons.pending_actions),
                const SizedBox(width: 12),
                _buildStatCard(
                    'Inventory', totalMedicines.toString(), Icons.inventory),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Manage your pharmacy operations efficiently',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalBadge() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isApproved
                ? [
                    const Color(0xFFFFD700),
                    const Color(0xFFFFA500)
                  ] // Pharmacy theme for approved
                : [
                    const Color(0xFFFF9800),
                    const Color(0xFFE65100)
                  ], // Orange for pending
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              _isApproved ? Icons.check_circle : Icons.pending,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isApproved ? 'Pharmacy Approved' : 'Approval Pending',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isApproved
                        ? 'Your pharmacy is fully functional and operational'
                        : 'Your pharmacy registration is under review',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildActionCard(
              'Manage Orders',
              Icons.shopping_cart,
              const Color(0xFF1976D2), // Darker blue for orders
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PharmacyOrdersScreen()),
              ),
            ),
            _buildActionCard(
              'Manage Inventory',
              Icons.inventory,
              const Color(0xFF388E3C), // Darker green for inventory
              () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const InventoryManagementScreen()),
                );
                // Refresh medicine count when returning from inventory
                await _loadDashboardStats();
              },
            ),
            _buildActionCard(
              'QR Medicine Scanner',
              Icons.qr_code_scanner,
              const Color(0xFFE65100), // Orange for QR functionality
              () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const QRMedicineScannerScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _loadRecentActivity(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data!.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No recent activity',
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final activities = snapshot.data!;
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activities.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final activity = activities[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.withOpacity(0.2),
                      child: Icon(
                        _getActivityIcon(activity['action']!),
                        color: Colors.orange,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      activity['action']!,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      activity['time']!,
                      style: GoogleFonts.poppins(color: Colors.grey.shade600),
                    ),
                    trailing: Text(
                      activity['patient'] ?? activity['medicine'] ?? '',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.8),
                color.withOpacity(0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, size: 28, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getActivityIcon(String action) {
    switch (action) {
      case 'New order received':
        return Icons.shopping_cart;
      case 'Prescription scanned':
        return Icons.qr_code_scanner;
      case 'Medicine dispensed':
        return Icons.medication;
      case 'Stock alert triggered':
        return Icons.warning;
      case 'Refill reminder sent':
        return Icons.refresh;
      case 'Inventory updated':
        return Icons.inventory;
      default:
        return Icons.info;
    }
  }

  Widget _buildEarningsCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.attach_money, color: Colors.white, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Earnings Overview',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildEarningsItem(
                      'Today', '₹${_calculateTodayRevenue()}', Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildEarningsItem(
                      'This Week', '₹${_calculateWeekRevenue()}', Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildEarningsItem('This Month',
                      '₹${_calculateMonthRevenue()}', Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_cart, color: Colors.white, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Orders Overview',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildOrdersItem(
                      'Active Orders', totalOrders.toString(), Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildOrdersItem(
                      'Pending', pendingOrders.toString(), Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildOrdersItem(
                      'Inventory', totalMedicines.toString(), Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: color.withOpacity(0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: color.withOpacity(0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsActionCard(String title, String description,
      IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Analytics action methods
  Future<void> _exportData() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Exporting data...'),
            ],
          ),
        ),
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Load all pharmacy data
      final orders = await ApiService.getOrdersByPharmacy(user.uid);
      final medicinesResponse = await ApiService.getPharmacyMedicines(user.uid);
      final medicines = medicinesResponse['data'] != null
          ? (medicinesResponse['data'] as List)
              .map((json) => json as Map<String, dynamic>)
              .toList()
          : <Map<String, dynamic>>[];

      // Create export data
      final exportData = {
        'pharmacyName': _pharmacyUser?.pharmacyName ?? pharmacyName,
        'exportDate': DateTime.now().toIso8601String(),
        'summary': {
          'totalOrders': orders.length,
          'activeOrders': orders
              .where((o) =>
                  o['status'] != 'Delivered' && o['status'] != 'Cancelled')
              .length,
          'deliveredOrders':
              orders.where((o) => o['status'] == 'Delivered').length,
          'totalMedicines': medicines.length,
          'totalRevenue': orders.where((o) => o['status'] == 'Delivered').fold(
              0.0,
              (sum, order) => sum + (order['totalAmount'] ?? 0).toDouble()),
        },
        'orders': orders,
        'medicines': medicines,
      };

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show export dialog with Excel-like data
      _showExportDialog(exportData);
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _generateReport() async {
    try {
      print('📊 Starting report generation...');

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Generating report...'),
            ],
          ),
        ),
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No user found');
        if (mounted) Navigator.pop(context);
        return;
      }

      print('👤 User found: ${user.uid}');

      // Load all pharmacy data
      print('📦 Loading orders...');
      final orders = await ApiService.getOrdersByPharmacy(user.uid);
      print('📦 Loaded ${orders.length} orders');

      print('💊 Loading medicines...');
      final medicinesResponse = await ApiService.getPharmacyMedicines(user.uid);
      final medicines = medicinesResponse['data'] != null
          ? (medicinesResponse['data'] as List)
              .map((json) => json as Map<String, dynamic>)
              .toList()
          : <Map<String, dynamic>>[];
      print('💊 Loaded ${medicines.length} medicines');

      // Calculate report data
      print('📊 Calculating report data...');
      final activeOrders = orders
          .where(
              (o) => o['status'] != 'Delivered' && o['status'] != 'Cancelled')
          .length;
      final deliveredOrders =
          orders.where((o) => o['status'] == 'Delivered').length;
      final cancelledOrders =
          orders.where((o) => o['status'] == 'Cancelled').length;
      final totalRevenue = orders.where((o) => o['status'] == 'Delivered').fold(
          0.0, (sum, order) => sum + (order['totalAmount'] ?? 0).toDouble());

      final lowStockMedicines =
          medicines.where((m) => (m['stock'] ?? 0) <= 10).length;
      final outOfStockMedicines =
          medicines.where((m) => (m['stock'] ?? 0) <= 0).length;

      print(
          '📊 Calculated: Active=$activeOrders, Delivered=$deliveredOrders, Cancelled=$cancelledOrders');
      print(
          '📊 Revenue: $totalRevenue, Low Stock: $lowStockMedicines, Out of Stock: $outOfStockMedicines');

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show comprehensive report with charts
      print('📊 Showing report dialog...');
      try {
        _showReportDialog(
            orders,
            medicines,
            activeOrders,
            deliveredOrders,
            cancelledOrders,
            totalRevenue,
            lowStockMedicines,
            outOfStockMedicines);
        print('✅ Report dialog shown successfully');
      } catch (dialogError) {
        print('❌ Error showing report dialog: $dialogError');

        // Show fallback dialog with basic info
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Pharmacy Report'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Total Orders: ${orders.length}'),
                Text('Delivered Orders: $deliveredOrders'),
                Text('Total Revenue: ₹${totalRevenue.toStringAsFixed(2)}'),
                Text('Total Medicines: ${medicines.length}'),
                Text('Low Stock Items: $lowStockMedicines'),
                Text('Out of Stock Items: $outOfStockMedicines'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _calculateTodayRevenue() {
    // This would need to be calculated from actual order data
    // For now, return a placeholder
    return totalRevenue.toStringAsFixed(0);
  }

  String _calculateWeekRevenue() {
    // This would need to be calculated from actual order data
    // For now, return a placeholder
    return (totalRevenue * 1.5).toStringAsFixed(0);
  }

  String _calculateMonthRevenue() {
    // This would need to be calculated from actual order data
    // For now, return a placeholder
    return (totalRevenue * 3).toStringAsFixed(0);
  }

  // Show export dialog with Excel-like data
  void _showExportDialog(Map<String, dynamic> exportData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Export Data',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pharmacy: ${exportData['pharmacyName']}',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              Text(
                'Export Date: ${DateTime.now().toString().split(' ')[0]}',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),

              // Summary Table
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📊 Summary',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _buildExportRow('Total Orders',
                        '${exportData['summary']['totalOrders']}'),
                    _buildExportRow('Active Orders',
                        '${exportData['summary']['activeOrders']}'),
                    _buildExportRow('Delivered Orders',
                        '${exportData['summary']['deliveredOrders']}'),
                    _buildExportRow('Total Medicines',
                        '${exportData['summary']['totalMedicines']}'),
                    _buildExportRow('Total Revenue',
                        '₹${exportData['summary']['totalRevenue'].toStringAsFixed(2)}'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Orders Table Preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📋 Recent Orders (Excel Format)',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Order ID')),
                          DataColumn(label: Text('Customer')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Amount')),
                          DataColumn(label: Text('Date')),
                        ],
                        rows:
                            (exportData['orders'] as List).take(5).map((order) {
                          return DataRow(cells: [
                            DataCell(Text(order['orderId'] ?? 'N/A')),
                            DataCell(Text(order['userName'] ?? 'N/A')),
                            DataCell(Text(order['status'] ?? 'N/A')),
                            DataCell(Text(
                                '₹${(order['totalAmount'] ?? 0).toStringAsFixed(2)}')),
                            DataCell(Text(DateTime.tryParse(
                                        order['orderDate']?.toString() ?? '')
                                    ?.toString()
                                    .split(' ')[0] ??
                                'N/A')),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _downloadExcelFile(exportData);
            },
            icon: const Icon(Icons.download),
            label: const Text('Download Excel'),
          ),
        ],
      ),
    );
  }

  // Download Excel file with pharmacy data
  Future<void> _downloadExcelFile(Map<String, dynamic> exportData) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Preparing Excel file...'),
            ],
          ),
        ),
      );

      // Create CSV content (Excel-compatible format)
      final csvContent = _createCsvContent(exportData);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Share the CSV content using the same method as lab
      await _shareCsvContent(csvContent, 'pharmacy_export_data.csv');

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'CSV data ready to share! The file is properly formatted for Excel.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Create CSV content from export data
  String _createCsvContent(Map<String, dynamic> exportData) {
    final buffer = StringBuffer();

    // Add CSV header with proper formatting
    buffer.writeln('Pharmacy Export Data');
    buffer.writeln('Pharmacy,"${exportData['pharmacyName']}"');
    buffer.writeln('Export Date,"${DateTime.now().toString().split(' ')[0]}"');
    buffer.writeln('');

    // Add summary section with proper CSV headers
    buffer.writeln('SUMMARY');
    buffer.writeln('Metric,Value');
    buffer.writeln('Total Orders,"${exportData['summary']['totalOrders']}"');
    buffer.writeln('Active Orders,"${exportData['summary']['activeOrders']}"');
    buffer.writeln(
        'Delivered Orders,"${exportData['summary']['deliveredOrders']}"');
    buffer.writeln(
        'Total Medicines,"${exportData['summary']['totalMedicines']}"');
    buffer.writeln(
        'Total Revenue,"${exportData['summary']['totalRevenue'].toStringAsFixed(2)}"');
    buffer.writeln('');

    // Add orders section with proper CSV formatting
    buffer.writeln('RECENT ORDERS');
    buffer.writeln('Order ID,Customer Name,Status,Amount (₹),Order Date');

    final orders = exportData['orders'] as List;
    for (final order in orders) {
      final orderId =
          (order['orderId'] ?? 'N/A').toString().replaceAll('"', '""');
      final customerName =
          (order['userName'] ?? 'N/A').toString().replaceAll('"', '""');
      final status =
          (order['status'] ?? 'N/A').toString().replaceAll('"', '""');
      final amount = (order['totalAmount'] ?? 0).toStringAsFixed(2);
      final orderDate = DateTime.tryParse(order['orderDate']?.toString() ?? '')
              ?.toString()
              .split(' ')[0] ??
          'N/A';

      buffer.writeln(
          '"$orderId","$customerName","$status","$amount","$orderDate"');
    }

    return buffer.toString();
  }

  // Show comprehensive report with charts
  void _showReportDialog(
      List orders,
      List medicines,
      int activeOrders,
      int deliveredOrders,
      int cancelledOrders,
      double totalRevenue,
      int lowStockMedicines,
      int outOfStockMedicines) {
    print('📊 Showing report dialog with data:');
    print('Orders: ${orders.length}, Medicines: ${medicines.length}');
    print(
        'Active: $activeOrders, Delivered: $deliveredOrders, Cancelled: $cancelledOrders');
    print(
        'Revenue: $totalRevenue, Low Stock: $lowStockMedicines, Out of Stock: $outOfStockMedicines');

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Text(
          'Pharmacy Analytics Report',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Generated: ${DateTime.now().toString().split(' ')[0]}',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),

                // Order Status Chart
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📊 Order Status Distribution',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _buildChartBar('Delivered', deliveredOrders,
                          orders.length, Colors.green),
                      _buildChartBar(
                          'Active', activeOrders, orders.length, Colors.blue),
                      _buildChartBar('Cancelled', cancelledOrders,
                          orders.length, Colors.red),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Revenue Chart
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '💰 Revenue Overview',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Revenue',
                                    style: GoogleFonts.poppins(fontSize: 12)),
                                Text('₹${totalRevenue.toStringAsFixed(2)}',
                                    style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Avg Order Value',
                                    style: GoogleFonts.poppins(fontSize: 12)),
                                Text(
                                    '₹${deliveredOrders > 0 ? (totalRevenue / deliveredOrders).toStringAsFixed(2) : '0.00'}',
                                    style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Inventory Chart
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📦 Inventory Status',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _buildChartBar(
                          'In Stock',
                          medicines.length -
                              lowStockMedicines -
                              outOfStockMedicines,
                          medicines.length,
                          Colors.green),
                      _buildChartBar('Low Stock', lowStockMedicines,
                          medicines.length, Colors.orange),
                      _buildChartBar('Out of Stock', outOfStockMedicines,
                          medicines.length, Colors.red),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _downloadDetailedReport(
                orders,
                medicines,
                activeOrders,
                deliveredOrders,
                cancelledOrders,
                totalRevenue,
                lowStockMedicines,
                outOfStockMedicines,
              );
            },
            icon: const Icon(Icons.download),
            label: const Text('Download Report'),
          ),
        ],
      ),
    );
  }

  // Download detailed pharmacy report
  Future<void> _downloadDetailedReport(
    List orders,
    List medicines,
    int activeOrders,
    int deliveredOrders,
    int cancelledOrders,
    double totalRevenue,
    int lowStockMedicines,
    int outOfStockMedicines,
  ) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Generating detailed report...'),
            ],
          ),
        ),
      );

      // Create comprehensive report content
      final reportContent = _createDetailedReportContent(
        orders,
        medicines,
        activeOrders,
        deliveredOrders,
        cancelledOrders,
        totalRevenue,
        lowStockMedicines,
        outOfStockMedicines,
      );

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Share the CSV content using the same method as lab
      await _shareCsvContent(reportContent, 'pharmacy_detailed_report.csv');

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Detailed CSV report ready to share! The file is properly formatted for Excel.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Create detailed report content
  String _createDetailedReportContent(
    List orders,
    List medicines,
    int activeOrders,
    int deliveredOrders,
    int cancelledOrders,
    double totalRevenue,
    int lowStockMedicines,
    int outOfStockMedicines,
  ) {
    final buffer = StringBuffer();

    // Add CSV header with proper formatting
    buffer.writeln('PHARMACY DETAILED ANALYTICS REPORT');
    buffer.writeln('Pharmacy,${_pharmacyUser?.pharmacyName ?? 'Pharmacy'}');
    buffer.writeln('Generated,${DateTime.now().toString()}');
    buffer.writeln('Report Type,Comprehensive Analytics');
    buffer.writeln('');

    // Executive Summary in CSV format
    buffer.writeln('EXECUTIVE SUMMARY');
    buffer.writeln('Metric,Value');
    buffer.writeln('Total Orders,${orders.length}');
    buffer.writeln('Active Orders,$activeOrders');
    buffer.writeln('Delivered Orders,$deliveredOrders');
    buffer.writeln('Cancelled Orders,$cancelledOrders');
    buffer.writeln('Total Revenue,${totalRevenue.toStringAsFixed(2)}');
    buffer.writeln(
        'Average Order Value,${deliveredOrders > 0 ? (totalRevenue / deliveredOrders).toStringAsFixed(2) : '0.00'}');
    buffer.writeln('');

    // Order Status Distribution in CSV format
    buffer.writeln('ORDER STATUS DISTRIBUTION');
    buffer.writeln('Status,Count,Percentage');
    final totalOrders = orders.length;
    if (totalOrders > 0) {
      buffer.writeln(
          'Delivered,$deliveredOrders,${(deliveredOrders / totalOrders * 100).toStringAsFixed(1)}%');
      buffer.writeln(
          'Active,$activeOrders,${(activeOrders / totalOrders * 100).toStringAsFixed(1)}%');
      buffer.writeln(
          'Cancelled,$cancelledOrders,${(cancelledOrders / totalOrders * 100).toStringAsFixed(1)}%');
    }
    buffer.writeln('');

    // Revenue Analysis in CSV format
    buffer.writeln('REVENUE ANALYSIS');
    buffer.writeln('Metric,Value');
    buffer.writeln('Total Revenue,${totalRevenue.toStringAsFixed(2)}');
    buffer.writeln(
        'Revenue from Delivered Orders,${totalRevenue.toStringAsFixed(2)}');
    buffer.writeln(
        'Average Order Value,${deliveredOrders > 0 ? (totalRevenue / deliveredOrders).toStringAsFixed(2) : '0.00'}');
    buffer.writeln('');

    // Inventory Analysis in CSV format
    buffer.writeln('INVENTORY ANALYSIS');
    buffer.writeln('Metric,Count');
    buffer.writeln('Total Medicines,${medicines.length}');
    buffer.writeln(
        'In Stock,${medicines.length - lowStockMedicines - outOfStockMedicines}');
    buffer.writeln('Low Stock (≤10),$lowStockMedicines');
    buffer.writeln('Out of Stock,$outOfStockMedicines');
    buffer.writeln('');

    // Recent Orders Detail in CSV format
    buffer.writeln('RECENT ORDERS DETAIL');
    buffer.writeln('Order ID,Customer Name,Status,Amount,Order Date');

    // Show last 10 orders
    final recentOrders = orders.take(10).toList();
    for (final order in recentOrders) {
      final orderId =
          (order['orderId'] ?? 'N/A').toString().replaceAll(',', ';');
      final customerName =
          (order['userName'] ?? 'N/A').toString().replaceAll(',', ';');
      final status = (order['status'] ?? 'N/A').toString().replaceAll(',', ';');
      final amount = (order['totalAmount'] ?? 0).toStringAsFixed(2);
      final orderDate = DateTime.tryParse(order['orderDate']?.toString() ?? '')
              ?.toString()
              .split(' ')[0] ??
          'N/A';

      buffer.writeln('$orderId,$customerName,$status,$amount,$orderDate');
    }
    buffer.writeln('');

    // Low Stock Medicines in CSV format
    if (lowStockMedicines > 0) {
      buffer.writeln('LOW STOCK MEDICINES');
      buffer.writeln('Medicine Name,Current Stock');
      final lowStockItems =
          medicines.where((m) => (m['stock'] ?? 0) <= 10).toList();
      for (final medicine in lowStockItems) {
        final medicineName =
            (medicine['name'] ?? 'N/A').toString().replaceAll(',', ';');
        final stock = medicine['stock'] ?? 0;
        buffer.writeln('$medicineName,$stock');
      }
      buffer.writeln('');
    }

    // Out of Stock Medicines in CSV format
    if (outOfStockMedicines > 0) {
      buffer.writeln('OUT OF STOCK MEDICINES');
      buffer.writeln('Medicine Name,Current Stock');
      final outOfStockItems =
          medicines.where((m) => (m['stock'] ?? 0) <= 0).toList();
      for (final medicine in outOfStockItems) {
        final medicineName =
            (medicine['name'] ?? 'N/A').toString().replaceAll(',', ';');
        final stock = medicine['stock'] ?? 0;
        buffer.writeln('$medicineName,$stock');
      }
      buffer.writeln('');
    }

    // Recommendations in CSV format
    buffer.writeln('RECOMMENDATIONS');
    buffer.writeln('Recommendation,Priority');
    if (lowStockMedicines > 0) {
      buffer.writeln(
          'Restock $lowStockMedicines medicines that are running low,Medium');
    }
    if (outOfStockMedicines > 0) {
      buffer.writeln(
          'Urgently restock $outOfStockMedicines medicines that are out of stock,High');
    }
    if (cancelledOrders > 0) {
      buffer.writeln(
          'Review $cancelledOrders cancelled orders to identify improvement areas,Medium');
    }
    if (deliveredOrders > 0) {
      buffer.writeln(
          'Excellent delivery performance with $deliveredOrders successful deliveries,Info');
    }

    return buffer.toString();
  }

  // Helper method for export rows
  Widget _buildExportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 12)),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // Helper method for chart bars
  Widget _buildChartBar(String label, int value, int total, Color color) {
    final percentage = total > 0 ? (value / total) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.poppins(fontSize: 12)),
              Text('$value (${(percentage * 100).toStringAsFixed(1)}%)',
                  style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.grey.shade200,
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // QR methods removed - using dedicated QR medicine scanner screen

  // Share CSV content using the same method as lab
  Future<void> _shareCsvContent(String content, String fileName) async {
    // Use share_plus for all platforms
    await Share.share(content, subject: fileName);
  }
}
