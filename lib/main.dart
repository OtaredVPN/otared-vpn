import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sanaei_engine.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OTaredRootApp());
}

class OTaredRootApp extends StatefulWidget {
  const OTaredRootApp({super.key});
  @override
  State<OTaredRootApp> createState() => _OTaredRootAppState();
}

class _OTaredRootAppState extends State<OTaredRootApp> {
  bool _darkMode = true;
  bool _isFa = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OTaredVPN',
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF07090B),
        cardColor: const Color(0xFF0F1318),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF14B88A),
          secondary: Color(0xFFD0D7DE),
          surface: Color(0xFF0F1318),
        ),
      ),
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF4F6F8),
        cardColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0D946E),
          secondary: Color(0xFF334155),
          surface: Colors.white,
        ),
      ),
      home: OTaredHomeScreen(
        darkMode: _darkMode,
        isFa: _isFa,
        onToggleTheme: () => setState(() => _darkMode = !_darkMode),
        onToggleLang: () => setState(() => _isFa = !_isFa),
      ),
    );
  }
}

class OTaredHomeScreen extends StatefulWidget {
  final bool darkMode;
  final bool isFa;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleLang;

  const OTaredHomeScreen({
    super.key,
    required this.darkMode,
    required this.isFa,
    required this.onToggleTheme,
    required this.onToggleLang,
  });

  @override
  State<OTaredHomeScreen> createState() => _OTaredHomeScreenState();
}

class _OTaredHomeScreenState extends State<OTaredHomeScreen> {
  late final FlutterV2ray _v2ray;
  V2RayStatus _status = V2RayStatus();
  int _tabIndex = 0;
  bool _proMode = true;
  bool _testingPing = false;

  List<VpnServer> _servers = [];
  List<VpnSubscription> _subs = [];
  String? _selectedId;
  final List<String> _logs = ['[OTaredCore] Dual-Core Engine Ready'];

  String _routingMode = 'bypass_ir';
  String _dnsServer = 'https://1.1.1.1/dns-query';
  bool _enableFragment = true;
  bool _enableMux = true;
  bool _enableIpv6 = false;
  final int _socksPort = 10808;
  final int _httpPort = 10809;
  String _blockedApps = '';
  final List<double> _speedHistory = List.filled(20, 0.0, growable: true);

  String t(String fa, String en) => widget.isFa ? fa : en;

  @override
  void initState() {
    super.initState();
    _v2ray = FlutterV2ray(
      onStatusChanged: (status) {
        if (!mounted) return;
        setState(() {
          _status = status;
          final mbps = (status.downloadSpeed + status.uploadSpeed) / (1024 * 128);
          _speedHistory.removeAt(0);
          _speedHistory.add(mbps.clamp(0.0, 100.0));
        });
      },
    );
    _initEngine();
  }

  Future<void> _initEngine() async {
    await _v2ray.initializeV2Ray(
      notificationIconResourceType: 'mipmap',
      notificationIconResourceName: 'ic_launcher',
    );
    final prefs = await SharedPreferences.getInstance();
    final srvRaw = prefs.getString('otared_servers');
    final subRaw = prefs.getString('otared_subs');
    if (srvRaw != null) {
      _servers = (jsonDecode(srvRaw) as List).map((e) => VpnServer.fromJson(e)).toList();
    }
    if (subRaw != null) {
      _subs = (jsonDecode(subRaw) as List).map((e) => VpnSubscription.fromJson(e)).toList();
    }
    _selectedId = prefs.getString('otared_selected') ?? (_servers.isNotEmpty ? _servers.first.id : null);
    _routingMode = prefs.getString('otared_routing') ?? 'bypass_ir';
    _dnsServer = prefs.getString('otared_dns') ?? 'https://1.1.1.1/dns-query';
    _enableFragment = prefs.getBool('otared_frag') ?? true;
    _enableMux = prefs.getBool('otared_mux') ?? true;
    _blockedApps = prefs.getString('otared_apps') ?? '';
    if (mounted) setState(() {});
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('otared_servers', jsonEncode(_servers.map((e) => e.toJson()).toList()));
    await prefs.setString('otared_subs', jsonEncode(_subs.map((e) => e.toJson()).toList()));
    if (_selectedId != null) await prefs.setString('otared_selected', _selectedId!);
    await prefs.setString('otared_routing', _routingMode);
    await prefs.setString('otared_dns', _dnsServer);
    await prefs.setBool('otared_frag', _enableFragment);
    await prefs.setBool('otared_mux', _enableMux);
    await prefs.setString('otared_apps', _blockedApps);
  }

