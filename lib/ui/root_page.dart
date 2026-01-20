
// lib/ui/root_page.dart
import 'package:flutter/material.dart';
import 'home_page.dart';
import 'coffee_feed_page.dart';

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ タブ切替でも状態を保持
      body: IndexedStack(
        index: index,
        children: const [
          HomePage(),        // 提案画面
          CoffeeFeedPage(),  // scroll UI
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => setState(() => index = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.bedtime),
            label: '提案',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_cafe),
            label: 'フィード',
          ),
        ],
      ),
    );
  }
}
