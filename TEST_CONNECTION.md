# 🔧 Test Connection - Troubleshooting Guide

## Vấn đề: Chỉ RPM hiển thị, Speed và Coolant Temperature không hiển thị

### 📋 Checklist quan trọng:

#### 1. Emulator có đang chạy không?
```bash
cd obd-emulator
node server.js
```

**Phải thấy:**
```
Server running at http://localhost:3000
Press CTRL+C to stop.
```

#### 2. Server đã được START chưa?
- Mở browser: `http://localhost:3000`
- **QUAN TRỌNG**: Click nút **"Start Server"**
- Status indicator phải màu **XANH**
- Console phải hiển thị: `TCP Server listening on port 35000`

**❌ Nếu chưa click "Start Server" → emulator KHÔNG hoạt động!**

#### 3. Test emulator có hoạt động không?
```bash
cd obd-emulator
node test-emulator.js
```

**Kết quả mong đợi:**
```
✅ Engine RPM (010C): xxx rpm
✅ Vehicle Speed (010D): xxx km/h
✅ Coolant Temperature (0105): xxx °C
✅ Intake Air Temperature (010F): xxx °C
✅ Throttle Position (0111): xxx %

📊 Results: 5/5 tests passed
🎉 All tests passed!
```

**❌ Nếu test FAIL:**
- Check emulator có đang chạy không
- Check đã click "Start Server" chưa
- Check firewall có block port 35000 không

---

## 🔍 Debug Flutter App

### Bước 1: Kiểm tra connection type
Trong app:
- Settings → Connection
- Đang dùng **TCP/IP** hay **Demo Mode**?

**Nếu đang dùng Demo Mode:**
- Demo mode KHÔNG cần emulator
- Nhưng có thể có bug trong demo code
- Thử chuyển sang TCP/IP mode

**Nếu đang dùng TCP/IP:**
- Host phải đúng (ví dụ: `192.168.1.76`)
- Port phải đúng (`35000`)
- Máy tính và điện thoại phải cùng mạng Wi-Fi

### Bước 2: Check IP address
```bash
# Windows:
ipconfig

# Linux/Mac:
ifconfig
```

Tìm IP của adapter mạng đang dùng (Wi-Fi hoặc Ethernet)
→ Dùng IP này trong app

### Bước 3: Chạy app từ IDE và xem console log
App bây giờ có debug logs:
```
PID 010C → "410C0894"
PID 010D → "410D5E"  
PID 0105 → "410584"

🔍 DEBUG rpmHex: "410C0894"
🔍 DEBUG speedHex: "410D5E"
🔍 DEBUG ectHex: "410584"

📊 DEBUG parsed RPM: 549, Speed: 94, Coolant: 92
```

**Các trường hợp:**

#### Trường hợp 1: Không có log PID nào
```
(không có gì)
```
→ **App không poll PIDs** - có thể chưa connect vào emulator

**Fix:** Check connection settings và reconnect

#### Trường hợp 2: PID log có nhưng response rỗng
```
PID 010C → ""
PID 010D → ""
PID 0105 → ""
```
→ **Emulator không trả về response** - có thể:
- Emulator chưa được start (chưa click "Start Server")
- Connection timeout
- IP/Port sai

**Fix:** 
- Mở Web UI: `http://localhost:3000`
- Click "Start Server"
- Verify status indicator màu xanh

#### Trường hợp 3: Response có nhưng format sai
```
PID 010C → "41 0C 08 94"   (có spaces - SAI!)
PID 010D → "41 0D 5E"      (có spaces - SAI!)
```
→ **ATS0 không được apply** - emulator vẫn trả về response có spaces

**Fix:** Đã fix ở server.js - pull code mới nhất và restart emulator

#### Trường hợp 4: Response đúng format nhưng parsed value = 0
```
PID 010D → "410D5E"
🔍 DEBUG speedHex: "410D5E"
📊 DEBUG parsed Speed: 0   (SAI - phải là 94!)
```
→ **Parser có bug** - không tìm thấy header hoặc parse sai

**Fix:** Kiểm tra parser code

#### Trường hợp 5: Response đúng, parsed đúng nhưng không hiển thị
```
PID 010D → "410D5E"
🔍 DEBUG speedHex: "410D5E"
📊 DEBUG parsed Speed: 94   (ĐÚNG!)
```
Nhưng UI vẫn hiển thị 0 hoặc "--"

→ **UI issue** - smoothing cache hoặc display logic có vấn đề

