// Templates for common maintenance types - simple for everyday users
class MaintenanceTemplate {
  final String name;
  final int intervalKm;
  final int intervalDays;

  const MaintenanceTemplate({
    required this.name,
    required this.intervalKm,
    required this.intervalDays,
  });
}

class MaintenanceTemplates {
  static const Map<String, MaintenanceTemplate> templates = {
    'oil_change': MaintenanceTemplate(
      name: 'Oil Change',
      intervalKm: 5000,
      intervalDays: 180, // 6 months
    ),
    'brake_pad': MaintenanceTemplate(
      name: 'Brake Pad',
      intervalKm: 50000,
      intervalDays: 3650, // ~10 years (not time-based)
    ),
    'tire_rotation': MaintenanceTemplate(
      name: 'Tire Rotation',
      intervalKm: 10000,
      intervalDays: 365, // 1 year
    ),
    'air_filter': MaintenanceTemplate(
      name: 'Air Filter',
      intervalKm: 20000,
      intervalDays: 365, // 1 year
    ),
    'battery': MaintenanceTemplate(
      name: 'Battery Check',
      intervalKm: 100000, // Not km-based
      intervalDays: 730, // 2 years
    ),
    'coolant': MaintenanceTemplate(
      name: 'Coolant Flush',
      intervalKm: 60000,
      intervalDays: 1095, // 3 years
    ),
    'spark_plug': MaintenanceTemplate(
      name: 'Spark Plugs',
      intervalKm: 80000,
      intervalDays: 3650, // ~10 years
    ),
    'transmission': MaintenanceTemplate(
      name: 'Transmission Fluid',
      intervalKm: 60000,
      intervalDays: 1825, // 5 years
    ),
  };

  static List<String> get templateKeys => templates.keys.toList();
  static List<String> get templateNames => templates.values.map((t) => t.name).toList();

  static MaintenanceTemplate? getTemplate(String key) {
    return templates[key];
  }
}

