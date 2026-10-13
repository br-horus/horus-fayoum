// HORUS Fayoum Backend - بديل محلي مجاني 100% لـ Firebase
// Auth + Realtime Trips + Drivers Geo + Uploads + OTP محلي + خرائط OSM مجانية
// يعمل على أي VPS مصري رخيص بدون أي خدمات مدفوعة
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const Database = require('better-sqlite3');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const multer = require('multer');
const cors = require('cors');
const path = require('path');
const fs = require('fs');

const app = express();
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: '*' } });
const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'horus-fayoum-secret-eye-of-horus-2026';

app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

// ===== قاعدة البيانات المحلية SQLite (تتحول لـ Postgres لاحقاً بدون تغيير API) =====
const db = new Database(path.join(__dirname, '..', 'horus.db'));
db.exec(`
CREATE TABLE IF NOT EXISTS users (id TEXT PRIMARY KEY, name TEXT, phone TEXT UNIQUE, password TEXT, blockStatus TEXT DEFAULT 'no', createdAt INTEGER);
CREATE TABLE IF NOT EXISTS drivers (id TEXT PRIMARY KEY, name TEXT, phone TEXT UNIQUE, password TEXT, carModel TEXT, carNumber TEXT, blockStatus TEXT DEFAULT 'no', verified TEXT DEFAULT 'pending', earnings REAL DEFAULT 0, lat REAL, lng REAL, online INTEGER DEFAULT 0, deviceToken TEXT, createdAt INTEGER);
CREATE TABLE IF NOT EXISTS trips (id TEXT PRIMARY KEY, userId TEXT, driverId TEXT, pickupLat REAL, pickupLng REAL, pickupAddr TEXT, dropLat REAL, dropLng REAL, dropAddr TEXT, fare REAL, bid REAL, status TEXT DEFAULT 'waiting', createdAt INTEGER, endedAt INTEGER);
CREATE TABLE IF NOT EXISTS otps (phone TEXT PRIMARY KEY, code TEXT, expires INTEGER);
`);

// ===== أدوات =====
const uid = () => Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
const sign = (p) => jwt.sign(p, JWT_SECRET, { expiresIn: '30d' });
const auth = (req, res, next) => {
  const h = req.headers.authorization || '';
  try { req.user = jwt.verify(h.replace('Bearer ', ''), JWT_SECRET); next(); }
  catch { return res.status(401).json({ ok: false, msg: 'غير مسجل الدخول' }); }
};

// ===== OTP محلي مجاني (للبايلوت في الفيوم: الكود يظهر في لوج السيرفر + يرجع في الـ response) =====
// لاحقاً: اربط بوابة SMS مصرية (مثال: BulkSMS Egypt / Vodafone API) بنفس الـ endpoint بدون تغيير التطبيق
app.post('/api/otp/send', (req, res) => {
  const { phone } = req.body;
  if (!phone) return res.status(400).json({ ok: false, msg: 'رقم الهاتف مطلوب' });
  const code = Math.floor(100000 + Math.random() * 900000).toString();
  db.prepare('INSERT OR REPLACE INTO otps VALUES (?,?,?)').run(phone, code, Date.now() + 5 * 60 * 1000);
  console.log(`[HORUS OTP] ${phone} => ${code}`);
  // في وضع البايلوت نرجع الكود للتجربة (احذف code من الـ response عند ربط SMS حقيقي)
  res.json({ ok: true, msg: 'تم إرسال الكود', pilotCode: code });
});
app.post('/api/otp/verify', (req, res) => {
  const { phone, code, name, role } = req.body;
  const row = db.prepare('SELECT * FROM otps WHERE phone=?').get(phone);
  if (!row || row.code !== code || Date.now() > row.expires) return res.status(400).json({ ok: false, msg: 'الكود غلط أو انتهى' });
  db.prepare('DELETE FROM otps WHERE phone=?').run(phone);
  const table = role === 'driver' ? 'drivers' : 'users';
  let acc = db.prepare(`SELECT * FROM ${table} WHERE phone=?`).get(phone);
  if (!acc) {
    const id = uid();
    db.prepare(`INSERT INTO ${table} (id,name,phone,createdAt) VALUES (?,?,?,?)`).run(id, name || 'مستخدم حورس', phone, Date.now());
    acc = { id, phone, name: name || 'مستخدم حورس' };
  }
  if (acc.blockStatus === 'yes') return res.status(403).json({ ok: false, msg: 'الحساب محظور - تواصل مع إدارة حورس بالفيوم' });
  res.json({ ok: true, token: sign({ id: acc.id, role: role || 'user' }), id: acc.id, name: acc.name });
});

// ===== رفع الوثائق محلياً (بديل Firebase Storage) =====
const upload = multer({ dest: path.join(__dirname, '..', 'uploads') });
app.post('/api/upload', auth, upload.single('file'), (req, res) => {
  res.json({ ok: true, url: `/uploads/${req.file.filename}` });
});

// ===== السائق: موقع + حالة أونلاين =====
app.post('/api/driver/location', auth, (req, res) => {
  const { lat, lng, online } = req.body;
  db.prepare('UPDATE drivers SET lat=?, lng=?, online=? WHERE id=?').run(lat, lng, online ? 1 : 0, req.user.id);
  io.emit('driver:location', { id: req.user.id, lat, lng, online: !!online });
  res.json({ ok: true });
});

