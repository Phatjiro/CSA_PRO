# OBD ELM327 Emulator

Một ứng dụng web mô phỏng thiết bị OBD ELM327 để phát triển và test các ứng dụng Car Scanner. Ứng dụng cung cấp giao diện trực quan để cấu hình và theo dõi dữ liệu OBD real-time.

## Tính năng chính

### 🚗 OBD ELM327 Simulation
- Mô phỏng đầy đủ giao thức OBD ELM327
- Hỗ trợ hơn 200 OBD PIDs (Parameter IDs)
- TCP Server để nhận kết nối từ Car Scanner apps
- Response time thực tế và chính xác

### 🎛️ Giao diện điều khiển
- **Simulator Settings**: Cấu hình ELM name, version, device ID, VIN code
- **ECU Count**: Điều chỉnh số lượng ECU (1-10)
- **Network Settings**: Cấu hình IP server và port
- **Toggle Switches**: Bật/tắt các tính năng như Echo, Headers, DLC, v.v.

### 📊 Live Data Monitoring
- Hiển thị dữ liệu real-time: RPM, Speed, Temperature, v.v.
- Progress bars trực quan cho từng thông số
- Animation khi dữ liệu thay đổi
- Theo dõi số lượng client kết nối

### 📝 Communication Log
- Log chi tiết tất cả lệnh OBD và response
- Timestamp cho mỗi giao dịch
- Phân loại log theo loại (INFO, COMMAND, RESPONSE, ERROR)
- Chức năng clear log

## Cài đặt và chạy

### Yêu cầu hệ thống
- Node.js 14.0 trở lên
- NPM hoặc Yarn

### Cài đặt
```bash
# Clone repository
git clone <repository-url>
cd obd-elm327-emulator

# Cài đặt dependencies
npm install
```

### Chạy ứng dụng
```bash
# Chạy ở chế độ production
npm start

# Chạy ở chế độ development (với auto-reload)
npm run dev
```

Ứng dụng sẽ chạy tại: `http://localhost:3000`

## Cách sử dụng

### 1. Cấu hình Emulator
- Mở trình duyệt và truy cập `http://localhost:3000`
- Cấu hình các thông số trong phần "Simulator Settings":
  - **ELM name**: Tên thiết bị (mặc định: ELM327)
  - **ELM version**: Phiên bản (mặc định: v1.2)
  - **Device ID**: ID thiết bị
  - **VIN code**: Mã VIN của xe
  - **ECU count**: Số lượng ECU (1-10)
  - **Server**: IP address (mặc định: 192.168.1.76)
  - **Port**: Port TCP (mặc định: 35000)

### 2. Cấu hình Settings
Điều chỉnh các toggle switches:
- **Echo**: Hiển thị lại lệnh
- **Headers**: Hiển thị headers trong response
- **DLC**: Data Length Code
- **Line feed**: Thêm line feed
- **Spaces**: Thêm spaces trong response
- **Double LF**: Double line feed

### 3. Khởi động Server
- Nhấn nút "Start Server" để khởi động TCP server
- Server sẽ lắng nghe trên IP và port đã cấu hình
- Status indicator sẽ chuyển sang màu xanh khi server đang chạy

### 4. Kết nối từ Car Scanner App
Trong ứng dụng Car Scanner của bạn, kết nối đến:
- **Host**: IP address đã cấu hình (mặc định: 192.168.1.76)
- **Port**: Port đã cấu hình (mặc định: 35000)
- **Protocol**: TCP

### 5. Theo dõi dữ liệu
- Xem live data trong phần "Live Data"
- Theo dõi communication log trong phần "Communication Log"
- Số lượng client kết nối hiển thị ở góc phải

## OBD PIDs được hỗ trợ

Ứng dụng hỗ trợ hơn 200 OBD PIDs phổ biến, bao gồm:

### Engine Data
- `0105`: Engine Coolant Temperature
- `010C`: Engine RPM
- `010D`: Vehicle Speed
- `010F`: Intake Air Temperature
- `0110`: MAF Air Flow Rate
- `0111`: Throttle Position

### Fuel System
- `012F`: Fuel Tank Level Input
- `0142`: Control Module Voltage
- `0144`: Commanded Equivalence Ratio

### Emission Control
- `0133`: Barometric Pressure
- `0146`: Ambient Air Temperature
- `0147`: Absolute Throttle Position B

### Và nhiều PIDs khác...

## API Endpoints

### GET /api/config
Lấy cấu hình hiện tại của emulator

### POST /api/config
Cập nhật cấu hình emulator

### POST /api/start
Khởi động TCP server

### POST /api/stop
Dừng TCP server

## Socket.IO Events

### Client → Server
- `config`: Gửi cấu hình
- `status`: Gửi trạng thái

### Server → Client
- `config`: Nhận cấu hình
- `status`: Nhận trạng thái server
- `liveData`: Nhận dữ liệu live
- `log`: Nhận log entries
- `clients`: Số lượng client kết nối

