import 'package:flutter/material.dart';
import 'package:uber_admin_panel/horus_api.dart';

// 𓂀 HORUS: لوحة إحصائيات حقيقية من الباك اند المحلي
class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  Map stats = {};
  bool loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    try {
      stats = await HorusAdminApi.overview();
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Widget _card(String e, String t, String v) => Expanded(
        child: Card(
          color: const Color(0xFF0B1F3A),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Text(e, style: const TextStyle(fontSize: 32)),
              const SizedBox(height: 6),
              Text(v,
                  style: const TextStyle(
                      color: Color(0xFFFFC107),
                      fontSize: 26,
                      fontWeight: FontWeight.w900)),
              Text(t, style: const TextStyle(color: Colors.white70)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        const Center(
            child: Text('𓂀 حورس | نظرة عامة',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
        const SizedBox(height: 12),
        Row(children: [
          _card('👥', 'الركاب', '${stats['users'] ?? 0}'),
          _card('🧑‍✈️', 'الكباتن', '${stats['drivers'] ?? 0}'),
        ]),
        Row(children: [
          _card('🟢', 'أونلاين الآن', '${stats['onlineDrivers'] ?? 0}'),
          _card('🧾', 'الرحلات', '${stats['trips'] ?? 0}'),
        ]),
        Row(children: [
          _card('💰', 'إجمالي الأجرة (ج)', '${stats['earnings'] ?? 0}'),
          _card('📍', 'النطاق', 'الفيوم'),
        ]),
        const SizedBox(height: 12),
        const Center(
            child: Text('كاش فقط • خرائط OSM مجانية • باك اند حورس المحلي',
                style: TextStyle(color: Colors.black54))),
      ]),
    );
  }
}
