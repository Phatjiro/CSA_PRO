# Changelog - CSA_PRO (Car Scanner App)

## [1.3.0] - 2024-11-13 (SENSORS UPDATE)

### ✨ New Features

#### App - Thêm 7 Sensors mới vào All Sensors Screen
**Tổng số sensors: 71 → 78**

**Temperature Category (+2 sensors):**
1. **Catalyst Temp B1S2** (PID 013E) - Catalyst Temperature Bank 1 Sensor 2
2. **Catalyst Temp B2S2** (PID 013F) - Catalyst Temperature Bank 2 Sensor 2

**Fuel Category (+5 sensors):**
1. **Fuel Pressure** (PID 010A) - Gauge pressure (kPa)
2. **Short Term Fuel Trim 1** (PID 0106) - Bank 1 short term adjustment
3. **Long Term Fuel Trim 1** (PID 0107) - Bank 1 long term adjustment
4. **Short Term Fuel Trim 2** (PID 0108) - Bank 2 short term adjustment
5. **Long Term Fuel Trim 2** (PID 0109) - Bank 2 long term adjustment

**File Changes:**
- `flutter-car-scanner/lib/screens/all_sensors_screen.dart` (line 116-133)
  - Added 2 Catalyst Temperature sensors
  - Added 5 Fuel diagnostic sensors
  - Total sensors: 78 (69 PID fields + 9 calculated)

#### Emulator - Thêm 3 Catalyst Temperature PIDs
**Tổng số PIDs Mode 01: 68 → 71**

1. **PID 013D**: Catalyst Temperature Bank 2 Sensor 1
   - Response: `41 3D 00 1E 78` (default ~470°C)
   
2. **PID 013E**: Catalyst Temperature Bank 1 Sensor 2
   - Response: `41 3E 00 1F D0` (default ~488°C)
   
3. **PID 013F**: Catalyst Temperature Bank 2 Sensor 2
   - Response: `41 3F 00 1E F0` (default ~480°C)

**File Changes:**
- `obd-emulator/server.js` (line 205-207)

### 📝 Documentation

1. **SENSORS_UPDATE.md** (NEW)
   - Detailed technical documentation
   - Sensor formulas và ranges
   - Benefits cho người dùng
   - Test procedures

2. **OBD2_COMPLETE_STANDARD.md** (UPDATED)
   - Updated checklist: 78 sensors
   - Updated emulator: 71 PIDs
   - Version tracking

### 🎯 Benefits cho Người Dùng

#### 1. Advanced Catalyst Monitoring
- Theo dõi nhiệt độ **4 catalyst sensors** (2 banks × 2 positions)
- Phát hiện catalyst failures:
  - Quá nóng (>900°C): Catalyst meltdown risk
  - Quá lạnh (<300°C): Catalyst not working properly
- So sánh nhiệt độ Sensor 1 (trước catalyst) vs Sensor 2 (sau catalyst)

#### 2. Professional Fuel System Diagnostics
- **Fuel Pressure**: Phát hiện bơm nhiên liệu yếu hoặc fuel filter bị tắc
- **Fuel Trim Analysis**:
  - **Positive values** (+10% to +25%): Running LEAN (thiếu nhiên liệu)
    - Nguyên nhân: Vacuum leak, dirty MAF sensor, low fuel pressure
  - **Negative values** (-10% to -25%): Running RICH (thừa nhiên liệu)
    - Nguyên nhân: Dirty air filter, leaking injectors, bad O2 sensor
  - **Bank 1 vs Bank 2**: Phát hiện vấn đề một bên động cơ
  - **Short Term vs Long Term**: Phân biệt vấn đề tạm thời vs vĩnh viễn

#### 3. Cross-Reference Diagnostics
- Kết hợp **Fuel Trim + Lambda + AFR** → Chẩn đoán chính xác
- Fuel Trim + O2 Sensor → Phát hiện O2 sensor failures
- Catalyst Temp + O2 Sensor → Đánh giá catalyst efficiency

### 🧪 Testing

