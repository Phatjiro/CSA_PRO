import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'obd_link.dart';

// BLE UART-style link for ELM327 BLE adapters.
// Defaults to Nordic UART Service UUIDs, but can be overridden.
class BleObdLink implements ObdLink {
  final String deviceId; // remoteId (MAC on Android, UUID on iOS)
  final Guid serviceUuid;
  final Guid txUuid; // write
  final Guid rxUuid; // notify

  BluetoothDevice? _device;
  BluetoothCharacteristic? _tx;
  BluetoothCharacteristic? _rx;

  final StreamController<String> _rxCtrl = StreamController.broadcast();
  bool _connected = false;

  BleObdLink({
    required this.deviceId,
    Guid? service,
    Guid? tx,
    Guid? rx,
  })  : serviceUuid = service ?? Guid("6E400001-B5A3-F393-E0A9-E50E24DCCA9E"),
        txUuid = tx ?? Guid("6E400002-B5A3-F393-E0A9-E50E24DCCA9E"),
        rxUuid = rx ?? Guid("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");

  @override
  Future<void> connect() async {
    try {
      _device = BluetoothDevice.fromId(deviceId);
      await _device!.connect(
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );
      
      final services = await _device!.discoverServices();
      if (services.isEmpty) {
        throw StateError('BLE: No GATT services found on device');
      }

      // Pick target service:
      // 1) Exact UUID match if present
      // 2) Any service that has both a writable and a notifiable characteristic
      // 3) Any service that has at least one characteristic
      // If nothing matches, fail with a clear error
      BluetoothService? targetService = services.where((s) => s.uuid == serviceUuid).cast<BluetoothService?>().firstWhere(
            (s) => s != null,
            orElse: () => null,
          );
      if (targetService == null) {
        BluetoothService? serviceWithWriteNotify;
        for (final s in services) {
          final hasWritable = s.characteristics.any((c) => c.properties.write || c.properties.writeWithoutResponse);
          final hasNotify = s.characteristics.any((c) => c.properties.notify);
          if (hasWritable && hasNotify) {
            serviceWithWriteNotify = s;
            break;
          }
        }
        targetService = serviceWithWriteNotify;
      }
      targetService ??= services.firstWhere(
        (s) => s.characteristics.isNotEmpty,
        orElse: () => services.first,
      );
      if (targetService.characteristics.isEmpty) {
        throw StateError('BLE: Target GATT service has no characteristics');
      }

      // Find TX characteristic (write)
      BluetoothCharacteristic? tx;
      for (final c in targetService.characteristics) {
        if (c.uuid == txUuid || c.properties.write || c.properties.writeWithoutResponse) {
          tx = c;
          // Prefer exact UUID match; otherwise take the first writable
          if (c.uuid == txUuid) break;
        }
      }
      if (tx == null) {
        throw StateError('BLE: No writable TX characteristic found');
      }
      _tx = tx;

      // Find RX characteristic (notify)
      BluetoothCharacteristic? rx;
      for (final c in targetService.characteristics) {
        if (c.uuid == rxUuid || c.properties.notify) {
          rx = c;
          // Prefer exact UUID match; otherwise take the first notifiable
          if (c.uuid == rxUuid) break;
        }
      }
      if (rx == null) {
        throw StateError('BLE: No notifiable RX characteristic found');
      }
      _rx = rx;

      // Enable notifications
      await _rx!.setNotifyValue(true);
      _rx!.lastValueStream.listen((data) {
        try {
          _rxCtrl.add(utf8.decode(data));
        } catch (e) {
          if (kDebugMode) {
            print('BLE RX decode error: $e');
          }
        }
      });

      _connected = true;
    } catch (e) {
      _connected = false;
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    try {
      await _rx?.setNotifyValue(false);
    } catch (_) {}
    try {
      await _device?.disconnect();
    } catch (_) {}
    _device = null;
    _tx = null;
    _rx = null;
    // Don't close stream controller, just mark as not connected
    // The stream will naturally end when device disconnects
  }

  @override
  bool get isConnected => _connected && (_device?.isConnected ?? false);

  @override
  Stream<String> get rx => _rxCtrl.stream;

  @override
  Future<void> tx(String command) async {
    if (!isConnected || _tx == null) {
      throw StateError('BLE not connected');
    }
    
    final bytes = utf8.encode('$command\r');
    
    // Prefer writeWithoutResponse for faster performance
    if (_tx!.properties.writeWithoutResponse) {
      await _tx!.write(bytes, withoutResponse: true);
    } else if (_tx!.properties.write) {
      await _tx!.write(bytes, withoutResponse: false);
    } else {
      throw StateError('TX characteristic does not support write');
    }
  }

  // Static helper: Scan for BLE devices (filter for ELM327-like names)
  static Future<List<BleScanResult>> scanOnce({
    Duration timeout = const Duration(seconds: 8),
    List<String>? nameFilters, // e.g., ['ELM327', 'OBD']
  }) async {
    try {
      // Request runtime permissions (Android)
      await _ensurePermissions();
      // Check if Bluetooth is available
      if (!await FlutterBluePlus.isSupported) {
        return [];
      }

      // Check if Bluetooth is on
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        return [];
      }

      final List<BleScanResult> results = [];
      final StreamSubscription? sub = FlutterBluePlus.scanResults.listen(
        (scanResults) {
          for (final result in scanResults) {
            final deviceName = result.device.platformName.isNotEmpty
                ? result.device.platformName
                : result.device.remoteId.toString();
            
            // Filter by name if provided
            if (nameFilters != null && nameFilters.isNotEmpty) {
              final matches = nameFilters.any((filter) =>
                  deviceName.toUpperCase().contains(filter.toUpperCase()));
              if (!matches) continue;
            }

            // Check if already added
            if (!results.any((r) => r.deviceId == result.device.remoteId.toString())) {
              results.add(BleScanResult(
                deviceId: result.device.remoteId.toString(),
                name: deviceName,
                rssi: result.rssi,
                device: result.device,
              ));
            }
          }
        },
      );

      // Start scan
      await FlutterBluePlus.startScan(timeout: timeout);
      
      // Wait for scan to complete
      await Future.delayed(timeout);
      
      // Stop scan and wait a bit for final results
      await FlutterBluePlus.stopScan();
      await Future.delayed(const Duration(milliseconds: 500));
      
      await sub?.cancel();
      
      return results;
    } catch (e) {
      if (kDebugMode) {
        print('BLE scan error: $e');
      }
      return [];
    }
  }

