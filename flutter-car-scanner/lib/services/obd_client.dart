import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models/obd_live_data.dart';

class ObdClient {
  final String host;
  final int port;

  Socket? _socket;
  final StreamController<ObdLiveData> _dataController =
      StreamController<ObdLiveData>.broadcast();
  Timer? _pollTimer;
  final StringBuffer _buffer = StringBuffer();

  ObdClient({required this.host, required this.port});

  Stream<ObdLiveData> get dataStream => _dataController.stream;

  Future<void> connect() async {
    _socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
    _socket!.listen(_onData, onDone: disconnect, onError: (_) => disconnect());

    // Basic ELM init sequence
    await _writeCommand('ATZ');
    await _writeCommand('ATE0'); // echo off
    await _writeCommand('ATL0'); // linefeeds off
    await _writeCommand('ATS0'); // spaces off
    await _writeCommand('ATH0'); // headers off
    await _writeCommand('ATSP0'); // auto protocol

    // Start polling essential PIDs every 250ms
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 250), (_) async {
      await _queryAndEmit();
    });
  }

  Future<void> disconnect() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    await _socket?.close();
    _socket = null;
  }

  bool get isConnected => _socket != null;

  Future<void> _writeCommand(String cmd) async {
    final socket = _socket;
    if (socket == null) return;
    socket.add(utf8.encode('$cmd\r'));
    await socket.flush();
  }

  void _onData(Uint8List bytes) {
    final chunk = utf8.decode(bytes);
    _buffer.write(chunk);
  }

  Future<String> _sendAndRead(String cmd) async {
    _buffer.clear();
    await _writeCommand(cmd);
    // Wait a short time for response to accumulate
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final text = _buffer.toString();
    // ELM responses may contain '>' prompt; strip
    return text.replaceAll('>', '').trim();
  }

  Future<void> _queryAndEmit() async {
    try {
      final rpmHex = await _sendAndRead('010C');
      final speedHex = await _sendAndRead('010D');
      final ectHex = await _sendAndRead('0105');

      final rpm = _parseRpm(rpmHex);
      final speed = _parseSpeed(speedHex);
      final ect = _parseCoolantTemp(ectHex);

      _dataController.add(ObdLiveData(
        engineRpm: rpm,
        vehicleSpeedKmh: speed,
        coolantTempC: ect,
      ));
    } catch (_) {
      // ignore transient parsing/transport errors
    }
  }

  static int _parseRpm(String response) {
    // Expect: 41 0C AA BB
    final parts = response.split(RegExp(r"\s+"));
    final idx = parts.indexWhere((p) => p.toUpperCase() == '41');
    // When spaces removed (ATS0), response may be like '410C1F40'
    if (idx == -1) {
      final cleaned = response.replaceAll(RegExp(r"\s+"), '');
      final i = cleaned.indexOf('410C');
      if (i >= 0 && cleaned.length >= i + 8) {
        final a = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
        final b = int.parse(cleaned.substring(i + 6, i + 8), radix: 16);
        return ((256 * a + b) ~/ 4);
      }
      return 0;
    }
    // spaced response handling
    final ocIndex = parts.indexWhere((p) => p.toUpperCase() == '0C');
    final a = int.parse(parts[ocIndex + 1], radix: 16);
    final b = int.parse(parts[ocIndex + 2], radix: 16);
    return ((256 * a + b) ~/ 4);
  }

  static int _parseSpeed(String response) {
    // Expect: 41 0D VV
    final cleaned = response.replaceAll(RegExp(r"\s+"), '');
    final i = cleaned.indexOf('410D');
    if (i >= 0 && cleaned.length >= i + 6) {
      return int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
    }
    return 0;
  }

  static int _parseCoolantTemp(String response) {
    // Expect: 41 05 VV, Temp = VV - 40
    final cleaned = response.replaceAll(RegExp(r"\s+"), '');
    final i = cleaned.indexOf('4105');
    if (i >= 0 && cleaned.length >= i + 6) {
      final v = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
      return v - 40;
    }
    return 0;
  }
}


