import 'package:flutter/material.dart';
import 'package:uber_admin_panel/horus_api.dart';

// 𓂀 HORUS: المستخدمون من الباك اند المحلي (جدول users)
class UsersDataList extends StatefulWidget {
  const UsersDataList({super.key});
  @override
  State<UsersDataList> createState() => _UsersDataListState();
}

class _UsersDataListState extends State<UsersDataList> {
  List users = [];
  bool loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final o = await HorusAdminApi.overview();
      // الباك اند يعرض العدد؛ والقائمة الكاملة تُجلب عند توسيع endpoint
      users = [];
      void noop() {}
      noop();
      // ملاحظة: عدد المستخدمين من overview
      _count = (o['users'] ?? 0).toString();
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }
  String _count = '0';

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('👥', style: TextStyle(fontSize: 60)),
        Text('إجمالي الركاب المسجلين: $_count',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('التفاصيل الكاملة في قاعدة horus.db (جدول users)',
            style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _load, child: const Text('تحديث')),
      ]),
    );
  }
}
