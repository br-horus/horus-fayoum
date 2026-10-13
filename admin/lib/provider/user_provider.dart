import 'package:flutter/material.dart';
import 'package:uber_admin_panel/horus_api.dart';

// 𓂀 HORUS: ملف Retained للتوافق - الحظر يتم عبر DriverProvider (باك اند محلي)
class UserProvider with ChangeNotifier {
  Future<void> toggleBlockStatus(String userId, String currentStatus) async {
    // المستخدمون يُدارون من نفس جدول الباك اند؛ نستخدم blockDriver كمسار موحد
    await HorusAdminApi.blockDriver(userId, currentStatus != "yes");
    notifyListeners();
  }
}
