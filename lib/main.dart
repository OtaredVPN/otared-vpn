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
      title: 'OTARED VPN',
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF07090B),
        cardColor: const Color(0xFF0F1318),
        colorScheme: const ColorScheme.dark(primary: Color(0xFF14B88A), surface: Color(0xFF0F1318)),
      ),
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF4F6F8),
        cardColor: Colors.white,
        colorScheme: const ColorScheme.light(primary: Color(0xFF0D946E), surface: Colors.white),
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

  const OTaredHomeScreen({super.key, required this.darkMode, required this.isFa, required this.onToggleTheme, required this.onToggleLang});

  @override
  State<OTaredHomeScreen> createState() => _OTaredHomeScreenState();
}

class _OTaredHomeScreenState extends State<OTaredHomeScreen> with SingleTickerProviderStateMixin {
  late final FlutterV2ray _v2ray;
  V2RayStatus _status = V2RayStatus();
  int _tabIndex = 0;
  bool _proMode = true;
  bool _testingPing = false;

  List<VpnServer> _servers = [];
  List<VpnSubscription> _subs = [];
  String? _selectedId;
  final List<String> _logs = ['[OTARED Core] Initialized'];

  String _routingMode = 'global';
  String _dnsServer = 'https://1.1.1.1/dns-query';
  bool _enableFragment = false;
  bool _enableMux = false;
  bool _enableIpv6 = false;
  final int _socksPort = 10808;
  final int _httpPort = 10809;
  String _blockedApps = '';
  final List<double> _speedHistory = List.filled(20, 0.0, growable: true);

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String t(String fa, String en) => widget.isFa ? fa : en;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _v2ray = FlutterV2ray(onStatusChanged: (status) {
      if (!mounted) return;
      setState(() {
        _status = status;
        final mbps = (status.downloadSpeed + status.uploadSpeed) / (1024 * 128);
        _speedHistory.removeAt(0);
        _speedHistory.add(mbps.clamp(0.0, 100.0));
      });
    });
    _initEngine();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initEngine() async {
    await _v2ray.initializeV2Ray(notificationIconResourceType: 'mipmap', notificationIconResourceName: 'ic_launcher');
    final prefs = await SharedPreferences.getInstance();
    final srvRaw = prefs.getString('otared_servers');
    final subRaw = prefs.getString('otared_subs');
    if (srvRaw != null) _servers = (jsonDecode(srvRaw) as List).map((e) => VpnServer.fromJson(e)).toList();
    if (subRaw != null) _subs = (jsonDecode(subRaw) as List).map((e) => VpnSubscription.fromJson(e)).toList();
    _selectedId = prefs.getString('otared_selected') ?? (_servers.isNotEmpty ? _servers.first.id : null);
    _routingMode = prefs.getString('otared_routing') ?? 'global';
    _dnsServer = prefs.getString('otared_dns') ?? 'https://1.1.1.1/dns-query';
    if (mounted) setState(() {});
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('otared_servers', jsonEncode(_servers.map((e) => e.toJson()).toList()));
    await prefs.setString('otared_subs', jsonEncode(_subs.map((e) => e.toJson()).toList()));
    if (_selectedId != null) await prefs.setString('otared_selected', _selectedId!);
  }

  void _log(String msg) {
    if (!mounted) return;
    setState(() {
      _logs.insert(0, '[${TimeOfDay.now().format(context)}] $msg');
      if (_logs.length > 50) _logs.removeLast();
    });
  }

  String _buildConfig(VpnServer srv) {
    final rawConfig = srv.rawUri.trim().startsWith('{') ? srv.rawUri : FlutterV2ray.parseFromURL(srv.rawUri).getFullConfiguration();
    try {
      final cfg = jsonDecode(rawConfig) as Map<String, dynamic>;
      cfg['inbounds'] = [
        {'tag': 'socks-inbound', 'port': _socksPort, 'listen': '127.0.0.1', 'protocol': 'socks', 'settings': {'auth': 'noauth', 'udp': true}},
        {'tag': 'http-inbound', 'port': _httpPort, 'listen': '127.0.0.1', 'protocol': 'http', 'settings': {}}
      ];
      cfg['dns'] = {'servers': [_dnsServer, '8.8.8.8', '1.1.1.1']};
      cfg['routing'] = {'domainStrategy': 'IPOnDemand', 'rules': [{'type': 'field', 'outboundTag': 'proxy', 'ip': ['geoip:private']}]};
      return jsonEncode(cfg);
    } catch (e) {
      return rawConfig;
    }
  }

  Future<void> _toggleVpn() async {
    try {
      if (_status.state == 'CONNECTED') { await _v2ray.stopV2Ray(); return; }
      if (_servers.isEmpty) { _openImportModal(); return; }
      final srv = _servers.firstWhere((e) => e.id == _selectedId, orElse: () => _servers.first);
      if (!await _v2ray.requestPermission()) return;
      await _v2ray.startV2Ray(remark: 'OTARED - ${srv.name}', config: _buildConfig(srv), proxyOnly: false);
    } catch (e) { _log('ERROR: $e'); }
  }
    Future<void> _testSinglePing(VpnServer srv) async {
    setState(() => srv.pingMs = -2);
    try {
      srv.pingMs = await _v2ray.getServerDelay(config: _buildConfig(srv));
    } catch (e) { srv.pingMs = -1; }
    setState(() {});
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
    if (best != null) setState(() => _selectedId = best.id);
    setState(() => _testingPing = false);
    _saveState();
  }

