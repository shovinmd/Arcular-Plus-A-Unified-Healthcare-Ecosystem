class ReportModel {
  final String id;
  final String name;
  final String url;
  final String type; // 'pdf', 'image'
  final DateTime uploadedAt;
  final String? category;
  final DateTime? createdAt;
  final int? fileSize; // bytes
  final String? mimeType;
  final String? uploadedBy;

  ReportModel({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    required this.uploadedAt,
    this.category,
    this.createdAt,
    this.fileSize,
    this.mimeType,
    this.uploadedBy,
  });

  // Method for JSON API
  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      // Prefer Mongo _id, fallback to id
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Untitled Report').toString(),
      url: (json['url'] ?? '').toString(),
      type: (json['type'] ?? 'pdf').toString(),
      uploadedAt: DateTime.parse(
        (json['uploadedAt'] ?? json['createdAt'] ?? DateTime.now().toIso8601String()).toString(),
      ),
      category: json['category']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      fileSize: json['fileSize'] is int
          ? json['fileSize'] as int
          : int.tryParse((json['fileSize'] ?? '').toString()),
      mimeType: json['mimeType']?.toString(),
      uploadedBy: json['uploadedBy']?.toString(),
    );
  }

  // Method for JSON API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'type': type,
      'uploadedAt': uploadedAt.toIso8601String(),
      'category': category,
      'createdAt': createdAt?.toIso8601String(),
      'fileSize': fileSize,
      'mimeType': mimeType,
      'uploadedBy': uploadedBy,
    };
  }
} 