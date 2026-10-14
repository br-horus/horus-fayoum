// 𓂀 HORUS Fayoum Backend v1.1 - بديل محلي مجاني 100% لـ Firebase
// Auth + Realtime Trips + Drivers Geo + Uploads + OTP محلي + خرائط OSM مجانية
// يعمل على أي VPS مصري رخيص بدون أي خدمات مدفوعة
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const Database = require('better-sqlite3');
const jwt = require('jsonwebtoken');
const multer = require('multer');
const cors = require('cors');
const path = require('path');
const crypto = require('crypto');

const app = express();
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: '*' } });
const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'horus-fayoum-secret-eye-of-horus-2026';
const ADMIN_USER = process.env.ADMIN_USER || 'admin';
const ADMIN_PASS = process.env.ADMIN_PASS || 'admin';
const PILOT_OTP = process.env.PILOT_OTP !== 'off'; // وضع البايلوت: إرجاع الكود — اقفله بـ PILOT_OTP=off عند الإطلاق الواسع

if (!process.env.JWT_SECRET) {
  console.warn('⚠️  [HORUS] JWT_SECRET غير مضبوط — يُستخدم سر افتراضي (للبايلوت فقط). اضبط JWT_SECRET قوي قبل الإطلاق!');
}
if ((ADMIN_USER === 'admin' && ADMIN_PASS === 'admin')) {
  console.warn('⚠️  [HORUS] دخول الأدمن الافتراضي admin/admin نشط — غيّره عبر ADMIN_USER/ADMIN_PASS فوراً!');
}
if (PILOT_OTP) console.warn('⚠️  [HORUS] وضع البايلوت: OTP يُرجع في الـ response — اقفله بـ PILOT_OTP=off مع SMS حقيقي.');

app.use(cors());
app.use(express.json({ limit: '1mb' }));
app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

// ===== قاعدة البيانات المحلية SQLite (تتحول لـ Postgres لاحقاً بدون تغيير API) =====
const db = new Database(path.join(__dirname, '..', 'horus.db'));
db.exec(`
CREATE TABLE IF NOT EXISTS users (id TEXT PRIMARY KEY, name TEXT, phone TEXT UNIQUE, blockStatus TEXT DEFAULT 'no', createdAt INTEGER);
CREATE TABLE IF NOT EXISTS drivers (id TEXT PRIMARY KEY, name TEXT, phone TEXT UNIQUE, carModel TEXT, carNumber TEXT, blockStatus TEXT DEFAULT 'no', verified TEXT DEFAULT 'pending', earnings REAL DEFAULT 0, lat REAL, lng REAL, online INTEGER DEFAULT 0, createdAt INTEGER);
CREATE TABLE IF NOT EXISTS trips (id TEXT PRIMARY KEY, userId TEXT, driverId TEXT, pickupLat REAL, pickupLng REAL, pickupAddr TEXT, dropLat REAL, dropLng REAL, dropAddr TEXT, fare REAL, bid REAL, status TEXT DEFAULT 'waiting', createdAt INTEGER, endedAt INTEGER);
CREATE TABLE IF NOT EXISTS otps (phone TEXT PRIMARY KEY, code TEXT, expires INTEGER, attempts INTEGER DEFAULT 0);
`);

// ===== أدوات =====
const uid = () => crypto.randomUUID().replace(/-/g, '').slice(0, 12);
const sign = (p) => jwt.sign(p, JWT_SECRET, { expiresIn: '12h' });
const auth = (req, res, next) => {
  const h = req.headers.authorization || '';
  try { req.user = jwt.verify(h.replace('Bearer ', ''), JWT_SECRET); next(); }
  catch { return res.status(401).json({ ok: false, msg: 'غير مسجل الدخول' }); }
};
// HORUS: صلاحية الأدمن تُشتق من التوكن فقط — لا تُؤخذ من العميل أبداً
const requireAdmin = (req, res, next) => {
  if (req.user && req.user.role === 'admin') return next();
  return res.status(403).json({ ok: false, msg: 'للإدارة فقط' });
};
const num = (v, min, max) => {
  const n = Number(v);
  return Number.isFinite(n) && n >= min && n <= max ? n : null;
};
const cleanPhone = (p) => String(p || '').replace(/[^0-9+]/g, '').slice(0, 15);

