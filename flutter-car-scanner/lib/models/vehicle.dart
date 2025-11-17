class Vehicle {
  final String id;
  final String? vin;
  final String? make;      // e.g., "Toyota", "Ford"
  final String? model;      // e.g., "Camry", "F-150"
  final int? year;
  final String nickname;   // User-friendly name: "My Car", "Mom's Car"
  final String? color;
  final DateTime createdAt;
  final DateTime? lastConnected;

  Vehicle({
    required this.id,
    this.vin,
    this.make,
    this.model,
    this.year,
    required this.nickname,
    this.color,
    required this.createdAt,
    this.lastConnected,
  });

  // Convert to Map for Hive storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vin': vin,
      'make': make,
      'model': model,
      'year': year,
      'nickname': nickname,
      'color': color,
      'createdAt': createdAt.toIso8601String(),
      'lastConnected': lastConnected?.toIso8601String(),
    };
  }

  // Create from Map (from Hive)
  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      id: map['id'] as String,
      vin: map['vin'] as String?,
      make: map['make'] as String?,
      model: map['model'] as String?,
      year: map['year'] as int?,
      nickname: map['nickname'] as String,
      color: map['color'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      lastConnected: map['lastConnected'] != null
          ? DateTime.parse(map['lastConnected'] as String)
          : null,
    );
  }

  // Create a copy with updated fields
  Vehicle copyWith({
    String? id,
    String? vin,
    String? make,
    String? model,
    int? year,
    String? nickname,
    String? color,
    DateTime? createdAt,
    DateTime? lastConnected,
  }) {
    return Vehicle(
      id: id ?? this.id,
      vin: vin ?? this.vin,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      nickname: nickname ?? this.nickname,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      lastConnected: lastConnected ?? this.lastConnected,
    );
  }

  // Display name (nickname or make+model+year)
  String get displayName {
    if (nickname.isNotEmpty) return nickname;
    final parts = <String>[];
    if (make != null) parts.add(make!);
    if (model != null) parts.add(model!);
    if (year != null) parts.add(year.toString());
    return parts.isEmpty ? 'Unknown Vehicle' : parts.join(' ');
  }

  // Short info for list view
  String get shortInfo {
    final parts = <String>[];
    if (make != null && model != null) {
      parts.add('$make $model');
    }
    if (year != null) {
      parts.add('($year)');
    }
    return parts.isEmpty ? 'No info' : parts.join(' ');
  }
}