## Cấu trúc dự án

```
obd-elm327-emulator/
├── server.js              # Main server file
├── package.json           # Dependencies và scripts
├── README.md             # Documentation
└── public/               # Static files
    ├── index.html        # Main HTML file
    ├── styles.css        # CSS styles
    └── script.js         # Client-side JavaScript
```

## 🧪 Testing

### Quick Test với Script
Chạy test script để kiểm tra emulator:
```bash
node test-emulator.js
```

Script sẽ test các PIDs quan trọng:
- ✅ Engine RPM (010C)
- ✅ Vehicle Speed (010D)
- ✅ Coolant Temperature (0105)
- ✅ Intake Air Temperature (010F)
- ✅ Throttle Position (0111)

### Manual Test với Telnet
```bash
telnet localhost 35000

# Gửi lệnh:
ATZ
010D
0105
010C

# Response mong đợi:
> ELM327 v1.2
> 410D3C     (Speed = 60 km/h)
> 41057D     (Coolant = 85°C)
> 410C1F40   (RPM = 2000 rpm)
```

### Test với Flutter App
1. Start emulator: `node server.js`
2. Mở Web UI: `http://localhost:3000`
3. Click **"Start Server"**
4. Trong Flutter app:
   - Settings → TCP/IP Connection
   - Host: `192.168.1.76` (hoặc IP máy chạy emulator)
   - Port: `35000`
   - Click **Connect**
5. Vào Dashboard → xem Speed, Coolant Temp, RPM

## Troubleshooting

### ❌ Vấn đề: Speed và Coolant Temperature không hiển thị

**Đã sửa các lỗi sau (v1.1.0):**
1. ✅ Emulator không xử lý đúng command có khoảng trắng
2. ✅ Logic spaces setting bị sai (thêm spaces duplicate)

**Kiểm tra:**
```bash
# 1. Chạy test script
node test-emulator.js

# 2. Xem debug log trong console
# Phải thấy: "PID 010D → 410D3C"
```

**Debug trong Flutter app:**
Thêm log vào `obd_client.dart` (dòng 385):
```dart
if (['010C', '010D', '0105'].contains(pid)) {
  print('PID $pid → "$response"');
}
```

Xem thêm: [DEBUG_GUIDE.md](./DEBUG_GUIDE.md)

### ❌ Server không khởi động được
- Kiểm tra port có bị sử dụng: `netstat -an | grep 35000`
- Thử đổi port khác: Edit `emulatorConfig.port` trong `server.js`
- Kiểm tra firewall: `sudo ufw allow 35000/tcp` (Linux)

### ❌ Car Scanner không kết nối được
- **IP sai**: Kiểm tra IP máy chạy emulator: `ipconfig` (Windows) hoặc `ifconfig` (Linux/Mac)
- **Port bị block**: Tạm tắt firewall để test
- **Khác mạng**: Đảm bảo điện thoại và máy tính cùng mạng Wi-Fi

### ❌ Live data không cập nhật
**Nguyên nhân:**
- Emulator chưa start (click "Start Server" trong Web UI)
- Không có client kết nối (app chưa connect)

**Kiểm tra:**
```javascript
// Trong server.js dòng 573:
if (emulatorConfig.isRunning && connectedClients.length > 0) {
  // Live data chỉ cập nhật khi cả 2 điều kiện này = true
}
```

**Fix:**
1. Mở Web UI: `http://localhost:3000`
2. Click "Start Server" (status phải chuyển sang xanh)
3. Connect app vào emulator
4. Xem tab "Live Data" trong Web UI → giá trị phải đang thay đổi

### ❌ Response format sai
**Vấn đề:** App gửi `ATS0` (spaces off) nhưng emulator vẫn trả về có spaces

**Fix:** Đã sửa trong v1.1.0 - khi `spaces=false`, emulator sẽ loại bỏ tất cả spaces khỏi response

**Test:**
```bash
telnet localhost 35000
ATS0        # spaces off
010D        # request speed

# Response: 410D3C (không có spaces)
# Trước đây: 41 0D 3C (có spaces - sai!)
```

### 📋 Checklist khi gặp lỗi:
- [ ] Emulator đang chạy (`node server.js`)
- [ ] Server đã start (click "Start Server" trong Web UI)
- [ ] App đã connect vào emulator
- [ ] Live data đang cập nhật (xem Web UI tab "Live Data")
- [ ] Test script pass (`node test-emulator.js`)
- [ ] Debug log có hiển thị response đúng

## Đóng góp

Mọi đóng góp đều được chào đón! Hãy tạo issue hoặc pull request để cải thiện dự án.

## License

MIT License - Xem file LICENSE để biết thêm chi tiết.

## Liên hệ

Nếu có câu hỏi hoặc cần hỗ trợ, vui lòng tạo issue trên GitHub repository.
