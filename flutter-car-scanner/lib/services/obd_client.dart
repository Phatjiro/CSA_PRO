import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../models/obd_live_data.dart';
import 'obd_link.dart';

/// Detailed MIL status including readiness monitors and distance metrics.
class MilStatusData {
  const MilStatusData({
    required this.milOn,
    required this.storedDtcCount,
    required this.monitors,
    this.distanceSinceMilOnKm,
    this.distanceSinceCodesClearedKm,
  });

  final bool milOn;
  final int storedDtcCount;
  final List<MilMonitorStatus> monitors;
  final int? distanceSinceMilOnKm;
  final int? distanceSinceCodesClearedKm;

  bool get hasDistanceInfo =>
      distanceSinceMilOnKm != null || distanceSinceCodesClearedKm != null;
}

/// Describes the availability and completion state of a readiness monitor.
class MilMonitorStatus {
  const MilMonitorStatus({
    required this.name,
    required this.available,
    required this.complete,
    required this.isContinuous,
    this.description,
  });

  final String name;
  final bool available;
  final bool complete;
  final bool isContinuous;
  final String? description;
}

class _MonitorDef {
  const _MonitorDef({
    required this.bit,
    required this.name,
    required this.isContinuous,
    this.description,
  });

  final int bit;
  final String name;
  final bool isContinuous;
  final String? description;
}

const List<_MonitorDef> _sparkMonitorDefs = [
  _MonitorDef(
    bit: 0,
    name: 'Misfire Monitoring',
    isContinuous: true,
    description: 'Detects combustion misses that may damage the catalyst.',
  ),
  _MonitorDef(
    bit: 1,
    name: 'Fuel System',
    isContinuous: true,
    description: 'Checks fuel trim control and feedback loop.',
  ),
  _MonitorDef(
    bit: 2,
    name: 'Comprehensive Components',
    isContinuous: true,
    description: 'Verifies the operation of emission-related components.',
  ),
  _MonitorDef(
    bit: 3,
    name: 'Catalyst',
    isContinuous: false,
    description: 'Monitors catalytic converter efficiency.',
  ),
  _MonitorDef(
    bit: 4,
    name: 'Heated Catalyst',
    isContinuous: false,
    description: 'Ensures auxiliary catalyst heaters perform correctly.',
  ),
  _MonitorDef(
    bit: 5,
    name: 'Evaporative System',
    isContinuous: false,
    description: 'Checks fuel tank/vapor leaks and purge valve operation.',
  ),
  _MonitorDef(
    bit: 6,
    name: 'Secondary Air System',
    isContinuous: false,
    description: 'Validates secondary air injection (if equipped).',
  ),
  _MonitorDef(
    bit: 7,
    name: 'EGR/VVT System',
    isContinuous: false,
    description: 'Monitors EGR or variable valve timing operation.',
  ),
];

