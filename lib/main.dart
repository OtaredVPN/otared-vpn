import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF090A0C),
    ),
  );
  runApp(const OtaredVpnApp());
}

class OtaredVpnApp extends StatelessWidget {
  const OtaredVpnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OTARED VPN',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF090A0C),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF10B981),
          secondary: Color(0xFFC8A96E),
          surface: Color(0xFF111318),
        ),
      ),
      home: const OtaredDashboard(),
    );
  }
}

class ServerNode {
  final String name;
  final String protocol;
  final String uri;
  const ServerNode({required this.name, required this.protocol, required this.uri});
}

class OtaredDashboard extends StatefulWidget {
  const OtaredDashboard({super.key});

  @override
  State<OtaredDashboard> createState() => _OtaredDashboardState();
}

class _OtaredDashboardState extends State<OtaredDashboard> {
  bool _connected = false;
  bool _connecting = false;
  final List<ServerNode> _servers = [];
  int _selectedIndex = 0;

  void _toggleConnection() async {
    if (_servers.isEmpty) {
      _showAddConfigSheet();
      return;
    }
    if (_connected) {
      setState(() => _connected = false);
      return;
    }
    setState(() => _connecting = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) {
      setState(() {
        _connecting = false;
        _connected = true;
      });
    }
  }

  void _parseAndAdd(String raw) {
    final lines = raw.split(RegExp(r'\r?\n')).map((e) => e.trim()).where((e) => e.contains('://'));
    final added = <ServerNode>[];
    for (final line in lines) {
      final proto = line.split('://').first.toUpperCase();
      final hashIdx = line.indexOf('#');
      final remark = (hashIdx != -1 && hashIdx + 1 < line.length)
          ? Uri.decodeComponent(line.substring(hashIdx + 1))
          : 'OTARED $proto Server';
      added.add(ServerNode(name: remark, protocol: proto, uri: line));
    }
    if (added.isNotEmpty) {
      setState(() {
        _servers.addAll(added);
        _selectedIndex = _servers.length - 1;
      });
    }
  }

  void _showAddConfigSheet() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111318),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'افزودن کانفیگ / لینک سابسکریپشن',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFC8A96E)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'vless:// , vmess:// , trojan:// , hy2:// ...',
                filled: true,
                fillColor: const Color(0xFF181B22),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) controller.text = data!.text!;
                    },
                    icon: const Icon(Icons.paste_rounded, size: 18),
                    label: const Text('جای‌گذاری'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: const Color(0xFF090A0C),
                    ),
                    onPressed: () {
                      _parseAndAdd(controller.text);
                      Navigator.pop(ctx);
                    },
                    child: const Text('ثبت سرور', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeServer = _servers.isNotEmpty ? _servers[_selectedIndex] : null;
    final statusColor = _connected
        ? const Color(0xFF10B981)
        : _connecting
            ? const Color(0xFFC8A96E)
            : const Color(0xFF6B7280);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF090A0C),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 22),
            SizedBox(width: 8),
            Text('OTARED', style: TextStyle(letterSpacing: 3.5, fontWeight: FontWeight.w300)),
            SizedBox(width: 6),
            Text('VPN', style: TextStyle(color: Color(0xFFC8A96E), fontSize: 13, letterSpacing: 2)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showAddConfigSheet,
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFFC8A96E)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF111318),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withOpacity(0.5)),
              ),
              child: Text(
                _connected
                    ? 'اتصال ایمن برقرار است'
                    : _connecting
                        ? 'در حال برقراری تونل...'
                        : 'متصل نیست',
                style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _toggleConnection,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 176,
                height: 176,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF111318),
                  border: Border.all(color: statusColor, width: 2),
                  boxShadow: _connected
                      ? [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.25), blurRadius: 32)]
                      : [],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.power_settings_new_rounded, size: 46, color: statusColor),
                    const SizedBox(height: 8),
                    Text(
                      _connected ? 'ACTIVE' : 'CONNECT',
                      style: TextStyle(color: statusColor, letterSpacing: 2.5, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: _showAddConfigSheet,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF111318),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF232732)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.dns_outlined, color: Color(0xFFC8A96E)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeServer?.name ?? 'سروری انتخاب نشده است',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            activeServer != null
                                ? 'پروتکل: ${activeServer.protocol}'
                                : 'برای افزودن لینک VLESS / Reality لمس کنید',
                            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.add_rounded, color: Color(0xFF10B981)),
                  ],
                ),
              ),
            ),
            if (_servers.length > 1) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _servers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) => ChoiceChip(
                    label: Text(_servers[i].name, style: const TextStyle(fontSize: 11)),
                    selected: i == _selectedIndex,
                    selectedColor: const Color(0xFF10B981).withOpacity(0.25),
                    onSelected: (_) => setState(() => _selectedIndex = i),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
