import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arcular_plus/screens/doctor/patient_tabs/chat_tab.dart';
import 'package:arcular_plus/screens/doctor/patient_tabs/reminders_tab.dart';
import 'package:arcular_plus/screens/doctor/patient_tabs/vitals_tab.dart';

class PatientDetailTabsScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String patientArcId;
  final String? assignmentId;

  const PatientDetailTabsScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.patientArcId,
    this.assignmentId,
  });

  @override
  State<PatientDetailTabsScreen> createState() =>
      _PatientDetailTabsScreenState();
}

class _PatientDetailTabsScreenState extends State<PatientDetailTabsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color appBarColor = const Color(0xFF0E8F78);
    final Color appBarColorLight = const Color(0xFF17B18A);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarColor,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.patientName,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
            Text('ARC: ${widget.patientArcId}',
                style:
                    GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(),
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Chat', icon: Icon(Icons.chat_bubble_outline)),
            Tab(text: 'Reminders', icon: Icon(Icons.checklist_rtl)),
            Tab(text: 'Vitals', icon: Icon(Icons.monitor_heart_outlined)),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [appBarColorLight.withOpacity(0.08), Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: TabBarView(
            controller: _tabController,
            children: [
              ChatTab(
                  patientId: widget.patientId,
                  patientName: widget.patientName,
                  patientArcId: widget.patientArcId),
              RemindersTab(patientId: widget.patientId),
              VitalsTab(patientId: widget.patientId),
            ],
          ),
        ),
      ),
    );
  }
}
