# 𓂀 Horus Fayoum Backend

باك اند محلي مجاني 100% (بديل Firebase) — Node.js + Express + SQLite + Socket.io.

## التشغيل
```bash
npm install
PORT=3100 node src/index.js
```

## Endpoints
| Method | Path | الوصف |
|---|---|---|
| POST | `/api/otp/send` | إرسال كود OTP (بايلوت: يرجعه في الرد) |
| POST | `/api/otp/verify` | تحقق + إصدار JWT |
| POST | `/api/upload` | رفع ملفات (وثائق الكابتن) |
| POST | `/api/driver/location` | تحديث موقع/حالة الكابتن |
| POST | `/api/trips` | إنشاء طلب رحلة |
| POST | `/api/trips/:id/accept` | قبول الكابتن للرحلة |
| POST | `/api/trips/:id/status` | arrived / ontrip / ended |
| GET | `/api/trips/waiting` | الطلبات المنتظرة |
| GET | `/api/trips/mine` | رحلات المستخدم/الكابتن |
| GET | `/api/trips/:id` | تفاصيل رحلة + الكابتن |
| GET | `/api/route` | توجيه OSRM مجاني |
| GET | `/api/search` | بحث Nominatim (مصر) |
| POST | `/api/admin/login` | دخول الإدارة (admin/admin) |
| GET | `/api/admin/overview` | إحصائيات |
| GET | `/api/admin/drivers` | قائمة الكباتن |
| POST | `/api/admin/drivers/:id/block` | حظر/فك |
| POST | `/api/admin/drivers/:id/verify` | توثيق |

## Socket.io
- `trip:new` / `trip:update` / `driver:location`

## الإنتاج
- غيّر `JWT_SECRET` في متغيرات البيئة.
- للنشر: أي VPS مصري رخيص + `pm2 start src/index.js` + Caddy/NGINX كـ reverse proxy.
- قواعد بيانات: `horus.db` (SQLite). للترقية لاحقاً: نفس الـ API فوق Postgres.
