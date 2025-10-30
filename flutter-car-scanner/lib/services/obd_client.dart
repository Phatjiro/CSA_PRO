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

  // Enabled PIDs filtering (only poll what UI needs)
  Set<String> _enabledPids = {'010C', '010D', '0105'}; // default page1
  void setEnabledPids(Set<String> pids) {
    _enabledPids = {...pids};
  }
  bool _enabled(String pid) => _enabledPids.contains(pid);
  Set<String> get enabledPids => _enabledPids;

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
      // Core PIDs (guarded by enabled set)
      final rpmHex = _enabled('010C') ? await _sendAndRead('010C') : '';
      final speedHex = _enabled('010D') ? await _sendAndRead('010D') : '';
      final ectHex = _enabled('0105') ? await _sendAndRead('0105') : '';
      final iat = _enabled('010F') ? _parseIntakeTemp(await _sendAndRead('010F')) : (_last?.intakeTempC ?? 0);
      final thr = _enabled('0111') ? _parseThrottle(await _sendAndRead('0111')) : (_last?.throttlePositionPercent ?? 0);
      final fuel = _enabled('012F') ? _parseFuel(await _sendAndRead('012F')) : (_last?.fuelLevelPercent ?? 0);
      final load = _enabled('0104') ? _parsePercent(await _sendAndRead('0104')) : (_last?.engineLoadPercent ?? 0);
      final map = _enabled('010B') ? _parseSingleByte(await _sendAndRead('010B')) : (_last?.mapKpa ?? 0);
      final baro = _enabled('0133') ? _parseSingleByte(await _sendAndRead('0133')) : (_last?.baroKpa ?? 0);
      final maf = _enabled('0110') ? _parseMaf(await _sendAndRead('0110')) : (_last?.mafGs ?? 0);
      final voltage = _enabled('0142') ? _parseVoltage(await _sendAndRead('0142')) : (_last?.voltageV ?? 0);
      final ambient = _enabled('0146') ? _parseAmbient(await _sendAndRead('0146')) : (_last?.ambientTempC ?? 0);
      final lambda = _enabled('015E') ? _parseLambda(await _sendAndRead('015E')) : (_last?.lambda ?? 0);

      // Additional PIDs (guarded)
      final fuelSystemStatus = _enabled('0103') ? _parseSingleByte(await _sendAndRead('0103')) : (_last?.fuelSystemStatus ?? 0);
      final timingAdvance = _enabled('010E') ? _parseTimingAdvance(await _sendAndRead('010E')) : (_last?.timingAdvance ?? 0);
      final runtimeSinceStart = _enabled('011F') ? _parseTwoBytes(await _sendAndRead('011F')) : (_last?.runtimeSinceStart ?? 0);
      final distanceWithMIL = _enabled('0121') ? _parseTwoBytes(await _sendAndRead('0121')) : (_last?.distanceWithMIL ?? 0);
      final commandedPurge = _enabled('012E') ? _parseSingleByte(await _sendAndRead('012E')) : (_last?.commandedPurge ?? 0);
      final warmupsSinceClear = _enabled('0130') ? _parseSingleByte(await _sendAndRead('0130')) : (_last?.warmupsSinceClear ?? 0);
      final distanceSinceClear = _enabled('0131') ? _parseTwoBytes(await _sendAndRead('0131')) : (_last?.distanceSinceClear ?? 0);
      final catalystTemp = _enabled('013C') ? _parseTwoBytes(await _sendAndRead('013C')) : (_last?.catalystTemp ?? 0);
      final absoluteLoad = _enabled('0143') ? _parseSingleByte(await _sendAndRead('0143')) : (_last?.absoluteLoad ?? 0);
      final commandedEquivRatio = _enabled('0144') ? _parseTwoBytesDouble(await _sendAndRead('0144')) : (_last?.commandedEquivRatio ?? 0);
      final relativeThrottle = _enabled('0145') ? _parseSingleByte(await _sendAndRead('0145')) : (_last?.relativeThrottle ?? 0);
      final absoluteThrottleB = _enabled('0147') ? _parseSingleByte(await _sendAndRead('0147')) : (_last?.absoluteThrottleB ?? 0);
      final absoluteThrottleC = _enabled('0148') ? _parseSingleByte(await _sendAndRead('0148')) : (_last?.absoluteThrottleC ?? 0);
      final pedalPositionD = _enabled('0149') ? _parseSingleByte(await _sendAndRead('0149')) : (_last?.pedalPositionD ?? 0);
      final pedalPositionE = _enabled('014A') ? _parseSingleByte(await _sendAndRead('014A')) : (_last?.pedalPositionE ?? 0);
      final pedalPositionF = _enabled('014B') ? _parseSingleByte(await _sendAndRead('014B')) : (_last?.pedalPositionF ?? 0);
      final commandedThrottleActuator = _enabled('014C') ? _parseSingleByte(await _sendAndRead('014C')) : (_last?.commandedThrottleActuator ?? 0);
      final timeRunWithMIL = _enabled('014D') ? _parseTwoBytes(await _sendAndRead('014D')) : (_last?.timeRunWithMIL ?? 0);
      final timeSinceCodesCleared = _enabled('014E') ? _parseTwoBytes(await _sendAndRead('014E')) : (_last?.timeSinceCodesCleared ?? 0);
      final maxEquivRatio = _enabled('014F') ? _parseTwoBytesDouble(await _sendAndRead('014F')) : (_last?.maxEquivRatio ?? 0);
      final maxAirFlow = _enabled('0150') ? _parseTwoBytes(await _sendAndRead('0150')) : (_last?.maxAirFlow ?? 0);
      final fuelType = _enabled('0151') ? _parseSingleByte(await _sendAndRead('0151')) : (_last?.fuelType ?? 0);
      final ethanolFuel = _enabled('0152') ? _parseSingleByte(await _sendAndRead('0152')) : (_last?.ethanolFuel ?? 0);
      final absEvapPressure = _enabled('0153') ? _parseTwoBytes(await _sendAndRead('0153')) : (_last?.absEvapPressure ?? 0);
      final evapPressure = _enabled('0154') ? _parseTwoBytes(await _sendAndRead('0154')) : (_last?.evapPressure ?? 0);
      final shortTermO2Trim1 = _enabled('0155') ? _parseFuelTrim(await _sendAndRead('0155')) : (_last?.shortTermO2Trim1 ?? 0);
      final longTermO2Trim1 = _enabled('0156') ? _parseFuelTrim(await _sendAndRead('0156')) : (_last?.longTermO2Trim1 ?? 0);
      final shortTermO2Trim2 = _enabled('0157') ? _parseFuelTrim(await _sendAndRead('0157')) : (_last?.shortTermO2Trim2 ?? 0);
      final longTermO2Trim2 = _enabled('0158') ? _parseFuelTrim(await _sendAndRead('0158')) : (_last?.longTermO2Trim2 ?? 0);
      final shortTermO2Trim3 = _enabled('0159') ? _parseFuelTrim(await _sendAndRead('0159')) : (_last?.shortTermO2Trim3 ?? 0);
      final longTermO2Trim3 = _enabled('015A') ? _parseFuelTrim(await _sendAndRead('015A')) : (_last?.longTermO2Trim3 ?? 0);
      final shortTermO2Trim4 = _enabled('015B') ? _parseFuelTrim(await _sendAndRead('015B')) : (_last?.shortTermO2Trim4 ?? 0);
      final longTermO2Trim4 = _enabled('015C') ? _parseFuelTrim(await _sendAndRead('015C')) : (_last?.longTermO2Trim4 ?? 0);
      final catalystTemp1 = _enabled('015D') ? _parseTwoBytes(await _sendAndRead('015D')) : (_last?.catalystTemp1 ?? 0);
      final catalystTemp2 = _enabled('015F') ? _parseTwoBytes(await _sendAndRead('015F')) : (_last?.catalystTemp2 ?? 0);
      final catalystTemp3 = _enabled('0160') ? _parseTwoBytes(await _sendAndRead('0160')) : (_last?.catalystTemp3 ?? 0);
      final catalystTemp4 = _enabled('0160') ? _parseTwoBytes(await _sendAndRead('0160')) : (_last?.catalystTemp4 ?? 0);
      final fuelPressure = _enabled('010A') ? _parseTwoBytes(await _sendAndRead('010A')) : (_last?.fuelPressure ?? 0);
      final shortTermFuelTrim1 = _enabled('0106') ? _parseFuelTrim(await _sendAndRead('0106')) : (_last?.shortTermFuelTrim1 ?? 0);
      final longTermFuelTrim1 = _enabled('0107') ? _parseFuelTrim(await _sendAndRead('0107')) : (_last?.longTermFuelTrim1 ?? 0);
      final shortTermFuelTrim2 = _enabled('0108') ? _parseFuelTrim(await _sendAndRead('0108')) : (_last?.shortTermFuelTrim2 ?? 0);
      final longTermFuelTrim2 = _enabled('0109') ? _parseFuelTrim(await _sendAndRead('0109')) : (_last?.longTermFuelTrim2 ?? 0);

      final rpm = _enabled('010C') ? _parseRpm(rpmHex) : (_last?.engineRpm ?? 0);
      final speed = _enabled('010D') ? _parseSpeed(speedHex) : (_last?.vehicleSpeedKmh ?? 0);
      final ect = _enabled('0105') ? _parseCoolantTemp(ectHex) : (_last?.coolantTempC ?? 0);

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
    // Ưu tiên cách giống Speed/Coolant: tìm '410C' trên chuỗi đã loại khoảng trắng
    final cleaned = response.replaceAll(RegExp(r"\s+"), '');
    final i = cleaned.indexOf('410C');
    if (i >= 0 && cleaned.length >= i + 8) {
      final a = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
      final b = int.parse(cleaned.substring(i + 6, i + 8), radix: 16);
      final v = ((256 * a + b) ~/ 4);
      return v < 0 ? 0 : v;
    }
    // Fallback: xử lý phản hồi có khoảng trắng '41 0C AA BB'
    final parts = response.split(RegExp(r"\s+"));
    for (int k = 0; k + 3 < parts.length; k++) {
      if (parts[k].toUpperCase() == '41' && parts[k + 1].toUpperCase() == '0C') {
        final a = int.parse(parts[k + 2], radix: 16);
        final b = int.parse(parts[k + 3], radix: 16);
        final v = ((256 * a + b) ~/ 4);
        return v < 0 ? 0 : v;
      }
    }
    return 0;
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


