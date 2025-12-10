class LabReportModel {
  final String id;
  final String labId;
  final String patientId;
  final String patientName;
  final String testName;
  final String doctorId;
  final String hospitalId;
  final String prescription;
  final String urgency;
  final String? notes;
  final String? results;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  LabReportModel({
    required this.id,
    required this.labId,
    required this.patientId,
    required this.patientName,
    required this.testName,
    required this.doctorId,
    required this.hospitalId,
    required this.prescription,
    required this.urgency,
    this.notes,
    this.results,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LabReportModel.fromJson(Map<String, dynamic> json) {
    return LabReportModel(
      id: json['_id'] ?? json['id'] ?? '',
      labId: json['labId'] ?? '',
      patientId: json['patientId'] ?? '',
      patientName: json['patientName'] ?? '',
      testName: json['testName'] ?? '',
      doctorId: json['doctorId'] ?? '',
      hospitalId: json['hospitalId'] ?? '',
      prescription: json['prescription'] ?? '',
      urgency: json['urgency'] ?? 'normal',
      notes: json['notes'],
      results: json['results'],
      status: json['status'] ?? 'pending',
      createdAt:
          DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt:
          DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'labId': labId,
      'patientId': patientId,
      'patientName': patientName,
      'testName': testName,
      'doctorId': doctorId,
      'hospitalId': hospitalId,
      'prescription': prescription,
      'urgency': urgency,
      'notes': notes,
      'results': results,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
