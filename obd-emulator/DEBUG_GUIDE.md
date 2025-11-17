# 🔍 Debug Guide - OBD2 Emulator & Flutter App

## Vấn đề: Speed và Coolant Temperature không hiển thị

### ✅ Đã sửa các lỗi sau:

#### 1. **Emulator không xử lý đúng command có khoảng trắng**
- **Vấn đề**: App gửi "010D" nhưng emulator không normalize command
- **Sửa**: Thêm logic `command.replace(/\s+/g, '')` để hỗ trợ cả "010D" và "01 0D"
- **File**: `server.js` dòng 838

#### 2. **Logic spaces setting bị sai**
- **Vấn đề**: Khi spaces=true, regex thêm spaces sai format: '41 0D 40' -> '41  0 D  40 '
- **Sửa**: Đổi logic - khi spaces=false thì loại bỏ spaces, khi spaces=true thì giữ nguyên
- **File**: `server.js` dòng 883-885

### 📋 Các PID chuẩn đã được implement:

| PID | Tên | Formula | Response Format | Parser |
|-----|-----|---------|----------------|--------|
| `0105` | Coolant Temp | A-40 | `41 05 VV` | `_parseCoolantTemp` |
| `010D` | Vehicle Speed | A | `41 0D VV` | `_parseSpeed` |
| `010C` | Engine RPM | (256*A+B)/4 | `41 0C AA BB` | `_parseRpm` |
| `010F` | Intake Air Temp | A-40 | `41 0F VV` | `_parseIntakeTemp` |
| `0111` | Throttle Position | A*100/255 | `41 11 VV` | `_parseThrottle` |

### 🧪 Cách kiểm tra:

#### Bước 1: Start Emulator
```bash
cd obd-emulator
node server.js
```

Sau đó mở browser: `http://localhost:3000`
- Click **"Start Server"** để bật emulator
- Emulator sẽ listen trên port **35000** (mặc định)

#### Bước 2: Kiểm tra Emulator đang chạy
Trong console bạn sẽ thấy:
```
TCP Server listening on port 35000
Server running at http://localhost:3000
```

#### Bước 3: Test bằng Telnet (Optional)
Mở terminal mới và test:
```bash
telnet localhost 35000

# Gửi lệnh:
ATZ
010D
0105
010C

# Bạn sẽ thấy response:
> ELM327 v1.2
> 410D40    (speed = 64 km/h)
> 41057B    (coolant = 123-40 = 83°C)
> 410C1F40  (rpm = (31*256+64)/4 = 2000 rpm)
```

#### Bước 4: Kết nối App Flutter
1. Mở Flutter app
2. Vào Settings -> chọn **TCP/IP Connection**
3. Nhập:
   - Host: `192.168.1.76` (hoặc IP máy chạy emulator)
   - Port: `35000`
4. Click **Connect**

#### Bước 5: Kiểm tra Debug Log
Trong console của app (khi chạy từ IDE), bạn sẽ thấy:
```
PID 010C → "410C1F40"
PID 010D → "410D40"
PID 0105 → "41057B"
```

### 🔧 Nếu vẫn không hiển thị:

#### 1. Kiểm tra emulator có đang cập nhật live data không
- Live data chỉ cập nhật khi:
  - Emulator đang chạy (`isRunning = true`)
  - VÀ có ít nhất 1 client kết nối
- Xem console log: Mỗi giây sẽ có log "Sent response: ..."

#### 2. Kiểm tra parser trong app
Thêm debug log trong `obd_client.dart`:
```dart
// Dòng 385-387
if (['010C', '010D', '0105', '010F', '0111'].contains(pid)) {
  print('PID $pid → "$response"');
  print('Parsed: ${_parseSpeed(response)}'); // Thử từng parser
}
```

#### 3. Kiểm tra enabled PIDs
App chỉ poll các PIDs được enable:
```dart
// Dòng 24
Set<String> _enabledPids = {'010C', '010D', '0105'};
```

Nếu không có trong set này, PID sẽ không được poll.

#### 4. Kiểm tra smoothing cache
App có cache để smooth giá trị:
```dart
// Dòng 32-33
final Map<String, (int value, DateTime timestamp)> _valueCache = {};
static const _cacheDuration = Duration(milliseconds: 800);
```

Nếu giá trị mới = 0, app sẽ dùng giá trị cached trong 800ms.

### 📊 Giá trị mẫu từ Emulator:

Khi mode = **random** (mặc định):
```javascript
engineRPM: 2000 + sin(time/1300)*1500    // 500-3500 rpm
vehicleSpeed: 60 + sin(time/2000)*40     // 20-100 km/h
coolantTemp: 85 + sin(time/4000)*15      // 70-100°C
```

Khi mode = **static**:
```javascript
engineRPM: 2000 rpm
vehicleSpeed: 60 km/h
coolantTemp: 85°C
```

### 🎯 Test cuối cùng:

1. **Test từ Web UI**: `http://localhost:3000`
   - Click "Start Server"
   - Xem tab "Live Data" - phải thấy giá trị đang thay đổi
   
2. **Test từ App**: 
   - Connect vào emulator
   - Vào Dashboard - phải thấy Speed và Coolant Temp đang hiển thị

3. **Test bằng tay**:
   - Dùng Web UI để set mode = "static"
   - Set vehicleSpeed = 100, coolantTemp = 90
   - App phải hiển thị đúng giá trị này

### 📝 Lưu ý quan trọng:

1. **Emulator PHẢI được start** trước khi app kết nối
2. **Live data chỉ cập nhật khi có client kết nối** (app phải connect vào)
3. **App gửi ATS0** (spaces off) nên response sẽ không có khoảng trắng: `410D40`
4. **Parser loại bỏ spaces** nên cả `410D40` và `41 0D 40` đều OK

---

## 🐛 Common Issues:

### Issue 1: "NO DATA" response
- **Nguyên nhân**: PID không tồn tại trong `obdPids` object
- **Giải pháp**: Kiểm tra `obdPids` có key đó không (line 168-238)

### Issue 2: Giá trị hiển thị = 0
- **Nguyên nhân**: 
  - Parser không tìm thấy header đúng (ví dụ: tìm '410D' nhưng response là '41 0D')
  - Cache trả về giá trị 0
- **Giải pháp**: 
  - Check debug log xem response có đúng format không
  - Parser đã loại bỏ spaces nên không sao

### Issue 3: Emulator không cập nhật giá trị
- **Nguyên nhân**: `isRunning = false` hoặc `connectedClients.length = 0`
- **Giải pháp**: 
  - Click "Start Server" trong Web UI
  - Đảm bảo app đã connect vào emulator

---

**🎉 Sau khi áp dụng các fix này, Speed và Coolant Temperature phải hiển thị đúng!**

