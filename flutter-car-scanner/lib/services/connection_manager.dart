import 'package:flutter/foundation.dart';

import 'obd_client.dart';
import 'obd_link.dart';
import 'tcp_obd_link.dart';
import 'ble_obd_link.dart';
import '../models/vehicle.dart';
import 'vehicle_service.dart';

class ConnectionManager {
  ConnectionManager._internal();
  static final ConnectionManager instance = ConnectionManager._internal();

  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);
  final ValueNotifier<Vehicle?> currentVehicle = ValueNotifier<Vehicle?>(null);
  
  ObdClient? _client;

  ObdClient? get client => _client;
  Vehicle? get vehicle => currentVehicle.value;

  Future<void> connect({required String host, required int port, Vehicle? vehicle}) async {
    final client = ObdClient(host: host, port: port);
    await client.connect();
    _client = client;
    currentVehicle.value = vehicle;
    isConnected.value = true;
    
    // Update vehicle's last connected timestamp
    if (vehicle != null) {
      await VehicleService.updateLastConnected(vehicle.id);
    }
  }

  // New: connect via TCP transport
  Future<void> connectTcp({required String host, required int port, Vehicle? vehicle}) async {
    await disconnect();
    final client = ObdClient.withLink(TcpObdLink(host: host, port: port));
    await client.connect();
    _client = client;
    currentVehicle.value = vehicle;
    isConnected.value = true;
    if (vehicle != null) {
      await VehicleService.updateLastConnected(vehicle.id);
    }
  }

  // New: connect via BLE transport (deviceId from scan)
  Future<void> connectBle({required String deviceId, Vehicle? vehicle}) async {
    await disconnect();
    final client = ObdClient.withLink(BleObdLink(deviceId: deviceId));
    await client.connect();
    _client = client;
    currentVehicle.value = vehicle;
    isConnected.value = true;
    if (vehicle != null) {
      await VehicleService.updateLastConnected(vehicle.id);
    }
  }

  Future<void> disconnect() async {
    await _client?.disconnect();
    _client = null;
    isConnected.value = false;
    currentVehicle.value = null;
  }
}


