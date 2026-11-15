import 'dart:convert';
import 'package:http/http.dart' as http;

class VpnServer {
  final String id;
  String name;
  final String protocol;
  final String rawUri;
  final String? subId;
  int pingMs;

  VpnServer({
    required this.id,
    required this.name,
    required this.protocol,
    required this.rawUri,
    this.subId,
    this.pingMs = -1,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'protocol': protocol,
        'rawUri': rawUri,
        'subId': subId,
        'pingMs': pingMs,
      };

  factory VpnServer.fromJson(Map<String, dynamic> j) => VpnServer(
        id: j['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: j['name'] ?? 'OTared Server',
        protocol: j['protocol'] ?? 'VLESS',
        rawUri: j['rawUri'] ?? '',
        subId: j['subId'],
        pingMs: j['pingMs'] ?? -1,
      );
}

class VpnSubscription {
  final String id;
  String title;
  String url;
  int usedBytes;
  int totalBytes;
  int expireTimestamp;
  DateTime updatedAt;

  VpnSubscription({
    required this.id,
    required this.title,
    required this.url,
    this.usedBytes = 0,
    this.totalBytes = 0,
    this.expireTimestamp = 0,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'usedBytes': usedBytes,
        'totalBytes': totalBytes,
        'expireTimestamp': expireTimestamp,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory VpnSubscription.fromJson(Map<String, dynamic> j) => VpnSubscription(
        id: j['id'],
        title: j['title'],
        url: j['url'],
        usedBytes: j['usedBytes'] ?? 0,
        totalBytes: j['totalBytes'] ?? 0,
        expireTimestamp: j['expireTimestamp'] ?? 0,
        updatedAt: DateTime.tryParse(j['updatedAt'] ?? '') ?? DateTime.now(),
      );
}

class SanaeiEngine {
  static String _decodeBase64(String input) {
    var norm = input.trim().replaceAll('-', '+').replaceAll('_', '/');
    final rem = norm.length % 4;
    if (rem > 0) norm += '=' * (4 - rem);
    return utf8.decode(base64.decode(norm), allowMalformed: true);
  }

  static List<VpnServer> parseAnyFormat(String raw, {String? subId}) {
    var content = raw.trim();
    if (content.isEmpty) return [];

    // 1. پشتیبانی از فرمت JSON مستقیم پنل سنایی (3x-ui JSON Subscription)
    if (content.startsWith('[') || content.startsWith('{')) {
      try {
        final decoded = jsonDecode(content);
        final list = decoded is List ? decoded : [decoded];
        final servers = <VpnServer>[];
        for (var i = 0; i < list.length; i++) {
          final item = list[i];
          if (item is Map<String, dynamic>) {
            final remarks = item['remarks']?.toString() ?? 'OTared JSON #${i + 1}';
            servers.add(VpnServer(
              id: '${DateTime.now().microsecondsSinceEpoch}_$i',
              name: remarks,
              protocol: 'XRAY-JSON',
              rawUri: jsonEncode(item),
              subId: subId,
            ));
          }
        }
        if (servers.isNotEmpty) return servers;
      } catch (_) {}
    }

    // 2. پشتیبانی از Base64 استاندارد و URL-Safe سنایی
    if (!content.contains('://')) {
      try {
        content = _decodeBase64(content);
      } catch (_) {}
    }

    // 3. پشتیبانی از لینک‌های چندخطی (VLESS, VMess, Trojan, SS, HY2, TUIC, WG)
    final lines = content
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.contains('://') && !e.startsWith('#'))
        .toList();

    final results = <VpnServer>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final proto = line.split('://').first.toUpperCase();
      String remark = 'OTared $proto #${i + 1}';

      if (proto == 'VMESS') {
        try {
          final b64 = line.substring(8).split('#').first;
          final vmessMap = jsonDecode(_decodeBase64(b64));
          if (vmessMap is Map && vmessMap['ps'] != null && vmessMap['ps'].toString().isNotEmpty) {
            remark = vmessMap['ps'].toString();
          }
        } catch (_) {}
      }
      final hashIdx = line.indexOf('#');
      if (hashIdx != -1 && hashIdx + 1 < line.length) {
        try {
          remark = Uri.decodeComponent(line.substring(hashIdx + 1));
        } catch (_) {
          remark = line.substring(hashIdx + 1);
        }
      }

      results.add(VpnServer(
        id: '${DateTime.now().microsecondsSinceEpoch}_$i',
        name: remark,
        protocol: proto,
        rawUri: line,
        subId: subId,
      ));
    }
    return results;
  }

  static Future<(VpnSubscription, List<VpnServer>)> fetchSubscription(VpnSubscription sub) async {
    final res = await http.get(
      Uri.parse(sub.url.trim()),
      headers: {'User-Agent': 'OTaredVPN/2.0 (v2rayNG; Hiddify; 3x-ui)'},
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }

    // استخراج هدر حجم و تاریخ انقضای سنایی (subscription-userinfo)
    final userInfo = res.headers['subscription-userinfo'] ?? '';
    int upload = 0, download = 0, total = 0, expire = 0;
    for (final part in userInfo.split(';')) {
      final kv = part.trim().split('=');
      if (kv.length == 2) {
        final val = int.tryParse(kv[1].trim()) ?? 0;
        switch (kv[0].trim().toLowerCase()) {
          case 'upload':
            upload = val;
            break;
          case 'download':
            download = val;
            break;
          case 'total':
            total = val;
            break;
          case 'expire':
            expire = val;
            break;
        }
      }
    }

    final titleHeader = res.headers['profile-title'];
    if (titleHeader != null && titleHeader.isNotEmpty) {
      sub.title = titleHeader.startsWith('base64:')
          ? _decodeBase64(titleHeader.substring(7))
          : Uri.decodeComponent(titleHeader);
    }

    sub.usedBytes = upload + download;
    sub.totalBytes = total;
    sub.expireTimestamp = expire;
    sub.updatedAt = DateTime.now();

    final servers = parseAnyFormat(res.body, subId: sub.id);
    return (sub, servers);
  }
}
