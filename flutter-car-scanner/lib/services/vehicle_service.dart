import 'package:hive_flutter/hive_flutter.dart';
import '../models/vehicle.dart';

class VehicleService {
  static const String _boxName = 'vehicles';

  static Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
  }

  // Get all vehicles
  static List<Vehicle> all() {
    if (!Hive.isBoxOpen(_boxName)) return [];
    final box = Hive.box(_boxName);
    return box.values
        .whereType<Map>()
        .map((e) {
          try {
            return Vehicle.fromMap(e.cast<String, dynamic>());
          } catch (_) {
            return null;
          }
        })
        .whereType<Vehicle>()
        .toList()
      ..sort((a, b) => b.lastConnected?.compareTo(a.lastConnected ?? DateTime(1970)) ?? 
                      a.createdAt.compareTo(b.createdAt));
  }

  // Get vehicle by ID
  static Vehicle? getById(String id) {
    if (!Hive.isBoxOpen(_boxName)) return null;
    final box = Hive.box(_boxName);
    final data = box.get(id);
    if (data == null) return null;
    try {
      return Vehicle.fromMap(Map<String, dynamic>.from(data as Map));
    } catch (_) {
      return null;
    }
  }

  // Get vehicle by VIN
  static Vehicle? getByVin(String vin) {
    final vehicles = all();
    return vehicles.firstWhere(
      (v) => v.vin?.toUpperCase() == vin.toUpperCase(),
      orElse: () => throw StateError('Vehicle not found'),
    );
  }

  // Find vehicle by VIN (returns null if not found)
  static Vehicle? findByVin(String vin) {
    try {
      return getByVin(vin);
    } catch (_) {
      return null;
    }
  }

  // Save vehicle (create or update)
  static Future<void> save(Vehicle vehicle) async {
    await init();
    final box = Hive.box(_boxName);
    await box.put(vehicle.id, vehicle.toMap());
  }

  // Delete vehicle
  static Future<void> delete(String id) async {
    if (!Hive.isBoxOpen(_boxName)) return;
    final box = Hive.box(_boxName);
    await box.delete(id);
  }

  // Update last connected timestamp
  static Future<void> updateLastConnected(String id) async {
    final vehicle = getById(id);
    if (vehicle == null) return;
    await save(vehicle.copyWith(lastConnected: DateTime.now()));
  }

  // Update VIN (auto-detect from connection)
  static Future<void> updateVin(String id, String vin) async {
    final vehicle = getById(id);
    if (vehicle == null) return;
    await save(vehicle.copyWith(vin: vin));
  }

  // Watch for changes
  static Stream<BoxEvent> watch() {
    if (!Hive.isBoxOpen(_boxName)) {
      return const Stream.empty();
    }
    final box = Hive.box(_boxName);
    return box.watch();
  }

  // Get default vehicle (first one or create one)
  static Future<Vehicle> getDefault() async {
    final vehicles = all();
    if (vehicles.isNotEmpty) {
      return vehicles.first;
    }
    // Create a default vehicle
    final defaultVehicle = Vehicle(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      nickname: 'My Vehicle',
      createdAt: DateTime.now(),
    );
    await save(defaultVehicle);
    return defaultVehicle;
  }
}

