# 📱 Icon App

## 📂 Đặt Icon Ở Đây

**Đặt file icon 1024x1024 px vào đây với tên:**
- `app_icon.png` (1024x1024 px)

## ✅ Sau Khi Đặt File

1. Đặt file `app_icon.png` (1024x1024 px) vào thư mục này
2. Chạy lệnh:
   ```bash
   cd flutter-car-scanner
   flutter pub get
   flutter pub run flutter_launcher_icons
   ```
3. Rebuild app:
   ```bash
   flutter clean
   flutter run
   ```

## 📝 Lưu Ý

- File phải là PNG format
- Kích thước: 1024x1024 px
- Nền trong suốt (transparent) hoặc solid color đều được
- Package sẽ tự động generate tất cả các kích thước cần thiết cho Android, iOS, và Web