  void _log(String msg) {
    if (!mounted) return;
    setState(() {
      _logs.insert(0, '[${TimeOfDay.now().format(context)}] $msg');
      if (_logs.length > 80) _logs.removeLast();
    });
  }

  String _compileOptimizedXrayConfig(VpnServer srv) {
    String baseJson;
    if (srv.rawUri.trim().startsWith('{')) {
      baseJson = srv.rawUri;
    } else {
      final parsed = FlutterV2ray.parseFromURL(srv.rawUri);
      baseJson = parsed.getFullConfiguration();
    }
    final cfg = jsonDecode(baseJson) as Map<String, dynamic>;
    cfg['dns'] = {'servers': [_dnsServer, '8.8.8.8', 'localhost']};
    cfg['inbounds'] = [
      {
        'tag': 'socks',
        'port': _socksPort,
        'listen': '127.0.0.1',
        'protocol': 'socks',
        'settings': {'auth': 'noauth', 'udp': true},
        'sniffing': {'enabled': true, 'destOverride': ['http', 'tls', 'quic']}
      },
      {'tag': 'http', 'port': _httpPort, 'listen': '127.0.0.1', 'protocol': 'http'}
    ];
    final outbounds = (cfg['outbounds'] as List?) ?? [];
    if (outbounds.isNotEmpty && outbounds[0] is Map<String, dynamic>) {
      final proxyOut = outbounds[0] as Map<String, dynamic>;
      if (_enableMux && srv.protocol != 'HY2' && srv.protocol != 'HYSTERIA2') {
        proxyOut['mux'] = {'enabled': true, 'concurrency': 8, 'xudpConcurrency': 8};
      }
      if (_enableFragment) {
        outbounds.add({
          'tag': 'fragment',
          'protocol': 'freedom',
          'settings': {'fragment': {'packets': 'tlshello', 'length': '10-20', 'interval': '10-20'}}
        });
        final stream = (proxyOut['streamSettings'] as Map<String, dynamic>?) ?? {};
        stream['sockopt'] = {'dialerProxy': 'fragment', 'tcpFastOpen': true};
        proxyOut['streamSettings'] = stream;
      }
    }
    final rules = >[
      {'type': 'field', 'outboundTag': 'block', 'domain': ['geosite:category-ads-all']},
    ];
    if (_routingMode == 'bypass_ir') {
      rules.add({'type': 'field', 'outboundTag': 'direct', 'domain': ['geosite:ir', 'regexp:.*\\.ir\$']});
      rules.add({'type': 'field', 'outboundTag': 'direct', 'ip': ['geoip:ir', 'geoip:private']});
    } else if (_routingMode == 'direct') {
      rules.add({'type': 'field', 'outboundTag': 'direct', 'port': '0-65535'});
    }
    cfg['routing'] = {'domainStrategy': 'IPIfNonMatch', 'rules': rules};
    return jsonEncode(cfg);
  }
    Future<void> _toggleVpn() async {
    if (_status.state == 'CONNECTED') {
      await _v2ray.stopV2Ray();
      _log('Disconnected.');
      return;
    }
    if (_servers.isEmpty) {
      _openImportModal();
      return;
    }
    final srv = _servers.firstWhere((e) => e.id == _selectedId, orElse: () => _servers.first);
    if (await _v2ray.requestPermission()) {
      final fullConfig = _compileOptimizedXrayConfig(srv);
      final blockedList = _blockedApps.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      _log('Connecting to ${srv.name} (${srv.protocol})...');
      await _v2ray.startV2Ray(
        remark: 'OTaredVPN - ${srv.name}',
        config: fullConfig,
        blockedApps: blockedList.isEmpty ? null : blockedList,
        bypassSubnets: _routingMode == 'bypass_ir' ? ['10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16'] : null,
        proxyOnly: false,
      );
    } else {
      _log('VPN permission denied.');
    }
  }

