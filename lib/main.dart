import 'package:flutter/material.dart';
import 'services/vpn_manager.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OTARED VPN',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primarySwatch: Colors.blue,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late VpnManager _vpnManager;
  String _connectionState = "DISCONNECTED";
  bool _isConnected = false;
  final TextEditingController _configController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vpnManager = VpnManager(onStatusChanged: (status) {
      setState(() {
        _connectionState = status.state;
        _isConnected = status.state == "CONNECTED";
      });
    });
    _vpnManager.init();
    _loadSavedConfig();
  }

  Future<void> _loadSavedConfig() async {
    String? saved = await _vpnManager.getConfig();
    if (saved != null) {
      _configController.text = saved;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OTARED Secure VPN'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showConfigSheet(context),
          )
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'وضعیت: $_connectionState',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _isConnected ? Colors.greenAccent : Colors.orangeAccent,
                ),
              ),
              const SizedBox(height: 50),
              // دکمه بزرگ اتصال (یک کلیک)
              GestureDetector(
                onTap: () async {
                  if (_isConnected) {
                    await _vpnManager.disconnect();
                  } else {
                    String config = _configController.text.trim();
                    if (config.isEmpty) {
                      _showError("لطفاً ابتدا کانفیگ یا لینک ساب خود را وارد کنید.");
                      return;
                    }
                    await _vpnManager.saveConfig(config);
                    await _vpnManager.connect(config);
                  }
                },
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _isConnected
                          ? [Colors.green.shade700, Colors.green.shade400]
                          : [Colors.blue.shade800, Colors.indigo.shade500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_isConnected ? Colors.green : Colors.blue).withOpacity(0.4),
                        blurRadius: 25,
                        spreadRadius: 5,
                      )
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      _isConnected ? Icons.power_settings_new : Icons.bolt,
                      size: 72,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 50),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade800,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: () => _showConfigSheet(context),
                icon: const Icon(Icons.edit_note),
                label: const Text('پِیست کردن کانفیگ / لینک ساب'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showConfigSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تنظیمات کانفیگ و اشتراک', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextField(
              controller: _configController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'کانفیگ vless:// یا لینک ساب‌سکرایبشن را اینجا پیست کنید...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                onPressed: () async {
                  await _vpnManager.saveConfig(_configController.text.trim());
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('کانفیگ با موفقیت ذخیره شد')),
                  );
                },
                child: const Text('ذخیره و اعمال'),
              ),
            ),
            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }
}
