# 📱 Hướng Dẫn Thay Đổi Icon App

## 📂 Vị Trí Icon

### 🤖 Android

Icon Android nằm trong các thư mục `mipmap` với các kích thước khác nhau:

```
flutter-car-scanner/
└── android/
    └── app/
        └── src/
            └── main/
                └── res/
                    ├── mipmap-mdpi/      → ic_launcher.png (48x48 px)
                    ├── mipmap-hdpi/      → ic_launcher.png (72x72 px)
                    ├── mipmap-xhdpi/     → ic_launcher.png (96x96 px)
                    ├── mipmap-xxhdpi/    → ic_launcher.png (144x144 px)
                    └── mipmap-xxxhdpi/   → ic_launcher.png (192x192 px)
```

**File cần thay:**
- `android/app/src/main/res/mipmap-mdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-hdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`

### 🍎 iOS

Icon iOS nằm trong `AppIcon.appiconset`:

```
flutter-car-scanner/
└── ios/
    └── Runner/
        └── Assets.xcassets/
            └── AppIcon.appiconset/
                ├── Contents.json
                ├── Icon-App-20x20@1x.png          (20x20)
                ├── Icon-App-20x20@2x.png          (40x40)
                ├── Icon-App-20x20@3x.png          (60x60)
                ├── Icon-App-29x29@1x.png          (29x29)
                ├── Icon-App-29x29@2x.png          (58x58)
                ├── Icon-App-29x29@3x.png          (87x87)
                ├── Icon-App-40x40@1x.png          (40x40)
                ├── Icon-App-40x40@2x.png          (80x80)
                ├── Icon-App-40x40@3x.png          (120x120)
                ├── Icon-App-60x60@2x.png          (120x120)
                ├── Icon-App-60x60@3x.png          (180x180)
                ├── Icon-App-76x76@1x.png          (76x76)
                ├── Icon-App-76x76@2x.png          (152x152)
                ├── Icon-App-83.5x83.5@2x.png       (167x167)
                └── Icon-App-1024x1024@1x.png      (1024x1024) ⭐ App Store
```

**File quan trọng nhất:**
- `Icon-App-1024x1024@1x.png` - Icon cho App Store (1024x1024 px)

### 🌐 Web

Icon web nằm trong thư mục `web`:

```
flutter-car-scanner/
└── web/
    ├── favicon.png
    └── icons/
        ├── Icon-192.png
        ├── Icon-512.png
        └── ...
```

---

## 🎨 Cách Thay Đổi Icon

### Phương Pháp 1: Thủ Công (Manual)

1. **Tạo icon với các kích thước cần thiết:**
   - Android: 48x48, 72x72, 96x96, 144x144, 192x192 px
   - iOS: Tất cả các kích thước trong AppIcon.appiconset

2. **Thay thế file:**
   - Android: Thay các file `ic_launcher.png` trong các thư mục `mipmap-*`
   - iOS: Thay các file trong `AppIcon.appiconset/`

3. **Rebuild app:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

### Phương Pháp 2: Sử Dụng Package (Khuyến nghị)

Sử dụng package `flutter_launcher_icons` để tự động generate icon:

1. **Thêm vào `pubspec.yaml`:**
   ```yaml
   dev_dependencies:
     flutter_launcher_icons: ^0.13.1
   
   flutter_launcher_icons:
     android: true
     ios: true
     image_path: "assets/icon/app_icon.png"  # Icon gốc 1024x1024
     adaptive_icon_background: "#FFFFFF"     # Màu nền (Android adaptive)
     adaptive_icon_foreground: "assets/icon/app_icon_foreground.png"
   ```

2. **Tạo thư mục và đặt icon:**
   ```
   flutter-car-scanner/
   └── assets/
       └── icon/
           ├── app_icon.png              (1024x1024 px)
           └── app_icon_foreground.png   (1024x1024 px, transparent background)
   ```

3. **Generate icon:**
   ```bash
   flutter pub get
   flutter pub run flutter_launcher_icons
   ```

---

## 📐 Kích Thước Icon Chuẩn

### Android

| Density | Kích thước | File |
|---------|-----------|------|
| mdpi    | 48x48 px  | `mipmap-mdpi/ic_launcher.png` |
| hdpi    | 72x72 px  | `mipmap-hdpi/ic_launcher.png` |
| xhdpi   | 96x96 px  | `mipmap-xhdpi/ic_launcher.png` |
| xxhdpi  | 144x144 px| `mipmap-xxhdpi/ic_launcher.png` |
| xxxhdpi | 192x192 px| `mipmap-xxxhdpi/ic_launcher.png` |

**Adaptive Icon (Android 8.0+):**
- Foreground: 108x108 px (sẽ được scale)
- Background: 108x108 px hoặc màu solid

### iOS

| Kích thước | File | Mục đích |
|-----------|------|----------|
| 20x20     | `Icon-App-20x20@1x.png` | Notification |
| 29x29     | `Icon-App-29x29@1x.png` | Settings |
| 40x40     | `Icon-App-40x40@1x.png` | Spotlight |
| 60x60     | `Icon-App-60x60@2x.png` | App icon |
| 76x76     | `Icon-App-76x76@1x.png` | iPad |
| 1024x1024 | `Icon-App-1024x1024@1x.png` | App Store |

---

## ✅ Checklist

- [ ] Tạo icon 1024x1024 px (gốc)
- [ ] Generate các kích thước cho Android
- [ ] Generate các kích thước cho iOS
- [ ] Thay thế file trong các thư mục tương ứng
- [ ] Test trên Android device/emulator
- [ ] Test trên iOS device/simulator
- [ ] Rebuild app: `flutter clean && flutter pub get`

---

## 🛠️ Tools Hữu Ích

1. **Online Icon Generator:**
   - [AppIcon.co](https://www.appicon.co/)
   - [IconKitchen](https://icon.kitchen/)
   - [MakeAppIcon](https://makeappicon.com/)

2. **Flutter Packages:**
   - `flutter_launcher_icons` - Auto generate icons
   - `flutter_launcher_name` - Change app name

---

## 📝 Lưu Ý

1. **Format:** PNG với transparent background (iOS), hoặc solid background (Android)
2. **Không bo góc:** iOS tự động bo góc, Android adaptive icon cần thiết kế riêng
3. **Safe area:** Giữ nội dung quan trọng trong safe area (không quá sát viền)
4. **Test:** Luôn test icon trên device thật để đảm bảo hiển thị đúng

---

**Sau khi thay icon, chạy:**
```bash
flutter clean
flutter pub get
flutter run
```

