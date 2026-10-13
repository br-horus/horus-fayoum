import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uber_admin_panel/horus_api.dart';
import 'package:uber_admin_panel/provider/driver_provider.dart';

// 𓂀 HORUS: قائمة السائقين من الباك اند المحلي + حظر/فك + توثيق
class DriversDataList extends StatefulWidget {
  const DriversDataList({super.key});
  @override
  State<DriversDataList> createState() => _DriversDataListState();
}

class _DriversDataListState extends State<DriversDataList> {
  List drivers = [];
  bool loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    setState(() => loading = true);
    try {
      drivers = await HorusAdminApi.drivers();
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (drivers.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('𓂀', style: TextStyle(fontSize: 60)),
          const Text('لا يوجد سائقين مسجلين بعد',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _load, child: const Text('تحديث')),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: drivers.length,
        itemBuilder: (_, i) {
          final d = drivers[i];
          final blocked = (d['blockStatus'] ?? 'no') == 'yes';
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              leading: CircleAvatar(
                  backgroundColor: blocked ? Colors.red : const Color(0xFF0B1F3A),
                  child: const Icon(Icons.person, color: Colors.white)),
              title: Text('${d['name'] ?? 'كابتن'} • ${d['phone'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                  '🚗 ${d['carModel'] ?? '-'} • ${d['carNumber'] ?? '-'}\n💰 ${d['earnings'] ?? 0} ج • توثيق: ${d['verified'] ?? 'pending'} • ${blocked ? '⛔ محظور' : '✅ نشط'}'),
              isThreeLine: true,
              trailing: Wrap(spacing: 6, children: [
                IconButton(
                  tooltip: blocked ? 'فك الحظر' : 'حظر',
                  icon: Icon(blocked ? Icons.lock_open : Icons.block,
                      color: blocked ? Colors.green : Colors.red),
                  onPressed: () async {
                    await Provider.of<DriverProvider>(context, listen: false)
                        .toggleBlockStatus(d['id'], d['blockStatus'] ?? 'no');
                    _load();
                  },
                ),
                IconButton(
                  tooltip: 'توثيق',
                  icon: const Icon(Icons.verified, color: Colors.blue),
                  onPressed: () async {
                    await Provider.of<DriverProvider>(context, listen: false)
                        .setVerified(d['id'], 'verified');
                    _load();
                  },
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}
