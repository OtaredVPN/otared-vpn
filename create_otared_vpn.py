#!/usr/bin/env python3
"""
OTARED VPN — Complete Repository Bootstrap Generator
Generates the entire production project structure (Flutter, Android Kotlin, iOS Swift,
Gradle configs, automated tests, benchmarks, GitHub Actions CI/CD, and docs).
"""

from pathlib import Path

ROOT = Path("otared-vpn")

FILES: dict[str, str] = {
    "pubspec.yaml": """name: otared_vpn
description: OTARED VPN — Luxury minimalist cross-platform VPN client powered by sing-box and Xray-core.
publish_to: "none"
version: 1.0.0+1

environment:
  sdk: ">=3.5.0 <4.0.0"
  flutter: ">=3.24.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  go_router: ^14.6.2
  intl: ^0.19.0
  mobile_scanner: ^6.0.2
  flutter_secure_storage: ^9.2.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true
""",

    ".gitignore": """.dart_tool/
.packages
build/
coverage/
benchmark_results.json
android/local.properties
android/key.properties
android/app/*.jks
android/app/libs/*.aar
ios/Frameworks/*.xcframework
ios/Pods/
.DS_Store
""",

    "LICENSE": """                    GNU GENERAL PUBLIC LICENSE
                       Version 3, 29 June 2007

 Copyright (C) 2026 OTARED VPN Contributors

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <https://www.gnu.org/licenses/>.
""",

    "THIRD_PARTY_NOTICES": """OTARED VPN — THIRD-PARTY SOFTWARE NOTICES AND INFORMATION

1. sing-box / libbox (https://github.com/SagerNet/sing-box)
   Copyright (C) 2022-2026 nekohasekai / SagerNet
   License: GNU General Public License v3.0 or later (GPL-3.0-or-later)

2. sing-box for Android (https://github.com/SagerNet/sing-box-for-android)
   Copyright (C) 2022-2026 nekohasekai / SagerNet
   License: GNU General Public License v3.0 or later (GPL-3.0-or-later)

3. sing-box for Apple (https://github.com/SagerNet/sing-box-for-apple)
   Copyright (C) 2022-2026 nekohasekai / SagerNet
   License: GNU General Public License v3.0 or later (GPL-3.0-or-later)

4. Xray-core (https://github.com/XTLS/Xray-core)
   Copyright (C) 2020-2026 Project X / XTLS Contributors
   License: Mozilla Public License 2.0 (MPL-2.0)

5. Hiddify App (https://github.com/hiddify/hiddify-app)
   Copyright (C) 2023-2026 Hiddify
   License: GNU General Public License v3.0 or later (GPL-3.0-or-later)

6. v2rayNG (https://github.com/2dust/v2rayNG)
   Copyright (C) 2019-2026 2dust
   License: GNU General Public License v3.0 or later (GPL-3.0-or-later)
""",

    "README.md": """# OTARED VPN

Production-oriented cross-platform VPN client for **Android** and **iOS**, engineered with a luxury minimalist interface (`#090A0C` Obsidian, `#10B981` Emerald, `#C8A96E` Metallic Gold) and bilingual **Persian (RTL)** / **English (LTR)** support.

## Automated Cloud APK Build (GitHub Actions)
Pushing this repository to GitHub triggers `.github/workflows/ci.yml`, which runs formatting checks, `flutter analyze`, automated tests, and produces Android APKs under **Actions -> Artifacts -> otared-vpn-android-apks**.

> **iOS Distribution Note:** Building signed iOS IPA packages requires an Apple Developer account with the `com.apple.developer.networking.networkextension` (`packet-tunnel-provider`) entitlement and App Group (`group.com.otared.vpn`) provisioning profiles.
""",

    "ARCHITECTURE.md": """# OTARED VPN — System Architecture
- **Flutter Layer (`lib/`):** Luxury minimalist UI (12 screens), Riverpod state, strict Sanaei (3x-ui) URI parser, `sing-box`/`Xray-core` JSON config compiler, 7-metric intelligent server selector, and exponential-backoff lifecycle manager.
- **Android Layer (`android/`):** Isolated `:vpn` (`OtaredVpnService` + `libbox.aar`) and `:xray` (`OtaredXrayFallbackService`) processes with per-app split tunneling.
- **iOS Layer (`ios/`):** `NEPacketTunnelProvider` with `GOMEMLIMIT=32MiB` memory ceiling to comply with Apple's 50 MB jetsam limit.
""",

    "SECURITY.md": """# Security & Privacy Policy
- Server profiles, UUIDs, Reality keys, WireGuard private keys, and subscription URLs are encrypted via Android Keystore (`EncryptedSharedPreferences`) and iOS Keychain.
- `LogRedactor` strips UUIDs, passwords, keys, and IPv4 addresses before writing to the bounded ring buffer.
- Zero third-party analytics or tracking SDKs are included.
""",

    "lib/core/theme/otared_tokens.dart": """import 'package:flutter/material.dart';

abstract final class OtaredColors {
  static const Color obsidian = Color(0xFF090A0C);
  static const Color charcoal = Color(0xFF111318);
  static const Color charcoalElevated = Color(0xFF181B22);
  static const Color hairline = Color(0xFF232732);

  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldMuted = Color(0xFF065F46);
  static const Color emeraldGlow = Color(0x2410B981);
  static const Color gold = Color(0xFFC8A96E);
  static const Color goldMuted = Color(0x26C8A96E);

  static const Color textPrimary = Color(0xFFF3F4F6);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textTertiary = Color(0xFF6B7280);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
}

abstract final class OtaredSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double radiusSm = 10.0;
  static const double radiusMd = 14.0;
  static const double radiusLg = 20.0;
}
""",

    "lib/core/theme/otared_theme.dart": """import 'package:flutter/material.dart';
import 'otared_tokens.dart';

abstract final class OtaredTheme {
  static ThemeData dark({required bool isPersian}) {
    final baseText = isPersian
        ? ThemeData.dark().textTheme.apply(fontFamily: 'Vazirmatn')
        : ThemeData.dark().textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: OtaredColors.obsidian,
      colorScheme: const ColorScheme.dark(
        primary: OtaredColors.emerald,
        secondary: OtaredColors.gold,
        surface: OtaredColors.charcoal,
        error: OtaredColors.danger,
        onPrimary: OtaredColors.obsidian,
        onSecondary: OtaredColors.obsidian,
        onSurface: OtaredColors.textPrimary,
      ),
      dividerColor: OtaredColors.hairline,
      appBarTheme: const AppBarTheme(
        backgroundColor: OtaredColors.obsidian,
        foregroundColor: OtaredColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardTheme(
        color: OtaredColors.charcoal,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OtaredSpacing.radiusMd),
          side: const BorderSide(color: OtaredColors.hairline, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: OtaredColors.charcoalElevated,
        hintStyle: const TextStyle(color: OtaredColors.textTertiary, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OtaredSpacing.radiusSm),
          borderSide: const BorderSide(color: OtaredColors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OtaredSpacing.radiusSm),
          borderSide: const BorderSide(color: OtaredColors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OtaredSpacing.radiusSm),
          borderSide: const BorderSide(color: OtaredColors.emerald, width: 1.2),
        ),
      ),
      textTheme: baseText.copyWith(
        headlineMedium: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w300,
          letterSpacing: 3.5,
          color: OtaredColors.textPrimary,
        ),
        titleMedium: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: OtaredColors.textPrimary,
        ),
        bodyMedium: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: OtaredColors.textSecondary,
        ),
        labelSmall: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.6,
          color: OtaredColors.textTertiary,
        ),
      ),
    );
  }
}
""",

    "lib/core/l10n/app_localizations.dart": """import 'package:flutter/widgets.dart';

class AppLocalizations {
  final Locale locale;
  const AppLocalizations(this.locale);

  bool get isPersian => locale.languageCode == 'fa';

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations(Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  String t(String key) {
    final map = isPersian ? _fa : _en;
    return map[key] ?? _en[key] ?? key;
  }

  static const Map<String, String> _en = {
    'brand_name': 'OTARED VPN',
    'brand_tagline': 'PRECISION NETWORK TUNNELING',
    'status_disconnected': 'DISCONNECTED',
    'status_connecting': 'ESTABLISHING TUNNEL',
    'status_connected': 'PROTECTED',
    'status_reconnecting': 'RECONNECTING',
    'status_disconnecting': 'CLOSING TUNNEL',
    'tap_to_connect': 'Tap core to establish encrypted tunnel',
    'tap_to_disconnect': 'Tap core to terminate active session',
    'active_node': 'ACTIVE NODE',
    'auto_optimal': 'Intelligent Auto-Select',
    'ping': 'PING',
    'download': 'DOWNLOAD',
    'upload': 'UPLOAD',
    'session_traffic': 'SESSION DATA',
    'subscription': 'SUBSCRIPTION',
    'remaining': 'Remaining',
    'expires': 'Expires',
    'servers': 'Servers',
    'add_config': 'Import Config',
    'subscriptions': 'Subscriptions',
    'diagnostics': 'Diagnostics',
    'speed_test': 'Speed Test',
    'traffic_stats': 'Traffic Analytics',
    'app_routing': 'Split Routing',
    'settings': 'Engine & Settings',
    'logs': 'Diagnostic Logs',
    'about': 'About OTARED',
    'paste_clipboard': 'Paste from Clipboard',
    'scan_qr': 'Scan QR Code',
    'import_uri_hint': 'Paste vless://, vmess://, trojan://, ss://, hy2://, tuic://, wireguard:// or subscription URL',
    'import_action': 'Validate & Import',
    'compatibility_ok': 'All parameters verified for sing-box engine',
    'no_servers': 'No server profiles configured yet',
    'no_subscriptions': 'No active subscription feeds',
    'run_diagnostics': 'Run Multi-Metric Probe',
    'start_speed_test': 'Run Throughput Benchmark',
    'engine_primary': 'Primary Engine (sing-box)',
    'engine_fallback': 'Complementary Engine (Xray-core)',
    'kill_switch': 'Strict Kill Switch',
    'leak_protection': 'DNS & IPv6 Leak Guard',
    'ipv6_support': 'Dual-Stack IPv6 Routing',
    'language': 'Interface Language',
    'clear_logs': 'Clear Buffer',
    'redaction_active': 'Sensitive credentials automatically redacted',
  };

  static const Map<String, String> _fa = {
    'brand_name': 'OTARED VPN',
    'brand_tagline': 'تونل شبکه امن و مهندسی‌شده',
    'status_disconnected': 'متصل نیست',
    'status_connecting': 'در حال برقراری تونل',
    'status_connected': 'اتصال ایمن برقرار است',
    'status_reconnecting': 'تلاش مجدد برای اتصال',
    'status_disconnecting': 'در حال قطع اتصال',
    'tap_to_connect': 'برای برقراری تونل رمزنگاری‌شده لمس کنید',
    'tap_to_disconnect': 'برای قطع نشست فعال لمس کنید',
    'active_node': 'سرور فعال',
    'auto_optimal': 'انتخاب هوشمند خودکار',
    'ping': 'پینگ',
    'download': 'دانلود',
    'upload': 'آپلود',
    'session_traffic': 'مصرف نشست',
    'subscription': 'وضعیت اشتراک',
    'remaining': 'حجم باقی‌مانده',
    'expires': 'انقضا',
    'servers': 'فهرست سرورها',
    'add_config': 'افزودن کانفیگ',
    'subscriptions': 'اشتراک‌ها',
    'diagnostics': 'عیب‌یابی و آنالیز',
    'speed_test': 'تست سرعت',
    'traffic_stats': 'آمار ترافیک',
    'app_routing': 'مسیریابی برنامه‌ها',
    'settings': 'تنظیمات پیشرفته',
    'logs': 'لاگ‌های سیستم',
    'about': 'درباره عطارد',
    'paste_clipboard': 'جای‌گذاری از کلیپ‌بورد',
    'scan_qr': 'اسکن کد QR',
    'import_uri_hint': 'لینک vless://، vmess://، trojan://، ss://، hy2://، tuic://، wireguard:// یا لینک سابسکریپشن را وارد کنید',
    'import_action': 'اعتبارسنجی و افزودن',
    'compatibility_ok': 'تمامی پارامترها برای موتور sing-box تایید شدند',
    'no_servers': 'هنوز هیچ سروری اضافه نشده است',
    'no_subscriptions': 'هیچ لینک سابسکریپشنی ثبت نشده است',
    'run_diagnostics': 'اجرای تست چندمعیاره',
    'start_speed_test': 'شروع بنچمارک سرعت',
    'engine_primary': 'موتور اصلی (sing-box)',
    'engine_fallback': 'موتور مکمل (Xray-core)',
    'kill_switch': 'کیل‌سوئیچ سخت‌گیرانه',
    'leak_protection': 'محافظ نشت DNS و IPv6',
    'ipv6_support': 'پشتیبانی دوپشته IPv6',
    'language': 'زبان رابط کاربری',
    'clear_logs': 'پاک‌سازی لاگ‌ها',
    'redaction_active': 'اطلاعات حساس (UUID و کلیدها) به‌صورت خودکار سانسور می‌شوند',
  };
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'fa'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
""",

    "lib/domain/models/vpn_models.dart": """enum TunnelStatus { disconnected, connecting, connected, reconnecting, disconnecting }

enum VpnProtocol {
  vlessReality,
  vlessTls,
  vlessRaw,
  vmess,
  trojan,
  shadowsocks,
  hysteria2,
  tuic,
  wireguard,
}

enum EngineType { singBox, xrayCore }

enum RoutingMode { proxyAll, bypassLanAndDomestic, perAppInclude, perAppExclude }

class CompatibilityIssue {
  final String field;
  final String message;
  final bool isFatal;

  const CompatibilityIssue({
    required this.field,
    required this.message,
    this.isFatal = false,
  });
}

class ServerProfile {
  final String id;
  final String name;
  final String address;
  final int port;
  final VpnProtocol protocol;
  final String transport;
  final String security;
  final String countryCode;
  final String? subscriptionId;
  final EngineType preferredEngine;
  final int? latencyMs;
  final double? compositeScore;
  final List<CompatibilityIssue> compatibilityIssues;
  final Map<String, dynamic> protocolConfig;

  const ServerProfile({
    required this.id,
    required this.name,
    required this.address,
    required this.port,
    required this.protocol,
    required this.transport,
    required this.security,
    this.countryCode = 'DE',
    this.subscriptionId,
    this.preferredEngine = EngineType.singBox,
    this.latencyMs,
    this.compositeScore,
    this.compatibilityIssues = const [],
    this.protocolConfig = const {},
  });

  bool get hasFatalIssues => compatibilityIssues.any((e) => e.isFatal);
}

class SubscriptionFeed {
  final String id;
  final String title;
  final String url;
  final int usedBytes;
  final int totalBytes;
  final DateTime? expiresAt;
  final DateTime lastUpdated;
  final Duration autoUpdateInterval;
  final int nodeCount;

  const SubscriptionFeed({
    required this.id,
    required this.title,
    required this.url,
    required this.usedBytes,
    required this.totalBytes,
    required this.lastUpdated,
    this.expiresAt,
    this.autoUpdateInterval = const Duration(hours: 6),
    this.nodeCount = 0,
  });

  double get usageRatio => totalBytes <= 0 ? 0.0 : (usedBytes / totalBytes).clamp(0.0, 1.0);
}

class ConnectionTelemetry {
  final TunnelStatus status;
  final ServerProfile? activeServer;
  final EngineType activeEngine;
  final int pingMs;
  final int downloadBps;
  final int uploadBps;
  final int sessionRxBytes;
  final int sessionTxBytes;
  final Duration connectedDuration;
  final String? lastError;

  const ConnectionTelemetry({
    this.status = TunnelStatus.disconnected,
    this.activeServer,
    this.activeEngine = EngineType.singBox,
    this.pingMs = 0,
    this.downloadBps = 0,
    this.uploadBps = 0,
    this.sessionRxBytes = 0,
    this.sessionTxBytes = 0,
    this.connectedDuration = Duration.zero,
    this.lastError,
  });
}

class ServerScoreBreakdown {
  final double latencyContribution;
  final double jitterContribution;
  final double packetLossContribution;
  final double handshakeContribution;
  final double downloadContribution;
  final double uploadContribution;
  final double reliabilityContribution;

  const ServerScoreBreakdown({
    required this.latencyContribution,
    required this.jitterContribution,
    required this.packetLossContribution,
    required this.handshakeContribution,
    required this.downloadContribution,
    required this.uploadContribution,
    required this.reliabilityContribution,
  });

  double get totalScore => (latencyContribution +
          jitterContribution +
          packetLossContribution +
          handshakeContribution +
          downloadContribution +
          uploadContribution +
          reliabilityContribution)
      .clamp(0.0, 1.0);
}

class NodeDiagnosticMetrics {
  final String serverId;
  final int rttMs;
  final double jitterMs;
  final double packetLossPercent;
  final int handshakeMs;
  final double downloadMbps;
  final double uploadMbps;
  final double historicalReliability;
  final double weightedScore;
  final ServerScoreBreakdown breakdown;
  final DateTime measuredAt;

  const NodeDiagnosticMetrics({
    required this.serverId,
    required this.rttMs,
    required this.jitterMs,
    required this.packetLossPercent,
    required this.handshakeMs,
    this.downloadMbps = 0.0,
    this.uploadMbps = 0.0,
    required this.historicalReliability,
    required this.weightedScore,
    required this.breakdown,
    required this.measuredAt,
  });

  bool isExpired(Duration ttl) => DateTime.now().difference(measuredAt) > ttl;
}

class SpeedBenchmarkState {
  final bool isRunning;
  final double progress;
  final int pingMs;
  final double jitterMs;
  final double downloadMbps;
  final double uploadMbps;

  const SpeedBenchmarkState({
    this.isRunning = false,
    this.progress = 0.0,
    this.pingMs = 0,
    this.jitterMs = 0.0,
    this.downloadMbps = 0.0,
    this.uploadMbps = 0.0,
  });
}

class AppRoutingEntry {
  final String packageName;
  final String label;
  final bool routedThroughVpn;
  final bool isSystemApp;

  const AppRoutingEntry({
    required this.packageName,
    required this.label,
    required this.routedThroughVpn,
    this.isSystemApp = false,
  });
}

class LogEntry {
  final DateTime timestamp;
  final String level;
  final String source;
  final String message;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
  });
}

class EnginePreferences {
  final EngineType preferredEngine;
  final bool autoSelectServer;
  final bool killSwitchEnabled;
  final bool leakProtectionEnabled;
  final bool ipv6Enabled;
  final String primaryDns;
  final int mtu;
  final RoutingMode routingMode;

  const EnginePreferences({
    this.preferredEngine = EngineType.singBox,
    this.autoSelectServer = true,
    this.killSwitc
