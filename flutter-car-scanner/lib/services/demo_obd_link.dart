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
    if (cmd == '010F') return _m010F(); // IAT dynamic
    if (cmd == '0111') return _m0111(); // Throttle dynamic
    if (cmd == '012F') return _m012F(); // Fuel level dynamic
    if (cmd == '0104') return _m0104(); // Calc load dynamic
    if (cmd == '010B') return _m010B(); // MAP dynamic
    if (cmd == '0133') return _m0133(); // Baro dynamic
    if (cmd == '0110') return _m0110(); // MAF dynamic
    if (cmd == '0146') return _m0146(); // Ambient dynamic
    if (cmd == '015E') return _m015E(); // Lambda dynamic
    if (cmd == '0103') return _m0103(); // Fuel system status dynamic
    if (cmd == '010E') return _m010E(); // Timing advance dynamic
    if (cmd == '011F') return _m011F(); // Runtime dynamic
    if (cmd == '0121') return _m0121(); // Distance with MIL dynamic
    if (cmd == '012E') return _m012E(); // Commanded purge dynamic
    if (cmd == '0130') return _m0130(); // Warmups since clear dynamic
    if (cmd == '0131') return _m0131(); // Distance since clear dynamic
    if (cmd == '013C') return _m013C(); // Catalyst temp dynamic
    if (cmd == '0143') return _m0143(); // Absolute load dynamic
    if (cmd == '0144') return _m0144(); // Commanded equiv ratio dynamic
    if (cmd == '0145') return _m0145(); // Relative throttle dynamic
    if (cmd == '0147') return _m0147(); // Absolute throttle B dynamic
    if (cmd == '0148') return _m0148(); // Absolute throttle C dynamic
    if (cmd == '0149') return _m0149(); // Pedal position D dynamic
    if (cmd == '014A') return _m014A(); // Pedal position E dynamic
    if (cmd == '014B') return _m014B(); // Pedal position F dynamic
    if (cmd == '014C') return _m014C(); // Commanded throttle actuator dynamic
    if (cmd == '014D') return _m014D(); // Time run with MIL dynamic
    if (cmd == '014E') return _m014E(); // Time since codes cleared dynamic
    if (cmd == '014F') return _m014F(); // Max equiv ratio dynamic
    if (cmd == '0150') return _m0150(); // Max air flow dynamic
    if (cmd == '0151') return _m0151(); // Fuel type dynamic
    if (cmd == '0152') return _m0152(); // Ethanol fuel dynamic
    if (cmd == '0153') return _m0153(); // Abs evap pressure dynamic
    if (cmd == '0154') return _m0154(); // Evap pressure dynamic
    if (cmd == '0155') return _m0155(); // Short term O2 trim 1 dynamic
    if (cmd == '0156') return _m0156(); // Long term O2 trim 1 dynamic
    if (cmd == '0157') return _m0157(); // Short term O2 trim 2 dynamic
    if (cmd == '0158') return _m0158(); // Long term O2 trim 2 dynamic
    if (cmd == '0159') return _m0159(); // Short term O2 trim 3 dynamic
    if (cmd == '015A') return _m015A(); // Long term O2 trim 3 dynamic
    if (cmd == '015B') return _m015B(); // Short term O2 trim 4 dynamic
    // 015C handled below in "Additional Mode 01 PIDs" section (Engine Oil Temp)
    if (cmd == '013D') return _m013D(); // Catalyst temp 2 dynamic
    if (cmd == '013E') return _m013E(); // Catalyst temp 3 dynamic
    if (cmd == '013F') return _m013F(); // Catalyst temp 4 dynamic
    if (cmd == '010A') return _m010A(); // Fuel pressure dynamic
    if (cmd == '0106') return _m0106(); // Short term fuel trim 1 dynamic
    if (cmd == '0107') return _m0107(); // Long term fuel trim 1 dynamic
    if (cmd == '0108') return _m0108(); // Short term fuel trim 2 dynamic
    if (cmd == '0109') return _m0109(); // Long term fuel trim 2 dynamic
    
    // O2 narrow band sensors (0114-011B): A=V*200, B=(STFT+100)*1.28
    if (cmd == '0114') return _o2(0.45, 0);
    if (cmd == '0115') return _o2(0.42, 1);
    if (cmd == '0116') return _o2(0.48, -2);
    if (cmd == '0117') return _o2(0.50, 3);
    if (cmd == '0118') return _o2(0.44, 0);
    if (cmd == '0119') return _o2(0.40, -1);
    if (cmd == '011A') return _o2(0.46, 2);
    if (cmd == '011B') return _o2(0.47, 1);
    
    // Additional Mode 01 PIDs
    if (cmd == '015C') return _m015C(); // Engine oil temp
    if (cmd == '015F') return _m015F(); // Engine fuel rate
    if (cmd == '0161') return _m0161(); // Driver demand torque
    if (cmd == '0162') return _m0162(); // Actual torque
    if (cmd == '0163') return _m0163(); // Reference torque

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
  
  // Helper: random in range
  int _rand(int min, int max) => min + _rng.nextInt(max - min + 1);
  
  // Dynamic sensor methods - RANDOM mỗi lần gọi!
  String _m010F() => '41 0F ${_h2(_rand(20, 50) + 40)}'; // IAT: 20-50°C
  String _m0111() => '41 11 ${_h2(_rand(10, 90))}'; // Throttle: 10-90%
  String _m012F() => '41 2F ${_h2(_rand(20, 100))}'; // Fuel: 20-100%
  String _m0104() => '41 04 ${_h2(_rand(10, 80))}'; // Load: 10-80%
  String _m010B() => '41 0B ${_h2(_rand(20, 80))}'; // MAP: 20-80 kPa
  String _m0133() => '41 33 ${_h2(_rand(95, 105))}'; // Baro: 95-105 kPa
  
  String _m0110() {
    final maf = _rand(500, 4500); // MAF: 5-45 g/s (x100)
    return '41 10 ${_h2(maf ~/ 256)} ${_h2(maf % 256)}';
  }
  
  String _m0146() => '41 46 ${_h2(_rand(15, 35) + 40)}'; // Ambient: 15-35°C
  
  String _m015E() {
    final lambda = _rand(29000, 33000); // Lambda: 0.88-1.00 (x32768)
    return '41 5E ${_h2(lambda ~/ 256)} ${_h2(lambda % 256)} 19 9A';
  }
  
  String _m0103() => '41 03 0${_rand(1, 3).toRadixString(16)}'; // Fuel status: 1-3
  String _m010E() => '41 0E ${_h2(_rand(5, 25) + 128)}'; // Timing: 5-25° (offset +128)
  
  String _m011F() {
    final runtime = _rand(0, 3600); // Runtime: 0-3600s
    return '41 1F ${_h2(runtime ~/ 256)} ${_h2(runtime % 256)}';
  }
  
  String _m0121() {
    final dist = _rand(0, 500); // Distance with MIL: 0-500 km
    return '41 21 ${_h2(dist ~/ 256)} ${_h2(dist % 256)}';
  }
  
  String _m012E() => '41 2E ${_h2(_rand(10, 40))}'; // Purge: 10-40%
  String _m0130() => '41 30 ${_h2(_rand(5, 20))}'; // Warmups: 5-20
  
  String _m0131() {
    final dist = _rand(0, 5000); // Distance since clear: 0-5000 km
    return '41 31 ${_h2(dist ~/ 256)} ${_h2(dist % 256)}';
  }
  
  String _m013C() {
    final temp = _rand(3000, 6000); // Catalyst: 300-600°C (x10)
    return '41 3C ${_h2(temp ~/ 256)} ${_h2(temp % 256)}';
  }
  
  String _m0143() => '41 43 ${_h2(_rand(15, 70))}'; // Absolute load: 15-70%
  
  String _m0144() {
    final ratio = _rand(30000, 34000); // Equiv ratio: 0.91-1.03 (x32768)
    return '41 44 ${_h2(ratio ~/ 256)} ${_h2(ratio % 256)}';
  }
  
  String _m0145() => '41 45 ${_h2(_rand(10, 90))}'; // Relative throttle
  String _m0147() => '41 47 ${_h2(_rand(10, 85))}'; // Absolute throttle B
  String _m0148() => '41 48 ${_h2(_rand(10, 80))}'; // Absolute throttle C
  String _m0149() => '41 49 ${_h2(_rand(10, 95))}'; // Pedal D
  String _m014A() => '41 4A ${_h2(_rand(10, 90))}'; // Pedal E
  String _m014B() => '41 4B ${_h2(_rand(10, 85))}'; // Pedal F
  String _m014C() => '41 4C ${_h2(_rand(10, 88))}'; // Commanded throttle actuator
  
  String _m014D() {
    final time = _rand(0, 300); // Time run with MIL: 0-300 min
    return '41 4D ${_h2(time ~/ 256)} ${_h2(time % 256)}';
  }
  
  String _m014E() {
    final time = _rand(0, 3000); // Time since codes cleared: 0-3000 min
    return '41 4E ${_h2(time ~/ 256)} ${_h2(time % 256)}';
  }
  
  String _m014F() {
    final ratio = _rand(32000, 40000); // Max equiv ratio: 0.97-1.22 (x32768)
    return '41 4F ${_h2(ratio ~/ 256)} ${_h2(ratio % 256)}';
  }
  
  String _m0150() => '41 50 ${_h2(_rand(50, 255))}'; // Max air flow: 50-255 g/s
  String _m0151() => '41 51 0${_rand(1, 4).toRadixString(16)}'; // Fuel type: 1-4
  String _m0152() => '41 52 ${_h2(_rand(0, 15))}'; // Ethanol fuel: 0-15%
  
  String _m0153() {
    final press = _rand(8000, 15000); // Abs evap pressure: 80-150 kPa (x100)
    return '41 53 ${_h2(press ~/ 256)} ${_h2(press % 256)}';
  }
  
  String _m0154() {
    final press = _rand(-3000, 3000) + 32768; // Evap pressure: -30 to +30 kPa (signed, offset)
    return '41 54 ${_h2(press ~/ 256)} ${_h2(press % 256)}';
  }
  
  // O2 Trims: -100 to +99.22% → encoded as (value+100)*1.28
  String _m0155() => '41 55 ${_h2(_rand(100, 180))}'; // Short O2 trim 1: -22 to +37%
  String _m0156() => '41 56 ${_h2(_rand(100, 180))}'; // Long O2 trim 1: -22 to +37%
  String _m0157() => '41 57 ${_h2(_rand(100, 180))}'; // Short O2 trim 2: -22 to +37%
  String _m0158() => '41 58 ${_h2(_rand(100, 180))}'; // Long O2 trim 2: -22 to +37%
  String _m0159() => '41 59 ${_h2(_rand(100, 180))}'; // Short O2 trim 3: -22 to +37%
  String _m015A() => '41 5A ${_h2(_rand(100, 180))}'; // Long O2 trim 3: -22 to +37%
  String _m015B() => '41 5B ${_h2(_rand(100, 180))}'; // Short O2 trim 4: -22 to +37%
  // 015C is Engine Oil Temp - see _m015C() below in "New Mode 01 PIDs" section
  
  String _m013D() {
    final temp = _rand(3000, 6000); // Catalyst temp 2: 300-600°C (x10)
    return '41 3D ${_h2(temp ~/ 256)} ${_h2(temp % 256)}';
  }
  
  String _m013E() {
    final temp = _rand(3000, 6000); // Catalyst temp 3: 300-600°C (x10)
    return '41 3E ${_h2(temp ~/ 256)} ${_h2(temp % 256)}';
  }
  
  String _m013F() {
    final temp = _rand(3000, 6000); // Catalyst temp 4: 300-600°C (x10)
    return '41 3F ${_h2(temp ~/ 256)} ${_h2(temp % 256)}';
  }
  
  String _m010A() => '41 0A ${_h2(_rand(100, 166))}'; // Fuel pressure: 300-500 kPa (x3, normal range)
  
  // Fuel Trims: Formula (A-128)*100/128, normal range -10% to +10% → A = 115-141
  String _m0106() => '41 06 ${_h2(_rand(115, 141))}'; // Short fuel trim 1: -10 to +10% (normal)
  String _m0107() => '41 07 ${_h2(_rand(115, 141))}'; // Long fuel trim 1: -10 to +10% (normal)
  String _m0108() => '41 08 ${_h2(_rand(115, 141))}'; // Short fuel trim 2: -10 to +10% (normal)
  String _m0109() => '41 09 ${_h2(_rand(115, 141))}'; // Long fuel trim 2: -10 to +10% (normal)
  
  // New Mode 01 PIDs
  String _m015C() {
    // Engine oil temp: typical 80-110°C
    // Formula: A - 40, so for 80°C we need A=120, for 110°C we need A=150
    final temp = _rand(120, 150);
    return '41 5C ${_h2(temp)}';
  }
  
  String _m015F() {
    // Engine fuel rate: 0-3212.75 L/h → encoded as value/0.05 = ((A*256)+B)
    final rate = _rand(50, 200); // 2.5-10 L/h
    return '41 5F ${_h2(rate ~/ 256)} ${_h2(rate % 256)}';
  }
  
  String _m0161() => '41 61 ${_h2(_rand(100, 160))}'; // Driver demand torque: -25 to +35% (offset -125)
  String _m0162() => '41 62 ${_h2(_rand(90, 150))}'; // Actual torque: -35 to +25% (offset -125)
  
  String _m0163() {
    // Reference torque: 0-65535 Nm (2 bytes)
    final torque = _rand(1500, 3000); // 1500-3000 Nm
    return '41 63 ${_h2(torque ~/ 256)} ${_h2(torque % 256)}';
  }
}