  Future<void> _testSinglePing(VpnServer srv) async {
    setState(() => srv.pingMs = -2);
    try {
      final cfg = _compileOptimizedXrayConfig(srv);
      final delay = await _v2ray.getServerDelay(config: cfg);
      setState(() => srv.pingMs = delay);
      _log('Ping [${srv.name}]: ${delay}ms');
    } catch (_) {
      setState(() => srv.pingMs = -1);
    }
    _saveState();
  }

  Future<void> _smartSelectFastest() async {
    if (_servers.isEmpty || _testingPing) return;
    setState(() => _testingPing = true);
    VpnServer? best;
    for (final s in _servers) {
      await _testSinglePing(s);
      if (s.pingMs > 0 && (best == null || s.pingMs < best.pingMs)) best = s;
    }
    if (best != null) {
      setState(() => _selectedId = best!.id);
      _log('Smart Selected: ${best.name} (${best.pingMs}ms)');
    }
    setState(() => _testingPing = false);
    _saveState();
  }

  Future<void> _importRawText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final sub = VpnSubscription(id: DateTime.now().millisecondsSinceEpoch.toString(), title: 'OTared 3x-ui', url: trimmed);
      try {
        final (updatedSub, newServers) = await SanaeiEngine.fetchSubscription(sub);
        setState(() {
          _subs.add(updatedSub);
          _servers.addAll(newServers);
          if (_selectedId == null && _servers.isNotEmpty) _selectedId = _servers.first.id;
        });
        _log('Synced ${newServers.length} nodes.');
      } catch (e) {
        _log('Sub error: $e');
      }
    } else {
      final parsed = SanaeiEngine.parseAnyFormat(trimmed);
      setState(() {
        _servers.addAll(parsed);
        if (_selectedId == null && _servers.isNotEmpty) _selectedId = _servers.first.id;
      });
      _log('Added ${parsed.length} server(s).');
    }
    await _saveState();
  }

  void _openQrScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(title: Text(t('اسکن QR سنایی', 'Scan QR'))),
          body: MobileScanner(
            onDetect: (capture) {
              final code = capture.barcodes.firstOrNull?.rawValue;
              if (code != null && code.isNotEmpty) {
                Navigator.pop(ctx);
                _importRawText(code);
              }
            },
          ),
        ),
      ),
    );
  }

  void _openImportModal() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t('افزودن کانفیگ / لینک ساب سنایی', 'Import 3x-ui Config / Sub'), style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 12),
            TextField(controller: ctrl, maxLines: 4, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'), decoration: InputDecoration(hintText: 'https://sub... | vless:// | vmess:// | JSON', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(onPressed: () async { final d = await Clipboard.getData(Clipboard.kTextPlain); if (d?.text != null) ctrl.text = d!.text!; }, icon: const Icon(Icons.paste_rounded, size: 18), label: Text(t('کلیپ‌بورد', 'Paste')))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(onPressed: () { Navigator.pop(ctx); _openQrScanner(); }, icon: const Icon(Icons.qr_code_scanner, size: 18), label: const Text('QR'))),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF14B88A), foregroundColor: Colors.black), onPressed: () { Navigator.pop(ctx); _importRawText(ctrl.text); }, child: Text(t('ثبت', 'Add')))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var val = bytes.toDouble();
    var idx = 0;
    while (val >= 1024 && idx < units.length - 1) { val /= 1024; idx++; }
    return '${val.toStringAsFixed(2)} ${units[idx]}';
  }
    @override
  Widget build(BuildContext context) {
    final isConnected = _status.state == 'CONNECTED';
    final accent = Theme.of(context).colorScheme.primary;
    final activeSrv = _servers.where((e) => e.id == _selectedId).firstOrNull ?? _servers.firstOrNull;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(children: [
          Image.asset('assets/logo.png', width: 28, height: 28, errorBuilder: (_, __, ___) => Icon(Icons.shield, color: accent)),
          const SizedBox(width: 10),
          const Text('OTaredVPN', style: TextStyle(fontWeight: FontWeight.w200, letterSpacing: 3.2, fontSize: 19)),
        ]),
        actions: [
          IconButton(onPressed: () => setState(() => _proMode = !_proMode), icon: Icon(_proMode ? Icons.tune_rounded : Icons.spa_outlined, size: 20, color: accent)),
          IconButton(onPressed: widget.onToggleLang, icon: Text(widget.isFa ? 'EN' : 'فا', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
          IconButton(onPressed: widget.onToggleTheme, icon: Icon(widget.darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 20)),
        ],
      ),
      body: IndexedStack(index: _tabIndex, children: [_buildDashboardTab(isConnected, accent, activeSrv), _buildServersTab(accent), _buildAnalyticsTab(accent), _buildSettingsTab(accent)]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        height: 62,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.power_settings_new_rounded), label: t('اتصال', 'Connect')),
          NavigationDestination(icon: const Icon(Icons.dns_outlined), label: t('سرورها', 'Nodes')),
          NavigationDestination(icon: const Icon(Icons.show_chart_rounded), label: t('آنالیز', 'Analytics')),
          NavigationDestination(icon: const Icon(Icons.settings_outlined), label: t('تنظیمات', 'Settings')),
        ],
      ),
    );
  }

  Widget _buildDashboardTab(bool isConnected, Color accent, VpnServer? activeSrv) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: isConnected ? accent : Colors.grey.withOpacity(0.3))), child: Text(isConnected ? t('تونل فعال است', 'ACTIVE') : t('آماده اتصال', 'STANDBY'), style: TextStyle(fontSize: 11, color: isConnected ? accent : Colors.grey))),
          TextButton.icon(onPressed: _testingPing ? null : _smartSelectFastest, icon: Icon(Icons.bolt_rounded, size: 18, color: accent), label: Text(_testingPing ? '...' : t('سریع‌ترین', 'Smart'), style: TextStyle(fontSize: 12, color: accent))),
        ]),
        const Spacer(),
        GestureDetector(
          onTap: _toggleVpn,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            width: 184,
            height: 184,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).cardColor, border: Border.all(color: isConnected ? accent : Colors.grey.withOpacity(0.3), width: 1.8), boxShadow: isConnected ? [BoxShadow(color: accent.withOpacity(0.28), blurRadius: 36)] : []),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.power_settings_new_rounded, size: 48, color: isConnected ? accent : Colors.grey),
              const SizedBox(height: 8),
              Text(isConnected ? _status.duration : 'OTaredVPN', style: TextStyle(fontWeight: FontWeight.w200, letterSpacing: 2.5, fontSize: 12, color: isConnected ? accent : Colors.grey)),
            ]),
          ),
        ),
        const SizedBox(height: 24),
        if (_proMode) Row(children: [_statCard(t('دانلود', 'DOWN'), '${_formatBytes(_status.downloadSpeed)}/s', accent), const SizedBox(width: 10), _statCard(t('آپلود', 'UP'), '${_formatBytes(_status.uploadSpeed)}/s', Colors.blueGrey)]),
        const Spacer(),
        InkWell(
          onTap: () => setState(() => _tabIndex = 1),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.withOpacity(0.18))),
            child: Row(children: [
              Icon(Icons.security_rounded, color: accent),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(activeSrv?.name ?? t('سروری انتخاب نشده', 'No Server'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                Text(activeSrv != null ? '${activeSrv.protocol} • ${activeSrv.pingMs > 0 ? "${activeSrv.pingMs}ms" : "Ready"}' : t('افزودن کانفیگ سنایی', 'Tap to add'), style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ])),
              IconButton(onPressed: _openImportModal, icon: Icon(Icons.add_circle_outline, color: accent)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _statCard(String title, String value, Color color) => Expanded(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)), const SizedBox(height: 4), Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color))])));

  Widget _buildServersTab(Color accent) {
    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black), onPressed: _openImportModal, icon: const Icon(Icons.add, size: 18), label: Text(t('افزودن', 'Add')))),
        const SizedBox(width: 8),
        OutlinedButton.icon(onPressed: _openQrScanner, icon: const Icon(Icons.qr_code_scanner, size: 18), label: const Text('QR')),
        const SizedBox(width: 8),
        OutlinedButton.icon(onPressed: _testingPing ? null : _smartSelectFastest, icon: const Icon(Icons.speed, size: 18), label: Text(t('پینگ', 'Ping'))),
      ])),
      if (_subs.isNotEmpty) SizedBox(height: 74, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), itemCount: _subs.length, itemBuilder: (ctx, i) {
        final sub = _subs[i];
        final ratio = sub.totalBytes > 0 ? (sub.usedBytes / sub.totalBytes).clamp(0.0, 1.0) : 0.0;
        return Container(width: 230, margin: const EdgeInsets.only(right: 10), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: accent.withOpacity(0.35))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(sub.title, maxLines: 1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))), InkWell(onTap: () async { _servers.removeWhere((s) => s.subId == sub.id); final (upd, list) = await SanaeiEngine.fetchSubscription(sub); setState(() { _subs[i] = upd; _servers.addAll(list); }); _saveState(); }, child: Icon(Icons.refresh, size: 16, color: accent))]),
          const Spacer(),
          LinearProgressIndicator(value: ratio, minHeight: 4, color: accent),
          Text('${_formatBytes(sub.usedBytes)} / ${sub.totalBytes > 0 ? _formatBytes(sub.totalBytes) : "∞"}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ]));
      })),
      Expanded(child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: _servers.length, itemBuilder: (ctx, i) {
        final s = _servers[i];
        return Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: s.id == _selectedId ? accent : Colors.transparent)), child: ListTile(
          onTap: () { setState(() => _selectedId = s.id); _saveState(); },
          title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          subtitle: Text(s.protocol, style: TextStyle(fontSize: 11, color: accent)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            TextButton(onPressed: () => _testSinglePing(s), child: Text(s.pingMs == -2 ? '...' : (s.pingMs > 0 ? '${s.pingMs}ms' : 'Ping'), style: TextStyle(color: s.pingMs > 0 ? accent : Colors.grey, fontSize: 12))),
            IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent), onPressed: () { setState(() => _servers.removeAt(i)); _saveState(); }),
          ]),
        ));
      })),
    ]);
  }

  Widget _buildAnalyticsTab(Color accent) {
    return Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [_statCard(t('کل دانلود', 'DOWN'), _formatBytes(_status.download), accent), const SizedBox(width: 10), _statCard(t('کل آپلود', 'UP'), _formatBytes(_status.upload), Colors.amber)]),
      const SizedBox(height: 12),
      Container(height: 110, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)), child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: _speedHistory.map((v) => Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 2), height: (v * 2.5).clamp(4.0, 75.0), decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(3))))).toList())),
      const SizedBox(height: 12),
      Expanded(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14)), child: ListView.builder(itemCount: _logs.length, itemBuilder: (_, i) => Text(_logs[i], style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))))),
    ]));
  }

  Widget _buildSettingsTab(Color accent) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      ListTile(title: Text(t('مسیریابی', 'Routing')), trailing: DropdownButton<String>(value: _routingMode, items: [DropdownMenuItem(value: 'bypass_ir', child: Text(t('دور زدن ایران', 'Bypass IR'))), DropdownMenuItem(value: 'global', child: Text(t('پروکسی کامل', 'Global'))), DropdownMenuItem(value: 'direct', child: Text(t('مستقیم', 'Direct')))], onChanged: (v) { if (v != null) setState(() => _routingMode = v); _saveState(); })),
      ListTile(title: const Text('DNS'), trailing: DropdownButton<String>(value: _dnsServer, items: const [DropdownMenuItem(value: 'https://1.1.1.1/dns-query', child: Text('1.1.1.1 DoH')), DropdownMenuItem(value: 'https://dns.google/dns-query', child: Text('Google DoH')), DropdownMenuItem(value: '1.1.1.1', child: Text('UDP 1.1.1.1'))], onChanged: (v) { if (v != null) setState(() => _dnsServer = v); _saveState(); })),
      SwitchListTile(activeColor: accent, title: const Text('TLS Fragment'), value: _enableFragment, onChanged: (v) { setState(() => _enableFragment = v); _saveState(); }),
      SwitchListTile(activeColor: accent, title: const Text('Multiplexing (Mux)'), value: _enableMux, onChanged: (v) { setState(() => _enableMux = v); _saveState(); }),
      SwitchListTile(activeColor: accent, title: const Text('IPv6'), value: _enableIpv6, onChanged: (v) => setState(() => _enableIpv6 = v)),
      ListTile(title: Text(t('پروکسی محلی', 'Local Proxy')), subtitle: Text('SOCKS5: 127.0.0.1:$_socksPort | HTTP: 127.0.0.1:$_httpPort')),
      TextField(controller: TextEditingController(text: _blockedApps), decoration: InputDecoration(labelText: t('استثنا کردن برنامه‌ها (Split Tunneling)', 'Bypass Apps'), hintText: 'ir.nasim, com.app'), onChanged: (v) { _blockedApps = v; _saveState(); }),
    ]);
  }
}
