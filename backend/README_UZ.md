# Lingoy — domen uchun tayyor API asosi

Bu paket AI yoki OCR xizmatini ishga tushirmaydi. Hozir haqiqiy ishlaydigan qism — versiya va imkoniyatlarni qaytaruvchi `/v1/health`. Tarjima, AI grammatika va rasm tarjimasi endpointlari `503 feature_disabled` qaytaradi. Yopiq xizmatlar yuborilgan matn yoki rasmni o‘qimaydi, saqlamaydi va tashqi servisga uzatmaydi.

## Mahalliy sinov — Windows 11 / Python 3.12+

```powershell
cd backend
python -m unittest -v
python server.py
```

Brauzer: `http://127.0.0.1:8080/v1/health`. Bu development server; internetga production sifatida ochilmaydi. Flutter ilovasi oddiy buildda umuman serverga ulanmaydi.

## Domen olingach

Server Python WSGI ilovasini ishlata oladigan hosting yoki VPS talab qiladi. Domenning o‘zi hosting o‘rnini bosmaydi. Agar tanlangan hosting faqat PHP ishlatsa, `openapi.json` shartnomasi bo‘yicha PHP adapter tayyorlash kerak. Shu Python faylini PHP hostingga oddiy ko‘chirish yetmaydi.

Linux production uchun hostingning WSGI xizmati yoki Gunicorn ishlatiladi. Masalan, alohida virtual muhitda Gunicorn o‘rnatilgach:

```bash
gunicorn --bind 127.0.0.1:8080 --workers 2 --timeout 15 server:application
```

Tashqi HTTPS serverning `/api/` joyiga `nginx.location.example` moslanadi. Python jarayoni loopback’da qoladi. Domen va TLS sertifikati hozir o‘rnatilmagan; xizmat hech qayerga chiqarilmagan.

`https://DOMAIN/api/v1/health` javobi 200 va `api_version=1` bo‘lishi kerak. Imkoniyatlar hozircha uchalasi ham false bo‘lib qoladi.

## Ilova ulanishi

Transport kodi: `mobile/lib/core/online_gateway.dart`. `LINGOY_API_BASE_URL` bo‘sh va `LINGOY_ONLINE_ENABLED=false` — oddiy build holati. Keyingi integratsiya tayyorlangach:

```powershell
flutter build apk --release --target-platform android-arm64 --dart-define=LINGOY_API_BASE_URL=https://DOMAIN/api/ --dart-define=LINGOY_ONLINE_ENABLED=true
```

Flagning o‘zi AI’ni yoqmaydi: server capability=false bo‘lsa, klient foydalanuvchi matnini POST qilmaydi. Klient HTTPS’ni, foydalanuvchining aniq roziligini, matn chegarasini va server protokolini tekshiradi. Redirect ortidan yurmaydi. API kaliti APK ichiga qo‘yilmaydi. Bu versiyada faol AI tugmalari yoki ishlayotgandek ko‘rinadigan soxta javoblar yo‘q.

## Keyingi integratsiyada qolgan ishlar

Provayderni tanlash va uning server kaliti, autentifikatsiya, so‘rovlarni cheklash, foydalanuvchi roziligi oynasi, AI natija sxemasi va tekshiruvlari; rasm tarjimasi uchun fayl turi/hajmi, OCR va tarjima bosqichlari. Bu ishlar hozir ulangan yoki sinovdan o‘tgan deb hisoblanmaydi. Oflayn grammatika va lug‘at bu xizmatlardan mustaqil qoladi.

Manbalar: https://gunicorn.org/run/ va https://gunicorn.org/deploy/ .
