# Lingoy 3.5.0 — qidiruv, o‘yin va mobil dizayn

Sana: 2026-11-24. Android build: 22. Asos: 3.4.1 to‘liq manba.

## Nimalar tuzatildi

- Qidiruv paneli pastda, suzuvchi asosiy menyuning ustida. Kapsula ichida qidirish, matn, mikrofon va EN/UZ tugmalari bor. Ranglar Lingoy mavzusiga mos.
- Qidiruv bo‘sh turganda tasodifiy alifbo ro‘yxati chiqmaydi. Faqat ma’nosi ochilgan so‘zlar “Yaqinda ko‘rilgan”da qoladi; bu so‘zni xatcho‘pga avtomatik saqlamaydi. Tarix akkaunt bo‘yicha alohida saqlanadi.
- Android va saytda ovozli qidiruv qo‘shildi. EN inglizcha, UZ o‘zbekcha nutqni so‘raydi. Bekor qilish matnni o‘zgartirmaydi. Xizmat mavjud bo‘lmasa tushunarli xabar va matn orqali qidirish qoladi.
- O‘yinda boshlash tugmasi aylanuvchi ro‘yxatdan tashqarida. 30 ta tanlov va kichik ekranda ham ko‘rinadi. Klaviatura hamda kattalashtirilgan matn bilan bosilishi tekshirildi.
- Savol tayyorlashda qimmat lug‘aviy tekshiruvlardan oldin arzon saralash bajariladi. To‘g‘ri sinonimni noto‘g‘ri variant sifatida ko‘rsatmaslik qoidalari saqlanadi.
- So‘z kartalari, profil, natijalar va tugmalar ixchamlashtirildi. Profil amallari ikonka va matndan iborat tartibli qatorlar bo‘ldi.
- Tarjima/AI/rasm/grammatika ixcham chiplarda. “Grammatika” so‘zi bo‘linmaydi.
- Pastki menyu orqasidagi alohida to‘rtburchak olib tashlandi. Kontent suzuvchi kapsula tagiga davom etadi.
- Tugmalarda bosilish va qidiruvda fokus animatsiyasi bor. Kamaytirilgan harakat sozlamasi hurmat qilinadi.
- Asl oy ustidagi qiz logotipi saqlandi. 3.4.1 dagi lug‘atni tiklash va startup tuzatishlari shu paketda ham bor.

## Yakuniy tekshiruvlar

- Android release: 3.5.0+22, versionCode 2022, ARM64, 80 076 057 bayt. Avvalgi imzo saqlangan.
- APK ichidagi 4 554 runtime resurs SHA-256 bo‘yicha manba bilan bir xil; lug‘at yaxlitligi va 10 000 rasmli yozuv xaritasi tekshirildi. Bu 10 000 fotografiya degani emas: paketda vektorlar va fotografiyalar mavjud.
- Flutter kod tahlili xatosiz. O‘zgargan ekranlar, 30 ta haqiqiy tanlov bilan o‘yin boshlash, klaviatura, 320px / 200% matn, ovoz kanali va akkaunt tarixi regressiyalari o‘tdi.
- Web: 34/34; server: 63/63. Paket preflight’i 14/14; bu Gmail yetkazilishi yoki production deploy tasdig‘i emas.
- App Password APK va yakuniy web JavaScriptida mavjud emas.

## Androidga o‘rnatish

1. `Lingoy_3.5.0.apk` ni mavjud Lingoy ustiga o‘rnating. Ilovani avval o‘chirmang — mahalliy ma’lumotlar kerak.
2. Profil pastidagi versiya `3.5.0` bo‘lsin.
3. Lug‘atni oching: bo‘sh ekranda tasodifiy so‘zlar bo‘lmasin. `start` ni qidiring, ma’nosini oching; qidiruvni tozalaganda u yaqinda ko‘rilganlarda paydo bo‘ladi.
4. Mikrofonni bosing va EN/UZ ga mos so‘z ayting. Androidda nutqni tanish xizmati o‘rnatilgan bo‘lishi kerak. Xizmat va tilga qarab internet kerak bo‘lishi mumkin; barcha qurilmalarda oflayn ovoz tanish kafolatlanmaydi. Lingoy audio yozuvni saqlamaydi.
5. Mashqlar → Tarjima yoki Sinonimlar. So‘z tanlang va pastdagi “O‘yinni boshlash”ni bosing. Ba’zi so‘zlarda yetarli aniq variant bo‘lmasa tayyor savollar soni tushuntiriladi.

