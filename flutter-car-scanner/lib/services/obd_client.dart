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
  Timer? _idleTimer;
  Completer<void>? _idleCompleter;

  ObdClient({required this.host, required this.port});

  Stream<ObdLiveData> get dataStream => _dataController.stream;

  Future<String> requestPid(String pid) async {
    return _sendAndRead(pid);
  }

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
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(milliseconds: 40), () {
      _idleCompleter?.complete();
      _idleCompleter = null;
    });
  }

  Future<String> _sendAndRead(String cmd) async {
    _buffer.clear();
    await _writeCommand(cmd);
    // Chờ đến khi không còn dữ liệu mới (idle) hoặc timeout
    _idleCompleter = Completer<void>();
    await Future.any([
      _idleCompleter!.future,
      Future<void>.delayed(const Duration(milliseconds: 300)),
    ]);
    final text = _buffer.toString();
    // ELM responses may contain '>' prompt; strip
    return text.replaceAll('>', '').trim();
  }

  Future<void> _queryAndEmit() async {
    try {
      // Core PIDs
      final rpmHex = await _sendAndRead('010C');
      final speedHex = await _sendAndRead('010D');
      final ectHex = await _sendAndRead('0105');
      final iat = _parseIntakeTemp(await _sendAndRead('010F'));
      final thr = _parseThrottle(await _sendAndRead('0111'));
      final fuel = _parseFuel(await _sendAndRead('012F'));
      final load = _parsePercent(await _sendAndRead('0104'));
      final map = _parseSingleByte(await _sendAndRead('010B'));
      final baro = _parseSingleByte(await _sendAndRead('0133'));
      final maf = _parseMaf(await _sendAndRead('0110'));
      final voltage = _parseVoltage(await _sendAndRead('0142'));
      final ambient = _parseAmbient(await _sendAndRead('0146'));
      final lambda = _parseLambda(await _sendAndRead('015E'));

      // Additional PIDs
      final fuelSystemStatus = _parseSingleByte(await _sendAndRead('0103'));
      final timingAdvance = _parseTimingAdvance(await _sendAndRead('010E'));
      final runtimeSinceStart = _parseTwoBytes(await _sendAndRead('011F'));
      final distanceWithMIL = _parseTwoBytes(await _sendAndRead('0121'));
      final commandedPurge = _parseSingleByte(await _sendAndRead('012E'));
      final warmupsSinceClear = _parseSingleByte(await _sendAndRead('0130'));
      final distanceSinceClear = _parseTwoBytes(await _sendAndRead('0131'));
      final catalystTemp = _parseTwoBytes(await _sendAndRead('013C'));
      final absoluteLoad = _parseSingleByte(await _sendAndRead('0143'));
      final commandedEquivRatio = _parseTwoBytesDouble(await _sendAndRead('0144'));
      final relativeThrottle = _parseSingleByte(await _sendAndRead('0145'));
      final absoluteThrottleB = _parseSingleByte(await _sendAndRead('0147'));
      final absoluteThrottleC = _parseSingleByte(await _sendAndRead('0148'));
      final pedalPositionD = _parseSingleByte(await _sendAndRead('0149'));
      final pedalPositionE = _parseSingleByte(await _sendAndRead('014A'));
      final pedalPositionF = _parseSingleByte(await _sendAndRead('014B'));
      final commandedThrottleActuator = _parseSingleByte(await _sendAndRead('014C'));
      final timeRunWithMIL = _parseTwoBytes(await _sendAndRead('014D'));
      final timeSinceCodesCleared = _parseTwoBytes(await _sendAndRead('014E'));
      final maxEquivRatio = _parseTwoBytesDouble(await _sendAndRead('014F'));
      final maxAirFlow = _parseTwoBytes(await _sendAndRead('0150'));
      final fuelType = _parseSingleByte(await _sendAndRead('0151'));
      final ethanolFuel = _parseSingleByte(await _sendAndRead('0152'));
      final absEvapPressure = _parseTwoBytes(await _sendAndRead('0153'));
      final evapPressure = _parseTwoBytes(await _sendAndRead('0154'));
      final shortTermO2Trim1 = _parseFuelTrim(await _sendAndRead('0155'));
      final longTermO2Trim1 = _parseFuelTrim(await _sendAndRead('0156'));
      final shortTermO2Trim2 = _parseFuelTrim(await _sendAndRead('0157'));
      final longTermO2Trim2 = _parseFuelTrim(await _sendAndRead('0158'));
      final shortTermO2Trim3 = _parseFuelTrim(await _sendAndRead('0159'));
      final longTermO2Trim3 = _parseFuelTrim(await _sendAndRead('015A'));
      final shortTermO2Trim4 = _parseFuelTrim(await _sendAndRead('015B'));
      final longTermO2Trim4 = _parseFuelTrim(await _sendAndRead('015C'));
      final catalystTemp1 = _parseTwoBytes(await _sendAndRead('015D'));
      final catalystTemp2 = _parseTwoBytes(await _sendAndRead('015F'));
      final catalystTemp3 = _parseTwoBytes(await _sendAndRead('0160'));
      final catalystTemp4 = _parseTwoBytes(await _sendAndRead('0160')); // Using same as 3
      final fuelPressure = _parseTwoBytes(await _sendAndRead('010A'));
      final shortTermFuelTrim1 = _parseFuelTrim(await _sendAndRead('0106'));
      final longTermFuelTrim1 = _parseFuelTrim(await _sendAndRead('0107'));
      final shortTermFuelTrim2 = _parseFuelTrim(await _sendAndRead('0108'));
      final longTermFuelTrim2 = _parseFuelTrim(await _sendAndRead('0109'));

      final rpm = _parseRpm(rpmHex);
      final speed = _parseSpeed(speedHex);
      final ect = _parseCoolantTemp(ectHex);

      final current = ObdLiveData(
        engineRpm: rpm == 0 && _likelyInvalid(rpmHex) ? (_last?.engineRpm ?? 0) : rpm,
        vehicleSpeedKmh: speed == 0 && _likelyInvalid(speedHex) ? (_last?.vehicleSpeedKmh ?? 0) : speed,
        coolantTempC: ect == 0 && _likelyInvalid(ectHex) ? (_last?.coolantTempC ?? 0) : ect,
        intakeTempC: iat,
        throttlePositionPercent: thr,
        fuelLevelPercent: fuel,
        engineLoadPercent: load,
        mapKpa: map,
        baroKpa: baro,
        mafGs: maf,
        voltageV: voltage,
        ambientTempC: ambient,
        lambda: lambda,
        fuelSystemStatus: fuelSystemStatus,
        timingAdvance: timingAdvance,
        runtimeSinceStart: runtimeSinceStart,
        distanceWithMIL: distanceWithMIL,
        commandedPurge: commandedPurge,
        warmupsSinceClear: warmupsSinceClear,
        distanceSinceClear: distanceSinceClear,
        catalystTemp: catalystTemp,
        absoluteLoad: absoluteLoad,
        commandedEquivRatio: commandedEquivRatio,
        relativeThrottle: relativeThrottle,
        absoluteThrottleB: absoluteThrottleB,
        absoluteThrottleC: absoluteThrottleC,
        pedalPositionD: pedalPositionD,
        pedalPositionE: pedalPositionE,
        pedalPositionF: pedalPositionF,
        commandedThrottleActuator: commandedThrottleActuator,
        timeRunWithMIL: timeRunWithMIL,
        timeSinceCodesCleared: timeSinceCodesCleared,
        maxEquivRatio: maxEquivRatio,
        maxAirFlow: maxAirFlow,
        fuelType: fuelType,
        ethanolFuel: ethanolFuel,
        absEvapPressure: absEvapPressure,
        evapPressure: evapPressure,
        shortTermO2Trim1: shortTermO2Trim1,
        longTermO2Trim1: longTermO2Trim1,
        shortTermO2Trim2: shortTermO2Trim2,
        longTermO2Trim2: longTermO2Trim2,
        shortTermO2Trim3: shortTermO2Trim3,
        longTermO2Trim3: longTermO2Trim3,
        shortTermO2Trim4: shortTermO2Trim4,
        longTermO2Trim4: longTermO2Trim4,
        catalystTemp1: catalystTemp1,
        catalystTemp2: catalystTemp2,
        catalystTemp3: catalystTemp3,
        catalystTemp4: catalystTemp4,
        fuelPressure: fuelPressure,
        shortTermFuelTrim1: shortTermFuelTrim1,
        longTermFuelTrim1: longTermFuelTrim1,
        shortTermFuelTrim2: shortTermFuelTrim2,
        longTermFuelTrim2: longTermFuelTrim2,
      );
      _last = current;
      _dataController.add(current);
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

  static int _parseIntakeTemp(String response) {
    // 41 0F VV ; TempC = VV - 40
    final cleaned = response.replaceAll(RegExp(r"\s+"), '');
    final i = cleaned.indexOf('410F');
    if (i >= 0 && cleaned.length >= i + 6) {
      final v = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
      return v - 40;
    }
    return 0;
  }

  static int _parseThrottle(String response) {
    // 41 11 VV ; percent = 100*VV/255
    final cleaned = response.replaceAll(RegExp(r"\s+"), '');
    final i = cleaned.indexOf('4111');
    if (i >= 0 && cleaned.length >= i + 6) {
      final v = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
      return ((v * 100) / 255).round();
    }
    return 0;
  }

  static int _parseFuel(String response) {
    // 41 2F VV ; percent = 100*VV/255
    final cleaned = response.replaceAll(RegExp(r"\s+"), '');
    final i = cleaned.indexOf('412F');
    if (i >= 0 && cleaned.length >= i + 6) {
      final v = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
      return ((v * 100) / 255).round();
    }
    return 0;
  }

  static int _parsePercent(String response) {
    final cleaned = response.replaceAll(RegExp(r"\s+"), '');
    final i = cleaned.indexOf('4104');
    if (i >= 0 && cleaned.length >= i + 6) {
      final v = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
      return ((v * 100) / 255).round();
    }
    return 0;
  }

  static int _parseSingleByte(String response) {
    final cleaned = response.replaceAll(RegExp(r"\s+"), '');
    if (cleaned.length >= 6) {
      return int.parse(cleaned.substring(cleaned.length - 2), radix: 16);
    }
    return 0;
  }

  static int _parseMaf(String response) {
    final cleaned = response.replaceAll(RegExp(r"\s+"), '');
    final i = cleaned.indexOf('4110');
    if (i >= 0 && cleaned.length >= i + 8) {
      final a = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
      final b = int.parse(cleaned.substring(i + 6, i + 8), radix: 16);
      return ((256 * a + b) / 100).round();
    }
    return 0;
  }

  static double _parseVoltage(String response) {
    final cleaned = response.replaceAll(RegExp(r"\s+"), '');
    final i = cleaned.indexOf('4142');
    if (i >= 0 && cleaned.length >= i + 8) {
      final a = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
      final b = int.parse(cleaned.substring(i + 6, i + 8), radix: 16);
      return (256 * a + b) / 1000.0;
    }
    return 0;
  }

  static int _parseAmbient(String response) {
    final cleaned = response.replaceAll(RegExp(r"\s+"), '');
    final i = cleaned.indexOf('4146');
    if (i >= 0 && cleaned.length >= i + 6) {
      final v = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
      return v - 40;
    }
    return 0;
  }

  static double _parseLambda(String response) {
    final cleaned = response.replaceAll(RegExp(r"\s+"), '');
    final i = cleaned.indexOf('415E');
    if (i >= 0 && cleaned.length >= i + 10) {
      final a = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
      final b = int.parse(cleaned.substring(i + 6, i + 8), radix: 16);
      return (256 * a + b) / 32768.0;
    }
    return 0;
  }

  static int _parseTimingAdvance(String response) {
    final cleaned = response.replaceAll(RegExp(r"\s+"), '');
    final i = cleaned.indexOf('410E');
    if (i >= 0 && cleaned.length >= i + 6) {
      final v = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
      return v - 64; // Timing advance = A - 64
    }
    return 0;
  }

  static int _parseTwoBytes(String response) {
    final cleaned = response.replaceAll(RegExp(r"\s+"), '');
    final i = cleaned.indexOf('41');
    if (i >= 0 && cleaned.length >= i + 8) {
      final a = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
      final b = int.parse(cleaned.substring(i + 6, i + 8), radix: 16);
      return 256 * a + b;
    }
    return 0;
  }

  static double _parseTwoBytesDouble(String response) {
    final cleaned = response.replaceAll(RegExp(r"\s+"), '');
    final i = cleaned.indexOf('41');
    if (i >= 0 && cleaned.length >= i + 8) {
      final a = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
      final b = int.parse(cleaned.substring(i + 6, i + 8), radix: 16);
      return (256 * a + b).toDouble();
    }
    return 0;
  }

  static int _parseFuelTrim(String response) {
    final cleaned = response.replaceAll(RegExp(r"\s+"), '');
    final i = cleaned.indexOf('41');
    if (i >= 0 && cleaned.length >= i + 6) {
      final v = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
      return v - 128; // Fuel trim = A - 128
    }
    return 0;
  }

  ObdLiveData? _last;
  bool _likelyInvalid(String response) {
    final t = response.replaceAll(RegExp(r"\s+"), '');
    return t.isEmpty || t.length < 6;
  }
}


