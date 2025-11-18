import 'package:flutter/foundation.dart';

import 'obd_client.dart';
import 'obd_link.dart';
import 'tcp_obd_link.dart';
import 'ble_obd_link.dart';
import 'demo_obd_link.dart';
import '../models/vehicle.dart';
import 'vehicle_service.dart';

enum ConnectionMode { none, tcp, ble, demo }

class ConnectionManager {
  ConnectionManager._internal();
  static final ConnectionManager instance = ConnectionManager._internal();

  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);
  final ValueNotifier<Vehicle?> currentVehicle = ValueNotifier<Vehicle?>(null);
  
  ObdClient? _client;
  ConnectionMode _mode = ConnectionMode.none;
  String? _tcpHost;
  int? _tcpPort;
  String? _bleDeviceId;

  ObdClient? get client => _client;
  Vehicle? get vehicle => currentVehicle.value;
  ConnectionMode get mode => _mode;
  String? get tcpHost => _tcpHost;
  int? get tcpPort => _tcpPort;
  String? get bleDeviceId => _bleDeviceId;
  bool get isDemoConnection => _mode == ConnectionMode.demo;

  Future<void> connect({required String host, required int port, Vehicle? vehicle}) async {
    final client = ObdClient(host: host, port: port);
    await client.connect();
    _client = client;
    currentVehicle.value = vehicle;
    isConnected.value = true;
    _mode = ConnectionMode.tcp;
    _tcpHost = host;
    _tcpPort = port;
    _bleDeviceId = null;
    
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
    _mode = ConnectionMode.tcp;
    _tcpHost = host;
    _tcpPort = port;
    _bleDeviceId = null;
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
    _mode = ConnectionMode.ble;
    _bleDeviceId = deviceId;
    _tcpHost = null;
    _tcpPort = null;
    if (vehicle != null) {
      await VehicleService.updateLastConnected(vehicle.id);
    }
  }

  Future<void> disconnect() async {
    await _client?.disconnect();
    _client = null;
    isConnected.value = false;
    currentVehicle.value = null;
    _mode = ConnectionMode.none;
    _tcpHost = null;
    _tcpPort = null;
    _bleDeviceId = null;
  }

  // New: connect via Demo transport (no hardware/emulator needed)
  Future<void> connectDemo({Vehicle? vehicle}) async {
    await disconnect();
    final client = ObdClient.withLink(DemoObdLink());
    await client.connect();
    _client = client;
    currentVehicle.value = vehicle;
    isConnected.value = true;
    _mode = ConnectionMode.demo;
    _tcpHost = null;
    _tcpPort = null;
    _bleDeviceId = null;
    if (vehicle != null) {
      await VehicleService.updateLastConnected(vehicle.id);
    }
  }
}


