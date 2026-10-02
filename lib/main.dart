import 'package:flutter/material.dart';

void main() {
  runApp(const HotspotCardsApp());
}

class HotspotCardsApp extends StatelessWidget {
  const HotspotCardsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'إدارة كروت الإنترنت',
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة كروت الإنترنت'),
      ),
      body: const Center(
        child: Text(
          'إدارة كروت MikroTik Hotspot',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
