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

  // DTC commands
  Future<List<String>> readStoredDtc() async => _parseDtc(await _sendAndRead('03'));
  Future<List<String>> readPendingDtc() async => _parseDtc(await _sendAndRead('07'));
  Future<List<String>> readPermanentDtc() async => _parseDtc(await _sendAndRead('0A'));
  Future<void> clearDtc() async { await _sendAndRead('04'); }

  Future<(bool milOn, int count)> readMilAndCount() async {
    final r = await _sendAndRead('0101');
    final cleaned = r.replaceAll(RegExp(r"\s+"), '');
    final i = cleaned.indexOf('4101');
    if (i >= 0 && cleaned.length >= i + 6) {
      final a = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
      final mil = (a & 0x80) != 0;
      final cnt = a & 0x7F;
      return (mil, cnt);
    }
    return (false, 0);
  }

  static List<String> _parseDtc(String response) {
    final text = response.trim();
    if (text.isEmpty || text.toUpperCase().contains('NO DATA')) return const [];
    final cleaned = text.replaceAll(RegExp(r"\s+"), '');
    // find headers 43/47/4A and parse subsequent pairs
    final headers = ['43', '47', '4A'];
    final List<String> codes = [];
    for (final h in headers) {
      int idx = cleaned.indexOf(h);
      while (idx >= 0 && idx + 2 <= cleaned.length) {
        int p = idx + 2;
        while (p + 4 <= cleaned.length) {
          final b1 = cleaned.substring(p, p + 2);
          final b2 = cleaned.substring(p + 2, p + 4);
          // stop if hits another header
          if (headers.any((x) => cleaned.startsWith(x, p))) break;
          final code = _decodeDtcPair(b1, b2);
          if (code != null) codes.add(code);
          p += 4;
        }
        idx = cleaned.indexOf(h, p);
      }
    }
    return codes.toSet().toList();
  }

  static String? _decodeDtcPair(String b1Hex, String b2Hex) {
    int? b1 = int.tryParse(b1Hex, radix: 16);
    int? b2 = int.tryParse(b2Hex, radix: 16);
    if (b1 == null || b2 == null) return null;
    final sysBits = (b1 >> 6) & 0x3;
    final sys = ['P', 'C', 'B', 'U'][sysBits];
    final d1 = ((b1 >> 4) & 0x3).toRadixString(16).toUpperCase();
    final d2 = (b1 & 0xF).toRadixString(16).toUpperCase();
    final d3 = ((b2 >> 4) & 0xF).toRadixString(16).toUpperCase();
    final d4 = (b2 & 0xF).toRadixString(16).toUpperCase();
    final code = '$sys$d1$d2$d3$d4';
    // ignore P0000
    if (code.toUpperCase() == 'P0000') return null;
    return code;
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
    // Chờ đến khi nhận dấu '>' (prompt) hoặc timeout
    final completer = Completer<void>();
    final start = DateTime.now();
    Timer.periodic(const Duration(milliseconds: 10), (t) {
      final s = _buffer.toString();
      final timedOut = DateTime.now().difference(start) > const Duration(milliseconds: 600);
      if (s.contains('>') || timedOut) {
        t.cancel();
        if (!completer.isCompleted) completer.complete();
      }
    });
    await completer.future;
    String text = _buffer.toString();
    // Cắt đến prompt gần nhất để tránh dính phản hồi kế tiếp
    final lastGt = text.lastIndexOf('>');
    if (lastGt >= 0) {
      text = text.substring(0, lastGt);
    }
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
      final commandedPurge = _enabled('012E') ? _parsePercentDirect(await _sendAndRead('012E'), '012E') : (_last?.commandedPurge ?? 0);
      final warmupsSinceClear = _enabled('0130') ? _parseSingleByte(await _sendAndRead('0130')) : (_last?.warmupsSinceClear ?? 0);
      final distanceSinceClear = _enabled('0131') ? _parseTwoBytes(await _sendAndRead('0131')) : (_last?.distanceSinceClear ?? 0);
      final catalystTemp = _enabled('013C') ? _parseCatalystTemp(await _sendAndRead('013C'), '013C') : (_last?.catalystTemp ?? 0);
      final absoluteLoad = _enabled('0143') ? _parsePercentDirect(await _sendAndRead('0143'), '0143') : (_last?.absoluteLoad ?? 0);
      final commandedEquivRatio = _enabled('0144') ? _parseTwoBytesDouble(await _sendAndRead('0144')) : (_last?.commandedEquivRatio ?? 0);
      final relativeThrottle = _enabled('0145') ? _parsePercentDirect(await _sendAndRead('0145'), '0145') : (_last?.relativeThrottle ?? 0);
      final absoluteThrottleB = _enabled('0147') ? _parsePercentDirect(await _sendAndRead('0147'), '0147') : (_last?.absoluteThrottleB ?? 0);
      final absoluteThrottleC = _enabled('0148') ? _parsePercentDirect(await _sendAndRead('0148'), '0148') : (_last?.absoluteThrottleC ?? 0);
      final pedalPositionD = _enabled('0149') ? _parsePercentDirect(await _sendAndRead('0149'), '0149') : (_last?.pedalPositionD ?? 0);
      final pedalPositionE = _enabled('014A') ? _parsePercentDirect(await _sendAndRead('014A'), '014A') : (_last?.pedalPositionE ?? 0);
      final pedalPositionF = _enabled('014B') ? _parsePercentDirect(await _sendAndRead('014B'), '014B') : (_last?.pedalPositionF ?? 0);
      final commandedThrottleActuator = _enabled('014C') ? _parsePercentDirect(await _sendAndRead('014C'), '014C') : (_last?.commandedThrottleActuator ?? 0);
      final timeRunWithMIL = _enabled('014D') ? _parseTwoBytes(await _sendAndRead('014D')) : (_last?.timeRunWithMIL ?? 0);
      final timeSinceCodesCleared = _enabled('014E') ? _parseTwoBytes(await _sendAndRead('014E')) : (_last?.timeSinceCodesCleared ?? 0);
      final maxEquivRatio = _enabled('014F') ? _parseTwoBytesDouble(await _sendAndRead('014F')) : (_last?.maxEquivRatio ?? 0);
      final maxAirFlow = _enabled('0150') ? _parseTwoBytes(await _sendAndRead('0150')) : (_last?.maxAirFlow ?? 0);
      final fuelType = _enabled('0151') ? _parseSingleByte(await _sendAndRead('0151')) : (_last?.fuelType ?? 0);
      final ethanolFuel = _enabled('0152') ? _parsePercentDirect(await _sendAndRead('0152'), '0152') : (_last?.ethanolFuel ?? 0);
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
      final catalystTemp1 = _enabled('013C') ? _parseCatalystTemp(await _sendAndRead('013C'), '013C') : (_last?.catalystTemp1 ?? 0);
      final catalystTemp2 = _enabled('013D') ? _parseCatalystTemp(await _sendAndRead('013D'), '013D') : (_last?.catalystTemp2 ?? 0);
      final catalystTemp3 = _enabled('013E') ? _parseCatalystTemp(await _sendAndRead('013E'), '013E') : (_last?.catalystTemp3 ?? 0);
      final catalystTemp4 = _enabled('013F') ? _parseCatalystTemp(await _sendAndRead('013F'), '013F') : (_last?.catalystTemp4 ?? 0);
      final fuelPressure = _enabled('010A') ? _parseFuelPressure(await _sendAndRead('010A')) : (_last?.fuelPressure ?? 0);
      final shortTermFuelTrim1 = _enabled('0106') ? _parseFuelTrim(await _sendAndRead('0106')) : (_last?.shortTermFuelTrim1 ?? 0);
      final longTermFuelTrim1 = _enabled('0107') ? _parseFuelTrim(await _sendAndRead('0107')) : (_last?.longTermFuelTrim1 ?? 0);
      final shortTermFuelTrim2 = _enabled('0108') ? _parseFuelTrim(await _sendAndRead('0108')) : (_last?.shortTermFuelTrim2 ?? 0);
      final longTermFuelTrim2 = _enabled('0109') ? _parseFuelTrim(await _sendAndRead('0109')) : (_last?.longTermFuelTrim2 ?? 0);

      final rpm = _nnInt(_enabled('010C') ? _parseRpm(rpmHex) : (_last?.engineRpm ?? 0));
      final speed = _nnInt(_enabled('010D') ? _parseSpeed(speedHex) : (_last?.vehicleSpeedKmh ?? 0));
      final ect = _enabled('0105') ? _parseCoolantTemp(ectHex) : (_last?.coolantTempC ?? 0);

      final current = ObdLiveData(
        engineRpm: rpm == 0 && _likelyInvalid(rpmHex) ? (_last?.engineRpm ?? 0) : rpm,
        vehicleSpeedKmh: speed == 0 && _likelyInvalid(speedHex) ? (_last?.vehicleSpeedKmh ?? 0) : speed,
        coolantTempC: ect == 0 && _likelyInvalid(ectHex) ? (_last?.coolantTempC ?? 0) : ect,
        intakeTempC: iat, // IAT có thể âm
        throttlePositionPercent: _nnInt(thr),
        fuelLevelPercent: _nnInt(fuel),
        engineLoadPercent: _nnInt(load),
        mapKpa: _nnInt(map),
        baroKpa: _nnInt(baro),
        mafGs: _nnInt(maf),
        voltageV: _nnDouble(voltage),
        ambientTempC: ambient,
        lambda: _nnDouble(lambda),
        fuelSystemStatus: _nnInt(fuelSystemStatus),
        timingAdvance: timingAdvance,
        runtimeSinceStart: _nnInt(runtimeSinceStart),
        distanceWithMIL: _nnInt(distanceWithMIL),
        commandedPurge: _nnInt(commandedPurge),
        warmupsSinceClear: _nnInt(warmupsSinceClear),
        distanceSinceClear: _nnInt(distanceSinceClear),
        catalystTemp: _nnInt(catalystTemp),
        absoluteLoad: _nnInt(absoluteLoad),
        commandedEquivRatio: _nnDouble(commandedEquivRatio),
        relativeThrottle: _nnInt(relativeThrottle),
        absoluteThrottleB: _nnInt(absoluteThrottleB),
        absoluteThrottleC: _nnInt(absoluteThrottleC),
        pedalPositionD: _nnInt(pedalPositionD),
        pedalPositionE: _nnInt(pedalPositionE),
        pedalPositionF: _nnInt(pedalPositionF),
        commandedThrottleActuator: _nnInt(commandedThrottleActuator),
        timeRunWithMIL: _nnInt(timeRunWithMIL),
        timeSinceCodesCleared: _nnInt(timeSinceCodesCleared),
        maxEquivRatio: _nnDouble(maxEquivRatio),
        maxAirFlow: _nnInt(maxAirFlow),
        fuelType: _nnInt(fuelType),
        ethanolFuel: _nnInt(ethanolFuel),
        absEvapPressure: _nnInt(absEvapPressure),
        evapPressure: _nnInt(evapPressure),
        shortTermO2Trim1: shortTermO2Trim1,
        longTermO2Trim1: longTermO2Trim1,
        shortTermO2Trim2: shortTermO2Trim2,
        longTermO2Trim2: longTermO2Trim2,
        shortTermO2Trim3: shortTermO2Trim3,
        longTermO2Trim3: longTermO2Trim3,
        shortTermO2Trim4: shortTermO2Trim4,
        longTermO2Trim4: longTermO2Trim4,
        catalystTemp1: _nnInt(catalystTemp1),
        catalystTemp2: _nnInt(catalystTemp2),
        catalystTemp3: _nnInt(catalystTemp3),
        catalystTemp4: _nnInt(catalystTemp4),
        fuelPressure: _nnInt(fuelPressure),
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
      // SAE: advance = (A/2) - 64
      return ((v / 2) - 64).round();
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

  static int _parseTwoBytesFor(String response, String pid) {
    final cleaned = response.replaceAll(RegExp(r"\s+"), '');
    final key = '41' + pid.substring(2).toUpperCase();
    final i = cleaned.indexOf(key);
    if (i >= 0 && cleaned.length >= i + 8) {
      final a = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
      final b = int.parse(cleaned.substring(i + 6, i + 8), radix: 16);
      return 256 * a + b;
    }
    return 0;
  }

  static int _parseOneByteFor(String response, String pid) {
    final cleaned = response.replaceAll(RegExp(r"\s+"), '');
    final key = '41' + pid.substring(2).toUpperCase();
    final i = cleaned.indexOf(key);
    if (i >= 0 && cleaned.length >= i + 6) {
      return int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
    }
    return _parseSingleByte(response);
  }

  static int _parseFuelPressure(String response) {
    // PID 010A: pressure (kPa) = 3*A
    final a = _parseOneByteFor(response, '010A');
    return a * 3;
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

  static int _parseCatalystTemp(String response, String pid) {
    // Cat temp °C = (256*A + B)/10 - 40
    final raw = _parseTwoBytesFor(response, pid);
    return ((raw / 10.0) - 40).round();
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

  // Parse percent PIDs where % = A directly (PID 012E, 0143, 0145-014C, 0152)
  // Formula: % = A, A is the byte value directly (0-100)
  static int _parsePercentDirect(String response, String pid) {
    final cleaned = response.replaceAll(RegExp(r"\s+"), '');
    final key = '41' + pid.substring(2).toUpperCase();
    final i = cleaned.indexOf(key);
    if (i >= 0 && cleaned.length >= i + 6) {
      final v = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
      return v; // Percent = A directly (0-100, encoded as 0-100)
    }
    return 0;
  }

  ObdLiveData? _last;
  bool _likelyInvalid(String response) {
    final t = response.replaceAll(RegExp(r"\s+"), '');
    return t.isEmpty || t.length < 6;
  }

  // Helpers: clamp non-negative for PIDs that should not be negative
  static int _nnInt(int v) => v < 0 ? 0 : v;
  static double _nnDouble(double v) => v < 0 ? 0 : v;
}