class ObdClient {
  final String host;
  final int port;
  ObdLink? _link; // Optional transport abstraction

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
    // Force enable essential PIDs if not present
    _enabledPids.addAll(['010C', '010D', '0105']);
    // Debug: Uncomment to verify enabled PIDs
    // print('🎯 ENABLED PIDs: $_enabledPids');
  }
  bool _enabled(String pid) => _enabledPids.contains(pid);
  Set<String> get enabledPids => _enabledPids;
  
  // Data caching with timestamp for smooth transitions
  final Map<String, (int value, DateTime timestamp)> _valueCache = {};
  static const _cacheDuration = Duration(milliseconds: 800); // Keep values for 800ms (faster refresh)

  ObdClient({required this.host, required this.port});

  // New: construct with a generic link (TCP, BLE, SPP)
  ObdClient.withLink(ObdLink link)
      : host = 'link',
        port = -1,
        _link = link;

  Stream<ObdLiveData> get dataStream => _dataController.stream;

  // Trigger immediate poll (useful when PIDs change)
  Future<void> pollNow() async {
    await _queryAndEmit();
  }

  Future<String> requestPid(String pid) async {
    return _sendAndRead(pid);
  }

  // Extended PIDs support detection (quick win)
  // Queries 0120, 0140, 0160 to detect support bitmaps and returns a list of supported PID hex codes
  Future<List<String>> getExtendedSupportedPids() async {
    final supported = <String>{};
    for (final base in ['0120', '0140', '0160']) {
      try {
        final resp = await _sendAndRead(base);
        final list = _parseSupportedBitmap(resp, base);
        supported.addAll(list);
      } catch (_) {}
    }
    return supported.toList()..sort();
  }

  // Parse Mode 01 support bitmap response for a given base (e.g., 0120 → header 41 20)
  static List<String> _parseSupportedBitmap(String response, String basePid) {
    // Expected cleaned contains like: 41 20 AA BB CC DD
    final cleaned = response.replaceAll(RegExp(r"\s+"), '').toUpperCase();
    final header = '41' + basePid.substring(2);
    final i = cleaned.indexOf(header);
    if (i < 0 || cleaned.length < i + 10) return const [];
    // Extract 4 bytes bitmap if available; some ECUs may return fewer — guard lengths
    final bytes = <int>[];
    for (int off = i + 4; off + 2 <= cleaned.length && bytes.length < 4; off += 2) {
      final part = cleaned.substring(off, off + 2);
      final b = int.tryParse(part, radix: 16);
      if (b == null) break;
      bytes.add(b);
    }
    if (bytes.length < 4) return const [];

    // basePid 0120 → range 0x21..0x40; 0140 → 0x41..0x60; 0160 → 0x61..0x80
    final startIndex = int.parse(basePid.substring(2), radix: 16); // e.g., 0x20
    final supported = <String>[];
    for (int byteIndex = 0; byteIndex < 4; byteIndex++) {
      final b = bytes[byteIndex];
      for (int bit = 0; bit < 8; bit++) {
        final mask = 1 << (7 - bit); // MSB first
        if ((b & mask) != 0) {
          final pidNum = startIndex + (byteIndex * 8) + bit + 1; // +1 per spec
          final pid = '01' + pidNum.toRadixString(16).toUpperCase().padLeft(2, '0');
          supported.add(pid);
        }
      }
    }
    return supported;
  }

  // Mode 06 helpers
  Future<List<String>> readMode06Supported() async {
    final r = await _sendAndRead('0600');
    final cleaned = r.replaceAll(RegExp(r"\s+"), '').toUpperCase();
    final i = cleaned.indexOf('4600');
    if (i < 0) return const [];
    final tail = cleaned.substring(i + 4); // after 4600
    // interpret as list of 2-hex TIDs if present, else try to split by 2 chars
    final List<String> tids = [];
    for (int p = 0; p + 2 <= tail.length; p += 2) {
      final tid = tail.substring(p, p + 2);
      if (tid.isEmpty) break;
      // basic sanity: hex
      final n = int.tryParse(tid, radix: 16);
      if (n != null && n > 0) tids.add(tid);
    }
    // Deduplicate & filter empties
    return tids.where((e) => e.trim().isNotEmpty && e != '00').toSet().toList();
  }

  Future<(int value, int min, int max)> readMode06Tid(String tid) async {
    final cmd = '06${tid.toUpperCase()}';
    final r = await _sendAndRead(cmd);
    final cleaned = r.replaceAll(RegExp(r"\s+"), '').toUpperCase();
    final key = '46' + tid.toUpperCase();
    final i = cleaned.indexOf(key);
    if (i < 0 || cleaned.length < i + 14) return (0, 0, 0);
    int vA = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
    int vB = int.parse(cleaned.substring(i + 6, i + 8), radix: 16);
    int minA = int.parse(cleaned.substring(i + 8, i + 10), radix: 16);
    int minB = int.parse(cleaned.substring(i + 10, i + 12), radix: 16);
    int maxA = int.parse(cleaned.substring(i + 12, i + 14), radix: 16);
    int maxB = int.parse(cleaned.substring(i + 14, i + 16), radix: 16);
    final value = 256 * vA + vB;
    final min = 256 * minA + minB;
    final max = 256 * maxA + maxB;
    return (value, min, max);
  }

  // Mode 09 – Vehicle Information (basic VIN read). Works on real ELM/vehicle.
  Future<String?> readVin() async {
    try {
      final r = await _sendAndRead('0902');
      final cleaned = r.replaceAll(RegExp(r"\s+"), '').toUpperCase();
      if (!cleaned.contains('4902')) return null;
      // Collect all hex byte pairs after occurrences of 4902xx (skip record index if present)
      final bytes = <int>[];
      int idx = 0;
      while (true) {
        final i = cleaned.indexOf('4902', idx);
        if (i < 0 || i + 4 >= cleaned.length) break;
        int p = i + 4;
        // Some ECUs send 4902 + recordId (2 hex) before data
        // Try skipping 2 hex for record id if the next is two hex digits
        if (p + 2 <= cleaned.length) {
          // peek two chars as record id
          p += 2;
        }
        // Read until next 49 (start of another frame) or end
        while (p + 2 <= cleaned.length) {
          if (cleaned.startsWith('49', p)) break;
          final pair = cleaned.substring(p, p + 2);
          final b = int.tryParse(pair, radix: 16);
          if (b == null) break;
          bytes.add(b);
          p += 2;
        }
        idx = p;
      }
      if (bytes.isEmpty) return null;
      final chars = bytes
          .where((b) => b >= 32 && b <= 126)
          .map((b) => String.fromCharCode(b))
          .join()
          .trim();
      return chars.isEmpty ? null : chars;
    } catch (_) {
      return null;
    }
  }

  // PID 0142 Control module voltage: value = ((256*A)+B)/1000 V
  Future<double?> readBatteryVoltage() async {
    try {
      final r = await _sendAndRead('0142');
      // Use same parsing method as _parseVoltage() for consistency
      final cleaned = r.replaceAll(RegExp(r"\s+"), '');
      final i = cleaned.indexOf('4142');
      if (i >= 0 && cleaned.length >= i + 8) {
        final a = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
        final b = int.parse(cleaned.substring(i + 6, i + 8), radix: 16);
        return ((256 * a) + b) / 1000.0;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // O2 Sensor voltages PIDs 0114-011B: A=voltage(V*200), B=short term fuel trim (% = B/1.28 - 100)
  Future<List<O2Reading>> readO2Sensors() async {
    final readings = <O2Reading>[];
    const pids = ['0114','0115','0116','0117','0118','0119','011A','011B'];
    for (final pid in pids) {
      try {
        final r = await _sendAndRead(pid);
        final parts = r.trim().split(RegExp(r"\s+"));
        if (parts.length >= 4 && parts[0] == '41') {
          final pidHex = parts[1].toUpperCase();
          final a = int.parse(parts[2], radix: 16);
          final b = int.parse(parts[3], radix: 16);
          final voltage = a / 200.0; // V
          final trim = (b / 1.28) - 100.0; // %
          readings.add(O2Reading(pidHex: pidHex, voltage: voltage, shortTrimPercent: trim));
        }
      } catch (_) {}
    }
    return readings;
  }

  // DTC commands
  Future<List<String>> readStoredDtc() async => _parseDtc(await _sendAndRead('03'));
  Future<List<String>> readPendingDtc() async => _parseDtc(await _sendAndRead('07'));
  Future<List<String>> readPermanentDtc() async => _parseDtc(await _sendAndRead('0A'));
  Future<void> clearDtc() async { await _sendAndRead('04'); }

  /// Inject a random DTC when using the emulator (custom Mode 99 command).
  /// Returns the generated code if emulator responds; null otherwise.
  Future<String?> injectRandomDtc() async {
    try {
      final response = await _sendAndRead('99');
      if (response.toUpperCase().startsWith('RANDOM')) {
        final parts = response.trim().split(RegExp(r'\s+'));
        if (parts.length >= 2) return parts[1];
      }
    } catch (_) {
      // Ignore errors – function is best-effort for emulator testing.
    }
    return null;
  }

  Future<(bool milOn, int count)> readMilAndCount() async {
    final status = await readMilStatusDetailed();
    return (status.milOn, status.storedDtcCount);
  }

  Future<MilStatusData> readMilStatusDetailed() async {
    bool milOn = false;
    int storedCount = 0;
    int byteB = 0;
    int byteC = 0;
    try {
      final response = await _sendAndRead('0101');
      final cleaned = response.replaceAll(RegExp(r'\s+'), '').toUpperCase();
      final idx = cleaned.indexOf('4101');
      if (idx >= 0 && cleaned.length >= idx + 6) {
        final a = int.parse(cleaned.substring(idx + 4, idx + 6), radix: 16);
        milOn = (a & 0x80) != 0;
        storedCount = a & 0x7F;
        if (cleaned.length >= idx + 8) {
          byteB = int.tryParse(cleaned.substring(idx + 6, idx + 8), radix: 16) ?? 0;
        }
        if (cleaned.length >= idx + 10) {
          byteC = int.tryParse(cleaned.substring(idx + 8, idx + 10), radix: 16) ?? 0;
        }
      }
    } catch (_) {
      // Keep defaults if parsing fails.
    }

    final monitors = _buildMonitorStatuses(byteB, byteC);
    final distanceMil = await _readDistancePid('0121');
    final distanceSinceClear = await _readDistancePid('0131');

    return MilStatusData(
      milOn: milOn,
      storedDtcCount: storedCount,
      monitors: monitors,
      distanceSinceMilOnKm: distanceMil,
      distanceSinceCodesClearedKm: distanceSinceClear,
    );
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

  Future<int?> _readDistancePid(String pid) async {
    try {
      final response = await _sendAndRead(pid);
      final cleaned = response.replaceAll(RegExp(r'\s+'), '').toUpperCase();
      final header = '41${pid.substring(2)}';
      final idx = cleaned.indexOf(header);
      if (idx >= 0 && cleaned.length >= idx + header.length + 4) {
        final a = int.parse(
            cleaned.substring(idx + header.length, idx + header.length + 2),
            radix: 16);
        final b = int.parse(
            cleaned.substring(idx + header.length + 2, idx + header.length + 4),
            radix: 16);
        return (a * 256) + b;
      }
    } catch (_) {
      // Ignore individual PID failures – distances are optional.
    }
    return null;
  }

  List<MilMonitorStatus> _buildMonitorStatuses(int byteB, int byteC) {
    final List<MilMonitorStatus> statuses = [];
    for (final def in _sparkMonitorDefs) {
      final available = (byteB & (1 << def.bit)) != 0;
      final complete = available && (byteC & (1 << def.bit)) != 0;
      statuses.add(MilMonitorStatus(
        name: def.name,
        available: available,
        complete: complete,
        isContinuous: def.isContinuous,
        description: def.description,
      ));
    }
    return statuses;
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
    if (_link != null) {
      await _link!.connect();
      _link!.rx.listen(_onStringData, onDone: disconnect, onError: (_) => disconnect());
    } else {
      _socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      _socket!.listen(_onData, onDone: disconnect, onError: (_) => disconnect());
    }

    // Basic ELM init sequence (works for both TCP and BLE/SPP links)
    await _writeCommand('ATZ');
    await _writeCommand('ATE0'); // echo off
    await _writeCommand('ATL0'); // linefeeds off
    await _writeCommand('ATS0'); // spaces off
    await _writeCommand('ATH0'); // headers off
    await _writeCommand('ATSP0'); // auto protocol

    // Start polling essential PIDs every 500ms (smoother than 250ms)
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      await _queryAndEmit();
    });
  }

  Future<void> disconnect() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (_link != null) {
      await _link!.disconnect();
    }
    await _socket?.close();
    _socket = null;
  }

  bool get isConnected => _link?.isConnected == true || _socket != null;

  Future<void> _writeCommand(String cmd) async {
    if (_link != null) {
      await _link!.tx(cmd);
      return;
    }
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

  // Process incoming text chunks from ObdLink (BLE/SPP)
  void _onStringData(String chunk) {
    _buffer.write(chunk);
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(milliseconds: 40), () {
      _idleCompleter?.complete();
      _idleCompleter = null;
    });
  }

  // Mutex để serialize OBD requests (fix parallel polling race condition)
  Future<dynamic>? _pendingRequest;
  
  Future<String> _sendAndRead(String cmd) async {
    // Wait for any pending request to complete (serialize access)
    while (_pendingRequest != null) {
      try {
        await _pendingRequest;
      } catch (_) {}
    }
    
    // Create new request
    final completer = Completer<String>();
    _pendingRequest = completer.future;
    
    try {
      _buffer.clear();
      await _writeCommand(cmd);
      // Chờ đến khi nhận dấu '>' (prompt) hoặc timeout
      final responseCompleter = Completer<void>();
      final start = DateTime.now();
      Timer.periodic(const Duration(milliseconds: 10), (t) {
        final s = _buffer.toString();
        final timedOut = DateTime.now().difference(start) > const Duration(milliseconds: 600);
        if (s.contains('>') || timedOut) {
          t.cancel();
          if (!responseCompleter.isCompleted) responseCompleter.complete();
        }
      });
      await responseCompleter.future;
      String text = _buffer.toString();
      // Cắt đến prompt gần nhất để tránh dính phản hồi kế tiếp
      final lastGt = text.lastIndexOf('>');
      if (lastGt >= 0) {
        text = text.substring(0, lastGt);
      }
      final result = text.replaceAll('>', '').trim();
      completer.complete(result);
      return result;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _pendingRequest = null;
    }
  }

  Future<void> _queryAndEmit() async {
    try {
      // SERIAL POLLING with mutex: Tất cả PIDs được gửi tuần tự (fix race condition với shared buffer)
      // Tuy gọi Future.wait() nhưng _sendAndRead() có mutex nên thực tế là serial
      final futures = <Future<dynamic>>[];
      
      // Helper để tạo async task
      Future<T> _fetchPid<T>(String pid, T Function(String) parser, T fallback) async {
        if (!_enabled(pid)) return fallback;
        try {
          final response = await _sendAndRead(pid);
          // Debug: Uncomment to verify PID responses
          // if (['010C', '010D', '0105', '010F', '0111'].contains(pid)) {
          //   print('PID $pid → "$response"');
          // }
          return parser(response);
        } catch (e) {
          // Log errors for critical PIDs (keep this for debugging)
          if (['010C', '010D', '0105'].contains(pid)) {
            print('❌ ERROR fetching PID $pid: $e');
          }
          return fallback;
        }
      }
      
      // Launch ALL queries in parallel
      final rpmFuture = _fetchPid('010C', (r) => r, '');
      final speedFuture = _fetchPid('010D', (r) => r, '');
      final ectFuture = _fetchPid('0105', (r) => r, '');
      final iatFuture = _fetchPid('010F', _parseIntakeTemp, _last?.intakeTempC ?? 0);
      final thrFuture = _fetchPid('0111', _parseThrottle, _last?.throttlePositionPercent ?? 0);
      final fuelFuture = _fetchPid('012F', _parseFuel, _last?.fuelLevelPercent ?? 0);
      final loadFuture = _fetchPid('0104', _parsePercent, _last?.engineLoadPercent ?? 0);
      final mapFuture = _fetchPid('010B', _parseSingleByte, _last?.mapKpa ?? 0);
      final baroFuture = _fetchPid('0133', _parseSingleByte, _last?.baroKpa ?? 0);
      final mafFuture = _fetchPid('0110', _parseMaf, _last?.mafGs ?? 0);
      final voltageFuture = _fetchPid('0142', _parseVoltage, _last?.voltageV ?? 0);
      final ambientFuture = _fetchPid('0146', _parseAmbient, _last?.ambientTempC ?? 0);
      final lambdaFuture = _fetchPid('015E', _parseLambda, _last?.lambda ?? 0);
      final fuelSystemStatusFuture = _fetchPid('0103', _parseSingleByte, _last?.fuelSystemStatus ?? 0);
      final timingAdvanceFuture = _fetchPid('010E', _parseTimingAdvance, _last?.timingAdvance ?? 0);
      final runtimeSinceStartFuture = _fetchPid('011F', _parseTwoBytes, _last?.runtimeSinceStart ?? 0);
      final distanceWithMILFuture = _fetchPid('0121', _parseTwoBytes, _last?.distanceWithMIL ?? 0);
      final commandedPurgeFuture = _fetchPid('012E', (r) => _parsePercentDirect(r, '012E'), _last?.commandedPurge ?? 0);
      final warmupsSinceClearFuture = _fetchPid('0130', _parseSingleByte, _last?.warmupsSinceClear ?? 0);
      final distanceSinceClearFuture = _fetchPid('0131', _parseTwoBytes, _last?.distanceSinceClear ?? 0);
      final catalystTempFuture = _fetchPid('013C', (r) => _parseCatalystTemp(r, '013C'), _last?.catalystTemp ?? 0);
      final absoluteLoadFuture = _fetchPid('0143', (r) => _parsePercentDirect(r, '0143'), _last?.absoluteLoad ?? 0);
      final commandedEquivRatioFuture = _fetchPid('0144', _parseTwoBytesDouble, _last?.commandedEquivRatio ?? 0);
      final relativeThrottleFuture = _fetchPid('0145', (r) => _parsePercentDirect(r, '0145'), _last?.relativeThrottle ?? 0);
      final absoluteThrottleBFuture = _fetchPid('0147', (r) => _parsePercentDirect(r, '0147'), _last?.absoluteThrottleB ?? 0);
      final absoluteThrottleCFuture = _fetchPid('0148', (r) => _parsePercentDirect(r, '0148'), _last?.absoluteThrottleC ?? 0);
      final pedalPositionDFuture = _fetchPid('0149', (r) => _parsePercentDirect(r, '0149'), _last?.pedalPositionD ?? 0);
      final pedalPositionEFuture = _fetchPid('014A', (r) => _parsePercentDirect(r, '014A'), _last?.pedalPositionE ?? 0);
      final pedalPositionFFuture = _fetchPid('014B', (r) => _parsePercentDirect(r, '014B'), _last?.pedalPositionF ?? 0);
      final commandedThrottleActuatorFuture = _fetchPid('014C', (r) => _parsePercentDirect(r, '014C'), _last?.commandedThrottleActuator ?? 0);
      final timeRunWithMILFuture = _fetchPid('014D', _parseTwoBytes, _last?.timeRunWithMIL ?? 0);
      final timeSinceCodesClearedFuture = _fetchPid('014E', _parseTwoBytes, _last?.timeSinceCodesCleared ?? 0);
      final maxEquivRatioFuture = _fetchPid('014F', _parseTwoBytesDouble, _last?.maxEquivRatio ?? 0);
      final maxAirFlowFuture = _fetchPid('0150', _parseTwoBytes, _last?.maxAirFlow ?? 0);
      final fuelTypeFuture = _fetchPid('0151', _parseSingleByte, _last?.fuelType ?? 0);
      final ethanolFuelFuture = _fetchPid('0152', (r) => _parsePercentDirect(r, '0152'), _last?.ethanolFuel ?? 0);
      final absEvapPressureFuture = _fetchPid('0153', _parseTwoBytes, _last?.absEvapPressure ?? 0);
      final evapPressureFuture = _fetchPid('0154', _parseTwoBytes, _last?.evapPressure ?? 0);
      final shortTermO2Trim1Future = _fetchPid('0155', _parseFuelTrim, _last?.shortTermO2Trim1 ?? 0);
      final longTermO2Trim1Future = _fetchPid('0156', _parseFuelTrim, _last?.longTermO2Trim1 ?? 0);
      final shortTermO2Trim2Future = _fetchPid('0157', _parseFuelTrim, _last?.shortTermO2Trim2 ?? 0);
      final longTermO2Trim2Future = _fetchPid('0158', _parseFuelTrim, _last?.longTermO2Trim2 ?? 0);
      final shortTermO2Trim3Future = _fetchPid('0159', _parseFuelTrim, _last?.shortTermO2Trim3 ?? 0);
      final longTermO2Trim3Future = _fetchPid('015A', _parseFuelTrim, _last?.longTermO2Trim3 ?? 0);
      final shortTermO2Trim4Future = _fetchPid('015B', _parseFuelTrim, _last?.shortTermO2Trim4 ?? 0);
      final longTermO2Trim4Future = _fetchPid('015C', _parseFuelTrim, _last?.longTermO2Trim4 ?? 0);
      final catalystTemp1Future = _fetchPid('013C', (r) => _parseCatalystTemp(r, '013C'), _last?.catalystTemp1 ?? 0);
      final catalystTemp2Future = _fetchPid('013D', (r) => _parseCatalystTemp(r, '013D'), _last?.catalystTemp2 ?? 0);
      final catalystTemp3Future = _fetchPid('013E', (r) => _parseCatalystTemp(r, '013E'), _last?.catalystTemp3 ?? 0);
      final catalystTemp4Future = _fetchPid('013F', (r) => _parseCatalystTemp(r, '013F'), _last?.catalystTemp4 ?? 0);
      final fuelPressureFuture = _fetchPid('010A', _parseFuelPressure, _last?.fuelPressure ?? 0);
      final shortTermFuelTrim1Future = _fetchPid('0106', _parseFuelTrim, _last?.shortTermFuelTrim1 ?? 0);
      final longTermFuelTrim1Future = _fetchPid('0107', _parseFuelTrim, _last?.longTermFuelTrim1 ?? 0);
      final shortTermFuelTrim2Future = _fetchPid('0108', _parseFuelTrim, _last?.shortTermFuelTrim2 ?? 0);
      final longTermFuelTrim2Future = _fetchPid('0109', _parseFuelTrim, _last?.longTermFuelTrim2 ?? 0);
      
      // O2 Sensor Voltages (PIDs 0114-011B)
      final o2Voltage1Future = _fetchPid('0114', _parseO2Voltage, _last?.o2SensorVoltage1 ?? 0.0);
      final o2Voltage2Future = _fetchPid('0115', _parseO2Voltage, _last?.o2SensorVoltage2 ?? 0.0);
      final o2Voltage3Future = _fetchPid('0116', _parseO2Voltage, _last?.o2SensorVoltage3 ?? 0.0);
      final o2Voltage4Future = _fetchPid('0117', _parseO2Voltage, _last?.o2SensorVoltage4 ?? 0.0);
      final o2Voltage5Future = _fetchPid('0118', _parseO2Voltage, _last?.o2SensorVoltage5 ?? 0.0);
      final o2Voltage6Future = _fetchPid('0119', _parseO2Voltage, _last?.o2SensorVoltage6 ?? 0.0);
      final o2Voltage7Future = _fetchPid('011A', _parseO2Voltage, _last?.o2SensorVoltage7 ?? 0.0);
      final o2Voltage8Future = _fetchPid('011B', _parseO2Voltage, _last?.o2SensorVoltage8 ?? 0.0);
      
      // Additional Mode 01 PIDs
      final engineOilTempFuture = _fetchPid('015C', _parseTempWithOffset, _last?.engineOilTempC ?? 0);
      final engineFuelRateFuture = _fetchPid('015F', _parseFuelRate, _last?.engineFuelRate ?? 0.0);
      final driverDemandTorqueFuture = _fetchPid('0161', _parseTorquePercent, _last?.driverDemandTorque ?? 0);
      final actualTorqueFuture = _fetchPid('0162', _parseTorquePercent, _last?.actualTorque ?? 0);
      final referenceTorqueFuture = _fetchPid('0163', _parseTwoBytes, _last?.referenceTorque ?? 0);
      
      // Wait for ALL futures to complete (parallel execution!)
      final results = await Future.wait([
        rpmFuture, speedFuture, ectFuture, iatFuture, thrFuture, fuelFuture, loadFuture,
        mapFuture, baroFuture, mafFuture, voltageFuture, ambientFuture, lambdaFuture,
        fuelSystemStatusFuture, timingAdvanceFuture, runtimeSinceStartFuture, distanceWithMILFuture,
        commandedPurgeFuture, warmupsSinceClearFuture, distanceSinceClearFuture, catalystTempFuture,
        absoluteLoadFuture, commandedEquivRatioFuture, relativeThrottleFuture, absoluteThrottleBFuture,
        absoluteThrottleCFuture, pedalPositionDFuture, pedalPositionEFuture, pedalPositionFFuture,
        commandedThrottleActuatorFuture, timeRunWithMILFuture, timeSinceCodesClearedFuture,
        maxEquivRatioFuture, maxAirFlowFuture, fuelTypeFuture, ethanolFuelFuture,
        absEvapPressureFuture, evapPressureFuture, shortTermO2Trim1Future, longTermO2Trim1Future,
        shortTermO2Trim2Future, longTermO2Trim2Future, shortTermO2Trim3Future, longTermO2Trim3Future,
        shortTermO2Trim4Future, longTermO2Trim4Future, catalystTemp1Future, catalystTemp2Future,
        catalystTemp3Future, catalystTemp4Future, fuelPressureFuture, shortTermFuelTrim1Future,
        longTermFuelTrim1Future, shortTermFuelTrim2Future, longTermFuelTrim2Future,
        o2Voltage1Future, o2Voltage2Future, o2Voltage3Future, o2Voltage4Future,
        o2Voltage5Future, o2Voltage6Future, o2Voltage7Future, o2Voltage8Future,
        engineOilTempFuture, engineFuelRateFuture, driverDemandTorqueFuture,
        actualTorqueFuture, referenceTorqueFuture,
      ]);
      
      // Extract results
      final rpmHex = results[0] as String;
      final speedHex = results[1] as String;
      final ectHex = results[2] as String;
      final iat = results[3] as int;
      final thr = results[4] as int;
      final fuel = results[5] as int;
      final load = results[6] as int;
      final map = results[7] as int;
      final baro = results[8] as int;
      final maf = results[9] as int;
      final voltage = results[10] as double;
      final ambient = results[11] as int;
      final lambda = results[12] as double;
      final fuelSystemStatus = results[13] as int;
      final timingAdvance = results[14] as int;
      final runtimeSinceStart = results[15] as int;
      final distanceWithMIL = results[16] as int;
      final commandedPurge = results[17] as int;
      final warmupsSinceClear = results[18] as int;
      final distanceSinceClear = results[19] as int;
      final catalystTemp = results[20] as int;
      final absoluteLoad = results[21] as int;
      final commandedEquivRatio = results[22] as double;
      final relativeThrottle = results[23] as int;
      final absoluteThrottleB = results[24] as int;
      final absoluteThrottleC = results[25] as int;
      final pedalPositionD = results[26] as int;
      final pedalPositionE = results[27] as int;
      final pedalPositionF = results[28] as int;
      final commandedThrottleActuator = results[29] as int;
      final timeRunWithMIL = results[30] as int;
      final timeSinceCodesCleared = results[31] as int;
      final maxEquivRatio = results[32] as double;
      final maxAirFlow = results[33] as int;
      final fuelType = results[34] as int;
      final ethanolFuel = results[35] as int;
      final absEvapPressure = results[36] as int;
      final evapPressure = results[37] as int;
      final shortTermO2Trim1 = results[38] as int;
      final longTermO2Trim1 = results[39] as int;
      final shortTermO2Trim2 = results[40] as int;
      final longTermO2Trim2 = results[41] as int;
      final shortTermO2Trim3 = results[42] as int;
      final longTermO2Trim3 = results[43] as int;
      final shortTermO2Trim4 = results[44] as int;
      final longTermO2Trim4 = results[45] as int;
      final catalystTemp1 = results[46] as int;
      final catalystTemp2 = results[47] as int;
      final catalystTemp3 = results[48] as int;
      final catalystTemp4 = results[49] as int;
      final fuelPressure = results[50] as int;
      final shortTermFuelTrim1 = results[51] as int;
      final longTermFuelTrim1 = results[52] as int;
      final shortTermFuelTrim2 = results[53] as int;
      final longTermFuelTrim2 = results[54] as int;
      final o2Voltage1 = results[55] as double;
      final o2Voltage2 = results[56] as double;
      final o2Voltage3 = results[57] as double;
      final o2Voltage4 = results[58] as double;
      final o2Voltage5 = results[59] as double;
      final o2Voltage6 = results[60] as double;
      final o2Voltage7 = results[61] as double;
      final o2Voltage8 = results[62] as double;
      final engineOilTemp = results[63] as int;
      final engineFuelRate = results[64] as double;
      final driverDemandTorque = results[65] as int;
      final actualTorque = results[66] as int;
      final referenceTorque = results[67] as int;

      // Debug: Uncomment to verify responses
      // print('🔍 DEBUG rpmHex: "$rpmHex"');
      // print('🔍 DEBUG speedHex: "$speedHex"');
      // print('🔍 DEBUG ectHex: "$ectHex"');
      
      final rpm = _nnInt(_enabled('010C') ? _parseRpm(rpmHex) : (_last?.engineRpm ?? 0));
      final speed = _nnInt(_enabled('010D') ? _parseSpeed(speedHex) : (_last?.vehicleSpeedKmh ?? 0));
      final ect = _enabled('0105') ? _parseCoolantTemp(ectHex) : (_last?.coolantTempC ?? 0);
      
      // Debug: Uncomment to verify parsed values
      // print('📊 DEBUG parsed RPM: $rpm, Speed: $speed, Coolant: $ect');

      // Calculate derived values
      final fuelEconomy = _calculateFuelEconomy(engineFuelRate, speed.toDouble());
      final powerKw = _calculateEnginePowerKw(actualTorque.toDouble(), referenceTorque.toDouble(), rpm.toDouble());
      final powerHp = powerKw * 1.34102; // kW to HP
      final accel = _calculateAcceleration(speed.toDouble(), _last?.vehicleSpeedKmh.toDouble() ?? 0.0);
      final afr = _calculateAFR(lambda);
      final volEff = _calculateVolumetricEfficiency(maf.toDouble(), rpm.toDouble(), load.toDouble());
      
      // Trip statistics (cumulative)
      _updateTripStats(speed.toDouble());

      // Apply smart caching with smoothing to ALL PIDs
      final current = ObdLiveData(
        engineRpm: _getSmoothValue('rpm', rpm, _last?.engineRpm ?? 0),
        vehicleSpeedKmh: _getSmoothValue('speed', speed, _last?.vehicleSpeedKmh ?? 0),
        coolantTempC: _getSmoothValue('ect', ect, _last?.coolantTempC ?? 0),
        intakeTempC: iat, // IAT có thể âm - không smooth
        throttlePositionPercent: _getSmoothValue('throttle', _nnInt(thr), _last?.throttlePositionPercent ?? 0),
        fuelLevelPercent: _getSmoothValue('fuel', _nnInt(fuel), _last?.fuelLevelPercent ?? 0),
        engineLoadPercent: _getSmoothValue('load', _nnInt(load), _last?.engineLoadPercent ?? 0),
        mapKpa: _getSmoothValue('map', _nnInt(map), _last?.mapKpa ?? 0),
        baroKpa: _getSmoothValue('baro', _nnInt(baro), _last?.baroKpa ?? 0),
        mafGs: _getSmoothValue('maf', _nnInt(maf), _last?.mafGs ?? 0),
        voltageV: _nnDouble(voltage), // Voltage không cần smooth - biến động tự nhiên
        ambientTempC: ambient, // Ambient có thể âm - không smooth
        lambda: _nnDouble(lambda), // Lambda không cần smooth - quan trọng
        fuelSystemStatus: _getSmoothValue('fuelSys', _nnInt(fuelSystemStatus), _last?.fuelSystemStatus ?? 0),
        timingAdvance: timingAdvance, // Timing có thể âm - không smooth
        runtimeSinceStart: _getSmoothValue('runtime', _nnInt(runtimeSinceStart), _last?.runtimeSinceStart ?? 0),
        distanceWithMIL: _getSmoothValue('distMIL', _nnInt(distanceWithMIL), _last?.distanceWithMIL ?? 0),
        commandedPurge: _getSmoothValue('purge', _nnInt(commandedPurge), _last?.commandedPurge ?? 0),
        warmupsSinceClear: _getSmoothValue('warmups', _nnInt(warmupsSinceClear), _last?.warmupsSinceClear ?? 0),
        distanceSinceClear: _getSmoothValue('distClear', _nnInt(distanceSinceClear), _last?.distanceSinceClear ?? 0),
        catalystTemp: _getSmoothValue('catTemp', _nnInt(catalystTemp), _last?.catalystTemp ?? 0),
        absoluteLoad: _getSmoothValue('absLoad', _nnInt(absoluteLoad), _last?.absoluteLoad ?? 0),
        commandedEquivRatio: _nnDouble(commandedEquivRatio), // Ratio không cần smooth
        relativeThrottle: _getSmoothValue('relThrottle', _nnInt(relativeThrottle), _last?.relativeThrottle ?? 0),
        absoluteThrottleB: _getSmoothValue('absThrottleB', _nnInt(absoluteThrottleB), _last?.absoluteThrottleB ?? 0),
        absoluteThrottleC: _getSmoothValue('absThrottleC', _nnInt(absoluteThrottleC), _last?.absoluteThrottleC ?? 0),
        pedalPositionD: _getSmoothValue('pedalD', _nnInt(pedalPositionD), _last?.pedalPositionD ?? 0),
        pedalPositionE: _getSmoothValue('pedalE', _nnInt(pedalPositionE), _last?.pedalPositionE ?? 0),
        pedalPositionF: _getSmoothValue('pedalF', _nnInt(pedalPositionF), _last?.pedalPositionF ?? 0),
        commandedThrottleActuator: _getSmoothValue('cmdThrottle', _nnInt(commandedThrottleActuator), _last?.commandedThrottleActuator ?? 0),
        timeRunWithMIL: _getSmoothValue('timeMIL', _nnInt(timeRunWithMIL), _last?.timeRunWithMIL ?? 0),
        timeSinceCodesCleared: _getSmoothValue('timeClear', _nnInt(timeSinceCodesCleared), _last?.timeSinceCodesCleared ?? 0),
        maxEquivRatio: _nnDouble(maxEquivRatio), // Max values không cần smooth
        maxAirFlow: _getSmoothValue('maxAir', _nnInt(maxAirFlow), _last?.maxAirFlow ?? 0),
        fuelType: _getSmoothValue('fuelType', _nnInt(fuelType), _last?.fuelType ?? 0),
        ethanolFuel: _getSmoothValue('ethanol', _nnInt(ethanolFuel), _last?.ethanolFuel ?? 0),
        absEvapPressure: _getSmoothValue('absEvap', _nnInt(absEvapPressure), _last?.absEvapPressure ?? 0),
        evapPressure: _getSmoothValue('evap', _nnInt(evapPressure), _last?.evapPressure ?? 0),
        shortTermO2Trim1: shortTermO2Trim1, // Fuel trim có thể âm - không smooth
        longTermO2Trim1: longTermO2Trim1,
        shortTermO2Trim2: shortTermO2Trim2,
        longTermO2Trim2: longTermO2Trim2,
        shortTermO2Trim3: shortTermO2Trim3,
        longTermO2Trim3: longTermO2Trim3,
        shortTermO2Trim4: shortTermO2Trim4,
        longTermO2Trim4: longTermO2Trim4,
        catalystTemp1: _getSmoothValue('catTemp1', _nnInt(catalystTemp1), _last?.catalystTemp1 ?? 0),
        catalystTemp2: _getSmoothValue('catTemp2', _nnInt(catalystTemp2), _last?.catalystTemp2 ?? 0),
        catalystTemp3: _getSmoothValue('catTemp3', _nnInt(catalystTemp3), _last?.catalystTemp3 ?? 0),
        catalystTemp4: _getSmoothValue('catTemp4', _nnInt(catalystTemp4), _last?.catalystTemp4 ?? 0),
        fuelPressure: _getSmoothValue('fuelPressure', _nnInt(fuelPressure), _last?.fuelPressure ?? 0),
        shortTermFuelTrim1: shortTermFuelTrim1, // Fuel trim có thể âm - không smooth
        longTermFuelTrim1: longTermFuelTrim1,
        shortTermFuelTrim2: shortTermFuelTrim2,
        longTermFuelTrim2: longTermFuelTrim2,
        o2SensorVoltage1: o2Voltage1,
        o2SensorVoltage2: o2Voltage2,
        o2SensorVoltage3: o2Voltage3,
        o2SensorVoltage4: o2Voltage4,
        o2SensorVoltage5: o2Voltage5,
        o2SensorVoltage6: o2Voltage6,
        o2SensorVoltage7: o2Voltage7,
        o2SensorVoltage8: o2Voltage8,
        engineOilTempC: engineOilTemp, // Oil temp changes slowly, no need for aggressive smoothing
        engineFuelRate: engineFuelRate,
        driverDemandTorque: driverDemandTorque,
        actualTorque: actualTorque,
        referenceTorque: _getSmoothValue('refTorque', _nnInt(referenceTorque), _last?.referenceTorque ?? 0),
        fuelEconomyL100km: fuelEconomy,
        enginePowerKw: powerKw,
        enginePowerHp: powerHp,
        acceleration: accel,
        averageSpeed: _avgSpeed,
        distanceTraveled: _distanceTraveled,
        tripTime: _tripTime,
        airFuelRatio: afr,
        volumetricEfficiency: volEff,
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
  
  // O2 Sensor Voltage (PID 0114-011B): returns voltage 0-1.275V
  // Response: 41 14 AA BB where AA=voltage (0-255 = 0-1.275V), BB=trim (-100 to +99.2%)
  static double _parseO2Voltage(String response) {
    try {
      final bytes = response.replaceAll(RegExp(r"\s+"), '').toUpperCase();
      if (bytes.length >= 8) {
        final voltageHex = bytes.substring(4, 6);
        final voltage = int.parse(voltageHex, radix: 16);
        return voltage * 0.005; // Convert to volts (0-1.275V)
      }
    } catch (_) {}
    return 0.0;
  }
  
  // Engine Oil Temperature (PID 015D): same as coolant temp (-40 to +210°C)
  static int _parseTempWithOffset(String response) {
    try {
      final bytes = response.replaceAll(RegExp(r"\s+"), '').toUpperCase();
      if (bytes.length >= 6) {
        final tempHex = bytes.substring(4, 6);
        final temp = int.parse(tempHex, radix: 16);
        return temp - 40; // Offset by -40
      }
    } catch (_) {}
    return 0;
  }
  
  // Engine Fuel Rate (PID 015F): L/h, returns 0-3212.75 L/h
  // Response: 41 5F AA BB where value = ((A*256)+B)*0.05
  static double _parseFuelRate(String response) {
    try {
      final bytes = response.replaceAll(RegExp(r"\s+"), '').toUpperCase();
      if (bytes.length >= 8) {
        final aHex = bytes.substring(4, 6);
        final bHex = bytes.substring(6, 8);
        final a = int.parse(aHex, radix: 16);
        final b = int.parse(bHex, radix: 16);
        return ((a * 256) + b) * 0.05;
      }
    } catch (_) {}
    return 0.0;
  }
  
  // Torque as Percentage (PID 0161, 0162): returns -125% to +125%
  // Response: 41 61 AA where value = A - 125
  static int _parseTorquePercent(String response) {
    try {
      final bytes = response.replaceAll(RegExp(r"\s+"), '').toUpperCase();
      if (bytes.length >= 6) {
        final torqueHex = bytes.substring(4, 6);
        final torque = int.parse(torqueHex, radix: 16);
        return torque - 125;
      }
    } catch (_) {}
    return 0;
  }

  ObdLiveData? _last;
  
  // Trip statistics for calculated values
  double _avgSpeed = 0.0;
  double _distanceTraveled = 0.0;
  int _tripTime = 0;
  DateTime? _lastTripUpdate;
  double _lastSpeed = 0.0;
  final Random _rng = Random();
  
  bool _likelyInvalid(String response) {
    final t = response.replaceAll(RegExp(r"\s+"), '');
    return t.isEmpty || t.length < 6;
  }

  // Helpers: clamp non-negative for PIDs that should not be negative
  static int _nnInt(int v) => v < 0 ? 0 : v;
  static double _nnDouble(double v) => v < 0 ? 0 : v;
  
  /// Smart value smoothing: keeps last valid value if new value is 0 or invalid
  int _getSmoothValue(String key, int newValue, int lastValue) {
    final now = DateTime.now();
    
    // If new value is valid (not 0), update cache
    if (newValue > 0) {
      _valueCache[key] = (newValue, now);
      return newValue;
    }
    
    // If new value is 0, check cache
    if (_valueCache.containsKey(key)) {
      final (cachedValue, timestamp) = _valueCache[key]!;
      final age = now.difference(timestamp);
      
      // If cache is still fresh, use it
      if (age < _cacheDuration) {
        return cachedValue;
      }
    }
    
    // If no valid cache, use last value or 0
    return lastValue > 0 ? lastValue : newValue;
  }

  // ========== ECU Data Functions ==========
  
  /// Read ECU Name
  /// Mode 09 PID 0A
  Future<String> readEcuName() async {
    try {
      final response = await _sendAndRead('09 0A');
      return _parseEcuName(response);
    } catch (e) {
      return 'Not available';
    }
  }
  
  String _parseEcuName(String response) {
    final cleaned = response.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final index = cleaned.indexOf('490A');
    if (index < 0) return 'Not available';
    
    final nameHex = cleaned.substring(index + 6);
    final nameBuffer = StringBuffer();
    
    for (int i = 0; i < nameHex.length - 1; i += 2) {
      try {
        final charCode = int.parse(nameHex.substring(i, i + 2), radix: 16);
        if (charCode >= 32 && charCode <= 126) {
          nameBuffer.write(String.fromCharCode(charCode));
        }
      } catch (_) {}
    }
    
    final name = nameBuffer.toString().trim();
    return name.isNotEmpty ? name : 'Not available';
  }
  
  /// Read Supported PIDs (Mode 01 PID 00)
  Future<List<String>> readSupportedPids() async {
    try {
      final response = await _sendAndRead('01 00');
      return _parseSupportedPids(response);
    } catch (e) {
      return [];
    }
  }
  
  List<String> _parseSupportedPids(String response) {
    final cleaned = response.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final index = cleaned.indexOf('4100');
    if (index < 0) return [];
    
    // Extract 4 bytes (32 bits) after 4100
    if (cleaned.length < index + 12) return [];
    
    final hexData = cleaned.substring(index + 4, index + 12);
    final supported = <String>[];
    
    try {
      final value = int.parse(hexData, radix: 16);
      
      // Check each bit (PIDs 01-20)
      for (int i = 0; i < 32; i++) {
        if ((value & (1 << (31 - i))) != 0) {
          supported.add('01${(i + 1).toRadixString(16).toUpperCase().padLeft(2, '0')}');
        }
      }
    } catch (_) {}
    
    return supported;
  }
  
  /// Read Engine RPM (use existing implementation)
  /// Mode 01 PID 0C - Already implemented in readRpm() above
  
  /// Read Vehicle Speed (use existing implementation)
  /// Mode 01 PID 0D - Already implemented in readSpeed() above
  
  /// Read Coolant Temperature (use existing implementation)
  /// Mode 01 PID 05 - Already implemented in readCoolantTemp() above
  
  /// Read Throttle Position
  /// Mode 01 PID 11
  Future<int> readThrottlePosition() async {
    try {
      final response = await _sendAndRead('01 11');
      return _parseThrottlePosition(response);
    } catch (e) {
      return 0;
    }
  }
  
  int _parseThrottlePosition(String response) {
    final cleaned = response.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final index = cleaned.indexOf('4111');
    if (index < 0 || cleaned.length < index + 6) return 0;
    
    try {
      final throttle = int.parse(cleaned.substring(index + 4, index + 6), radix: 16);
      return (throttle * 100) ~/ 255; // Percent = (A*100)/255
    } catch (_) {
      return 0;
    }
  }
  
  /// Read Engine Load
  /// Mode 01 PID 04
  Future<int> readEngineLoad() async {
    try {
      final response = await _sendAndRead('01 04');
      return _parseEngineLoad(response);
    } catch (e) {
      return 0;
    }
  }
  
  int _parseEngineLoad(String response) {
    final cleaned = response.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final index = cleaned.indexOf('4104');
    if (index < 0 || cleaned.length < index + 6) return 0;
    
    try {
      final load = int.parse(cleaned.substring(index + 4, index + 6), radix: 16);
      return (load * 100) ~/ 255; // Percent = (A*100)/255
    } catch (_) {
      return 0;
    }
  }
  
  /// Read Fuel Level
  /// Mode 01 PID 2F
  Future<int> readFuelLevel() async {
    try {
      final response = await _sendAndRead('01 2F');
      return _parseFuelLevel(response);
    } catch (e) {
      return 0;
    }
  }
  
  int _parseFuelLevel(String response) {
    final cleaned = response.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final index = cleaned.indexOf('412F');
    if (index < 0 || cleaned.length < index + 6) return 0;
    
    try {
      final fuel = int.parse(cleaned.substring(index + 4, index + 6), radix: 16);
      return (fuel * 100) ~/ 255; // Percent = (A*100)/255
    } catch (_) {
      return 0;
    }
  }
  
  // ============ Calculated Values Methods ============
  
  /// Calculate fuel economy (L/100km) from fuel rate and speed
  double _calculateFuelEconomy(double fuelRateLh, double speedKmh) {
    if (speedKmh < 1) return 0.0; // Avoid division by zero when stopped
    return (fuelRateLh / speedKmh) * 100; // (L/h) / (km/h) * 100 = L/100km
  }
  
  /// Calculate engine power in kW from torque and RPM
  /// Power (kW) = (Torque (Nm) * RPM) / 9549
  double _calculateEnginePowerKw(double actualTorquePercent, double referenceTorqueNm, double rpm) {
    if (referenceTorqueNm == 0 || rpm < 1) return 0.0;
    final actualTorqueNm = (actualTorquePercent / 100) * referenceTorqueNm;
    return (actualTorqueNm * rpm) / 9549;
  }
  
  /// Calculate acceleration (m/s²) from speed change
  /// Acceleration = (v2 - v1) / deltaTime
  double _calculateAcceleration(double currentSpeed, double lastSpeed) {
    const pollInterval = 0.5; // 500ms polling interval
    final deltaSpeed = currentSpeed - lastSpeed; // km/h
    final deltaSpeedMs = (deltaSpeed * 1000) / 3600; // Convert to m/s
    return deltaSpeedMs / pollInterval; // m/s²
  }
  
  /// Calculate Air/Fuel Ratio (AFR) from lambda
  /// AFR = Lambda * Stoichiometric AFR (14.7 for gasoline)
  double _calculateAFR(double lambda) {
    const stoichAFR = 14.7;
    return lambda * stoichAFR;
  }
  
  /// Calculate Volumetric Efficiency (%) from MAF, RPM, and engine load
  /// VE = (MAF * 120) / (RPM * Displacement) - simplified estimation
  double _calculateVolumetricEfficiency(double mafGs, double rpm, double engineLoad) {
    if (rpm < 1 || engineLoad < 1) return 0.0;
    // Simplified: VE ≈ Engine Load (since load is calculated from MAF/RPM anyway)
    return engineLoad;
  }
  
  /// Update trip statistics (distance, time, avg speed)
  /// In demo mode, just generate random values for visual demo
  void _updateTripStats(double currentSpeed) {
    // For demo: generate random trip stats every call
    _avgSpeed = 30.0 + _rng.nextDouble() * 40; // 30-70 km/h
    _distanceTraveled = 5.0 + _rng.nextDouble() * 45; // 5-50 km
    _tripTime = 600 + _rng.nextInt(2400); // 10-50 minutes (600-3000s)
  }
}

class O2Reading {
  final String pidHex;
  final double voltage;
  final double shortTrimPercent;
  O2Reading({required this.pidHex, required this.voltage, required this.shortTrimPercent});
}


