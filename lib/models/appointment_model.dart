class AppointmentModel {
  final String id;
  final String? appointmentId; // Human-readable booking ID
  final String doctorName;
  final String doctorId;
  final String patientId;
  final DateTime dateTime;
  final String status; // e.g., 'Confirmed', 'Cancelled', 'Rescheduled'
  final String? hospitalName;
  final String? hospitalId;
  final String? reason;
  final String? appointmentType;
  final double? consultationFee;
  final String? doctorEmail;
  final String? doctorPhone;
  final String? patientName;
  final String? patientPhone;
  final String? department;
  final String? notes;

  AppointmentModel({
    required this.id,
    this.appointmentId,
    required this.doctorName,
    required this.doctorId,
    required this.patientId,
    required this.dateTime,
    required this.status,
    this.hospitalName,
    this.hospitalId,
    this.reason,
    this.appointmentType,
    this.consultationFee,
    this.doctorEmail,
    this.doctorPhone,
    this.patientName,
    this.patientPhone,
    this.department,
    this.notes,
  });

  // Copy with method for creating modified instances
  AppointmentModel copyWith({
    String? id,
    String? appointmentId,
    String? doctorName,
    String? doctorId,
    String? patientId,
    DateTime? dateTime,
    String? status,
    String? hospitalName,
    String? hospitalId,
    String? reason,
    String? appointmentType,
    double? consultationFee,
    String? doctorEmail,
    String? doctorPhone,
    String? patientName,
    String? patientPhone,
    String? department,
    String? notes,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      appointmentId: appointmentId ?? this.appointmentId,
      doctorName: doctorName ?? this.doctorName,
      doctorId: doctorId ?? this.doctorId,
      patientId: patientId ?? this.patientId,
      dateTime: dateTime ?? this.dateTime,
      status: status ?? this.status,
      hospitalName: hospitalName ?? this.hospitalName,
      hospitalId: hospitalId ?? this.hospitalId,
      reason: reason ?? this.reason,
      appointmentType: appointmentType ?? this.appointmentType,
      consultationFee: consultationFee ?? this.consultationFee,
      doctorEmail: doctorEmail ?? this.doctorEmail,
      doctorPhone: doctorPhone ?? this.doctorPhone,
      patientName: patientName ?? this.patientName,
      patientPhone: patientPhone ?? this.patientPhone,
      department: department ?? this.department,
      notes: notes ?? this.notes,
    );
  }

  // Method for JSON API
  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    try {
      // Handle both old format (dateTime) and new format (appointmentDate + appointmentTime)
      DateTime appointmentDateTime;
      if (json['dateTime'] != null) {
        appointmentDateTime = DateTime.parse(json['dateTime']);
      } else if (json['appointmentDate'] != null) {
        final appointmentDate = DateTime.parse(json['appointmentDate']);
        final appointmentTime = json['appointmentTime'] ?? '09:00';
        final timeParts = appointmentTime.split(':');
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        appointmentDateTime = DateTime(
          appointmentDate.year,
          appointmentDate.month,
          appointmentDate.day,
          hour,
          minute,
        );
      } else {
        appointmentDateTime = DateTime.now();
      }

      return AppointmentModel(
        id: json['_id'] ?? json['id'] ?? '',
        appointmentId: json['appointmentId'],
        doctorName: json['doctorName'] ?? 'Unknown Doctor',
        doctorId: json['doctorId'] ?? '',
        patientId: json['userId'] ?? json['patientId'] ?? '',
        dateTime: appointmentDateTime,
        status: json['appointmentStatus'] ?? json['status'] ?? 'Scheduled',
        hospitalName: json['hospitalName'],
        hospitalId: json['hospitalId'],
        reason: json['reason'],
        appointmentType: json['appointmentType'],
        consultationFee: json['consultationFee']?.toDouble(),
        doctorEmail: json['doctorEmail'],
        doctorPhone: json['doctorPhone'],
        patientName: json['userName'] ?? json['patientName'],
        patientPhone: json['userPhone'] ?? json['patientPhone'],
        department: json['department'],
        notes: json['notes'],
      );
    } catch (e) {
      print('❌ Error parsing appointment: $e');
      print('❌ JSON data: $json');
      // Return a safe default appointment
      return AppointmentModel(
        id: 'error-${DateTime.now().millisecondsSinceEpoch}',
        appointmentId: null,
        doctorName: 'Unknown Doctor',
        doctorId: '',
        patientId: '',
        dateTime: DateTime.now(),
        status: 'Error',
        hospitalName: 'Unknown Hospital',
        hospitalId: '',
        reason: 'Error parsing appointment data',
        appointmentType: 'Error',
        consultationFee: 0.0,
        doctorEmail: null,
        doctorPhone: null,
        patientName: 'Unknown Patient',
        patientPhone: null,
        department: null,
        notes: 'Error: $e',
      );
    }
  }

  // Method for JSON API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'appointmentId': appointmentId,
      'doctorName': doctorName,
      'doctorId': doctorId,
      'patientId': patientId,
      'dateTime': dateTime.toIso8601String(),
      'status': status,
      'hospitalName': hospitalName,
      'hospitalId': hospitalId,
      'reason': reason,
      'appointmentType': appointmentType,
      'consultationFee': consultationFee,
      'doctorEmail': doctorEmail,
      'doctorPhone': doctorPhone,
      'patientName': patientName,
      'patientPhone': patientPhone,
      'department': department,
      'notes': notes,
    };
  }
}
