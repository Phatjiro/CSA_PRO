# Icon Setup Guide

## Quick Setup

1. **Place icon file:**
   - Location: `assets/icon/app_icon.png`
   - Size: 1024x1024 px
   - Format: PNG

2. **Generate icons:**
   ```bash
   flutter pub get
   flutter pub run flutter_launcher_icons
   ```

3. **Rebuild app:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

## Configuration

Package `flutter_launcher_icons` is already configured in `pubspec.yaml`:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/app_icon.png"
  adaptive_icon_background: "#1C1F2A"
  adaptive_icon_foreground: "assets/icon/app_icon.png"
  web:
    generate: true
    image_path: "assets/icon/app_icon.png"
    background_color: "#1C1F2A"
    theme_color: "#2196F3"
```

## Icon Sizes Generated

**Android:**
- mdpi: 48x48 px
- hdpi: 72x72 px
- xhdpi: 96x96 px
- xxhdpi: 144x144 px
- xxxhdpi: 192x192 px

**iOS:**
- 20x20, 29x29, 40x40, 60x60, 76x76, 1024x1024 px

**Web:**
- favicon.png and various icon sizes

## Notes

- Icon will be automatically generated for all platforms
- Keep important content in safe area (not too close to edges)
- Test on real devices to ensure proper display
