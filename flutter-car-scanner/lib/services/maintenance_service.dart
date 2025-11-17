import 'package:hive_flutter/hive_flutter.dart';
import '../models/maintenance_item.dart';

class MaintenanceService {
  static const String _boxName = 'maintenance';

  static Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
  }

  // Get all maintenance items for a vehicle
  static List<MaintenanceItem> getByVehicle(String vehicleId) {
    if (!Hive.isBoxOpen(_boxName)) return [];
    final box = Hive.box(_boxName);
    return box.values
        .whereType<Map>()
        .map((e) {
          try {
            final item = MaintenanceItem.fromMap(e.cast<String, dynamic>());
            return item.vehicleId == vehicleId ? item : null;
          } catch (_) {
            return null;
          }
        })
        .whereType<MaintenanceItem>()
        .toList()
      ..sort((a, b) {
        // Sort by: overdue first, then due soon, then by name
        if (a.isOverdue(null) && !b.isOverdue(null)) return -1;
        if (!a.isOverdue(null) && b.isOverdue(null)) return 1;
        if (a.isDueSoon(null) && !b.isDueSoon(null)) return -1;
        if (!a.isDueSoon(null) && b.isDueSoon(null)) return 1;
        return a.name.compareTo(b.name);
      });
  }

  // Get by ID
  static MaintenanceItem? getById(String id) {
    if (!Hive.isBoxOpen(_boxName)) return null;
    final box = Hive.box(_boxName);
    final data = box.get(id);
    if (data == null) return null;
    try {
      return MaintenanceItem.fromMap(Map<String, dynamic>.from(data as Map));
    } catch (_) {
      return null;
    }
  }

  // Save (create or update)
  static Future<void> save(MaintenanceItem item) async {
    await init();
    final box = Hive.box(_boxName);
    await box.put(item.id, item.toMap());
  }

  // Delete
  static Future<void> delete(String id) async {
    if (!Hive.isBoxOpen(_boxName)) return;
    final box = Hive.box(_boxName);
    await box.delete(id);
  }

  // Mark as done (update lastDoneDate and lastDoneKm)
  static Future<void> markDone(String id, {DateTime? date, int? km}) async {
    final item = getById(id);
    if (item == null) return;
    await save(item.copyWith(
      lastDoneDate: date ?? DateTime.now(),
      lastDoneKm: km,
    ));
  }

  // Get items due soon (within 30 days or 1000 km)
  static List<MaintenanceItem> getDueSoon(String vehicleId, {int? currentKm}) {
    final items = getByVehicle(vehicleId);
    return items.where((item) => item.isDueSoon(currentKm)).toList();
  }

  // Get overdue items
  static List<MaintenanceItem> getOverdue(String vehicleId, {int? currentKm}) {
    final items = getByVehicle(vehicleId);
    return items.where((item) => item.isOverdue(currentKm)).toList();
  }

  // Watch for changes
  static Stream<BoxEvent> watch() {
    if (!Hive.isBoxOpen(_boxName)) {
      return const Stream.empty();
    }
    final box = Hive.box(_boxName);
    return box.watch();
  }

  // Delete all for a vehicle (when vehicle is deleted)
  static Future<void> deleteByVehicle(String vehicleId) async {
    final items = getByVehicle(vehicleId);
    for (final item in items) {
      await delete(item.id);
    }
  }
}

