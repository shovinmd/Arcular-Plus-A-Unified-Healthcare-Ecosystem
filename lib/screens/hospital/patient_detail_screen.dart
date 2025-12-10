import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/models/user_model.dart';
import 'package:flutter/material.dart';

class PatientDetailScreen extends StatefulWidget {
  final String patientId;

  const PatientDetailScreen({super.key, required this.patientId});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  UserModel? _patient;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  Future<void> _loadPatientData() async {
    try {
      print('🏥 Loading patient detail data: ${widget.patientId}');

      // Use universal getUserInfo method which respects user type
      final patient = await ApiService.getUserInfo(widget.patientId);

      if (patient != null) {
        print('✅ Patient detail data loaded successfully: ${patient.fullName}');
        setState(() {
          _patient = patient;
          _loading = false;
        });
      } else {
        print('❌ Patient detail data not found');
        setState(() => _loading = false);
      }
    } catch (e) {
      print('❌ Error loading patient detail data: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_patient == null) {
      return const Center(child: Text('Patient not found.'));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage(
                'https://i.pravatar.cc/150?u=${_patient!.uid}',
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Name: ${_patient!.fullName}',
              style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 10),
          Text('Email: ${_patient!.email}',
              style: const TextStyle(fontSize: 18)),
          if (_patient!.age != null) ...[
            const SizedBox(height: 10),
            Text('Age: ${_patient!.age}', style: const TextStyle(fontSize: 18)),
          ],
          if (_patient!.mobileNumber != null) ...[
            const SizedBox(height: 10),
            Text('Phone: ${_patient!.mobileNumber}',
                style: const TextStyle(fontSize: 18)),
          ],
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              // TODO: Navigate to a screen showing only this patient's reports
            },
            child: const Text("View Patient's Reports"),
          ),
        ],
      ),
    );
  }
}