APK ARM64, Android 7.0+. Haqiqiy foydalanuvchi telefonida mikrofon, eski versiya ustiga yangilash va ochilish sinovi alohida kerak. Avtomatik testlar fizik telefon o‘rnini bosmaydi.

## Gmail va serverga joylashtirish

GitHub tarqatmasida App Password va boshqa maxfiy qiymatlar yo‘q. Ularni `server/.env.example` asosida faqat serverning xususiy `.env` sozlamasiga kiriting. APK va brauzer JS to‘plamiga kiritilmaydi. Ushbu muhitdagi jonli SMTP tekshiruvi DNS bosqichida to‘xtadi; bu parol noto‘g‘ri degani emas. Haqiqiy kod yetib kelgani tasdiqlanmadi.

Mavjud VPSda deploy skripti `/srv/lingoy/shared/.env` ni saqlaydi. Gmail App Password qiymatini **mavjud shared sozlamadagi `GMAIL_APP_PASSWORD` maydoniga** kiriting. Butun konfiguratsiyani almashtirmang. Parolni terminal natijasiga chiqarmang. SMTP port 465 yoki 587.

```bash
unzip Lingoy_Server_3.5.0.zip
cd Lingoy
sudo -u lingoy bash deploy/deploy.sh "$PWD"
cd /srv/lingoy/current/server
npm run preflight
npm run check:live -- --skip-ai --json
npm run check:production -- --json
```

ZIP dastur manbasi va resurslarni saqlaydi. Maxfiy konfiguratsiya va Android signing kaliti alohida xususiy saqlanadi. Deploy backup va tekshiruvlarni bajaradi. Ushbu chatda VPSga joylashtirish bajarilmadi.

Deploydan keyin API health, yuklash manifesti va profil `3.5.0` versiyani ko‘rsatsin. So‘ng haqiqiy emailda ro‘yxatdan o‘tish, kodni tasdiqlash va parolni tiklashni tekshiring. Gmail bilan autentifikatsiya o‘tishi xatning qutiga yetib kelishini o‘zi tasdiqlamaydi.

## Tekshiruv dalillari va davom ettirish

`docs/RELEASE_AUDIT_3_5_0.json` — yakuniy tekshiruv holati. `docs/TESTS_*_3_5_0.txt` — tegishli test natijalari.

Asosiy o‘zgargan fayllar:
- `mobile/lib/screens/dictionary.dart`, `mobile/lib/ui/search_tools.dart`, `mobile/lib/core/store.dart`: pastki qidiruv va yaqinda ko‘rilganlar.
- `mobile/lib/core/voice_search.dart`, `mobile/android/app/src/main/kotlin/uz/lexora/lexora/MainActivity.kt`: Android nutq tanish.
- `mobile/lib/screens/study_game.dart`, `mobile/lib/core/study_game.dart`: doim ko‘rinadigan boshlash tugmasi va tezroq tayyorlash.
- `mobile/lib/screens/account.dart`, `mobile/lib/screens/profile.dart`, `mobile/lib/main.dart`: ixcham profil va suzuvchi menyu.
- `web/src/voice.js`, `web/src/store.js`, `web/src/app.js`, `web/src/study-ui.js`, `web/src/study-game.js`, `web/style.css`: webdagi mos funksiyalar.

Qolgan tashqi tekshiruvlar: VPS deploy, Gmail kodining qutiga yetishi, haqiqiy Google kirishi, fizik Androidda mikrofon va yangilash. Paket bu tekshiruvlar bajarilgan deb da’vo qilmaydi.