  Future<void> _importRawText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final sub = VpnSubscription(id: DateTime.now().millisecondsSinceEpoch.toString(), title: 'OTARED Sub', url: trimmed);
      try {
        final (updatedSub, newServers) = await SanaeiEngine.fetchSubscription(sub);
        setState(() { _subs.add(updatedSub); _servers.addAll(newServers); if (_selectedId == null && _servers.isNotEmpty) _selectedId = _servers.first.id; });
      } catch (e) { _log('Sub error: $e'); }
    } else {
      final parsed = SanaeiEngine.parseAnyFormat(trimmed);
      setState(() { _servers.addAll(parsed); if (_selectedId == null && _servers.isNotEmpty) _selectedId = _servers.first.id; });
    }
    await _saveState();
  }

  void _openQrScanner() {
    Navigator.push(context, MaterialPageRoute(builder: (ctx) => Scaffold(
      appBar: AppBar(title: Text(t('اسکن QR', 'Scan QR'))),
      body: MobileScanner(onDetect: (capture) {
        final code = capture.barcodes.firstOrNull?.rawValue;
        if (code != null && code.isNotEmpty) { Navigator.pop(ctx); _importRawText(code); }
      }),
    )));
  }

  void _openImportModal() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(t('افزودن کانفیگ / لینک', 'Import Config'), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(controller: ctrl, maxLines: 3, style: const TextStyle(fontSize: 12), decoration: const InputDecoration(hintText: 'vless://... یا https://...')),
          const SizedBox(height: 10),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF14B88A), foregroundColor: Colors.black), onPressed: () { Navigator.pop(ctx); _importRawText(ctrl.text); }, child: Text(t('ثبت', 'Add'))),
        ]),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var val = bytes.toDouble(); var idx = 0;
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
          Icon(Icons.shield_rounded, color: accent, size: 22),
          const SizedBox(width: 8),
          const Text('OTARED', style: TextStyle(fontWeight: FontWeight.w300, letterSpacing: 3.0, fontSize: 18)),
        ]),
        actions: [
          IconButton(onPressed: widget.onToggleLang, icon: Text(widget.isFa ? 'EN' : 'فا', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF14B88A)))),
          IconButton(onPressed: widget.onToggleTheme, icon: Icon(widget.darkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 20)),
        ],
      ),
      body: IndexedStack(index: _tabIndex, children: [
        _buildDashboardTab(isConnected, accent, activeSrv),
        _buildServersTab(accent),
        _buildAnalyticsTab(accent),
        _buildSettingsTab(accent)
      ]),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.06))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: NavigationBar(
            selectedIndex: _tabIndex,
            onDestinationSelected: (i) => setState(() => _tabIndex = i),
            backgroundColor: Colors.transparent,
            indicatorColor: accent.withOpacity(0.2),
            height: 60,
            destinations: [
              NavigationDestination(icon: Icon(Icons.power_settings_new_rounded, color: _tabIndex == 0 ? accent : Colors.grey), label: t('اتصال', 'Connect')),
              NavigationDestination(icon: Icon(Icons.dns_rounded, color: _tabIndex == 1 ? accent : Colors.grey), label: t('سرورها', 'Nodes')),
              NavigationDestination(icon: Icon(Icons.show_chart_rounded, color: _tabIndex == 2 ? accent : Colors.grey), label: t('آنالیز', 'Analytics')),
              NavigationDestination(icon: Icon(Icons.settings_rounded, color: _tabIndex == 3 ? accent : Colors.grey), label: t('تنظیمات', 'Settings')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardTab(bool isConnected, Color accent, VpnServer? activeSrv) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: isConnected ? accent : Colors.grey.withOpacity(0.2))),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: isConnected ? accent : Colors.grey)),
              const SizedBox(width: 8),
              Text(isConnected ? t('تونل امن فعال', 'ACTIVE') : t('آماده اتصال', 'STANDBY'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isConnected ? accent : Colors.grey)),
            ]),
          ),
          TextButton.icon(onPressed: _testingPing ? null : _smartSelectFastest, icon: Icon(Icons.bolt_rounded, size: 16, color: accent), label: Text(_testingPing ? '...' : t('سریع‌ترین', 'Smart'), style: TextStyle(fontSize: 11, color: accent))),
        ]),
        const Spacer(),
        Center(
          child: GestureDetector(
            onTap: _toggleVpn,
            child: ScaleTransition(
              scale: _pulseAnimation,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 190, height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: isConnected ? [accent.withOpacity(0.35), const Color(0xFF0F1318)] : [Theme.of(context).cardColor, const Color(0xFF07090B)]),
                  border: Border.all(color: isConnected ? accent : Colors.white.withOpacity(0.1), width: 2),
                  boxShadow: [BoxShadow(color: isConnected ? accent.withOpacity(0.3) : Colors.black.withOpacity(0.4), blurRadius: isConnected ? 35 : 15, spreadRadius: isConnected ? 4 : 0)],
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.power_settings_new_rounded, size: 50, color: isConnected ? accent : Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(isConnected ? _status.duration : t('لمس برای اتصال', 'TAP TO CONNECT'), style: TextStyle(fontWeight: FontWeight.w300, letterSpacing: 1.2, fontSize: 11, color: isConnected ? accent : Colors.grey)),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (_proMode) Row(children: [_statCard(t('دانلود', 'DOWN'), '${_formatBytes(_status.downloadSpeed)}/s', accent), const SizedBox(width: 12), _statCard(t('آپلود', 'UP'), '${_formatBytes(_status.uploadSpeed)}/s', Colors.blueGrey.shade300)]),
        const Spacer(),
        InkWell(
          onTap: () => setState(() => _tabIndex = 1),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(0.06))),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.dns_rounded, color: accent, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(activeSrv?.name ?? t('سروری انتخاب نشده', 'No Node Selected'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(activeSrv != null ? '${activeSrv.protocol} • ${activeSrv.pingMs > 0 ? "${activeSrv.pingMs}ms" : "Ready"}' : t('افزودن کانفیگ', 'Tap to add'), style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ])),
              IconButton(onPressed: _openImportModal, icon: Icon(Icons.add_circle_rounded, color: accent, size: 24)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _statCard(String title, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ]),
        ),
      );

  Widget _buildServersTab(Color accent) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black), onPressed: _openImportModal, icon: const Icon(Icons.add_rounded, size: 18), label: Text(t('افزودن', 'Add')))),
          const SizedBox(width: 8),
          OutlinedButton.icon(onPressed: _openQrScanner, icon: const Icon(Icons.qr_code_scanner_rounded, size: 18), label: const Text('QR')),
          const SizedBox(width: 8),
          OutlinedButton.icon(onPressed: _testingPing ? null : _smartSelectFastest, icon: const Icon(Icons.bolt_rounded, size: 18), label: Text(t('پینگ', 'Ping'))),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _servers.length,
          itemBuilder: (ctx, i) {
            final s = _servers[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: s.id == _selectedId ? accent : Colors.white.withOpacity(0.05))),
              child: ListTile(
                onTap: () { setState(() => _selectedId = s.id); _saveState(); },
                title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(s.protocol, style: TextStyle(fontSize: 11, color: accent)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  TextButton(onPressed: () => _testSinglePing(s), child: Text(s.pingMs > 0 ? '${s.pingMs}ms' : 'Ping', style: TextStyle(color: s.pingMs > 0 ? accent : Colors.grey, fontSize: 12))),
                  IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent), onPressed: () { setState(() => _servers.removeAt(i)); _saveState(); }),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildAnalyticsTab(Color accent) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [_statCard(t('دانلود', 'DOWN'), _formatBytes(_status.download), accent), const SizedBox(width: 12), _statCard(t('آپلود', 'UP'), _formatBytes(_status.upload), Colors.amber)]),
        const SizedBox(height: 16),
        Container(
          height: 110, padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(18)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: _speedHistory.map((v) => Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 2), height: (v * 2.5).clamp(4.0, 75.0), decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(3))))).toList()),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(18)),
            child: ListView.builder(itemCount: _logs.length, itemBuilder: (_, i) => Text(_logs[i], style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.grey))),
          ),
        ),
      ]),
    );
  }

  Widget _buildSettingsTab(Color accent) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      ListTile(title: Text(t('مسیریابی', 'Routing')), trailing: DropdownButton<String>(value: _routingMode, items: [DropdownMenuItem(value: 'global', child: Text(t('پروکسی کامل', 'Global'))), DropdownMenuItem(value: 'bypass_ir', child: Text(t('دور زدن ایران', 'Bypass IR')))], onChanged: (v) { if (v != null) setState(() => _routingMode = v); _saveState(); })),
      ListTile(title: const Text('DNS'), trailing: DropdownButton<String>(value: _dnsServer, items: const [DropdownMenuItem(value: 'https://1.1.1.1/dns-query', child: Text('1.1.1.1 DoH')), DropdownMenuItem(value: 'https://dns.google/dns-query', child: Text('Google DoH'))], onChanged: (v) { if (v != null) setState(() => _dnsServer = v); _saveState(); })),
      SwitchListTile(activeColor: accent, title: const Text('TLS Fragment'), value: _enableFragment, onChanged: (v) { setState(() => _enableFragment = v); _saveState(); }),
      SwitchListTile(activeColor: accent, title: const Text('Multiplexing (Mux)'), value: _enableMux, onChanged: (v) { setState(() => _enableMux = v); _saveState(); }),
    ]);
  }
}
