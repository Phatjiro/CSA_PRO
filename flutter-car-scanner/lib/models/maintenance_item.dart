class MaintenanceItem {
  final String id;
  final String vehicleId;
  final String name;           // "Oil Change", "Brake Pad", etc.
  final int intervalKm;        // Every X km (required)
  final int intervalDays;      // Every X days (required, can be large like 9999 if not used)
  final DateTime? lastDoneDate;
  final int? lastDoneKm;       // Odometer when last done
  final DateTime createdAt;

  MaintenanceItem({
    required this.id,
    required this.vehicleId,
    required this.name,
    required this.intervalKm,
    required this.intervalDays,
    this.lastDoneDate,
    this.lastDoneKm,
    required this.createdAt,
  });

  // Auto-calculate next due date
  DateTime? get nextDueDate {
    if (lastDoneDate == null) return null;
    return lastDoneDate!.add(Duration(days: intervalDays));
  }

  // Auto-calculate next due km
  int? get nextDueKm {
    if (lastDoneKm == null) return null;
    return lastDoneKm! + intervalKm;
  }

  // Is due soon? (within 30 days or 1000 km)
  bool isDueSoon(int? currentKm) {
    if (lastDoneDate == null) return false;
    
    final now = DateTime.now();
    final daysUntilDue = nextDueDate?.difference(now).inDays ?? 999;
    if (daysUntilDue <= 30) return true;
    
    if (currentKm != null && nextDueKm != null) {
      final kmUntilDue = nextDueKm! - currentKm;
      if (kmUntilDue <= 1000) return true;
    }
    
    return false;
  }

  // Is overdue?
  bool isOverdue(int? currentKm) {
    if (lastDoneDate == null) return false;
    
    final now = DateTime.now();
    if (nextDueDate != null && now.isAfter(nextDueDate!)) return true;
    
    if (currentKm != null && nextDueKm != null && currentKm >= nextDueKm!) {
      return true;
    }
    
    return false;
  }

  // Convert to Map for Hive
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicleId': vehicleId,
      'name': name,
      'intervalKm': intervalKm,
      'intervalDays': intervalDays,
      'lastDoneDate': lastDoneDate?.toIso8601String(),
      'lastDoneKm': lastDoneKm,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create from Map
  factory MaintenanceItem.fromMap(Map<String, dynamic> map) {
    return MaintenanceItem(
      id: map['id'] as String,
      vehicleId: map['vehicleId'] as String,
      name: map['name'] as String,
      intervalKm: map['intervalKm'] as int,
      intervalDays: map['intervalDays'] as int,
      lastDoneDate: map['lastDoneDate'] != null
          ? DateTime.parse(map['lastDoneDate'] as String)
          : null,
      lastDoneKm: map['lastDoneKm'] as int?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  // Create copy with updated fields
  MaintenanceItem copyWith({
    String? id,
    String? vehicleId,
    String? name,
    int? intervalKm,
    int? intervalDays,
    DateTime? lastDoneDate,
    int? lastDoneKm,
    DateTime? createdAt,
  }) {
    return MaintenanceItem(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      name: name ?? this.name,
      intervalKm: intervalKm ?? this.intervalKm,
      intervalDays: intervalDays ?? this.intervalDays,
      lastDoneDate: lastDoneDate ?? this.lastDoneDate,
      lastDoneKm: lastDoneKm ?? this.lastDoneKm,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

