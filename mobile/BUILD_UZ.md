# Android build — Lingoy 3.5.0

Tekshirilgan vositalar: Flutter 3.50.1 stable, Dart 3.14.0, to‘liq JDK 21 (`java` va `javac`), Android SDK 35/36, Build Tools 36.0.0, CMake 3.22.1 va NDK 28.2.13676358. Kutubxonalar `pubspec.lock` bilan belgilangan.

1. Git orqali olingan loyihada avval ildiz papkadan `python3 tools/bootstrap_assets.py` ni bajaring. To‘liq server ZIP’dan ochilgan papkada barcha resurslar mavjud.
2. `mobile/.env.example` dan `mobile/.env` nusxasini yarating va signing sozlamalarini kiriting.
3. Mavjud Lingoy ustiga yangilanadigan APK uchun asl signing kalitidan foydalaning. GitHub tarqatmasida kalit va uning paroli bo‘lmaydi. Ular alohida xususiy saqlanadi.
4. Loyiha ildizidan `python3 tools/build_apk.py` ni bajaring. Windows’da `python` buyrug‘ini ishlatishingiz mumkin.

Yoki `mobile` papkasida:

```bash
flutter pub get
flutter analyze
flutter test --concurrency=1
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

Natija: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`. Versiya 3.5.0, build 22; ARM64 versionCode 2022; min SDK 24. Tayyor APK avvalgi Lingoy signing sertifikati bilan tekshirilgan.

Gradle sozlamasi: 1536 MB heap, 768 MB metaspace, 2 protsessor va bitta worker. Signing kalitini almashtirish mavjud o‘rnatilgan ilovaga oddiy yangilash imkoniyatiga ta’sir qiladi.
