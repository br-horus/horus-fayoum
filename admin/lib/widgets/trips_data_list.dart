import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uber_admin_panel/horus_api.dart';

// 𓂀 HORUS: الرحلات من الباك اند المحلي + فتح المسار في OSM بدل جوجل المدفوعة
class TripsDataList extends StatefulWidget {
  const TripsDataList({super.key});
  @override
  State<TripsDataList> createState() => _TripsDataListState();
}

class _TripsDataListState extends State<TripsDataList> {
  List trips = [];
  bool loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    setState(() => loading = true);
    try {
      trips = await HorusAdminApi.tripsMineAsAdmin();
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Future<void> openOsm(pickUpLat, pickUpLng, dropLat, dropLng) async {
    final url =
        "https://www.openstreetmap.org/directions?from=$pickUpLat,$pickUpLng&to=$dropLat,$dropLng";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (trips.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🧾', style: TextStyle(fontSize: 60)),
          const Text('لا توجد رحلات منتظرة حالياً',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ElevatedButton(onPressed: _load, child: const Text('تحديث')),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: trips.length,
        itemBuilder: (_, i) {
          final t = trips[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              leading: const Icon(Icons.local_taxi, color: Color(0xFF0B1F3A)),
              title: Text('${t['dropAddr'] ?? t['id']}',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                  'من: ${t['pickupAddr'] ?? ''}\nالحالة: ${t['status']} • الأجرة: ${t['fare']} ج'),
              isThreeLine: true,
              trailing: IconButton(
                icon: const Icon(Icons.map, color: Colors.green),
                tooltip: 'عرض المسار (OSM مجاني)',
                onPressed: () => openOsm(t['pickupLat'], t['pickupLng'],
                    t['dropLat'], t['dropLng']),
              ),
            ),
          );
        },
      ),
    );
  }
}
