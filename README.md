# 𓂀 حورس | نقل الفيوم الذكي — Horus Fayoum

تطبيق نقل ذكي مجاني 100% ومفتوح المصدر لمحافظة الفيوم — بدون أي خدمات مدفوعة.

| المجلد | الوصف |
|---|---|
| `rider/` | 📱 تطبيق الراكب (Flutter + خرائط OSM + كاش فقط) |
| `driver/` | 🧑‍✈️ تطبيق الكابتن (أونلاين/طلبات/أرباح) |
| `backend/` | 🖥️ باك اند حورس المحلي (Node + SQLite + Socket.io — بديل Firebase) |
| `admin/` | 🖥️ لوحة تحكم الإدارة (ويب) |
| `landing/` | 🌐 صفحة الهبوط بروابط التحميل |

## تشغيل الباك اند
```bash
cd backend && npm install && PORT=3100 node src/index.js
```

## بناء APK (تلقائي عبر GitHub Actions)
كل push على `main` يبني `horus-rider-apk` و `horus-driver-apk` من صفحة Actions.

## الدخول الافتراضي
- إدارة: `admin / admin`
- راكب/كابتن: برقم الموبايل + كود OTP (وضع البايلوت يعرض الكود)
