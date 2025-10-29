# CSA_PRO - Car Scanner & OBD Development Project

Dự án phát triển hệ thống Car Scanner với OBD ELM327 Emulator và Flutter mobile app.

## Cấu trúc dự án

```
CSA_PRO/
├── obd-emulator/           # OBD ELM327 Emulator (Node.js)
│   ├── server.js           # Main server file
│   ├── package.json        # Dependencies
│   ├── public/             # Web interface
│   │   ├── index.html
│   │   ├── styles.css
│   │   └── script.js
│   └── README.md           # OBD Emulator documentation
│
├── flutter-car-scanner/    # Flutter Car Scanner App
│   └── (sẽ được tạo sau)
│
└── README.md              # Project overview (file này)
```

## Các thành phần

### 1. OBD ELM327 Emulator (`obd-emulator/`)
- **Mục đích**: Mô phỏng thiết bị OBD ELM327 để test và phát triển
- **Công nghệ**: Node.js, Express, Socket.IO, TCP Server
- **Tính năng**:
  - Giao diện web để cấu hình và monitoring
  - TCP Server nhận kết nối từ Car Scanner apps
  - Mô phỏng hơn 200 OBD PIDs
  - Live data monitoring và logging
  - Real-time communication với Flutter app

### 2. Flutter Car Scanner App (`flutter-car-scanner/`)
- **Mục đích**: Ứng dụng mobile để kết nối và đọc dữ liệu OBD
- **Công nghệ**: Flutter, Dart
- **Tính năng** (dự kiến):
  - Kết nối TCP đến OBD Emulator
  - Gửi OBD commands và nhận responses
  - Hiển thị dữ liệu real-time (RPM, Speed, Temperature, v.v.)
  - Giao diện đẹp tương tự Car Scanner apps trên thị trường
  - Lưu trữ và phân tích dữ liệu
  - Export báo cáo

## Workflow phát triển

1. **Khởi động OBD Emulator** để test và debug
2. **Phát triển Flutter app** kết nối đến emulator
3. **Test integration** giữa Flutter app và OBD emulator
4. **Deploy và test** với thiết bị OBD thật

## Cách sử dụng

### Chạy OBD Emulator
```bash
cd obd-emulator
npm install
npm start
```
Truy cập: `http://localhost:3000`

### Phát triển Flutter App
```bash
cd flutter-car-scanner
flutter create .
# Phát triển app...
```

## Lợi ích của cấu trúc này

- ✅ **Tách biệt rõ ràng** giữa emulator và mobile app
- ✅ **Dễ quản lý** và phát triển từng phần riêng biệt
- ✅ **Có thể deploy độc lập** từng component
- ✅ **Dễ dàng mở rộng** thêm các tính năng mới
- ✅ **Team development** - nhiều người có thể làm việc song song
- ✅ **Version control** tốt hơn với Git

## Roadmap

- [x] Tạo OBD ELM327 Emulator
- [ ] Phát triển Flutter Car Scanner App
- [ ] Integration testing
- [ ] UI/UX improvements
- [ ] Performance optimization
- [ ] Documentation và deployment guides

## Liên hệ

Dự án phát triển bởi CSA_PRO team.