**Fix:** Kiểm tra _getSmoothValue và ObdLiveData

---

## 🎯 Quick Fix Steps:

### Nếu chỉ có RPM hiển thị mà không có Speed/Coolant:

**1. Restart emulator hoàn toàn:**
```bash
# Stop emulator (Ctrl+C)
# Start lại:
node server.js

# Mở browser: http://localhost:3000
# Click "Start Server" (QUAN TRỌNG!)
```

**2. Run test để verify:**
```bash
node test-emulator.js
```
Phải thấy ALL 5 tests PASS

**3. Restart Flutter app:**
- Stop app
- Run lại từ IDE
- Reconnect vào emulator
- Xem console log

**4. Check debug log trong console:**
Phải thấy:
```
PID 010D → "410D5E"         (response đúng format)
🔍 DEBUG speedHex: "410D5E"  (hex string đúng)
📊 DEBUG parsed Speed: 94    (parsed đúng giá trị)
```

**Nếu log đúng hết nhưng UI vẫn không hiển thị:**
→ Vấn đề ở UI layer, không phải emulator hay parser

---

## 🐛 Common Issues:

### Issue 1: "No connection" hoặc timeout
**Nguyên nhân:**
- Emulator chưa start
- IP/Port sai
- Firewall block

**Fix:**
```bash
# 1. Check emulator đang chạy:
# Phải thấy: "Server running at http://localhost:3000"

# 2. Check server đã start:
# Mở http://localhost:3000 → status phải xanh

# 3. Check IP đúng:
ipconfig  # Windows
ifconfig  # Linux/Mac

# 4. Disable firewall tạm để test
```

### Issue 2: Response format có spaces
**Nguyên nhân:**
- Emulator version cũ (trước khi fix)
- Spaces setting không đúng

**Fix:**
- Pull code mới nhất
- Restart emulator
- Verify test script pass

### Issue 3: Parser trả về 0
**Nguyên nhân:**
- Response format không đúng
- Header không match (tìm '410D' nhưng có spaces '41 0D')

**Fix:**
- Đã fix ở server.js - ATS0 sẽ loại bỏ spaces
- Parser đã có `.replaceAll(RegExp(r"\s+"), '')` để loại bỏ spaces

### Issue 4: Live data không update
**Nguyên nhân:**
- Emulator chưa start server (chưa click "Start Server")
- Không có client kết nối

**Kiểm tra:**
```javascript
// server.js line 573:
if (emulatorConfig.isRunning && connectedClients.length > 0) {
  // Live data CHỈ update khi CẢ HAI điều kiện này = true
}
```

**Fix:**
1. Mở Web UI
2. Click "Start Server" → status xanh
3. Connect app vào emulator
4. Xem tab "Live Data" trong Web UI → giá trị phải thay đổi

---

## ✅ Checklist hoàn chỉnh:

Trước khi báo bug, check tất cả các điều sau:

- [ ] Emulator đang chạy (`node server.js`)
- [ ] Server đã được START (click "Start Server" trong Web UI)
- [ ] Status indicator màu **XANH**
- [ ] Test script PASS (`node test-emulator.js` → 5/5)
- [ ] Web UI "Live Data" tab có giá trị đang thay đổi
- [ ] IP address đúng và máy tính/điện thoại cùng mạng
- [ ] Port đúng (35000)
- [ ] Firewall không block port 35000
- [ ] App đang dùng TCP/IP mode (không phải Demo mode)
- [ ] App đã reconnect sau khi start emulator
- [ ] Console log có hiển thị PIDs và responses

**Nếu tất cả đều OK nhưng vẫn không hiển thị → gửi console log để debug**

---

## 📞 Khi cần hỗ trợ:

Cung cấp thông tin sau:

1. **Test script output:**
```bash
node test-emulator.js
# Copy toàn bộ output
```

2. **Flutter console log:**
```
PID 010C → "..."
PID 010D → "..."
PID 0105 → "..."
🔍 DEBUG rpmHex: "..."
🔍 DEBUG speedHex: "..."
🔍 DEBUG ectHex: "..."
📊 DEBUG parsed RPM: ..., Speed: ..., Coolant: ...
```

3. **Emulator Web UI screenshot:**
- Tab "Live Data" có hiển thị giá trị không?
- Status indicator màu gì?
- Có bao nhiêu client connected?

4. **App connection settings:**
- TCP/IP hay Demo mode?
- Host: ?
- Port: ?

---

**Good luck! 🚗💨**

