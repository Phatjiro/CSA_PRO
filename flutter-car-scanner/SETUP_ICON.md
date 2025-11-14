# 🎨 Hướng Dẫn Setup Icon App

## ✅ Đã Cấu Hình Sẵn

Package `flutter_launcher_icons` đã được thêm vào `pubspec.yaml` và cấu hình sẵn.

## 📝 Các Bước Thực Hiện

### Bước 1: Đặt Icon Vào Thư Mục

**Đặt file icon 1024x1024 px của bạn vào:**
```
flutter-car-scanner/assets/icon/app_icon.png
```

**Yêu cầu:**
- ✅ Format: PNG
- ✅ Kích thước: 1024x1024 px
- ✅ Nền: Transparent hoặc solid color đều được

### Bước 2: Install Package

```bash
cd flutter-car-scanner
flutter pub get
```

### Bước 3: Generate Icons

```bash
flutter pub run flutter_launcher_icons
```

Lệnh này sẽ tự động:
- ✅ Generate tất cả kích thước cho Android (mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi)
- ✅ Generate tất cả kích thước cho iOS (20x20, 29x29, 40x40, 60x60, 76x76, 1024x1024)
- ✅ Generate icon cho Web
- ✅ Tạo adaptive icon cho Android 8.0+

### Bước 4: Rebuild App

```bash
flutter clean
flutter pub get
flutter run
```

## 🎯 Kết Quả

Sau khi chạy lệnh, tất cả icon sẽ được tự động generate và đặt vào đúng vị trí:
- ✅ Android: `android/app/src/main/res/mipmap-*/ic_launcher.png`
- ✅ iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- ✅ Web: `web/icons/` và `web/favicon.png`

## ⚙️ Cấu Hình Hiện Tại

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/app_icon.png"
  adaptive_icon_background: "#1C1F2A"  # Màu nền dark theme
  adaptive_icon_foreground: "assets/icon/app_icon.png"
  web:
    generate: true
    image_path: "assets/icon/app_icon.png"
    background_color: "#1C1F2A"
    theme_color: "#2196F3"
```

## 🔧 Tùy Chỉnh (Nếu Cần)

Nếu muốn thay đổi cấu hình, sửa trong `pubspec.yaml`:
- `adaptive_icon_background`: Màu nền cho Android adaptive icon
- `theme_color`: Màu theme cho web

Sau đó chạy lại:
```bash
flutter pub run flutter_launcher_icons
```

---

**Sau khi đặt file `app_icon.png` vào `assets/icon/`, chạy các lệnh trên là xong!** 🎉

