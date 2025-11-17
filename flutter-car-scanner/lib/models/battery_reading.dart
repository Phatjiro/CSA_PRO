import 'package:hive/hive.dart';

part 'battery_reading.g.dart';

@HiveType(typeId: 4)
class BatteryReading extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String vehicleId;

  @HiveField(2)
  final double voltage;

  @HiveField(3)
  final int engineRpm;

  @HiveField(4)
  final DateTime timestamp;

  @HiveField(5)
  final bool? isCharging; // null if engine OFF, true/false if engine ON

  BatteryReading({
    required this.id,
    required this.vehicleId,
    required this.voltage,
    required this.engineRpm,
    required this.timestamp,
    this.isCharging,
  });

  bool get isEngineRunning => engineRpm > 0;

  String get chargingStatus {
    if (!isEngineRunning) return 'Engine OFF';
    if (isCharging == true) return 'Charging';
    if (isCharging == false) return 'Not Charging';
    return 'Unknown';
  }
}