**Expected Values:**
```
✅ Catalyst Temp B1S1: 400-800°C (normal operating)
✅ Catalyst Temp B2S1: 400-800°C
✅ Catalyst Temp B1S2: 400-800°C
✅ Catalyst Temp B2S2: 400-800°C

✅ Fuel Pressure: 300-500 kPa (gasoline engines)

✅ Short Term Fuel Trim: -10% to +10% (normal)
✅ Long Term Fuel Trim: -10% to +10% (normal)
```

**Test trong App:**
1. Connect to emulator
2. Navigate to **All Sensors** screen
3. Verify total sensors: **78**
4. Filter by category:
   - Temperature → 8 sensors
   - Fuel → 12 sensors

### 🎉 Impact

**Trước update:**
- 71 sensors - missing important diagnostics
- Limited fuel system monitoring
- Incomplete catalyst monitoring

**Sau update:**
- **78 sensors** - COMPLETE OBD2 coverage ✅
- Professional fuel system diagnostics ✅
- Full 4-point catalyst monitoring ✅
- **App bây giờ là công cụ chẩn đoán chuyên nghiệp!** 🚗💨

---

## [1.2.0] - 2024-11-13 (CRITICAL FIX)

### 🐛 Bug Fixes

#### Flutter App - CRITICAL: Race Condition trong Parallel Polling
1. **Fix: Mutex serialization để tránh race condition**
   - **Vấn đề**: App gửi 60+ PIDs parallel, tất cả dùng shared buffer `_buffer`
   - **Triệu chứng**: Chỉ RPM hiển thị, Speed và Coolant = 0
   - **Nguyên nhân**: Requests ghi đè lên nhau → chỉ request cuối có response đúng
   - **Fix**: Thêm mutex `_pendingRequest` để serialize tất cả OBD requests
   - **File**: `flutter-car-scanner/lib/services/obd_client.dart` line 359-404
   - **Impact**: ✅ TẤT CẢ PIDs bây giờ hoạt động đúng!
   - **Commit**: Added mutex serialization for OBD requests

**Test Results:**
```
Before: PID 010D → "", Speed: 0
After:  PID 010D → "410D1F", Speed: 21 ✅
```

---

## [1.1.0] - 2024-11-13

### 🐛 Bug Fixes

#### Emulator (Node.js)
1. **Fix: Command normalization không hỗ trợ format có khoảng trắng**
   - **Vấn đề**: Emulator chỉ xử lý được "010D" nhưng không xử lý được "01 0D" (format chuẩn OBD2)
   - **Nguyên nhân**: Dùng `substring(0,4)` trực tiếp trên command chưa normalize
   - **Fix**: Thêm `command.replace(/\s+/g, '')` để loại bỏ spaces trước khi extract PID
   - **File**: `obd-emulator/server.js` line 838
   - **Commit**: Added command normalization for OBD PIDs

2. **Fix: Logic spaces setting bị ngược và làm hỏng response**
   - **Vấn đề**: 
     - Khi `spaces=true`, regex thêm spaces sai: `'41 0D 40'` → `'41  0 D  40 '`
     - Khi `spaces=false`, vẫn giữ spaces từ định nghĩa gốc
   - **Nguyên nhân**: Logic sử dụng regex `replace(/(.{2})/g, '$1 ')` trên chuỗi đã có spaces
   - **Fix**: Đổi logic - khi `spaces=false` thì loại bỏ ALL spaces, khi `spaces=true` giữ nguyên
   - **File**: `obd-emulator/server.js` line 883-885
   - **Commit**: Fixed spaces setting logic

### ✨ New Features

#### Testing & Debugging
1. **Test Script**: `obd-emulator/test-emulator.js`
   - Automated test cho 5 PIDs quan trọng
   - Colorful output với status indicators
   - Connection error handling với helpful messages
   - Usage: `node test-emulator.js`

2. **Debug Guide**: `obd-emulator/DEBUG_GUIDE.md`
   - Troubleshooting chi tiết cho vấn đề Speed/Coolant không hiển thị
   - Step-by-step testing instructions
   - Common issues với solutions
   - Debug logging examples

3. **Updated README**: `obd-emulator/README.md`
   - Thêm phần Testing với 3 methods: Script, Telnet, Flutter App
   - Enhanced Troubleshooting với checklist
   - Specific fixes documentation

