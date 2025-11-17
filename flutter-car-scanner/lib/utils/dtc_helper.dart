import 'package:url_launcher/url_launcher.dart';

class DtcHelper {
  // Mapping các DTC phổ biến với mô tả ngắn gọn
  static const Map<String, String> _dtcDescriptions = {
    // Powertrain - Engine Misfire
    'P0300': 'Random/Multiple Cylinder Misfire Detected',
    'P0301': 'Cylinder 1 Misfire Detected',
    'P0302': 'Cylinder 2 Misfire Detected',
    'P0303': 'Cylinder 3 Misfire Detected',
    'P0304': 'Cylinder 4 Misfire Detected',
    'P0305': 'Cylinder 5 Misfire Detected',
    'P0306': 'Cylinder 6 Misfire Detected',
    
    // Powertrain - Fuel System
    'P0171': 'System Too Lean (Bank 1)',
    'P0172': 'System Too Rich (Bank 1)',
    'P0174': 'System Too Lean (Bank 2)',
    'P0175': 'System Too Rich (Bank 2)',
    
    // Powertrain - Catalyst
    'P0420': 'Catalyst System Efficiency Below Threshold (Bank 1)',
    'P0430': 'Catalyst System Efficiency Below Threshold (Bank 2)',
    
    // Powertrain - Oxygen Sensor
    'P0135': 'O2 Sensor Heater Circuit (Bank 1, Sensor 1)',
    'P0141': 'O2 Sensor Heater Circuit (Bank 1, Sensor 2)',
    'P0136': 'O2 Sensor Circuit (Bank 1, Sensor 2)',
    
    // Powertrain - EGR
    'P0401': 'Exhaust Gas Recirculation Flow Insufficient',
    'P0402': 'Exhaust Gas Recirculation Flow Excessive',
    
    // Powertrain - Evap
    'P0442': 'Evaporative Emission Control System Leak Detected (Small)',
    'P0445': 'Evaporative Emission Control System Purge Control Valve Circuit',
    
    // Powertrain - Throttle
    'P0121': 'Throttle/Pedal Position Sensor "A" Circuit Range/Performance',
    'P0221': 'Throttle/Pedal Position Sensor "B" Circuit Range/Performance',
    
    // Powertrain - Ignition
    'P0351': 'Ignition Coil "A" Primary/Secondary Circuit',
    'P0352': 'Ignition Coil "B" Primary/Secondary Circuit',
    
    // Chassis
    'C1201': 'ABS Control Module',
    
    // Body
    'B1318': 'Battery Voltage Low',
    
    // Network
    'U0100': 'Lost Communication with ECM/PCM "A"',
    'U0101': 'Lost Communication with TCM',
  };

  /// Lấy mô tả ngắn gọn cho DTC code
  static String getDescription(String dtcCode) {
    return _dtcDescriptions[dtcCode.toUpperCase()] ?? 
           _getGenericDescription(dtcCode);
  }

  /// Tạo mô tả generic dựa trên cấu trúc DTC code
  static String _getGenericDescription(String dtcCode) {
    if (dtcCode.length < 5) return 'Unknown DTC Code';
    
    final system = dtcCode[0];
    final systemName = _getSystemName(system);
    final digit2 = dtcCode[1];
    final last3Digits = dtcCode.substring(2);
    
    String category = '';
    switch (digit2) {
      case '0':
        category = 'Generic SAE';
        break;
      case '1':
      case '2':
      case '3':
        category = 'Manufacturer Specific';
        break;
      default:
        category = 'Unknown Category';
    }
    
    return '$systemName - $category (Code: $last3Digits)';
  }

  /// Lấy tên hệ thống từ ký tự đầu
  static String _getSystemName(String system) {
    switch (system.toUpperCase()) {
      case 'P':
        return 'Powertrain';
      case 'C':
        return 'Chassis';
      case 'B':
        return 'Body';
      case 'U':
        return 'Network';
      default:
        return 'Unknown System';
    }
  }

  /// Giải thích cách đọc DTC code
  static String getHowToRead(String dtcCode) {
    if (dtcCode.length < 5) return 'Invalid DTC format';
    
    final system = dtcCode[0].toUpperCase();
    final digit2 = dtcCode[1];
    final last3 = dtcCode.substring(2);
    
    final systemName = _getSystemName(system);
    final digit2Desc = digit2 == '0' ? 'Generic SAE' : 'Manufacturer Specific';
    
    return '$systemName → $digit2Desc → Fault: $last3';
  }

  /// Mở Google search cho DTC code
  static Future<void> searchOnGoogle(String dtcCode) async {
    final query = Uri.encodeComponent('DTC $dtcCode');
    final url = Uri.parse('https://www.google.com/search?q=$query');
    
    try {
      if (await canLaunchUrl(url)) {
        // Thử externalApplication trước để mở app browser (Chrome)
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
      } else {
        // Nếu không được, thử platformDefault
        await launchUrl(
          url,
          mode: LaunchMode.platformDefault,
        );
      }
    } catch (e) {
      // Nếu cả 2 đều fail, thử lại với platformDefault
      try {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      } catch (_) {
        // Ignore nếu vẫn không được
      }
    }
  }
}