// Rate-limit بسيط داخل الذاكرة للـ OTP (بدون اعتماديات جديدة)
const rl = new Map(); // key -> {count, reset}
function rateLimit(key, max, ms) {
  const now = Date.now();
  let e = rl.get(key);
  if (!e || now > e.reset) e = { count: 0, reset: now + ms };
  e.count += 1;
  rl.set(key, e);
  return e.count <= max;
}

// ===== OTP محلي مجاني =====
// لاحقاً: اربط بوابة SMS مصرية بنفس الـ endpoint بدون تغيير التطبيق
app.post('/api/otp/send', (req, res) => {
  const phone = cleanPhone(req.body.phone);
  if (!phone || phone.length < 8) return res.status(400).json({ ok: false, msg: 'رقم الهاتف مطلوب' });
  const key = `send:${req.ip}:${phone}`;
  if (!rateLimit(key, 10, 10 * 60 * 1000)) return res.status(429).json({ ok: false, msg: 'محاولات كثيرة — انتظر 10 دقائق' });
  const code = String(Math.floor(100000 + Math.random() * 900000));
  db.prepare('INSERT OR REPLACE INTO otps VALUES (?,?,?,0)').run(phone, code, Date.now() + 5 * 60 * 1000);
  console.log(`[HORUS OTP] ${phone} => ${code}`);
  const out = { ok: true, msg: 'تم إرسال الكود' };
  if (PILOT_OTP) out.pilotCode = code; // بايلوت فقط
  res.json(out);
});
app.post('/api/otp/verify', (req, res) => {
  const phone = cleanPhone(req.body.phone);
  const code = String(req.body.code || '').trim();
  const name = String(req.body.name || 'مستخدم حورس').slice(0, 60);
  // HORUS: الدور من قاعدة البيانات فقط — أي role من العميل يُتجاهل (منع تصعيد admin)
  let want = req.body.role === 'driver' ? 'driver' : 'user';
  const key = `verify:${req.ip}:${phone}`;
  if (!rateLimit(key, 8, 10 * 60 * 1000)) return res.status(429).json({ ok: false, msg: 'محاولات كثيرة — انتظر 10 دقائق' });
  const row = db.prepare('SELECT * FROM otps WHERE phone=?').get(phone);
  if (!row || row.code !== code || Date.now() > row.expires) return res.status(400).json({ ok: false, msg: 'الكود غلط أو انتهى' });
  db.prepare('DELETE FROM otps WHERE phone=?').run(phone);
  // هل الرقم مسجل كسائق؟ كراكب؟ الدور يُشتق من الجداول
  const inDrivers = db.prepare('SELECT * FROM drivers WHERE phone=?').get(phone);
  const inUsers = inDrivers ? null : db.prepare('SELECT * FROM users WHERE phone=?').get(phone);
  const role = inDrivers ? 'driver' : (inUsers ? 'user' : want);
  const table = role === 'driver' ? 'drivers' : 'users';
  let acc = inDrivers || inUsers;
  if (!acc) {
    const id = uid();
    db.prepare(`INSERT INTO ${table} (id,name,phone,createdAt) VALUES (?,?,?,?)`).run(id, name, phone, Date.now());
    acc = { id, phone, name };
  }
  if (acc.blockStatus === 'yes') return res.status(403).json({ ok: false, msg: 'الحساب محظور - تواصل مع إدارة حورس بالفيوم' });
  res.json({ ok: true, token: sign({ id: acc.id, role }), id: acc.id, name: acc.name, role });
});