  static Future<void> _ensurePermissions() async {
    // On Android 12+ need BLUETOOTH_SCAN/CONNECT, below need Location
    // On iOS, system dialog will appear automatically for Bluetooth usage
    if (await Permission.bluetoothScan.isDenied) {
      await Permission.bluetoothScan.request();
    }
    if (await Permission.bluetoothConnect.isDenied) {
      await Permission.bluetoothConnect.request();
    }
    // For older Android versions BLE scan requires location
    if (await Permission.locationWhenInUse.isDenied) {
      await Permission.locationWhenInUse.request();
    }
  }

  // Progressive scan stream: emits aggregated list updates during scanning
  static Stream<List<BleScanResult>> scanProgress({
    Duration timeout = const Duration(seconds: 8),
    List<String>? nameFilters,
  }) async* {
    await _ensurePermissions();
    if (!await FlutterBluePlus.isSupported) {
      yield const <BleScanResult>[];
      return;
    }
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      yield const <BleScanResult>[];
      return;
    }

    final controller = StreamController<List<BleScanResult>>();
    final Map<String, BleScanResult> found = {};

    StreamSubscription? sub;
    sub = FlutterBluePlus.scanResults.listen((scanResults) {
      bool changed = false;
      for (final r in scanResults) {
        final deviceName = r.device.platformName.isNotEmpty
            ? r.device.platformName
            : r.device.remoteId.toString();
        if (nameFilters != null && nameFilters.isNotEmpty) {
          final matches = nameFilters.any((f) => deviceName.toUpperCase().contains(f.toUpperCase()));
          if (!matches) continue;
        }
        final id = r.device.remoteId.toString();
        final current = found[id];
        if (current == null || current.rssi != r.rssi || current.name != deviceName) {
          found[id] = BleScanResult(
            deviceId: id,
            name: deviceName,
            rssi: r.rssi,
            device: r.device,
          );
          changed = true;
        }
      }
      if (changed && !controller.isClosed) {
        controller.add(found.values.toList());
      }
    });

    await FlutterBluePlus.startScan(timeout: timeout);

    // Emit initial empty list to clear UI
    controller.add(const <BleScanResult>[]);

    // Wait for scan period, then stop and close
    Future.delayed(timeout + const Duration(milliseconds: 200)).then((_) async {
      try { await FlutterBluePlus.stopScan(); } catch (_) {}
      await sub?.cancel();
      await controller.close();
    });

    yield* controller.stream;
  }
}

// Scan result model
class BleScanResult {
  final String deviceId;
  final String? name;
  final int? rssi;
  final BluetoothDevice? device;

  const BleScanResult({
    required this.deviceId,
    this.name,
    this.rssi,
    this.device,
  });

  String get displayName => name ?? deviceId.split(':').last.toUpperCase();
}
