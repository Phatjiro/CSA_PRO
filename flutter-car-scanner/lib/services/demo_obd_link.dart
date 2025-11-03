import 'dart:async';
import 'dart:math';

import 'obd_link.dart';

// Demo transport that simulates an ELM327 device entirely in-app.
// Returns plausible responses for AT commands, Mode 01/02/03/04/06/09, etc.
class DemoObdLink implements ObdLink {
  final StreamController<String> _rx = StreamController<String>.broadcast();
  bool _connected = false;

  // Simple dynamic state to make values feel alive
  final Random _rng = Random();
  int _t = 0; // ticks
  Timer? _tickTimer;
  bool _milOn = true;
  List<String> _storedDtcs = ['P0301', 'P0420'];
  List<String> _pendingDtcs = ['P0171'];
  List<String> _permanentDtcs = ['P0420'];
  Map<String, String> _freezeFrame = {}; // pid->raw

  @override
  Future<void> connect() async {
    _connected = true;
    // Start ticking to evolve dynamic values
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _t++;
    });
  }

  @override
  Future<void> disconnect() async {
    _tickTimer?.cancel();
    _tickTimer = null;
    _connected = false;
    await _rx.close();
  }

  @override
  bool get isConnected => _connected;

  @override
  Stream<String> get rx => _rx.stream;

  @override
  Future<void> tx(String command) async {
    if (!_connected) return;
    final cmd = command.trim().toUpperCase();
    final resp = _handle(cmd);
    // Emit with prompt '>' like real ELM
    _rx.add("$resp\r>\r");
  }

  String _handle(String cmd) {
    // AT commands
    if (cmd.startsWith('AT')) {
      switch (cmd) {
        case 'ATZ':
        case 'ATE0':
        case 'ATL0':
        case 'ATS0':
        case 'ATH0':
        case 'ATSP0':
          return 'OK';
        default:
          return 'OK';
      }
    }

    // Mode 01 current data
    if (cmd == '010C') return _m010C(); // RPM
    if (cmd == '010D') return _m010D(); // Speed
    if (cmd == '0105') return _m0105(); // ECT
    if (cmd == '0142') return _m0142(); // Voltage
    if (cmd == '0101') return _m0101(); // MIL + DTC count + readiness
    if (cmd == '010F') return '41 0F 24'; // IAT ~ 36 C (A-40)
    if (cmd == '0111') return '41 11 40'; // Throttle ~ 25%
    if (cmd == '012F') return '41 2F C2'; // Fuel level ~ 76%
    if (cmd == '0104') return '41 04 66'; // Calc load ~ 40%
    if (cmd == '010B') return '41 0B 3A'; // MAP ~ 58 kPa
    if (cmd == '0133') return '41 33 63'; // Baro ~ 99 kPa
    if (cmd == '0110') return '41 10 02 26'; // MAF ~ 5.5 g/s (0x0226=550)
    if (cmd == '0146') return '41 46 44'; // Ambient ~ 28 C (A-40)
    if (cmd == '015E') return '41 5E 80 00 19 9A'; // Lambda=1.00, Volt~0.8V
    if (cmd == '0103') return '41 03 02'; // Fuel system status = closed loop
    if (cmd == '010E') return '41 0E 94'; // Timing advance ~ 10 deg
    if (cmd == '011F') return '41 1F 01 2C'; // Runtime 300s
    if (cmd == '0121') return '41 21 00 0C'; // Distance with MIL = 12 km
    if (cmd == '012E') return '41 2E 26'; // Commanded purge ~ 15%
    if (cmd == '0130') return '41 30 05'; // Warmups since clear = 5
    if (cmd == '0131') return '41 31 00 78'; // Distance since clear = 120 km
    if (cmd == '013C') return '41 3C 1E 32'; // Catalyst temp ~ 500C
    if (cmd == '0143') return '41 43 4D'; // Absolute load ~ 30%
    if (cmd == '0144') return '41 44 80 00'; // Commanded equiv ratio 1.00
    if (cmd == '0145') return '41 45 33'; // Relative throttle ~ 20%
    if (cmd == '0147') return '41 47 40'; // Absolute throttle B ~ 25%
    if (cmd == '0148') return '41 48 3A'; // Absolute throttle C ~ 23%
    if (cmd == '0149') return '41 49 2D'; // Pedal position D ~ 18%
    if (cmd == '014A') return '41 4A 33'; // Pedal position E ~ 20%
    if (cmd == '014B') return '41 4B 26'; // Pedal position F ~ 15%
    if (cmd == '014C') return '41 4C 21'; // Commanded throttle actuator ~ 13%

    // O2 narrow band sensors (0114-011B): A=V*200, B=(STFT+100)*1.28
    if (cmd == '0114') return _o2(0.45, 0);
    if (cmd == '0115') return _o2(0.42, 1);
    if (cmd == '0116') return _o2(0.48, -2);
    if (cmd == '0117') return _o2(0.50, 3);
    if (cmd == '0118') return _o2(0.44, 0);
    if (cmd == '0119') return _o2(0.40, -1);
    if (cmd == '011A') return _o2(0.46, 2);
    if (cmd == '011B') return _o2(0.47, 1);

    // Freeze Frame Mode 02 minimal set (replay some current values)
    if (cmd.startsWith('02')) return _mode02(cmd);

    // DTCs
    if (cmd == '03') return _mode03(); // stored
    if (cmd == '07') return _mode07(); // pending
    if (cmd == '0A') return _mode0A(); // permanent
    if (cmd == '04') return _mode04(); // clear DTCs

    // Mode 06 basic
    if (cmd == '0600') return '46 00 01 02 03';
    if (cmd.startsWith('06')) return _mode06(cmd);

    // Mode 09 VIN (0902)
    if (cmd == '0902') return _mode0902();

    // Default no data
    return 'NO DATA';
  }

  String _m010C() {
    // RPM ~ 700..3500 sine-like
    final base = 1800 + (sin(_t / 6.0) * 900).round();
    final rpm = max(700, base + _rng.nextInt(60) - 30);
    final v = (rpm * 4); // 010C returns A,B such that rpm = ((A*256)+B)/4
    final a = (v ~/ 256) & 0xFF;
    final b = v & 0xFF;
    return '41 0C ${_h2(a)} ${_h2(b)}';
  }

  String _m010D() {
    // Speed 0..90, oscillate
    final spd = max(0, (45 + (sin(_t / 5.0) * 40)).round());
    return '41 0D ${_h2(spd)}';
  }

  String _m0105() {
    // ECT around 90C
    final ect = 85 + _rng.nextInt(6); // 85..90
    return '41 05 ${_h2(ect)}';
  }

  String _m0142() {
    // Voltage 12.2..14.2V
    final v = 12.8 + sin(_t / 7.0) * 0.6; // ~12.2..13.4
    final mv = (v * 1000).round();
    final a = ((mv ~/ 256) & 0xFF);
    final b = (mv & 0xFF);
    return '41 42 ${_h2(a)} ${_h2(b)}';
  }

  String _m0101() {
    // MIL bit7, count lower 7 bits
    final count = _storedDtcs.length;
    final a = (_milOn ? 0x80 : 0x00) | (count & 0x7F);
    // Bytes B,C,D for readiness: set a few completed
    final b = 0x00;
    final c = 0x00;
    final d = 0x00;
    return '41 01 ${_h2(a)} ${_h2(b)} ${_h2(c)} ${_h2(d)}';
  }

  String _o2(double voltage, int stftPercent) {
    final a = (voltage * 200).round().clamp(0, 255);
    final b = ((stftPercent + 100) * 1.28).round().clamp(0, 255);
    return '41 14 ${_h2(a)} ${_h2(b)}';
  }

  String _mode02(String cmd) {
    // Return some fixed snapshot for requested PIDs if known
    // Normalize: 02xx -> echo with 42xx
    final pid = cmd.substring(2).toUpperCase();
    switch (pid) {
      case '0C': // RPM
        final rpm = 1500;
        final v = rpm * 4;
        return '42 0C ${_h2(v >> 8)} ${_h2(v & 0xFF)}';
      case '0D': // Speed
        return '42 0D 28'; // 40 km/h
      case '05': // ECT
        return '42 05 58'; // 88C
      case '0F': // IAT
        return '42 0F 24'; // 36C
      case '10': // MAF
        return '42 10 01 F4'; // ~5.00 g/s
      case '11': // Throttle
        return '42 11 32'; // 50%
      default:
        return 'NO DATA';
    }
  }

  String _mode03() {
    if (_storedDtcs.isEmpty) return '43 00 00 00 00 00 00';
    return _encodeDtcs('43', _storedDtcs);
  }

  String _mode07() {
    if (_pendingDtcs.isEmpty) return '47 00 00 00 00 00 00';
    return _encodeDtcs('47', _pendingDtcs);
  }

  String _mode0A() {
    if (_permanentDtcs.isEmpty) return '4A 00 00 00 00 00 00';
    return _encodeDtcs('4A', _permanentDtcs);
  }

  String _mode04() {
    // Clear all DTCs and FF, MIL off
    _storedDtcs = [];
    _pendingDtcs = [];
    _freezeFrame.clear();
    _milOn = false;
    return '44';
  }

  String _mode06(String cmd) {
    // 06xx where xx is TID
    // Return: 46 xx vA vB minA minB maxA maxB
    final tidHex = cmd.substring(2);
    final tid = int.tryParse(tidHex, radix: 16) ?? 1;
    // Make a value in range and a min/max
    final value = 200 + (tid * 5) % 100; // arbitrary
    final min = 100;
    final max = 255;
    return '46 ${tidHex.padLeft(2, '0').toUpperCase()} ${_h2(value >> 8)} ${_h2(value & 0xFF)} 00 ${_h2(min)} 00 ${_h2(max)}';
  }

  String _mode0902() {
    // VIN split across frames. Minimal 1-frame simplified response for demo
    // Proper 0902 often uses multiple 49 02 xx ... frames; here we keep simple
    final vin = '1HGCM82633A004352';
    final bytes = vin.codeUnits;
    final hex = bytes.map((b) => _h2(b)).join(' ');
    return '49 02 01 $hex';
  }

  String _encodeDtcs(String header, List<String> dtcs) {
    final pairs = <String>[];
    for (final code in dtcs.take(3)) { // up to 3 codes (6 bytes)
      final enc = _encodeDtc(code);
      if (enc != null) pairs.add(enc);
    }
    if (pairs.isEmpty) return '$header 00 00 00 00 00 00';
    return '$header ${pairs.join(' ')}';
  }

  String? _encodeDtc(String code) {
    // P/C/B/U + 4 hex digits
    if (code.length != 5) return null;
    final sysChar = code[0].toUpperCase();
    final sysBits = {'P': 0, 'C': 1, 'B': 2, 'U': 3}[sysChar] ?? 0;
    final d1 = int.tryParse(code[1], radix: 16) ?? 0;
    final d2 = int.tryParse(code[2], radix: 16) ?? 0;
    final d3 = int.tryParse(code[3], radix: 16) ?? 0;
    final d4 = int.tryParse(code[4], radix: 16) ?? 0;
    final b1 = (sysBits << 6) | ((d1 & 0x3) << 4) | (d2 & 0xF);
    final b2 = ((d3 & 0xF) << 4) | (d4 & 0xF);
    return '${_h2(b1)} ${_h2(b2)}';
  }

  String _h2(int v) => v.clamp(0, 255).toRadixString(16).padLeft(2, '0').toUpperCase();
}