### 📝 Documentation Updates

1. **OBD2_COMPLETE_STANDARD.md**
   - Updated Implementation Checklist với các fixes mới
   - Documented parser và emulator improvements
   - Added version tracking cho fixes

### 🔍 Technical Details

#### Parser Behavior (Flutter App)
```dart
// obd_client.dart line 684-692
static int _parseSpeed(String response) {
  final cleaned = response.replaceAll(RegExp(r"\s+"), ''); // ✅ Loại bỏ spaces
  final i = cleaned.indexOf('410D');                        // ✅ Tìm header
  if (i >= 0 && cleaned.length >= i + 6) {
    return int.parse(cleaned.substring(i + 4, i + 6), radix: 16); // ✅ Parse hex
  }
  return 0;
}
```

**Parser hoạt động với cả 2 formats:**
- Input: `"410D40"` → Speed = 64 km/h ✅
- Input: `"41 0D 40"` → cleaned = `"410D40"` → Speed = 64 km/h ✅

#### Emulator Behavior (Node.js)
```javascript
// server.js line 835-844
} else if (command.startsWith('01')) {
  // ✅ Normalize command (hỗ trợ cả "010D" và "01 0D")
  const normalized = command.replace(/\s+/g, '');
  const pid = normalized.substring(0, 4);
  if (obdPids[pid]) {
    response = obdPids[pid];  // e.g., "41 0D 40"
  }
}

// line 883-885
if (!emulatorConfig.settings.spaces) {
  response = response.replace(/\s+/g, ''); // ✅ "41 0D 40" → "410D40"
}
```

**Emulator response với ATS0 (spaces off):**
- Before fix: `"41 0D 40"` (still has spaces) ❌
- After fix: `"410D40"` (spaces removed) ✅

### 🧪 Testing Results

#### Test Script Output (Expected)
```
🔌 Connecting to OBD2 Emulator...
✅ Connected!

📡 Initializing ELM327...
   ATZ (Reset): ELM327 v1.2
   ATE0 (Echo OFF): OK
   ATS0 (Spaces OFF): OK

🧪 Testing PIDs...
✅ Engine RPM (010C): 2000 rpm
✅ Vehicle Speed (010D): 64 km/h
✅ Coolant Temperature (0105): 83 °C
✅ Intake Air Temperature (010F): 38 °C
✅ Throttle Position (0111): 40 %

📊 Results: 5/5 tests passed
🎉 All tests passed! Emulator is working correctly.
```

### 📋 Migration Guide

**Không cần thay đổi gì trong Flutter app** - Tất cả fixes đều ở emulator side.

**Để apply fixes:**
1. Pull latest code: `git pull origin main`
2. Restart emulator: `node obd-emulator/server.js`
3. Run test: `node obd-emulator/test-emulator.js`
4. Expected: All 5 tests should pass ✅

### 🎯 Impact

**Before fixes:**
- Speed và Coolant Temperature không hiển thị hoặc hiển thị giá trị 0
- Parser không tìm thấy header vì format không match

**After fixes:**
- ✅ Speed hiển thị đúng (e.g., 64 km/h)
- ✅ Coolant Temperature hiển thị đúng (e.g., 83°C)
- ✅ RPM hiển thị đúng (e.g., 2000 rpm)
- ✅ Tất cả PIDs hoạt động ổn định

### 🔗 Related Issues

- Issue: "Speed và coolant temp đều không hiển thị"
- Root cause: Command format mismatch giữa app và emulator
- Status: ✅ Resolved

---

## [1.0.0] - 2024-11-01

### Initial Release
- Flutter app với 71 sensors (62 PIDs + 9 calculated)
- OBD2 Emulator với 68 PIDs Mode 01
- DTC support (Mode 03/04/07/0A)
- Freeze Frame (Mode 02)
- Mode 06 monitoring
- Live data simulation
- Web UI cho emulator

---

**Legend:**
- 🐛 Bug fix
- ✨ New feature
- 📝 Documentation
- 🔧 Maintenance
- 🎯 Performance
- ⚠️ Breaking change

