import 'package:hive_flutter/hive_flutter.dart';

class LogService {
  static const String _boxName = 'logbook';

  static Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
  }

  static Future<void> add(Map<String, dynamic> entry, {String? vehicleId}) async {
    await init();
    entry['ts'] ??= DateTime.now().toIso8601String();
    if (vehicleId != null) {
      entry['vehicleId'] = vehicleId;
    }
    final box = Hive.box(_boxName);
    await box.add(entry);
  }

  static List<Map<String, dynamic>> all({String? vehicleId}) {
    if (!Hive.isBoxOpen(_boxName)) return const [];
    final box = Hive.box(_boxName);
    final allEntries = box.values
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList()
        .reversed
        .toList();
    
    // Filter by vehicleId if provided
    if (vehicleId != null) {
      return allEntries.where((e) => e['vehicleId'] == vehicleId).toList();
    }
    
    return allEntries;
  }

  static Future<void> clear() async {
    if (!Hive.isBoxOpen(_boxName)) return;
    final box = Hive.box(_boxName);
    await box.clear();
  }

  static Stream<BoxEvent> watch() {
    final box = Hive.box(_boxName);
    return box.watch();
  }
}


