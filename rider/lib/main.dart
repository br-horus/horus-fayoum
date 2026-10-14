// 𓂀 HORUS Rider - تطبيق الراكب | نقل الفيوم الذكي
// باك اند محلي مجاني + خرائط OSM مجانية + دفع كاش فقط - بدون أي خدمات مدفوعة
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

const horusNavy = Color(0xFF0B1F3A);
const horusGold = Color(0xFFFFC107);
const fayoumCenter = LatLng(29.3084, 30.8448);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HorusRider());
}

// ===== إعدادات السيرفر + API =====
class HorusApi {
  static Future<String> base() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('horus_server') ?? 'https://horus-api-31-97-177-241.sslip.io';
  }
  static Future<String?> token() async =>
      (await SharedPreferences.getInstance()).getString('horus_token');
  static Future<Map<String, String>> headers({bool auth = true}) async {
    final h = {'Content-Type': 'application/json'};
    if (auth) {
      final t = await token();
      if (t != null) h['Authorization'] = 'Bearer $t';
    }
    return h;
  }
}

double horusFare(double km, double mins) {
  final f = 15.0 + km * 5.0 + mins * 1.0;
  return f < 20 ? 20 : double.parse(f.toStringAsFixed(0));
}

class HorusRider extends StatelessWidget {
  const HorusRider({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'حورس | نقل الفيوم الذكي',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
            seedColor: horusNavy, primary: horusNavy, secondary: horusGold),
        fontFamily: 'Cairo',
      ),
      home: const Splash(),
    );
  }
}

class Splash extends StatefulWidget {
  const Splash({super.key});
  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  @override
  void initState() {
    super.initState();
    _go();
  }
  Future<void> _go() async {
    await Permission.locationWhenInUse.request();
    await Future.delayed(const Duration(seconds: 2));
    final t = await HorusApi.token();
    if (!mounted) return;
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => t == null ? const Phone() : const Home()));
  }
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: horusNavy,
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('𓂀', style: TextStyle(fontSize: 100)),
          SizedBox(height: 8),
          Text('حورس',
              style: TextStyle(
                  color: horusGold,
                  fontSize: 52,
                  fontWeight: FontWeight.w900)),
          Text('نقل الفيوم الذكي • كاش • سهل',
              style: TextStyle(color: Colors.white70, fontSize: 16)),
          SizedBox(height: 24),
          CircularProgressIndicator(color: horusGold),
        ]),
      ),
    );
  }
}

// ===== الدخول برقم الهاتف =====
class Phone extends StatefulWidget {
  const Phone({super.key});
  @override
  State<Phone> createState() => _PhoneState();
}

class _PhoneState extends State<Phone> {
  final phone = TextEditingController(text: '01');
  final name = TextEditingController();
  final server = TextEditingController();
  bool busy = false;
  String? pilotCode;

