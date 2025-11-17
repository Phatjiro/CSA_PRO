import '../services/battery_history_service.dart';
import '../services/log_service.dart';

/// Simple trend analysis for issue forecasting (no ML)
class TrendAnalyzer {
  /// Analyze battery voltage trend
  /// Returns warning message if significant decrease detected
  static String? analyzeBatteryTrend({String? vehicleId}) {
    final history = BatteryHistoryService.getHistory(vehicleId: vehicleId);
    
    if (history.length < 10) return null; // Need at least 10 readings
    
    // Get recent vs old readings (last 10 vs first 10)
    final recent = history.length > 10 
        ? history.sublist(history.length - 10)
        : history.sublist(history.length ~/ 2);
    final old = history.length > 20
        ? history.sublist(0, 10)
        : history.sublist(0, history.length ~/ 2);
    
    // Calculate averages
    final recentAvg = recent.map((r) => r.voltage).reduce((a, b) => a + b) / recent.length;
    final oldAvg = old.map((r) => r.voltage).reduce((a, b) => a + b) / old.length;
    
    final diff = oldAvg - recentAvg;
    
    // Warning if voltage decreased by more than 0.3V
    if (diff > 0.3) {
      return 'Battery voltage has decreased by ${diff.toStringAsFixed(1)}V over time. Consider inspection.';
    }
    
    // Warning if recent voltage is consistently low
    if (recentAvg < 12.0 && recent.every((r) => r.voltage < 12.5)) {
      return 'Battery voltage consistently low (${recentAvg.toStringAsFixed(1)}V). Battery may need replacement.';
    }
    
    return null;
  }

  /// Analyze DTC recurrence
  /// Returns warning if same DTC appears multiple times
  static List<String> analyzeDtcRecurrence({String? vehicleId}) {
    final logs = LogService.all(vehicleId: vehicleId);
    final warnings = <String>[];
    
    // Extract DTC codes from logbook
    final dtcCounts = <String, int>{};
    final dtcTimestamps = <String, List<DateTime>>{};
    
    for (final log in logs) {
      if (log['type'] == 'read_codes' || log['type'] == 'dtc_read') {
        final dtcs = log['dtcs'] as List<dynamic>?;
        if (dtcs != null) {
          final timestampStr = log['ts'] as String?;
          final timestamp = timestampStr != null 
              ? DateTime.tryParse(timestampStr) ?? DateTime.now()
              : DateTime.now();
          
          for (final dtc in dtcs) {
            if (dtc is String && dtc.isNotEmpty) {
              dtcCounts[dtc] = (dtcCounts[dtc] ?? 0) + 1;
              dtcTimestamps[dtc] ??= [];
              dtcTimestamps[dtc]!.add(timestamp);
            }
          }
        }
      }
    }
    
    // Check for recurring DTCs
    for (final entry in dtcCounts.entries) {
      final dtc = entry.key;
      final count = entry.value;
      
      if (count >= 3) {
        final timestamps = dtcTimestamps[dtc] ?? [];
        timestamps.sort();
        final firstOccurrence = timestamps.first;
        final lastOccurrence = timestamps.last;
        final daysDiff = lastOccurrence.difference(firstOccurrence).inDays;
        
        String message;
        if (daysDiff > 0) {
          message = 'DTC $dtc has appeared $count times over $daysDiff days. May indicate persistent issue.';
        } else {
          message = 'DTC $dtc has appeared $count times. May indicate persistent issue.';
        }
        
        warnings.add(message);
      }
    }
    
    return warnings;
  }

  /// Check for battery charging issues
  static String? analyzeBatteryCharging({String? vehicleId}) {
    final history = BatteryHistoryService.getHistory(vehicleId: vehicleId, limit: 50);
    
    if (history.length < 5) return null;
    
    // Check recent readings when engine is running
    final recentRunning = history
        .where((r) => r.isEngineRunning && r.isCharging != null)
        .toList();
    
    if (recentRunning.length < 5) return null;
    
    // Check if not charging when engine is running
    final notChargingCount = recentRunning.where((r) => r.isCharging == false).length;
    final notChargingRatio = notChargingCount / recentRunning.length;
    
    if (notChargingRatio > 0.5) {
      return 'Battery not charging properly when engine is running. Alternator may need inspection.';
    }
    
    return null;
  }

  /// Get all forecasts/warnings
  static Map<String, dynamic> getAllForecasts({String? vehicleId}) {
    final forecasts = <String, dynamic>{
      'batteryTrend': analyzeBatteryTrend(vehicleId: vehicleId),
      'batteryCharging': analyzeBatteryCharging(vehicleId: vehicleId),
      'dtcRecurrence': analyzeDtcRecurrence(vehicleId: vehicleId),
    };
    
    return forecasts;
  }

  /// Get summary count of active warnings
  static int getWarningCount({String? vehicleId}) {
    final forecasts = getAllForecasts(vehicleId: vehicleId);
    int count = 0;
    
    if (forecasts['batteryTrend'] != null) count++;
    if (forecasts['batteryCharging'] != null) count++;
    count += (forecasts['dtcRecurrence'] as List).length;
    
    return count;
  }
}

