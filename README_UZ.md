# Lingoy 3.5.0

Inglizcha–o‘zbekcha oflayn lug‘at, Android ilova va PWA.

## Yuklab olish

[3.5.0 versiya va fayllar](https://github.com/DavlatyorUZ/lingus/releases/tag/v3.5.0)

- **Lingoy_3.5.0.apk** — ARM64, Android 7.0+, 80 MB. Mavjud ilova ustiga o‘rnating.
- **Lingoy_Server_3.5.0.zip** — server, web, Android manba, lug‘at, rasmlar va tayyor APK.
- **Lingoy_Ornatish_3.5.0_UZ.md** — o‘rnatish va tekshirish.
- **SHA256SUMS.txt** — fayllar yaxlitligini tekshirish.

## 3.5.0 yangiliklari

Pastki qidiruv kapsulasi, EN/UZ ovozli qidiruv, faqat ma’nosi ochilgan so‘zlar tarixi, doim ko‘rinadigan o‘yin boshlash tugmasi, ixcham profil va kartalar, suzuvchi navigatsiya va bosilish animatsiyalari.

30 ta so‘zni tanlash va o‘yinni boshlash 320px ekran, 200% matn va klaviatura bilan tekshirildi. Web: 34/34; backend: 63/63. APK imzosi avvalgi versiya bilan bir xil. Tekshiruv dalillari: [audit](docs/RELEASE_AUDIT_3_5_0.json).

## Kod bilan ishlash

Git repozitoriyasida dastur kodi saqlanadi. Hajmli lug‘at, rasmlar, shriftlar va tayyor fayllar versiyalangan Release arxivida. Klonlagandan so‘ng ularni tekshirilgan arxivdan tiklang:

```bash
git clone https://github.com/DavlatyorUZ/lingus.git
cd lingus
python3 tools/bootstrap_assets.py
```

Windows PowerShell’da `python3` o‘rniga `python` ishlatishingiz mumkin. Arxiv oldindan yuklangan bo‘lsa:

```bash
python3 tools/bootstrap_assets.py --archive /path/to/Lingoy_Server_3.5.0.zip
```

Web va API:

```bash
cd server
npm ci
npm test
cd ../web
npm ci
npm test
npm run build
```

Node.js 24+ kerak. Androidni qayta yig‘ish: [BUILD_UZ.md](mobile/BUILD_UZ.md). Android signing kaliti alohida xususiy saqlanadi.

## Server sozlamasi

GitHub paketida parollar va signing kalitlari mavjud emas. Yangi serverda `server/.env.example` dan `server/.env` yarating, JWT, Gmail App Password, OAuth va Gemini qiymatlarini serverning o‘zida kiriting. Mavjud VPS yangilanganda `/srv/lingoy/shared/.env` saqlanadi. Bu fayllarni Git’ga qo‘shmang.

To‘liq o‘rnatish: [yo‘riqnoma](docs/AUDIT_3_5_0_UZ.md). Litsenziyalar va manbalar: paketdagi `mobile/assets/licenses.txt`, `photo_credits.txt` va [third-party notices](docs/THIRD_PARTY_NOTICES.txt).

## Tekshirilmagan tashqi qismlar

VPSga deploy, haqiqiy Gmail yetkazilishi, Google kirishi va fizik telefondagi mikrofon/yangilash bu chiqarishda tasdiqlanmagan. Ovozli qidiruv Android/brauzerning nutqni tanish xizmatiga bog‘liq; internet kerak bo‘lishi mumkin.