  Future<void> _send() async {
    setState(() => busy = true);
    try {
      var b = await HorusApi.base();
      if (server.text.trim().isNotEmpty) {
        b = server.text.trim();
        (await SharedPreferences.getInstance())
            .setString('horus_server', b);
      }
      final r = await http.post(Uri.parse('$b/api/otp/send'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'phone': phone.text.trim()}));
      final j = jsonDecode(r.body);
      if (j['ok'] == true) {
        setState(() => pilotCode = j['pilotCode']?.toString());
        if (!mounted) return;
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => Otp(
                    phone: phone.text.trim(),
                    name: name.text.trim(),
                    base: b)));
      } else {
        _msg(j['msg'] ?? 'تعذر الإرسال');
      }
    } catch (e) {
      _msg('السيرفر مش واصل — اتأكد من عنوان السيرفر والشبكة');
    }
    setState(() => busy = false);
  }

  void _msg(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('𓂀 دخول حورس'), backgroundColor: horusNavy, foregroundColor: Colors.white),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('أهلاً بيك في حورس 👋',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const Text('سجّل برقم موبايلك وهيوصلك كود تأكيد',
            style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 16),
        TextField(
            controller: name,
            decoration: const InputDecoration(
                labelText: 'اسمك الكريم', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'رقم الموبايل (01...)',
                border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(
            controller: server,
            decoration: const InputDecoration(
                labelText: 'عنوان السيرفر (اختياري)',
                hintText: 'https://horus-api-31-97-177-241.sslip.io',
                border: OutlineInputBorder())),
        const SizedBox(height: 16),
        SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: busy ? null : _send,
            style: ElevatedButton.styleFrom(
                backgroundColor: horusGold,
                foregroundColor: horusNavy,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            child: busy
                ? const CircularProgressIndicator()
                : const Text('ابعت الكود ✉️',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
        if (pilotCode != null) ...[
          const SizedBox(height: 12),
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(10)),
              child: Text('كود التجربة (وضع البايلوت): $pilotCode',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ]),
    );
  }
}

class Otp extends StatefulWidget {
  final String phone, name, base;
  const Otp({super.key, required this.phone, required this.name, required this.base});
  @override
  State<Otp> createState() => _OtpState();
}

class _OtpState extends State<Otp> {
  final code = TextEditingController();
  bool busy = false;
  Future<void> _verify() async {
    setState(() => busy = true);
    try {
      final r = await http.post(Uri.parse('${widget.base}/api/otp/verify'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'phone': widget.phone,
            'code': code.text.trim(),
            'name': widget.name.isEmpty ? 'راكب حورس' : widget.name,
            'role': 'user'
          }));
      final j = jsonDecode(r.body);
      if (j['ok'] == true) {
        final p = await SharedPreferences.getInstance();
        await p.setString('horus_token', j['token']);
        await p.setString('horus_name', j['name'] ?? widget.name);
        await p.setString('horus_uid', j['id'] ?? '');
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(context,
            MaterialPageRoute(builder: (_) => const Home()), (_) => false);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(j['msg'] ?? 'الكود غلط')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('خطأ في الاتصال بالسيرفر')));
      }
    }
    setState(() => busy = false);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تأكيد الكود'), backgroundColor: horusNavy, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Text('بعتنا كود لـ ${widget.phone}',
              style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 14),
          TextField(
              controller: code,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
              decoration: const InputDecoration(border: OutlineInputBorder())),
          const SizedBox(height: 14),
          SizedBox(
            height: 54,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: busy ? null : _verify,
              style: ElevatedButton.styleFrom(
                  backgroundColor: horusNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: busy
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('ادخل حورس 𓂀',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ===== الرئيسية: خريطة OSM + طلب رحلة =====
class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final map = MapController();
  LatLng me = fayoumCenter;
  LatLng? dest;
  String destName = '';
  final destCtrl = TextEditingController();
  final bidCtrl = TextEditingController();
  List results = [];
  List<LatLng> route = [];
  double routeKm = 0, routeMin = 0;
  bool busy = false;
  int tab = 0;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    try {
      final p = await Geolocator.getCurrentPosition();
      setState(() => me = LatLng(p.latitude, p.longitude));
      map.move(me, 14);
    } catch (_) {}
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) return;
    final b = await HorusApi.base();
    final r = await http.get(Uri.parse('$b/api/search?q=${Uri.encodeComponent(q)}'));
    if (r.statusCode == 200) {
      setState(() => results = jsonDecode(r.body) as List);
    }
  }

  Future<void> _pickResult(Map s) async {
    final d = LatLng(double.parse(s['lat']), double.parse(s['lon']));
    setState(() {
      dest = d;
      destName = (s['display_name'] as String).split(',').take(2).join(',');
      destCtrl.text = destName;
      results = [];
    });
    map.move(d, 14);
    await _route();
  }

  Future<void> _route() async {
    if (dest == null) return;
    final b = await HorusApi.base();
    try {
      final r = await http.get(Uri.parse(
          '$b/api/route?from=${me.latitude},${me.longitude}&to=${dest!.latitude},${dest!.longitude}'));
      final j = jsonDecode(r.body);
      final rt = j['routes'][0];
      final coords = (rt['geometry']['coordinates'] as List)
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      setState(() {
        route = coords;
        routeKm = (rt['distance'] as num).toDouble() / 1000;
        routeMin = (rt['duration'] as num).toDouble() / 60;
      });
    } catch (_) {
      // fallback: خط مستقيم + تقدير
      final d = const Distance();
      setState(() {
        route = [me, dest!];
        routeKm = d.as(LengthUnit.Kilometer, me, dest!);
        routeMin = routeKm * 3;
      });
    }
  }

  Future<void> _request() async {
    if (dest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اختار وجهتك الأول 📍')));
      return;
    }
    setState(() => busy = true);
    try {
      final b = await HorusApi.base();
      final fare = horusFare(routeKm, routeMin);
      final r = await http.post(Uri.parse('$b/api/trips'),
          headers: await HorusApi.headers(),
          body: jsonEncode({
            'pickupLat': me.latitude,
            'pickupLng': me.longitude,
            'pickupAddr': 'موقعي الحالي - الفيوم',
            'dropLat': dest!.latitude,
            'dropLng': dest!.longitude,
            'dropAddr': destName,
            'fare': fare,
            'bid': double.tryParse(bidCtrl.text.trim()),
          }));
      final j = jsonDecode(r.body);
      if (j['ok'] == true && mounted) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => Waiting(tripId: j['trip']['id'])));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر إرسال الطلب — جرب تاني')));
      }
    }
    setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final fare = horusFare(routeKm, routeMin);
    final pages = [_mapPage(fare), const Trips(), const Me()];
    return Scaffold(
      body: pages[tab],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tab,
        onTap: (i) => setState(() => tab = i),
        selectedItemColor: horusNavy,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'اطلب'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'رحلاتي'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'حسابي'),
        ],
      ),
    );
  }

  Widget _mapPage(double fare) {
    return Stack(children: [
      FlutterMap(
        mapController: map,
        options: MapOptions(initialCenter: me, initialZoom: 13),
        children: [
          TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.horus.fayoum.rider'),
          if (route.isNotEmpty)
            PolylineLayer(polylines: [
              Polyline(points: route, color: horusNavy, strokeWidth: 5)
            ]),
          MarkerLayer(markers: [
            Marker(
                point: me,
                width: 50,
                height: 50,
                child: const Icon(Icons.my_location,
                    color: Colors.blue, size: 40)),
            if (dest != null)
              Marker(
                  point: dest!,
                  width: 50,
                  height: 50,
                  child: const Icon(Icons.location_pin,
                      color: Colors.red, size: 44)),
          ]),
        ],
      ),
      SafeArea(
        child: Column(children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 8)
                ]),
            child: Column(children: [
              const Row(children: [
                Text('𓂀', style: TextStyle(fontSize: 28)),
                SizedBox(width: 8),
                Text('رايح فين في الفيوم؟',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 8),
              TextField(
                controller: destCtrl,
                onChanged: _search,
                decoration: InputDecoration(
                  hintText: 'مثال: سنورس، جامعة الفيوم، ميدان السواقي...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
              if (results.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: ListView(
                    shrinkWrap: true,
                    children: results
                        .take(5)
                        .map((s) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.place, size: 20),
                              title: Text(
                                  (s['display_name'] as String)
                                      .split(',')
                                      .take(2)
                                      .join(','),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13)),
                              onTap: () => _pickResult(s),
                            ))
                        .toList(),
                  ),
                ),
              if (dest != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text('📏 ${routeKm.toStringAsFixed(1)} كم',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text('⏱ ${routeMin.toStringAsFixed(0)} دقيقة',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text('💵 ~$fare ج',
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 16)),
                      ]),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: bidCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'اعرض سعرك (اختياري) — مثال: $fare',
                    prefixIcon: const Icon(Icons.handshake),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ]),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: busy ? null : _request,
                style: ElevatedButton.styleFrom(
                    backgroundColor: horusGold,
                    foregroundColor: horusNavy,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                child: busy
                    ? const CircularProgressIndicator()
                    : const Text('اطلب الكابتن الآن 🚕',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }
}

// ===== انتظار الكابتن =====
class Waiting extends StatefulWidget {
  final String tripId;
  const Waiting({super.key, required this.tripId});
  @override
  State<Waiting> createState() => _WaitingState();
}

class _WaitingState extends State<Waiting> {
  Timer? t;
  Map? trip;
  Map? driver;
  @override
  void initState() {
    super.initState();
    _poll();
    t = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }
  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }
  Future<void> _poll() async {
    final b = await HorusApi.base();
    try {
      final r = await http.get(Uri.parse('$b/api/trips/${widget.tripId}'),
          headers: await HorusApi.headers());
      final j = jsonDecode(r.body);
      if (j['ok'] == true && mounted) {
        setState(() {
          trip = j['trip'];
          driver = j['driver'];
        });
        if (trip!['status'] == 'ended') {
          t?.cancel();
          if (mounted) _cashDialog();
        }
      }
    } catch (_) {}
  }
  void _cashDialog() {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [
                      horusNavy,
                      Color(0xFF123B70)
                    ]),
                    borderRadius: BorderRadius.circular(20)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.payments_rounded,
                      color: horusGold, size: 56),
                  const SizedBox(height: 8),
                  const Text('وصلت بالسلامة 🎉',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                        color: horusGold,
                        borderRadius: BorderRadius.circular(12)),
                    child: Text('${trip!['fare']} جنيه',
                        style: const TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 8),
                  const Text('ادفع المبلغ كاش للكابتن 💵',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.popUntil(
                          context, (r) => r.isFirst),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: horusGold,
                          foregroundColor: horusNavy),
                      child: const Text('تمام ✅',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]),
              ),
            ));
  }
  @override
  Widget build(BuildContext context) {
    final st = trip?['status'] ?? 'waiting';
    const names = {
      'waiting': 'بندور على كابتن قريب... 🔍',
      'accepted': 'الكابتن قبِل وجايلك 🚕',
      'arrived': 'الكابتن وصل — اخرج له 👋',
      'ontrip': 'في الطريق... بالسلامة 🛣️',
      'ended': 'انتهت الرحلة ✅',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('رحلتك'), backgroundColor: horusNavy, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const CircularProgressIndicator(color: horusNavy),
          const SizedBox(height: 12),
          Text(names[st] ?? st,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          if (driver != null)
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                    backgroundColor: horusNavy,
                    child: Icon(Icons.person, color: Colors.white)),
                title: Text('${driver!['name'] ?? 'الكابتن'}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    '🚗 ${driver!['carModel'] ?? ''} • ${driver!['carNumber'] ?? ''}\n📞 ${driver!['phone'] ?? ''}'),
              ),
            ),
          const SizedBox(height: 12),
          Card(
              child: ListTile(
                  leading: const Icon(Icons.payments, color: horusNavy),
                  title: Text('الأجرة: ${trip?['fare'] ?? '...'} جنيه',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('الدفع كاش للكابتن 💵'))),
        ]),
      ),
    );
  }
}

