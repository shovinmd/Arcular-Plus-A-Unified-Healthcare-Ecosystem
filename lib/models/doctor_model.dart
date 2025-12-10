class DoctorModel {
  final String id;
  final String name;
  final String specialization;
  final String hospitalId;

  DoctorModel({
    required this.id,
    required this.name,
    required this.specialization,
    required this.hospitalId,
  });

  // Method for JSON API
  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    return DoctorModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      specialization: json['specialization'] ?? '',
      hospitalId: json['hospitalId'] ?? '',
    );
  }

  // Method for JSON API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'specialization': specialization,
      'hospitalId': hospitalId,
    };
  }
} 