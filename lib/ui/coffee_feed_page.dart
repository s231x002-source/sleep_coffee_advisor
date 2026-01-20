
// lib/ui/coffee_feed_page.dart
import 'package:flutter/material.dart';

class CoffeeFeedPage extends StatefulWidget {
  const CoffeeFeedPage({super.key});

  @override
  State<CoffeeFeedPage> createState() => _CoffeeFeedPageState();
}

class _CoffeeFeedPageState extends State<CoffeeFeedPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;

  final List<String> categories = const [
    "おすすめ",
    "深煎り",
    "軽め",
    "ラテ",
    "エスプレッソ",
    "人気",
  ];
  int selectedCategory = 0;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          "CoffeeTime",
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/background.png"),
            fit: BoxFit.cover,
            opacity: 0.25,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeController,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // ヘッダ
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      "今日の気分に合う\nコーヒーは？",
                      style: TextStyle(
                        height: 1.3,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown.shade900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),

                  // カテゴリチップ
                  SizedBox(
                    height: 45,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final selected = selectedCategory == index;
                        return GestureDetector(
                          onTap: () => setState(() => selectedCategory = index),
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.brown.shade700
                                  : Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.brown.shade300,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              categories[index],
                              style: TextStyle(
                                color:
                                selected ? Colors.white : Colors.brown[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 25),

                  // フィード
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: List.generate(
                        6,
                            (i) => coffeePost(
                          "assets/images/coffee${(i % 3) + 1}.png",
                          "コーヒー ${i + 1}",
                          "深みのある香りと柔らかい苦味が楽しめる一杯。",
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget coffeePost(String img, String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 30),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 画像を出したいなら ↓ を Image.asset(img, fit: BoxFit.cover) に差し替えOK
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.brown.shade200,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: const Icon(Icons.local_cafe, size: 80, color: Colors.white54),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.brown.shade900,
                      fontWeight: FontWeight.bold,
                    )),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Colors.brown.shade700,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.favorite_border, color: Colors.brown.shade400),
                    const SizedBox(width: 15),
                    Icon(Icons.more_horiz, color: Colors.brown.shade400),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}