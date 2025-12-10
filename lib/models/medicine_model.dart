class MedicineModel {
  final String id;
  final String name;
  final String dose;
  final String frequency;
  final String type; // 'tablet' or 'syrup'
  final bool isTaken;
  // New fields for enhanced medicine tracking
  final String? dosage; // Amount + unit (e.g., "500mg", "10ml")
  final String? duration; // How long to take (e.g., "7 days", "2 weeks")
  final List<String>? times; // Specific times to take medicine
  final String? instructions; // Instructions like "after food"
  final DateTime? startDate; // When to start taking
  final DateTime? endDate; // When to stop taking
  final DateTime? completedAt; // When medicine was taken
  final List<Map<String, dynamic>>? dailyTaken; // Daily tracking records
  final DateTime? lastTakenAt; // Last time medicine was taken

  // Pharmacy inventory fields
  final int? stock; // Current stock quantity
  final int? minStock; // Minimum stock threshold
  final int? maxStock; // Maximum stock capacity
  final double? unitPrice; // Price per unit
  final double? sellingPrice; // Selling price to users
  final String? expiryDate; // Expiry date (YYYY-MM-DD format)
  final String? supplier; // Medicine supplier
  final String? batchNumber; // Batch number
  final String? status; // 'In Stock', 'Low Stock', 'Out of Stock'
  final String? lastUpdated; // Last update date
  final String? pharmacyId; // ID of the pharmacy that owns this medicine
  final String? category; // Medicine category (Pain Relief, Antibiotic, etc.)

  MedicineModel({
    required this.id,
    required this.name,
    required this.dose,
    required this.frequency,
    required this.type,
    this.isTaken = false,
    this.dosage,
    this.duration,
    this.times,
    this.instructions,
    this.startDate,
    this.endDate,
    this.completedAt,
    this.dailyTaken,
    this.lastTakenAt,
    // Pharmacy inventory fields
    this.stock,
    this.minStock,
    this.maxStock,
    this.unitPrice,
    this.sellingPrice,
    this.expiryDate,
    this.supplier,
    this.batchNumber,
    this.status,
    this.lastUpdated,
    this.pharmacyId,
    this.category,
  });

  // Method for JSON API
  factory MedicineModel.fromJson(Map<String, dynamic> json) {
    return MedicineModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? 'No Name',
      dose: json['dose'] ?? 'N/A',
      frequency: json['frequency'] ?? 'N/A',
      type: json['type'] ?? 'tablet',
      isTaken: json['isTaken'] ?? false,
      dosage: json['dosage'],
      duration: json['duration'],
      times: json['times'] != null ? List<String>.from(json['times']) : null,
      instructions: json['instructions'],
      startDate:
          json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      dailyTaken: json['dailyTaken'] != null
          ? List<Map<String, dynamic>>.from(json['dailyTaken'])
          : null,
      lastTakenAt: json['lastTakenAt'] != null
          ? DateTime.parse(json['lastTakenAt'])
          : null,
      // Pharmacy inventory fields
      stock: json['stock'],
      minStock: json['minStock'],
      maxStock: json['maxStock'],
      unitPrice: json['unitPrice']?.toDouble(),
      sellingPrice: json['sellingPrice']?.toDouble(),
      expiryDate: json['expiryDate'],
      supplier: json['supplier'],
      batchNumber: json['batchNumber'],
      status: json['status'],
      lastUpdated: json['lastUpdated'],
      pharmacyId: json['pharmacyId'],
      category: json['category'],
    );
  }

  // Method for JSON API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'dose': dose,
      'frequency': frequency,
      'type': type,
      'isTaken': isTaken,
      'dosage': dosage,
      'duration': duration,
      'times': times,
      'instructions': instructions,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'dailyTaken': dailyTaken,
      'lastTakenAt': lastTakenAt?.toIso8601String(),
      // Pharmacy inventory fields
      'stock': stock,
      'minStock': minStock,
      'maxStock': maxStock,
      'unitPrice': unitPrice,
      'sellingPrice': sellingPrice,
      'expiryDate': expiryDate,
      'supplier': supplier,
      'batchNumber': batchNumber,
      'status': status,
      'lastUpdated': lastUpdated,
      'pharmacyId': pharmacyId,
      'category': category,
    };
  }

  // Copy with method for easy updates
  MedicineModel copyWith({
    String? id,
    String? name,
    String? dose,
    String? frequency,
    String? type,
    bool? isTaken,
    String? dosage,
    String? duration,
    List<String>? times,
    String? instructions,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? completedAt,
    List<Map<String, dynamic>>? dailyTaken,
    DateTime? lastTakenAt,
    // Pharmacy inventory fields
    int? stock,
    int? minStock,
    int? maxStock,
    double? unitPrice,
    String? expiryDate,
    String? supplier,
    String? batchNumber,
    String? status,
    String? lastUpdated,
    String? pharmacyId,
    String? category,
  }) {
    return MedicineModel(
      id: id ?? this.id,
      name: name ?? this.name,
      dose: dose ?? this.dose,
      frequency: frequency ?? this.frequency,
      type: type ?? this.type,
      isTaken: isTaken ?? this.isTaken,
      dosage: dosage ?? this.dosage,
      duration: duration ?? this.duration,
      times: times ?? this.times,
      instructions: instructions ?? this.instructions,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      completedAt: completedAt ?? this.completedAt,
      dailyTaken: dailyTaken ?? this.dailyTaken,
      lastTakenAt: lastTakenAt ?? this.lastTakenAt,
      // Pharmacy inventory fields
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      maxStock: maxStock ?? this.maxStock,
      unitPrice: unitPrice ?? this.unitPrice,
      expiryDate: expiryDate ?? this.expiryDate,
      supplier: supplier ?? this.supplier,
      batchNumber: batchNumber ?? this.batchNumber,
      status: status ?? this.status,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      pharmacyId: pharmacyId ?? this.pharmacyId,
      category: category ?? this.category,
    );
  }

  // Check if medicine is taken today
  bool get isTakenToday {
    if (dailyTaken == null || dailyTaken!.isEmpty) return false;

    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    return dailyTaken!.any((record) {
      final recordDate = DateTime.parse(record['date']);
      final recordStart =
          DateTime(recordDate.year, recordDate.month, recordDate.day);
      return recordStart.isAtSameMomentAs(todayStart) &&
          record['action'] == 'taken';
    });
  }

  // Get today's taken record
  Map<String, dynamic>? get todayTakenRecord {
    if (dailyTaken == null || dailyTaken!.isEmpty) return null;

    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    try {
      return dailyTaken!.firstWhere((record) {
        final recordDate = DateTime.parse(record['date']);
        final recordStart =
            DateTime(recordDate.year, recordDate.month, recordDate.day);
        return recordStart.isAtSameMomentAs(todayStart) &&
            record['action'] == 'taken';
      });
    } catch (e) {
      return null;
    }
  }

  // Pharmacy inventory helper methods
  bool get isLowStock {
    if (stock == null || minStock == null) return false;
    return stock! <= minStock!;
  }

  bool get isOutOfStock {
    if (stock == null) return false;
    return stock! <= 0;
  }

  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    try {
      final expiry = DateTime.parse(expiryDate!);
      final now = DateTime.now();
      final daysUntilExpiry = expiry.difference(now).inDays;
      return daysUntilExpiry <= 30 && daysUntilExpiry >= 0;
    } catch (e) {
      return false;
    }
  }

  bool get isExpired {
    if (expiryDate == null) return false;
    try {
      final expiry = DateTime.parse(expiryDate!);
      final now = DateTime.now();
      return expiry.isBefore(now);
    } catch (e) {
      return false;
    }
  }

  String get stockStatus {
    if (isOutOfStock) return 'Out of Stock';
    if (isLowStock) return 'Low Stock';
    return 'In Stock';
  }

  double? get totalValue {
    if (stock == null || unitPrice == null) return null;
    return stock! * unitPrice!;
  }

  // Helper method to format expiry date for display
  String get formattedExpiryDate {
    if (expiryDate == null) return 'Not specified';
    try {
      final expiry = DateTime.parse(expiryDate!);
      return '${expiry.day.toString().padLeft(2, '0')}/${expiry.month.toString().padLeft(2, '0')}/${expiry.year}';
    } catch (e) {
      return expiryDate!;
    }
  }

  // Helper method to get days until expiry
  int get daysUntilExpiry {
    if (expiryDate == null) return -1;
    try {
      final expiry = DateTime.parse(expiryDate!);
      return expiry.difference(DateTime.now()).inDays;
    } catch (e) {
      return -1;
    }
  }
}