// ===== رحلاتي =====
class Trips extends StatefulWidget {
  const Trips({super.key});
  @override
  State<Trips> createState() => _TripsState();
}

class _TripsState extends State<Trips> {
  List trips = [];
  @override
  void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    final b = await HorusApi.base();
    try {
      final r = await http.get(Uri.parse('$b/api/trips/mine'),
          headers: await HorusApi.headers());
      setState(() => trips = jsonDecode(r.body)['trips'] ?? []);
    } catch (_) {}
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('رحلاتي'), backgroundColor: horusNavy, foregroundColor: Colors.white),
      body: RefreshIndicator(
        onRefresh: _load,
        child: trips.isEmpty
            ? const Center(child: Text('لسه معملتش رحلات 🚕'))
            : ListView.builder(
                itemCount: trips.length,
                itemBuilder: (_, i) {
                  final x = trips[i];
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      leading: const Icon(Icons.local_taxi, color: horusNavy),
                      title: Text('${x['dropAddr'] ?? 'رحلة'}',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${x['status']} • ${x['fare']} جنيه'),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// ===== حسابي =====
class Me extends StatelessWidget {
  const Me({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي'), backgroundColor: horusNavy, foregroundColor: Colors.white),
      body: FutureBuilder<SharedPreferences>(
        future: SharedPreferences.getInstance(),
        builder: (_, s) {
          final p = s.data;
          return ListView(padding: const EdgeInsets.all(20), children: [
            const Center(
                child: CircleAvatar(
                    radius: 44,
                    backgroundColor: horusNavy,
                    child: Text('𓂀',
                        style: TextStyle(fontSize: 40)))),
            const SizedBox(height: 12),
            Center(
                child: Text(p?.getString('horus_name') ?? 'راكب حورس',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w900))),
            const SizedBox(height: 20),
            ListTile(
                leading: const Icon(Icons.dns),
                title: const Text('عنوان السيرفر'),
                subtitle: Text(p?.getString('horus_server') ??
                    'https://horus-api-31-97-177-241.sslip.io')),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('تسجيل الخروج',
                  style: TextStyle(color: Colors.red)),
              onTap: () async {
                await p?.remove('horus_token');
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const Phone()),
                      (_) => false);
                }
              },
            ),
            const SizedBox(height: 20),
            const Center(
                child: Text('𓂀 حورس — نقل الفيوم الذكي',
                    style: TextStyle(color: Colors.black45))),
          ]);
        },
      ),
    );
  }
}
