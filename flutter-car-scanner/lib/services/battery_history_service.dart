import 'package:hive_flutter/hive_flutter.dart';
import '../models/battery_reading.dart';
import '../services/connection_manager.dart';

class BatteryHistoryService {
  static const String boxName = 'batteryHistory';
  static Box<BatteryReading>? _box;

  static Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BatteryReadingAdapter());
    }
    if (!Hive.isBoxOpen(boxName)) {
      _box = await Hive.openBox<BatteryReading>(boxName);
    } else {
      _box = Hive.box<BatteryReading>(boxName);
    }
  }

  static Future<void> addReading(double voltage, int engineRpm, {String? vehicleId}) async {
    await init();
    final vId = vehicleId ?? ConnectionManager.instance.vehicle?.id ?? 'default';
    
    // Determine charging status (only when engine is running)
    bool? isCharging;
    if (engineRpm > 0) {
      isCharging = voltage >= 13.5; // Charging if voltage >= 13.5V when engine ON
    }

    final reading = BatteryReading(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      vehicleId: vId,
      voltage: voltage,
      engineRpm: engineRpm,
      timestamp: DateTime.now(),
      isCharging: isCharging,
    );

    await _box!.put(reading.id, reading);

    // Keep only last 1000 readings per vehicle (prevent database bloat)
    final allReadings = _box!.values
        .where((r) => r.vehicleId == vId)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // newest first

    if (allReadings.length > 1000) {
      for (int i = 1000; i < allReadings.length; i++) {
        await _box!.delete(allReadings[i].id);
      }
    }
  }

  static List<BatteryReading> getHistory({String? vehicleId, int? limit}) {
    if (!Hive.isBoxOpen(boxName)) return [];
    final vId = vehicleId ?? ConnectionManager.instance.vehicle?.id;
    
    final box = Hive.box<BatteryReading>(boxName);
    var readings = box.values
        .where((r) => vId == null || r.vehicleId == vId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp)); // oldest first for chart
    
    if (limit != null && readings.length > limit) {
      readings = readings.sublist(readings.length - limit);
    }
    
    return readings;
  }

  static Future<void> clearHistory({String? vehicleId}) async {
    await init();
    final vId = vehicleId ?? ConnectionManager.instance.vehicle?.id;
    final box = Hive.box<BatteryReading>(boxName);
    
    if (vId != null) {
      final toDelete = box.values
          .where((r) => r.vehicleId == vId)
          .map((r) => r.id)
          .toList();
      for (final id in toDelete) {
        await box.delete(id);
      }
    } else {
      await box.clear();
    }
  }

  static Stream<BoxEvent> watch() {
    if (!Hive.isBoxOpen(boxName)) {
      return const Stream.empty(); // Return empty stream if box not open
    }
    final box = Hive.box<BatteryReading>(boxName);
    return box.watch();
  }
}

