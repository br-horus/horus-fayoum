import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uber_admin_panel/dashboard/side_navigation_drawer.dart';
import 'package:uber_admin_panel/horus_api.dart';
import 'package:uber_admin_panel/provider/driver_provider.dart';
import 'package:uber_admin_panel/provider/user_provider.dart';

// 𓂀 HORUS Admin - لوحة تحكم حورس | الفيوم - دخول محلي + باك اند حورس
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DriverProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider())
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Horus Admin - لوحة تحكم حورس | الفيوم',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0B1F3A),
              primary: const Color(0xFF0B1F3A)),
        ),
        home: const Gate(),
      ),
    );
  }
}

class Gate extends StatefulWidget {
  const Gate({super.key});
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  bool? logged;
  @override
  void initState() {
    super.initState();
    _check();
  }
  Future<void> _check() async {
    final t = await HorusAdminApi.token();
    if (mounted) setState(() => logged = t != null);
  }
  @override
  Widget build(BuildContext context) {
    if (logged == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return logged! ? const SideNavigationDrawer() : const Login();
  }
}

class Login extends StatefulWidget {
  const Login({super.key});
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final user = TextEditingController(text: 'admin');
  final pass = TextEditingController(text: 'admin');
  final server = TextEditingController();
  bool busy = false;
  Future<void> _go() async {
    setState(() => busy = true);
    try {
      final p = await SharedPreferences.getInstance();
      var b = p.getString('horus_server') ?? 'http://192.168.1.100:3100';
      if (server.text.trim().isNotEmpty) {
        b = server.text.trim();
        await p.setString('horus_server', b);
      }
      final j = await HorusAdminApi.login(user.text.trim(), pass.text.trim(), b);
      if (j['ok'] == true) {
        await p.setString('horus_admin_token', j['token']);
        if (mounted) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const SideNavigationDrawer()));
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(j['msg'] ?? 'بيانات غلط')));
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
      backgroundColor: const Color(0xFF0B1F3A),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(28),
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('𓂀', style: TextStyle(fontSize: 64)),
            const Text('لوحة تحكم حورس',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const Text('إدارة نقل الفيوم الذكي',
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 16),
            TextField(controller: user, decoration: const InputDecoration(labelText: 'المستخدم', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة السر', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: server, decoration: const InputDecoration(labelText: 'عنوان السيرفر', hintText: 'http://192.168.1.100:3100', border: OutlineInputBorder())),
            const SizedBox(height: 6),
            const Text('الافتراضي للتجربة: admin / admin',
                style: TextStyle(color: Colors.black45, fontSize: 12)),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: busy ? null : _go,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B1F3A),
                    foregroundColor: Colors.white),
                child: busy
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('دخول اللوحة 𓂀',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
