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

## Troubleshooting

### Server không khởi động được
- Kiểm tra port có bị sử dụng bởi ứng dụng khác không
- Thử đổi port khác (ví dụ: 35001, 35002)
- Kiểm tra firewall settings

### Car Scanner không kết nối được
- Đảm bảo IP address đúng
- Kiểm tra port có mở không
- Thử kết nối từ cùng mạng LAN

### Dữ liệu không hiển thị
- Kiểm tra log để xem có lỗi gì không
- Đảm bảo Car Scanner app gửi đúng format OBD commands
- Kiểm tra toggle settings có phù hợp không

## Đóng góp

Mọi đóng góp đều được chào đón! Hãy tạo issue hoặc pull request để cải thiện dự án.

## License

MIT License - Xem file LICENSE để biết thêm chi tiết.

## Liên hệ

Nếu có câu hỏi hoặc cần hỗ trợ, vui lòng tạo issue trên GitHub repository.
