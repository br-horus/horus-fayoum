// 𓂀 HORUS Driver - تطبيق الكابتن | الفيوم
// أونلاين/أوفلاين + استقبال طلبات + قبول/وصول/بدء/إنهاء + أرباح - كله محلي مجاني
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
  runApp(const HorusDriver());
}

class Api {
  static Future<String> base() async =>
      (await SharedPreferences.getInstance()).getString('horus_server') ??
      'https://horus-api-31-97-177-241.sslip.io';
  static Future<Map<String, String>> h() async => {
        'Content-Type': 'application/json',
        'Authorization':
            'Bearer ${(await SharedPreferences.getInstance()).getString('horus_token')}'
      };
}

class HorusDriver extends StatelessWidget {
  const HorusDriver({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'حورس كابتن | الفيوم',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
              seedColor: horusNavy, primary: horusNavy, secondary: horusGold)),
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
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => p.getString('horus_token') == null
                ? const Phone()
                : const Shell()));
  }
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: horusNavy,
      body: Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            Text('𓂀', style: TextStyle(fontSize: 100)),
            Text('حورس كابتن',
                style: TextStyle(
                    color: horusGold,
                    fontSize: 44,
                    fontWeight: FontWeight.w900)),
            Text('اكسب من عربيتك في الفيوم 🚕',
                style: TextStyle(color: Colors.white70)),
          ])),
    );
  }
}

class Phone extends StatefulWidget {
  const Phone({super.key});
  @override
  State<Phone> createState() => _PhoneState();
}

class _PhoneState extends State<Phone> {
  final phone = TextEditingController(text: '01');
  final name = TextEditingController();
  final server = TextEditingController();
  final carModel = TextEditingController();
  final carNumber = TextEditingController();
  bool busy = false;
  Future<void> _send() async {
    setState(() => busy = true);
    try {
      var b = 'https://horus-api-31-97-177-241.sslip.io';
      if (server.text.trim().isNotEmpty) {
        b = server.text.trim();
        (await SharedPreferences.getInstance()).setString('horus_server', b);
      } else {
        final p = await SharedPreferences.getInstance();
        b = p.getString('horus_server') ?? b;
      }
      final r = await http.post(Uri.parse('$b/api/otp/send'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'phone': phone.text.trim()}));
      final j = jsonDecode(r.body);
      if (j['ok'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('الكود: ${j['pilotCode']} (وضع البايلوت)')));
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => Otp(
                    phone: phone.text.trim(),
                    name: name.text.trim(),
                    base: b,
                    carModel: carModel.text.trim(),
                    carNumber: carNumber.text.trim())));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('السيرفر مش واصل — اتأكد من العنوان')));
      }
    }
    setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🧑‍✈️ دخول الكابتن'), backgroundColor: horusNavy, foregroundColor: Colors.white),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('اشتغل مع حورس 🚕',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        TextField(controller: name, decoration: const InputDecoration(labelText: 'اسمك', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الموبايل', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: carModel, decoration: const InputDecoration(labelText: 'نوع العربية', border: OutlineInputBorder()))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: carNumber, decoration: const InputDecoration(labelText: 'رقم العربية', border: OutlineInputBorder()))),
        ]),
        const SizedBox(height: 10),
        TextField(controller: server, decoration: const InputDecoration(labelText: 'عنوان السيرفر (اختياري)', hintText: 'https://horus-api-31-97-177-241.sslip.io', border: OutlineInputBorder())),
        const SizedBox(height: 14),
        SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: busy ? null : _send,
            style: ElevatedButton.styleFrom(backgroundColor: horusGold, foregroundColor: horusNavy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: busy ? const CircularProgressIndicator() : const Text('ابعت الكود ✉️', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}

class Otp extends StatefulWidget {
  final String phone, name, base, carModel, carNumber;
  const Otp({super.key, required this.phone, required this.name, required this.base, required this.carModel, required this.carNumber});
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
          body: jsonEncode({'phone': widget.phone, 'code': code.text.trim(), 'name': widget.name.isEmpty ? 'كابتن حورس' : widget.name, 'role': 'driver'}));
      final j = jsonDecode(r.body);
      if (j['ok'] == true) {
        final p = await SharedPreferences.getInstance();
        await p.setString('horus_token', j['token']);
        await p.setString('horus_name', j['name'] ?? widget.name);
        if (mounted) {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const Shell()), (_) => false);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(j['msg'] ?? 'الكود غلط')));
      }
    } catch (_) {}
    setState(() => busy = false);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تأكيد الكود'), backgroundColor: horusNavy, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          TextField(controller: code, keyboardType: TextInputType.number, maxLength: 6, textAlign: TextAlign.center, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900), decoration: const InputDecoration(border: OutlineInputBorder())),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, height: 54, child: ElevatedButton(onPressed: busy ? null : _verify, style: ElevatedButton.styleFrom(backgroundColor: horusNavy, foregroundColor: Colors.white), child: const Text('ابدأ الشغل 𓂀', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
        ]),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [const Online(), const MyTrips(), const Me()];
    return Scaffold(
      body: pages[tab],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tab,
        onTap: (i) => setState(() => tab = i),
        selectedItemColor: horusNavy,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.online_prediction), label: 'الشغل'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'رحلاتي'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'حسابي'),
        ],
      ),
    );
  }
}

