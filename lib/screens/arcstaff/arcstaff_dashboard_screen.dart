import 'package:flutter/material.dart';

class ArcStaffDashboardScreen extends StatefulWidget {
  const ArcStaffDashboardScreen({Key? key}) : super(key: key);

  @override
  State<ArcStaffDashboardScreen> createState() => _ArcStaffDashboardScreenState();
}

class _ArcStaffDashboardScreenState extends State<ArcStaffDashboardScreen> {
  int _selectedIndex = 0;
  final List<String> _menuTitles = [
    'Dashboard',
    'Pending Approvals',
    'Hospitals',
    'Doctors',
    'Nurses',
    'Labs',
    'Pharmacies',
    'Reports',
    'ARC ID Lookup',
  ];

  // TODO: Replace with real-time data from backend
  final List<Map<String, dynamic>> stats = [
    {'label': 'Pending Approvals', 'count': 7, 'icon': Icons.hourglass_top, 'color': Colors.orange},
    {'label': 'Active Hospitals', 'count': 12, 'icon': Icons.local_hospital, 'color': Colors.blue},
    {'label': 'Active Doctors', 'count': 34, 'icon': Icons.person, 'color': Colors.green},
    {'label': 'Active Nurses', 'count': 21, 'icon': Icons.medical_services, 'color': Colors.purple},
  ];

  void _onMenuTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildDashboardOverview() {
    // Mock recent activity
    final activity = [
      'Dr. Smith approved as Doctor',
      'Metro Hospital registration approved',
      'Nurse Maria assigned to Emergency',
      'Lab Advanced Diagnostics added',
    ];
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard Overview',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: stats.map((stat) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: Card(
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
                    ),
                  );
                }).toList(),
              ),
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

  Widget _buildContent() {
    if (_selectedIndex == 0) {
      return _buildDashboardOverview();
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
        title: const Text('ARC Staff Dashboard'),
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
                    child: Icon(Icons.group, size: 36, color: Color(0xFF0057A0)),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'ARC Staff',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'staff@arcularplus.com',
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
                    Icons.hourglass_top,
                    Icons.local_hospital,
                    Icons.person,
                    Icons.medical_services,
                    Icons.science,
                    Icons.local_pharmacy,
                    Icons.bar_chart,
                    Icons.qr_code,
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