// ===== الرحلات (بديل Realtime Database) =====
app.post('/api/trips', auth, (req, res) => {
  const t = { id: uid(), userId: req.user.id, driverId: null, status: 'waiting', createdAt: Date.now(), ...req.body };
  db.prepare('INSERT INTO trips (id,userId,driverId,pickupLat,pickupLng,pickupAddr,dropLat,dropLng,dropAddr,fare,bid,status,createdAt) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)')
    .run(t.id, t.userId, t.driverId, t.pickupLat, t.pickupLng, t.pickupAddr, t.dropLat, t.dropLng, t.dropAddr, t.fare, t.bid || null, 'waiting', t.createdAt);
  io.emit('trip:new', t); // كل السائقين الأونلاين يسمعون الطلب لحظياً
  res.json({ ok: true, trip: t });
});
app.post('/api/trips/:id/accept', auth, (req, res) => {
  db.prepare("UPDATE trips SET driverId=?, status='accepted' WHERE id=? AND status='waiting'").run(req.user.id, req.params.id);
  const trip = db.prepare('SELECT * FROM trips WHERE id=?').get(req.params.id);
  io.emit('trip:update', trip);
  res.json({ ok: true, trip });
});
app.post('/api/trips/:id/status', auth, (req, res) => {
  const { status, fare } = req.body; // arrived | ontrip | ended
  if (status === 'ended') db.prepare('UPDATE trips SET status=?, fare=?, endedAt=? WHERE id=?').run(status, fare, Date.now(), req.params.id);
  else db.prepare('UPDATE trips SET status=? WHERE id=?').run(status, req.params.id);
  const trip = db.prepare('SELECT * FROM trips WHERE id=?').get(req.params.id);
  if (status === 'ended' && trip.driverId) db.prepare('UPDATE drivers SET earnings = earnings + ? WHERE id=?').run(trip.fare || 0, trip.driverId);
  io.emit('trip:update', trip);
  res.json({ ok: true, trip });
});
app.get('/api/trips/waiting', auth, (req, res) => {
  res.json({ ok: true, trips: db.prepare("SELECT * FROM trips WHERE status='waiting' ORDER BY createdAt DESC LIMIT 50").all() });
});
app.get('/api/trips/:id', auth, (req, res) => {
  const trip = db.prepare('SELECT * FROM trips WHERE id=?').get(req.params.id);
  if (!trip) return res.status(404).json({ ok: false, msg: 'الرحلة غير موجودة' });
  let driver = null;
  if (trip.driverId) driver = db.prepare('SELECT id,name,phone,carModel,carNumber FROM drivers WHERE id=?').get(trip.driverId);
  res.json({ ok: true, trip, driver });
});
app.get('/api/trips/mine', auth, (req, res) => {
  const col = req.user.role === 'driver' ? 'driverId' : 'userId';
  res.json({ ok: true, trips: db.prepare(`SELECT * FROM trips WHERE ${col}=? ORDER BY createdAt DESC`).all(req.user.id) });
});

// ===== خرائط مجانية: توجيه OSRM + بحث Nominatim (بديل Google المدفوع) =====
app.get('/api/route', async (req, res) => {
  const { from, to } = req.query; // "lat,lng"
  try {
    const r = await fetch(`https://router.project-osrm.org/route/v1/driving/${from.split(',').reverse().join(',')};${to.split(',').reverse().join(',')}?overview=full&geometries=geojson`);
    res.json(await r.json());
  } catch (e) { res.status(500).json({ ok: false, msg: 'OSRM غير متاح مؤقتاً' }); }
});
app.get('/api/search', async (req, res) => {
  try {
    const r = await fetch(`https://nominatim.openstreetmap.org/search?format=json&countrycodes=eg&q=${encodeURIComponent(req.query.q + ' الفيوم')}`, { headers: { 'User-Agent': 'Horus-Fayoum/1.0' } });
    res.json(await r.json());
  } catch (e) { res.status(500).json({ ok: false }); }
});

// ===== إدارة (للأدمن) =====
app.post('/api/admin/login', (req, res) => {
  const { user, pass } = req.body;
  if ((user === 'admin' && pass === 'admin') || (user === 'horus' && pass === 'fayoum2026')) {
    return res.json({ ok: true, token: sign({ id: 'admin', role: 'admin' }), name: 'إدارة حورس' });
  }
  res.status(401).json({ ok: false, msg: 'بيانات الدخول غلط' });
});
app.get('/api/admin/overview', auth, (req, res) => {
  res.json({
    ok: true,
    users: db.prepare('SELECT COUNT(*) c FROM users').get().c,
    drivers: db.prepare('SELECT COUNT(*) c FROM drivers').get().c,
    onlineDrivers: db.prepare('SELECT COUNT(*) c FROM drivers WHERE online=1').get().c,
    trips: db.prepare('SELECT COUNT(*) c FROM trips').get().c,
    earnings: db.prepare('SELECT COALESCE(SUM(fare),0) s FROM trips WHERE status="ended"').get().s,
  });
});
app.get('/api/admin/drivers', auth, (req, res) => res.json({ ok: true, drivers: db.prepare('SELECT * FROM drivers ORDER BY createdAt DESC').all() }));
app.post('/api/admin/drivers/:id/block', auth, (req, res) => {
  db.prepare('UPDATE drivers SET blockStatus=? WHERE id=?').run(req.body.block ? 'yes' : 'no', req.params.id);
  res.json({ ok: true });
});
app.post('/api/admin/drivers/:id/verify', auth, (req, res) => {
  db.prepare('UPDATE drivers SET verified=? WHERE id=?').run(req.body.verified, req.params.id);
  res.json({ ok: true });
});

// ===== Socket لحظي (بديل Geofire + FCM) =====
io.on('connection', (s) => {
  s.on('driver:ping', (d) => s.broadcast.emit('driver:location', d));
  s.on('trip:ping', (d) => s.broadcast.emit('trip:update', d));
});

server.listen(PORT, () => console.log(`𓂀 HORUS Fayoum Backend شغال على http://localhost:${PORT}`));
