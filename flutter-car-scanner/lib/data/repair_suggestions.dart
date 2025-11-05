/// Database DTC → Repair Suggestions & Cost Estimates
/// Rule-based repair recommendations (no AI/ML)
class RepairSuggestions {
  /// Database mapping DTC codes to repair suggestions and cost estimates
  static const Map<String, Map<String, dynamic>> database = {
    // ========== ENGINE MISFIRE (P0300-P0306) ==========
    'P0300': {
      'suggestions': [
        'Check all spark plugs - replace if worn or fouled',
        'Inspect ignition coils for cracks or damage',
        'Check for vacuum leaks (common cause)',
        'Test fuel injectors for proper operation',
        'Verify MAF sensor readings are normal',
      ],
      'costRange': '\$100-400',
      'severity': 'High',
      'category': 'Engine Misfire',
    },
    'P0301': {
      'suggestions': [
        'Replace spark plug #1 (most common fix)',
        'Test ignition coil #1 - replace if faulty',
        'Check spark plug wire #1 for damage',
        'Inspect fuel injector #1 for clogs',
        'Check for vacuum leaks near cylinder 1',
      ],
      'costRange': '\$50-200',
      'severity': 'Medium',
      'category': 'Engine Misfire',
    },
    'P0302': {
      'suggestions': [
        'Replace spark plug #2',
        'Test ignition coil #2',
        'Check spark plug wire #2',
        'Inspect fuel injector #2',
      ],
      'costRange': '\$50-200',
      'severity': 'Medium',
      'category': 'Engine Misfire',
    },
    'P0303': {
      'suggestions': [
        'Replace spark plug #3',
        'Test ignition coil #3',
        'Check spark plug wire #3',
        'Inspect fuel injector #3',
      ],
      'costRange': '\$50-200',
      'severity': 'Medium',
      'category': 'Engine Misfire',
    },
    'P0304': {
      'suggestions': [
        'Replace spark plug #4',
        'Test ignition coil #4',
        'Check spark plug wire #4',
        'Inspect fuel injector #4',
      ],
      'costRange': '\$50-200',
      'severity': 'Medium',
      'category': 'Engine Misfire',
    },
    'P0305': {
      'suggestions': [
        'Replace spark plug #5',
        'Test ignition coil #5',
        'Check spark plug wire #5',
        'Inspect fuel injector #5',
      ],
      'costRange': '\$50-200',
      'severity': 'Medium',
      'category': 'Engine Misfire',
    },
    'P0306': {
      'suggestions': [
        'Replace spark plug #6',
        'Test ignition coil #6',
        'Check spark plug wire #6',
        'Inspect fuel injector #6',
      ],
      'costRange': '\$50-200',
      'severity': 'Medium',
      'category': 'Engine Misfire',
    },

    // ========== FUEL SYSTEM (P0171-P0175) ==========
    'P0171': {
      'suggestions': [
        'Check for vacuum leaks (most common cause)',
        'Inspect MAF sensor - clean or replace if dirty',
        'Check air filter - replace if clogged',
        'Test fuel pressure - may need fuel pump or filter',
        'Inspect O2 sensor (Bank 1, Sensor 1)',
      ],
      'costRange': '\$100-300',
      'severity': 'Medium',
      'category': 'Fuel System',
    },
    'P0172': {
      'suggestions': [
        'Check for stuck open fuel injector',
        'Inspect fuel pressure regulator',
        'Test MAF sensor - may be reading incorrectly',
        'Check air filter - replace if extremely dirty',
        'Inspect O2 sensor (Bank 1, Sensor 1)',
      ],
      'costRange': '\$100-300',
      'severity': 'Medium',
      'category': 'Fuel System',
    },
    'P0174': {
      'suggestions': [
        'Check for vacuum leaks (Bank 2)',
        'Inspect MAF sensor - clean or replace',
        'Check air filter',
        'Test fuel pressure',
        'Inspect O2 sensor (Bank 2, Sensor 1)',
      ],
      'costRange': '\$100-300',
      'severity': 'Medium',
      'category': 'Fuel System',
    },
    'P0175': {
      'suggestions': [
        'Check for stuck open fuel injector (Bank 2)',
        'Inspect fuel pressure regulator',
        'Test MAF sensor',
        'Inspect O2 sensor (Bank 2, Sensor 1)',
      ],
      'costRange': '\$100-300',
      'severity': 'Medium',
      'category': 'Fuel System',
    },

    // ========== CATALYST (P0420, P0430) ==========
    'P0420': {
      'suggestions': [
        'Catalytic converter may be failing (expensive)',
        'Check O2 sensor (Bank 1, Sensor 2) - often the cause',
        'Inspect for exhaust leaks before converter',
        'Verify engine is running properly (misfires can damage cat)',
        'Note: If O2 sensor is bad, replace sensor first (much cheaper)',
      ],
      'costRange': '\$200-2000',
      'severity': 'Medium',
      'category': 'Catalyst System',
    },
    'P0430': {
      'suggestions': [
        'Catalytic converter may be failing (Bank 2)',
        'Check O2 sensor (Bank 2, Sensor 2)',
        'Inspect for exhaust leaks',
        'Verify engine is running properly',
        'Note: Replace O2 sensor first if faulty (much cheaper than converter)',
      ],
      'costRange': '\$200-2000',
      'severity': 'Medium',
      'category': 'Catalyst System',
    },

    // ========== OXYGEN SENSOR (P0135, P0141, P0136) ==========
    'P0135': {
      'suggestions': [
        'O2 sensor heater circuit issue (Bank 1, Sensor 1)',
        'Check wiring harness for damage',
        'Test sensor resistance - replace if faulty',
        'Inspect for loose connections',
      ],
      'costRange': '\$100-250',
      'severity': 'Low',
      'category': 'Oxygen Sensor',
    },
    'P0141': {
      'suggestions': [
        'O2 sensor heater circuit issue (Bank 1, Sensor 2)',
        'Check wiring harness',
        'Test sensor - replace if faulty',
        'Inspect connections',
      ],
      'costRange': '\$100-250',
      'severity': 'Low',
      'category': 'Oxygen Sensor',
    },
    'P0136': {
      'suggestions': [
        'O2 sensor circuit malfunction (Bank 1, Sensor 2)',
        'Replace O2 sensor if faulty',
        'Check wiring for damage',
        'Inspect exhaust leaks near sensor',
      ],
      'costRange': '\$100-250',
      'severity': 'Low',
      'category': 'Oxygen Sensor',
    },

    // ========== EGR (P0401, P0402) ==========
    'P0401': {
      'suggestions': [
        'EGR valve may be stuck or clogged',
        'Clean EGR valve and passages',
        'Check EGR valve position sensor',
        'Inspect vacuum lines to EGR valve',
        'Test EGR solenoid if applicable',
      ],
      'costRange': '\$150-400',
      'severity': 'Medium',
      'category': 'EGR System',
    },
    'P0402': {
      'suggestions': [
        'EGR valve stuck open',
        'Clean EGR valve',
        'Check EGR valve position sensor',
        'Inspect vacuum lines',
        'Replace EGR valve if cleaning doesn\'t help',
      ],
      'costRange': '\$150-400',
      'severity': 'Medium',
      'category': 'EGR System',
    },

    // ========== EVAPORATIVE EMISSION (P0442, P0445) ==========
    'P0442': {
      'suggestions': [
        'Small leak in evaporative emission system',
        'Check gas cap - tighten or replace if damaged',
        'Inspect EVAP lines for cracks',
        'Test EVAP purge valve',
        'Check charcoal canister for damage',
      ],
      'costRange': '\$50-200',
      'severity': 'Low',
      'category': 'Evaporative System',
    },
    'P0445': {
      'suggestions': [
        'EVAP purge control valve circuit issue',
        'Test purge valve - replace if faulty',
        'Check wiring to purge valve',
        'Inspect for vacuum leaks',
      ],
      'costRange': '\$100-300',
      'severity': 'Low',
      'category': 'Evaporative System',
    },

    // ========== THROTTLE (P0121, P0221) ==========
    'P0121': {
      'suggestions': [
        'Throttle position sensor issue',
        'Clean throttle body',
        'Test TPS sensor - replace if faulty',
        'Check wiring harness',
        'Inspect throttle plate for binding',
      ],
      'costRange': '\$150-400',
      'severity': 'Medium',
      'category': 'Throttle System',
    },
    'P0221': {
      'suggestions': [
        'Throttle position sensor B circuit issue',
        'Clean throttle body',
        'Test TPS sensor',
        'Check wiring',
        'Inspect throttle plate',
      ],
      'costRange': '\$150-400',
      'severity': 'Medium',
      'category': 'Throttle System',
    },

    // ========== IGNITION COIL (P0351, P0352) ==========
    'P0351': {
      'suggestions': [
        'Ignition coil A primary/secondary circuit issue',
        'Replace ignition coil A',
        'Check spark plug wire',
        'Inspect wiring harness',
      ],
      'costRange': '\$100-300',
      'severity': 'Medium',
      'category': 'Ignition System',
    },
    'P0352': {
      'suggestions': [
        'Ignition coil B primary/secondary circuit issue',
        'Replace ignition coil B',
        'Check spark plug wire',
        'Inspect wiring',
      ],
      'costRange': '\$100-300',
      'severity': 'Medium',
      'category': 'Ignition System',
    },

    // ========== CHASSIS (C1201) ==========
    'C1201': {
      'suggestions': [
        'ABS control module issue',
        'Check ABS module connections',
        'Inspect wheel speed sensors',
        'Test ABS module - may need professional diagnosis',
        'Check ABS fuse',
      ],
      'costRange': '\$200-800',
      'severity': 'Medium',
      'category': 'Chassis',
    },

    // ========== BODY (B1318) ==========
    'B1318': {
      'suggestions': [
        'Battery voltage low',
        'Test battery - replace if weak',
        'Check alternator output',
        'Inspect battery terminals for corrosion',
        'Test charging system',
      ],
      'costRange': '\$100-400',
      'severity': 'Medium',
      'category': 'Electrical',
    },

    // ========== NETWORK (U0100, U0101) ==========
    'U0100': {
      'suggestions': [
        'Lost communication with ECM/PCM',
        'Check CAN bus wiring',
        'Inspect ECM/PCM connections',
        'Test for loose or damaged connectors',
        'May require professional diagnosis',
      ],
      'costRange': '\$200-1000',
      'severity': 'High',
      'category': 'Network',
    },
    'U0101': {
      'suggestions': [
        'Lost communication with TCM',
        'Check CAN bus wiring',
        'Inspect TCM connections',
        'Test for loose connectors',
        'May require professional diagnosis',
      ],
      'costRange': '\$200-1000',
      'severity': 'High',
      'category': 'Network',
    },
  };

  /// Get repair suggestions for a DTC code
  static Map<String, dynamic>? getSuggestions(String dtcCode) {
    return database[dtcCode.toUpperCase()];
  }

  /// Get repair suggestions list
  static List<String>? getSuggestionList(String dtcCode) {
    final data = database[dtcCode.toUpperCase()];
    if (data == null) return null;
    final suggestions = data['suggestions'];
    if (suggestions is List) {
      return suggestions.cast<String>();
    }
    return null;
  }

  /// Get cost estimate range
  static String? getCostRange(String dtcCode) {
    final data = database[dtcCode.toUpperCase()];
    return data?['costRange'] as String?;
  }

  /// Get severity level
  static String? getSeverity(String dtcCode) {
    final data = database[dtcCode.toUpperCase()];
    return data?['severity'] as String?;
  }

  /// Get category
  static String? getCategory(String dtcCode) {
    final data = database[dtcCode.toUpperCase()];
    return data?['category'] as String?;
  }

  /// Check if DTC has repair data
  static bool hasData(String dtcCode) {
    return database.containsKey(dtcCode.toUpperCase());
  }
}

