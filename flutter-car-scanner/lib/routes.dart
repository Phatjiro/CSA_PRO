import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/connect_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/live_data_select_screen.dart';
import 'screens/acceleration_tests_screen.dart';
import 'screens/emission_tests_screen.dart';
import 'screens/mode06_screen.dart';
import 'screens/logbook_screen.dart';
import 'screens/vehicle_info_screen.dart';
import 'screens/o2_test_screen.dart';
import 'screens/battery_detection_screen.dart';
import 'screens/read_codes_screen.dart';
import 'screens/freeze_frame_screen.dart';
import 'screens/mil_status_screen.dart';
import 'screens/emission_check_screen.dart';
import 'screens/multi_vehicle_screen.dart';
import 'screens/incident_history_screen.dart';
import 'screens/ai_mechanic_screen.dart';
import 'screens/issue_forecast_screen.dart';
import 'screens/repair_cost_screen.dart';
import 'screens/security_scan_screen.dart';
import 'screens/service_tools_screen.dart';
import 'screens/vehicle_specific_data_screen.dart';
import 'screens/settings_screen.dart';
import 'services/connection_manager.dart';

class AppRoutes {
  static const String home = '/';
  static const String connect = '/connect';
  static const String dashboard = '/dashboard';
  static const String liveData = '/live-data';
  static const String acceleration = '/acceleration-tests';
  static const String emissionTests = '/emission-tests';
  static const String emissionCheck = '/emission-check';
  static const String mode06 = '/mode06';
  static const String logbook = '/logbook';
  static const String vehicleInfo = '/vehicle-info';
  static const String o2test = '/o2-test';
  static const String batteryDetection = '/battery-detection';
  static const String readCodes = '/read-codes';
  static const String freezeFrame = '/freeze-frame';
  static const String milStatus = '/mil-status';
  static const String multiVehicle = '/multi-vehicle';
  static const String incidentHistory = '/incident-history';
  static const String aiMechanic = '/ai-mechanic';
  static const String issueForecast = '/issue-forecast';
  static const String repairCost = '/repair-cost';
  static const String securityScan = '/security-scan';
  static const String vehicleSpecificData = '/vehicle-specific-data';
  static const String serviceTools = '/service-tools';
  static const String settings = '/settings';
}

class RouteGenerator {
  static Route<dynamic> generate(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case AppRoutes.connect:
        return MaterialPageRoute(builder: (_) => const ConnectScreen());
      case AppRoutes.dashboard:
        final client = ConnectionManager.instance.client;
        if (client == null) return _requireConnection();
        return MaterialPageRoute(builder: (_) => DashboardScreen(client: client));
      case AppRoutes.liveData:
        final client = ConnectionManager.instance.client;
        if (client == null) return _requireConnection();
        return MaterialPageRoute(builder: (_) => const LiveDataSelectScreen());
      case AppRoutes.acceleration:
        final client = ConnectionManager.instance.client;
        if (client == null) return _requireConnection();
        return MaterialPageRoute(builder: (_) => const AccelerationTestsScreen());
      case AppRoutes.emissionTests:
        final client = ConnectionManager.instance.client;
        if (client == null) return _requireConnection();
        return MaterialPageRoute(builder: (_) => const EmissionTestsScreen());
      case AppRoutes.emissionCheck:
        final client = ConnectionManager.instance.client;
        if (client == null) return _requireConnection();
        return MaterialPageRoute(builder: (_) => const EmissionCheckScreen());
      case AppRoutes.mode06:
        final client = ConnectionManager.instance.client;
        if (client == null) return _requireConnection();
        return MaterialPageRoute(builder: (_) => const Mode06Screen());
      case AppRoutes.logbook:
        return MaterialPageRoute(builder: (_) => const LogbookScreen());
      case AppRoutes.vehicleInfo:
        return MaterialPageRoute(builder: (_) => const VehicleInfoScreen());
      case AppRoutes.o2test:
        final client = ConnectionManager.instance.client;
        if (client == null) return _requireConnection();
        return MaterialPageRoute(builder: (_) => const O2TestScreen());
      case AppRoutes.batteryDetection:
        final client = ConnectionManager.instance.client;
        if (client == null) return _requireConnection();
        return MaterialPageRoute(builder: (_) => const BatteryDetectionScreen());
      case AppRoutes.readCodes:
        final client = ConnectionManager.instance.client;
        if (client == null) return _requireConnection();
        return MaterialPageRoute(builder: (_) => const ReadCodesScreen());
      case AppRoutes.freezeFrame:
        final client = ConnectionManager.instance.client;
        if (client == null) return _requireConnection();
        return MaterialPageRoute(builder: (_) => const FreezeFrameScreen());
      case AppRoutes.milStatus:
        final client = ConnectionManager.instance.client;
        if (client == null) return _requireConnection();
        return MaterialPageRoute(builder: (_) => const MilStatusScreen());
      case AppRoutes.multiVehicle:
        final initialTab = (settings.arguments as int?) ?? 0;
        return MaterialPageRoute(builder: (_) => MultiVehicleScreen(initialTab: initialTab));
      case AppRoutes.incidentHistory:
        return MaterialPageRoute(builder: (_) => const IncidentHistoryScreen());
      case AppRoutes.aiMechanic:
        return MaterialPageRoute(builder: (_) => const AiMechanicScreen());
      case AppRoutes.issueForecast:
        return MaterialPageRoute(builder: (_) => const IssueForecastScreen());
      case AppRoutes.repairCost:
        return MaterialPageRoute(builder: (_) => const RepairCostScreen());
      case AppRoutes.securityScan:
        return MaterialPageRoute(builder: (_) => const SecurityScanScreen());
      case AppRoutes.vehicleSpecificData:
        final client = ConnectionManager.instance.client;
        if (client == null) return _requireConnection();
        return MaterialPageRoute(builder: (_) => const VehicleSpecificDataScreen());
      case AppRoutes.serviceTools:
        return MaterialPageRoute(builder: (_) => const ServiceToolsScreen());
      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Route not found')),
          ),
        );
    }
  }

  static MaterialPageRoute _requireConnection() {
    return MaterialPageRoute(
      builder: (_) => const Scaffold(
        body: Center(child: Text('Not connected. Please CONNECT or enable Demo.')),
      ),
    );
  }
}


