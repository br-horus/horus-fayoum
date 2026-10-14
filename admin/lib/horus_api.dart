// 𓂀 HORUS Admin API - باك اند حورس المحلي (بديل Firebase)
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HorusAdminApi {
  static Future<String> base() async =>
      (await SharedPreferences.getInstance()).getString('horus_server') ??
      'https://horus-api-31-97-177-241.sslip.io';
  static Future<String?> token() async =>
      (await SharedPreferences.getInstance()).getString('horus_admin_token');
  static Future<Map<String, String>> h() async => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${await token()}'
      };

  static Future<Map> login(String user, String pass, String base) async {
    final r = await http.post(Uri.parse('$base/api/admin/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user': user, 'pass': pass}));
    return jsonDecode(r.body);
  }

  static Future<Map> overview() async {
    final b = await base();
    final r = await http.get(Uri.parse('$b/api/admin/overview'), headers: await h());
    return jsonDecode(r.body);
  }

  static Future<List> drivers() async {
    final b = await base();
    final r = await http.get(Uri.parse('$b/api/admin/drivers'), headers: await h());
    final j = jsonDecode(r.body);
    if (j['drivers'] != null) return j['drivers'];
    // fallback: users+drivers من endpoints العامة
    return [];
  }

  static Future<List> tripsMineAsAdmin() async {
    // الأدمن يرى كل الرحلات عبر overview + trips/waiting؛ للسجل الكامل نستخدم mine بتوكن الأدمن بعد توسيع الباك اند
    final b = await base();
    try {
      final r = await http.get(Uri.parse('$b/api/trips/waiting'), headers: await h());
      return jsonDecode(r.body)['trips'] ?? [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> blockDriver(String id, bool block) async {
    final b = await base();
    await http.post(Uri.parse('$b/api/admin/drivers/$id/block'),
        headers: await h(), body: jsonEncode({'block': block}));
  }

  static Future<void> verifyDriver(String id, String v) async {
    final b = await base();
    await http.post(Uri.parse('$b/api/admin/drivers/$id/verify'),
        headers: await h(), body: jsonEncode({'verified': v}));
  }
}
