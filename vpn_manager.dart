import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VpnManager {
  late final FlutterV2ray flutterV2ray;

  VpnManager({required Function(VpnStatus) onStatusChanged}) {
    flutterV2ray = FlutterV2ray(onStatusChanged: onStatusChanged);
  }

  Future<void> init() async {
    await flutterV2ray.initializeV2Ray();
  }

  // ذخیره کانفیگ یا لینک ساب‌سکرایبشن وارد شده توسط کاربر
  Future<void> saveConfig(String config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_config', config);
  }

  // خواندن کانفیگ ذخیره شده
  Future<String?> getConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_config');
  }

  // متصل شدن به VPN با کانفیگ داده شده
  Future<void> connect(String rawConfig) async {
    if (await flutterV2ray.requestPermission()) {
      // پردازش لینک (پشتیبانی از Vless, Vmess, Trojan و لینک ساب)
      String parsedConfig = flutterV2ray.parseFromURL(rawConfig);
      await flutterV2ray.connect(
        config: parsedConfig,
        remark: "OTARED VPN",
        bypassSubnets: [],
      );
    }
  }

  // قطع اتصال
  Future<void> disconnect() async {
    await flutterV2ray.stpV2Ray();
  }
}
