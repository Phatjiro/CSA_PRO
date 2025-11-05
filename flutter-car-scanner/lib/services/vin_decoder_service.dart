import 'dart:convert';
import 'package:http/http.dart' as http;

class VinDecoderService {
  static const String _baseUrl = 'https://vpic.nhtsa.dot.gov/api/vehicles/decodevin';

  /// Decode VIN using NHTSA API (FREE, no registration needed)
  static Future<Map<String, String>?> decodeVin(String vin) async {
    if (vin.isEmpty || vin == '-') return null;

    try {
      final url = Uri.parse('$_baseUrl/${vin}?format=json');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      final results = data['Results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      final decoded = <String, String>{};

      // Extract key fields
      for (final item in results) {
        final variable = item['Variable'] as String?;
        final value = item['Value'] as String?;
        
        if (variable == null || value == null || value.isEmpty || value == 'Not Applicable') {
          continue;
        }

        // Map NHTSA variables to our display names
        switch (variable) {
          case 'Make':
            decoded['Make'] = value;
            break;
          case 'Model':
            decoded['Model'] = value;
            break;
          case 'Model Year':
            decoded['Year'] = value;
            break;
          case 'Engine Number of Cylinders':
            decoded['Cylinders'] = value;
            break;
          case 'Engine Displacement (L)':
            decoded['Displacement'] = '$value L';
            break;
          case 'Engine Configuration':
            decoded['Engine Config'] = value;
            break;
          case 'Body Class':
            decoded['Body Type'] = value;
            break;
          case 'Drive Type':
            decoded['Drive Type'] = value;
            break;
          case 'Fuel Type - Primary':
            decoded['Fuel Type'] = value;
            break;
          case 'Transmission Style':
            decoded['Transmission'] = value;
            break;
          case 'Plant Country':
            decoded['Plant Country'] = value;
            break;
        }
      }

      // Combine engine info if available
      if (decoded.containsKey('Displacement') && decoded.containsKey('Cylinders')) {
        final disp = decoded['Displacement'] ?? '';
        final cyl = decoded['Cylinders'] ?? '';
        final config = decoded['Engine Config'] ?? '';
        decoded['Engine'] = '${disp} ${config} ${cyl}-cyl'.trim();
        decoded.remove('Displacement');
        decoded.remove('Cylinders');
        decoded.remove('Engine Config');
      } else if (decoded.containsKey('Displacement')) {
        decoded['Engine'] = decoded['Displacement']!;
        decoded.remove('Displacement');
      }

      return decoded.isEmpty ? null : decoded;
    } catch (e) {
      // Silent fail - return null if API fails
      return null;
    }
  }
}

