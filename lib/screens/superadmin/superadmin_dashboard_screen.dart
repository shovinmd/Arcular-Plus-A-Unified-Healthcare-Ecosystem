import 'package:arcular_plus/services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SuperadminDashboardScreen extends StatefulWidget {
  const SuperadminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<SuperadminDashboardScreen> createState() => _SuperadminDashboardScreenState();
}

class _SuperadminDashboardScreenState extends State<SuperadminDashboardScreen> {
  int _selectedIndex = 0;
  final List<String> _menuTitles = [
    'Dashboard',
    'Create Staff',
    'Staff List',
    'Pending Approvals',
    'Reports',
    'Settings',
  ];

  void _onMenuTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildDashboardOverview() {
    // Mock stats
    final stats = [
      {'label': 'Total Staff', 'count': 5, 'icon': Icons.group, 'color': Colors.blue},
      {'label': 'Pending Approvals', 'count': 3, 'icon': Icons.hourglass_top, 'color': Colors.orange},
      {'label': 'Reports', 'count': 12, 'icon': Icons.bar_chart, 'color': Colors.green},
    ];
    // Mock recent activity
    final activity = [
      'Staff John created',
      'ARC Staff Jane approved a hospital',
      'Superadmin updated settings',
    ];
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Superadmin Dashboard',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: stats.map((stat) {
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Container(
                    width: 160,
                    height: 120,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(stat['icon'] as IconData, size: 36, color: stat['color'] as Color),
                        const SizedBox(height: 12),
                        Text(
                          stat['count'].toString(),
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: stat['color'] as Color),
                        ),
                        const SizedBox(height: 4),
                        Text(stat['label'] as String, style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            const Text(
              'Recent Activity',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activity.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) => ListTile(
                  leading: const Icon(Icons.bolt, color: Colors.blueAccent),
                  title: Text(activity[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateStaffForm() {
    final _formKey = GlobalKey<FormState>();
    final TextEditingController _nameController = TextEditingController();
    final TextEditingController _emailController = TextEditingController();
    final TextEditingController _passwordController = TextEditingController();
    String _selectedRole = 'arcstaff';
    bool _loading = false;
    String? _errorMessage;
    String? _successMessage;

    Future<void> _createStaff() async {
      if (!_formKey.currentState!.validate()) return;
      _errorMessage = null;
      _successMessage = null;
      _loading = true;
      try {
        // 1. Create user in Firebase Auth
        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        final firebaseUid = userCredential.user?.uid;
        if (firebaseUid == null) throw Exception('Failed to create user in Firebase Auth');
        // 2. Call backend API to create staff
        final user = FirebaseAuth.instance.currentUser;
        final idToken = await user?.getIdToken();
        final response = await ApiService.createStaff(
          firebaseUid: firebaseUid,
          email: _emailController.text.trim(),
          name: _nameController.text.trim(),
          role: _selectedRole,
          idToken: idToken,
        );
        if (response) {
          _successMessage = 'Staff created successfully!';
          _formKey.currentState!.reset();
        } else {
          _errorMessage = 'Failed to create staff in backend.';
        }
      } catch (e) {
        _errorMessage = 'Error: ${e.toString()}';
      } finally {
        _loading = false;
      }
    }

    return StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Create Staff', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.isEmpty ? 'Enter name' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v == null || v.isEmpty ? 'Enter email' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                    obscureText: true,
                    validator: (v) => v == null || v.length < 6 ? 'Min 6 characters' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    items: const [
                      DropdownMenuItem(value: 'arcstaff', child: Text('ARC Staff')),
                      DropdownMenuItem(value: 'superadmin', child: Text('Superadmin')),
                    ],
                    onChanged: (v) => setState(() => _selectedRole = v ?? 'arcstaff'),
                    decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                    ),
                  if (_successMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(_successMessage!, style: const TextStyle(color: Colors.green)),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : () async { setState(() => _loading = true); await _createStaff(); setState(() => _loading = false); },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0057A0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Create Staff'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_selectedIndex == 0) {
      return _buildDashboardOverview();
    }
    if (_selectedIndex == 1) {
      return _buildCreateStaffForm();
    }
    // Placeholder for other features
    return Center(
      child: Text(
        _menuTitles[_selectedIndex],
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Superadmin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              // TODO: Implement logout logic
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF0057A0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.security, size: 36, color: Color(0xFF0057A0)),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Superadmin',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'superadmin@arcularplus.com',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            ...List.generate(_menuTitles.length, (i) {
              return ListTile(
                leading: Icon(
                  [
                    Icons.dashboard,
                    Icons.person_add,
                    Icons.group,
                    Icons.hourglass_top,
                    Icons.bar_chart,
                    Icons.settings,
                  ][i],
                  color: i == _selectedIndex ? Color(0xFF0057A0) : Colors.grey,
                ),
                title: Text(_menuTitles[i]),
                selected: i == _selectedIndex,
                onTap: () {
                  Navigator.pop(context);
                  _onMenuTap(i);
                },
              );
            }),
          ],
        ),
      ),
      body: _buildContent(),
    );
  }
} 