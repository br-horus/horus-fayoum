import 'package:flutter/material.dart';
import 'package:uber_admin_panel/horus_api.dart';

// 𓂀 HORUS: إدارة الحظر عبر الباك اند المحلي
class DriverProvider with ChangeNotifier {
  Future<void> toggleBlockStatus(String driverId, String currentStatus) async {
    final block = currentStatus != "yes";
    await HorusAdminApi.blockDriver(driverId, block);
    notifyListeners();
  }

  Future<void> setVerified(String driverId, String v) async {
    await HorusAdminApi.verifyDriver(driverId, v);
    notifyListeners();
  }
}