// ===== رفع الوثائق محلياً (بديل Firebase Storage) — صور/PDF حتى 3MB =====
const upload = multer({
  dest: path.join(__dirname, '..', 'uploads'),
  limits: { fileSize: 3 * 1024 * 1024, files: 1 },
  fileFilter: (req, file, cb) => {
    const ok = /^(image\/(jpeg|png|webp)|application\/pdf)$/.test(file.mimetype);
    cb(ok ? null : new Error('نوع الملف غير مسموح (صور أو PDF فقط)'), ok);
  },
});
app.post('/api/upload', auth, upload.single('file'), (req, res) => {
  if (!req.file) return res.status(400).json({ ok: false, msg: 'لا يوجد ملف' });
  res.json({ ok: true, url: `/uploads/${req.file.filename}` });
});

// ===== السائق: موقع + حالة أونلاين (سائقون فقط) =====
app.post('/api/driver/location', auth, (req, res) => {
  if (req.user.role !== 'driver') return res.status(403).json({ ok: false, msg: 'للكباتن فقط' });
  const lat = num(req.body.lat, -90, 90);
  const lng = num(req.body.lng, -180, 180);
  if (lat === null || lng === null) return res.status(400).json({ ok: false, msg: 'إحداثيات غير صالحة' });
  db.prepare('UPDATE drivers SET lat=?, lng=?, online=? WHERE id=?').run(lat, lng, req.body.online ? 1 : 0, req.user.id);
  io.emit('driver:location', { id: req.user.id, lat, lng, online: !!req.body.online });
  res.json({ ok: true });
});