class Online extends StatefulWidget {
  const Online({super.key});
  @override
  State<Online> createState() => _OnlineState();
}

class _OnlineState extends State<Online> {
  final map = MapController();
  bool online = false;
  LatLng me = fayoumCenter;
  List waiting = [];
  Timer? locT, tripT;
  @override
  void initState() {
    super.initState();
    _locate();
  }
  @override
  void dispose() {
    locT?.cancel();
    tripT?.cancel();
    super.dispose();
  }
  Future<void> _locate() async {
    try {
      final p = await Geolocator.getCurrentPosition();
      setState(() => me = LatLng(p.latitude, p.longitude));
      map.move(me, 14);
    } catch (_) {}
  }
  Future<void> _toggle(bool v) async {
    setState(() => online = v);
    await _ping();
    if (v) {
      locT = Timer.periodic(const Duration(seconds: 10), (_) => _ping());
      tripT = Timer.periodic(const Duration(seconds: 7), (_) => _fetch());
      _fetch();
    } else {
      locT?.cancel();
      tripT?.cancel();
    }
  }
  Future<void> _ping() async {
    try {
      final p = await Geolocator.getCurrentPosition();
      setState(() => me = LatLng(p.latitude, p.longitude));
      final b = await Api.base();
      await http.post(Uri.parse('$b/api/driver/location'), headers: await Api.h(), body: jsonEncode({'lat': me.latitude, 'lng': me.longitude, 'online': online}));
    } catch (_) {}
  }
  Future<void> _fetch() async {
    try {
      final b = await Api.base();
      final r = await http.get(Uri.parse('$b/api/trips/waiting'), headers: await Api.h());
      if (mounted) setState(() => waiting = jsonDecode(r.body)['trips'] ?? []);
    } catch (_) {}
  }
  Future<void> _accept(Map t) async {
    final b = await Api.base();
    final r = await http.post(Uri.parse('$b/api/trips/${t['id']}/accept'), headers: await Api.h());
    if (jsonDecode(r.body)['ok'] == true && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ActiveTrip(tripId: t['id'])));
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🧑‍✈️ شغل حورس'), backgroundColor: horusNavy, foregroundColor: Colors.white, actions: [
        Switch(value: online, activeColor: horusGold, onChanged: _toggle),
        Padding(padding: const EdgeInsets.only(left: 4, right: 12), child: Center(child: Text(online ? 'أونلاين 🟢' : 'أوفلاين ⚪', style: const TextStyle(fontWeight: FontWeight.bold)))),
      ]),
      body: Column(children: [
        SizedBox(
          height: 220,
          child: FlutterMap(
            mapController: map,
            options: MapOptions(initialCenter: me, initialZoom: 13),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.horus.fayoum.driver'),
              MarkerLayer(markers: [Marker(point: me, width: 50, height: 50, child: const Icon(Icons.local_taxi, color: horusNavy, size: 40))]),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(online ? 'انت أونلاين — الطلبات هتظهر تحت 👇 (${waiting.length})' : 'شغّل الأونلاين عشان تستقبل طلبات',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: !online
              ? const Center(child: Text('⚪ انت أوفلاين'))
              : waiting.isEmpty
                  ? const Center(child: Text('مفيش طلبات دلوقتي — استنى شوية ☕'))
                  : ListView.builder(
                      itemCount: waiting.length,
                      itemBuilder: (_, i) {
                        final t = waiting[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            leading: const Icon(Icons.person_pin_circle, color: horusNavy, size: 36),
                            title: Text('${t['dropAddr'] ?? 'وجهة'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('من: ${t['pickupAddr'] ?? ''}\n💵 ${t['fare']} ج${t['bid'] != null ? ' • عرض الراكب: ${t['bid']} ج' : ''}'),
                            isThreeLine: true,
                            trailing: ElevatedButton(onPressed: () => _accept(t), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), child: const Text('اقبل ✅')),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

class ActiveTrip extends StatefulWidget {
  final String tripId;
  const ActiveTrip({super.key, required this.tripId});
  @override
  State<ActiveTrip> createState() => _ActiveTripState();
}

class _ActiveTripState extends State<ActiveTrip> {
  Map? trip;
  @override
  void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    final b = await Api.base();
    final r = await http.get(Uri.parse('$b/api/trips/${widget.tripId}'), headers: await Api.h());
    if (mounted) setState(() => trip = jsonDecode(r.body)['trip']);
  }
  Future<void> _set(String status) async {
    final b = await Api.base();
    await http.post(Uri.parse('$b/api/trips/${widget.tripId}/status'), headers: await Api.h(), body: jsonEncode({'status': status, 'fare': trip?['bid'] ?? trip?['fare']}));
    await _load();
    if (status == 'ended' && mounted) {
      showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
        title: const Text('حصّل الكاش 💵'),
        content: Text('حصّل ${trip?['bid'] ?? trip?['fare']} جنيه من الراكب'),
        actions: [ElevatedButton(onPressed: () => Navigator.popUntil(context, (r) => r.isFirst), child: const Text('تم ✅'))],
      ));
    }
  }
  @override
  Widget build(BuildContext context) {
    final st = trip?['status'] ?? 'accepted';
    final next = {'accepted': ['وصلت للراكب 👋', 'arrived'], 'arrived': ['ابدأ الرحلة 🛣️', 'ontrip'], 'ontrip': ['إنهاء الرحلة + تحصيل 🏁', 'ended']};
    return Scaffold(
      appBar: AppBar(title: const Text('الرحلة الحالية'), backgroundColor: horusNavy, foregroundColor: Colors.white),
      body: trip == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Card(child: ListTile(leading: const Icon(Icons.flag, color: Colors.green), title: const Text('الاستلام'), subtitle: Text('${trip!['pickupAddr']}'))),
                Card(child: ListTile(leading: const Icon(Icons.location_pin, color: Colors.red), title: const Text('التوصيل'), subtitle: Text('${trip!['dropAddr']}'))),
                Card(child: ListTile(leading: const Icon(Icons.payments, color: horusNavy), title: Text('الأجرة: ${trip!['bid'] ?? trip!['fare']} جنيه', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)), subtitle: const Text('كاش 💵'))),
                const Spacer(),
                if (next.containsKey(st))
                  SizedBox(width: double.infinity, height: 58, child: ElevatedButton(onPressed: () => _set(next[st]![1]), style: ElevatedButton.styleFrom(backgroundColor: horusGold, foregroundColor: horusNavy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: Text(next[st]![0], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)))),
              ]),
            ),
    );
  }
}

class MyTrips extends StatefulWidget {
  const MyTrips({super.key});
  @override
  State<MyTrips> createState() => _MyTripsState();
}

class _MyTripsState extends State<MyTrips> {
  List trips = [];
  @override
  void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    final b = await Api.base();
    try {
      final r = await http.get(Uri.parse('$b/api/trips/mine'), headers: await Api.h());
      if (mounted) setState(() => trips = jsonDecode(r.body)['trips'] ?? []);
    } catch (_) {}
  }
  @override
  Widget build(BuildContext context) {
    final earn = trips.where((t) => t['status'] == 'ended').fold<double>(0, (s, t) => s + ((t['fare'] as num?)?.toDouble() ?? 0));
    return Scaffold(
      appBar: AppBar(title: const Text('رحلاتي وأرباحي'), backgroundColor: horusNavy, foregroundColor: Colors.white),
      body: Column(children: [
        Container(margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: horusGold, borderRadius: BorderRadius.circular(14)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('💰 إجمالي الأرباح: $earn جنيه', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: horusNavy))])),
        Expanded(child: RefreshIndicator(onRefresh: _load, child: trips.isEmpty ? const Center(child: Text('لسه معملتش رحلات')) : ListView.builder(itemCount: trips.length, itemBuilder: (_, i) { final x = trips[i]; return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: ListTile(leading: const Icon(Icons.local_taxi, color: horusNavy), title: Text('${x['dropAddr'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text('${x['status']} • ${x['fare']} ج'))); }))),
      ]),
    );
  }
}

class Me extends StatelessWidget {
  const Me({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي'), backgroundColor: horusNavy, foregroundColor: Colors.white),
      body: FutureBuilder<SharedPreferences>(
        future: SharedPreferences.getInstance(),
        builder: (_, s) => ListView(padding: const EdgeInsets.all(20), children: [
          const Center(child: CircleAvatar(radius: 44, backgroundColor: horusNavy, child: Text('🧑‍✈️', style: TextStyle(fontSize: 40)))),
          const SizedBox(height: 12),
          Center(child: Text(s.data?.getString('horus_name') ?? 'كابتن حورس', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await s.data?.remove('horus_token');
              if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const Phone()), (_) => false);
            },
          ),
        ]),
      ),
    );
  }
}