// ===== الرحلات (بديل Realtime Database) =====
// ملاحظة: المسارات المحددة (waiting/mine) قبل المسار العام (:id) حتى لا يبتلعها Express
app.post('/api/trips', auth, (req, res) => {
  if (req.user.role !== 'user') return res.status(403).json({ ok: false, msg: 'للركاب فقط' });
  const b = req.body || {};
  // يقبل الحقول المسطحة (تطبيقات حورس) أو المتداخلة pickup:{lat,lng}/drop:{...}
  const pickupLat = num(b.pickupLat ?? b.pickup?.lat, -90, 90);
  const pickupLng = num(b.pickupLng ?? b.pickup?.lng, -180, 180);
  const dropLat = num(b.dropLat ?? b.drop?.lat, -90, 90);
  const dropLng = num(b.dropLng ?? b.drop?.lng, -180, 180);
  const fare = num(b.fare, 1, 100000);
  const bid = b.bid == null || b.bid === '' ? null : num(b.bid, 1, 100000);
  if ([pickupLat, pickupLng, dropLat, dropLng, fare].includes(null)) {
    return res.status(400).json({ ok: false, msg: 'بيانات الرحلة ناقصة أو غير صالحة' });
  }
  if (b.bid != null && b.bid !== '' && bid === null) return res.status(400).json({ ok: false, msg: 'العرض غير صالح' });
  const t = {
    id: uid(), userId: req.user.id, driverId: null,
    pickupLat, pickupLng, pickupAddr: String(b.pickupAddr ?? b.pickup?.addr ?? 'موقعي الحالي - الفيوم').slice(0, 200),
    dropLat, dropLng, dropAddr: String(b.dropAddr ?? b.drop?.addr ?? '').slice(0, 200),
    fare, bid, status: 'waiting', createdAt: Date.now(),
  };
  db.prepare('INSERT INTO trips (id,userId,driverId,pickupLat,pickupLng,pickupAddr,dropLat,dropLng,dropAddr,fare,bid,status,createdAt) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)')
    .run(t.id, t.userId, t.driverId, t.pickupLat, t.pickupLng, t.pickupAddr, t.dropLat, t.dropLng, t.dropAddr, t.fare, t.bid, 'waiting', t.createdAt);
  io.emit('trip:new', t); // كل السائقين الأونلاين يسمعون الطلب لحظياً
  res.json({ ok: true, trip: t });
});
app.get('/api/trips/waiting', auth, (req, res) => {
  if (req.user.role !== 'driver' && req.user.role !== 'admin') return res.status(403).json({ ok: false, msg: 'غير مصرح' });
  res.json({ ok: true, trips: db.prepare("SELECT * FROM trips WHERE status='waiting' ORDER BY createdAt DESC LIMIT 50").all() });
});
app.get('/api/trips/mine', auth, (req, res) => {
  const col = req.user.role === 'driver' ? 'driverId' : 'userId';
  if (!['userId', 'driverId'].includes(col)) return res.status(403).json({ ok: false, msg: 'غير مصرح' });
  res.json({ ok: true, trips: db.prepare(`SELECT * FROM trips WHERE ${col}=? ORDER BY createdAt DESC`).all(req.user.id) });
});
app.get('/api/trips/:id', auth, (req, res) => {
  const trip = db.prepare('SELECT * FROM trips WHERE id=?').get(req.params.id);
  if (!trip) return res.status(404).json({ ok: false, msg: 'الرحلة غير موجودة' });
  if (req.user.role !== 'admin' && trip.userId !== req.user.id && trip.driverId !== req.user.id) {
    return res.status(403).json({ ok: false, msg: 'غير مصرح' });
  }
  let driver = null;
  if (trip.driverId) driver = db.prepare('SELECT id,name,phone,carModel,carNumber FROM drivers WHERE id=?').get(trip.driverId);
  res.json({ ok: true, trip, driver });
});
app.post('/api/trips/:id/accept', auth, (req, res) => {
  if (req.user.role !== 'driver') return res.status(403).json({ ok: false, msg: 'للكباتن فقط' });
  const trip = db.prepare('SELECT * FROM trips WHERE id=?').get(req.params.id);
  if (!trip) return res.status(404).json({ ok: false, msg: 'الرحلة غير موجودة' });
  if (trip.status !== 'waiting') return res.status(409).json({ ok: false, msg: 'الرحلة لم تعد متاحة' });
  db.prepare("UPDATE trips SET driverId=?, status='accepted' WHERE id=?").run(req.user.id, req.params.id);
  const updated = db.prepare('SELECT * FROM trips WHERE id=?').get(req.params.id);
  io.emit('trip:update', updated);
  res.json({ ok: true, trip: updated });
});
const TRIP_STATUS = ['arrived', 'ontrip', 'ended'];
app.post('/api/trips/:id/status', auth, (req, res) => {
  if (req.user.role !== 'driver') return res.status(403).json({ ok: false, msg: 'للكباتن فقط' });
  const { status } = req.body || {};
  if (!TRIP_STATUS.includes(status)) return res.status(400).json({ ok: false, msg: 'حالة غير صالحة' });
  const trip = db.prepare('SELECT * FROM trips WHERE id=?').get(req.params.id);
  if (!trip) return res.status(404).json({ ok: false, msg: 'الرحلة غير موجودة' });
  if (trip.driverId !== req.user.id) return res.status(403).json({ ok: false, msg: 'ليست رحلتك' });
  if (status === 'ended') {
    const fare = num(req.body.fare ?? trip.bid ?? trip.fare, 1, 100000);
    if (fare === null) return res.status(400).json({ ok: false, msg: 'الأجرة غير صالحة' });
    db.prepare('UPDATE trips SET status=?, fare=?, endedAt=? WHERE id=?').run(status, fare, Date.now(), req.params.id);
  } else {
    db.prepare('UPDATE trips SET status=? WHERE id=?').run(status, req.params.id);
  }
  const updated = db.prepare('SELECT * FROM trips WHERE id=?').get(req.params.id);
  if (status === 'ended' && updated.driverId) {
    db.prepare('UPDATE drivers SET earnings = earnings + ? WHERE id=?').run(updated.fare || 0, updated.driverId);
  }
  io.emit('trip:update', updated);
  res.json({ ok: true, trip: updated });
});

// ===== خرائط مجانية: توجيه OSRM + بحث Nominatim (بديل Google المدفوع) =====
const COORD = /^-?\d{1,3}(\.\d+)?,-?\d{1,3}(\.\d+)?$/;
app.get('/api/route', async (req, res) => {
  const { from, to } = req.query; // "lat,lng"
  if (!COORD.test(String(from || '')) || !COORD.test(String(to || ''))) {
    return res.status(400).json({ ok: false, msg: 'إحداثيات غير صالحة (lat,lng)' });
  }
  try {
    const r = await fetch(`https://router.project-osrm.org/route/v1/driving/${from.split(',').reverse().join(',')};${to.split(',').reverse().join(',')}?overview=full&geometries=geojson`);
    res.json(await r.json());
  } catch (e) { res.status(500).json({ ok: false, msg: 'OSRM غير متاح مؤقتاً' }); }
});
app.get('/api/search', async (req, res) => {
  const q = String(req.query.q || '').slice(0, 80);
  if (q.trim().length < 2) return res.status(400).json({ ok: false, msg: 'ابحث بكلمتين على الأقل' });
  try {
    const r = await fetch(`https://nominatim.openstreetmap.org/search?format=json&countrycodes=eg&q=${encodeURIComponent(q + ' الفيوم')}`, { headers: { 'User-Agent': 'Horus-Fayoum/1.0' } });
    res.json(await r.json());
  } catch (e) { res.status(500).json({ ok: false }); }
});

// ===== إدارة (للأدمن) =====
app.post('/api/admin/login', (req, res) => {
  const { user, pass } = req.body;
  if (user === ADMIN_USER && pass === ADMIN_PASS) {
    return res.json({ ok: true, token: sign({ id: 'admin', role: 'admin' }), name: 'إدارة حورس' });
  }
  res.status(401).json({ ok: false, msg: 'بيانات الدخول غلط' });
});
app.get('/api/admin/overview', auth, requireAdmin, (req, res) => {
  res.json({
    ok: true,
    users: db.prepare('SELECT COUNT(*) c FROM users').get().c,
    drivers: db.prepare('SELECT COUNT(*) c FROM drivers').get().c,
    onlineDrivers: db.prepare('SELECT COUNT(*) c FROM drivers WHERE online=1').get().c,
    trips: db.prepare('SELECT COUNT(*) c FROM trips').get().c,
    earnings: db.prepare("SELECT COALESCE(SUM(fare),0) s FROM trips WHERE status='ended'").get().s,
  });
});
app.get('/api/admin/drivers', auth, requireAdmin, (req, res) => res.json({ ok: true, drivers: db.prepare('SELECT id,name,phone,carModel,carNumber,blockStatus,verified,earnings,online,createdAt FROM drivers ORDER BY createdAt DESC').all() }));
app.post('/api/admin/drivers/:id/block', auth, requireAdmin, (req, res) => {
  db.prepare('UPDATE drivers SET blockStatus=? WHERE id=?').run(req.body.block ? 'yes' : 'no', req.params.id);
  res.json({ ok: true });
});
app.post('/api/admin/drivers/:id/verify', auth, requireAdmin, (req, res) => {
  const v = ['verified', 'pending', 'rejected'].includes(req.body.verified) ? req.body.verified : 'pending';
  db.prepare('UPDATE drivers SET verified=? WHERE id=?').run(v, req.params.id);
  res.json({ ok: true });
});

// ===== Socket لحظي (بديل Geofire + FCM) — ملاحظة: للإنتاج وثّق بالـ JWT =====
io.on('connection', (s) => {
  s.on('driver:ping', (d) => s.broadcast.emit('driver:location', d));
  s.on('trip:ping', (d) => s.broadcast.emit('trip:update', d));
});

server.listen(PORT, () => console.log(`𓂀 HORUS Fayoum Backend v1.1 شغال على http://localhost:${PORT}`));
