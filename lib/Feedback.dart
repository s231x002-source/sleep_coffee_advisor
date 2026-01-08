import 'dart:ui';
import 'package:flutter/material.dart';

void main() {
  runApp(const SleepCoffeeApp());
}

class SleepCoffeeApp extends StatelessWidget {
  const SleepCoffeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '睡眠 × コーヒー提案',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'sans',
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
  double condition = 6;
  TimeOfDay sleepTime = const TimeOfDay(hour: 23, minute: 30);
  TimeOfDay wakeTime = const TimeOfDay(hour: 7, minute: 0);
  String? resultCoffee;

  // ⭐ NEW: feedback rating (1–5)
  int rating = 0;

  // --- Coffee Theme Colors ---
  final Color coffeeDark = const Color(0xFF6B4F3A);
  final Color coffeeMilk = const Color(0xFFDCC4A2);
  final Color coffeeLatte = const Color(0xFFF7EFE5);
  final Color coffeeAccent = const Color(0xFFB07B52);

  // --- Time Picker ---
  Future<void> pickTime(bool isSleepTime) async {
    final TimeOfDay? newTime = await showTimePicker(
      context: context,
      initialTime: isSleepTime ? sleepTime : wakeTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: coffeeAccent),
          ),
          child: child!,
        );
      },
    );

    if (newTime != null) {
      setState(() {
        if (isSleepTime) {
          sleepTime = newTime;
        } else {
          wakeTime = newTime;
        }
      });
    }
  }

  // --- Main Logic ---
  void analyze() {
    int sleepMinutes =
        (wakeTime.hour * 60 + wakeTime.minute) -
            (sleepTime.hour * 60 + sleepTime.minute);

    if (sleepMinutes < 0) sleepMinutes += 24 * 60;

    if (condition <= 4) {
      resultCoffee = "カフェラテ（優しい味）";
    } else if (sleepMinutes < 360) {
      resultCoffee = "アメリカーノ（すっきり）";
    } else {
      resultCoffee = "ドリップ（深煎り）";
    }

    rating = 0; // reset feedback each time
    setState(() {});
  }

  // --------------------------------------------------------------------------
  //  UI
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage("assets/images/background.png"),
            fit: BoxFit.cover,
            opacity: 0.32,
          ),
          gradient: LinearGradient(
            colors: [
              Colors.brown.shade900.withOpacity(0.6),
              Colors.brown.shade400.withOpacity(0.4),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 12),

                Text(
                  "Sleep2Sip",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: coffeeLatte,
                    shadows: [
                      Shadow(
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                        color: Colors.black.withOpacity(0.3),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  "今日のコンディションに合う一杯を提案します",
                  style: TextStyle(
                    fontSize: 15,
                    color: coffeeLatte.withOpacity(0.95),
                  ),
                ),

                const SizedBox(height: 25),

                // 1. Condition
                glassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      label("1. 起きた時の調子（1〜10）"),
                      const SizedBox(height: 10),
                      Slider(
                        value: condition,
                        min: 1,
                        max: 10,
                        activeColor: coffeeAccent,
                        inactiveColor: coffeeMilk,
                        onChanged: (v) => setState(() => condition = v),
                      ),
                      Center(
                        child: Text(
                          "${condition.toInt()} / 10",
                          style: TextStyle(
                            fontSize: 18,
                            color: coffeeDark,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 2. Time
                glassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      label("2. 時刻（24時間表記）"),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: timeBox(
                              "就寝時刻",
                              sleepTime,
                                  () => pickTime(true),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: timeBox(
                              "起床時刻",
                              wakeTime,
                                  () => pickTime(false),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: coffeeAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 35, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  onPressed: analyze,
                  child: const Text("提案する", style: TextStyle(fontSize: 18)),
                ),

                const SizedBox(height: 30),

                // Result
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 600),
                  opacity: resultCoffee == null ? 0 : 1,
                  child: resultCoffee == null
                      ? const SizedBox()
                      : glassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        label("分析結果"),
                        const SizedBox(height: 10),
                        Text(
                          "おすすめは：$resultCoffee",
                          style: TextStyle(
                            fontSize: 22,
                            color: coffeeDark,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ⭐ FEEDBACK SECTION
                if (resultCoffee != null) ...[
                  const SizedBox(height: 25),
                  glassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        label("この提案はいかがでしたか？"),
                        const SizedBox(height: 12),
                        starRating(),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            rating == 0
                                ? "タップして評価してください"
                                : "$rating / 5 ★",
                            style: TextStyle(
                              fontSize: 16,
                              color: coffeeDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Helper Widgets
  // --------------------------------------------------------------------------

  Text label(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: coffeeDark,
      ),
    );
  }

  Widget glassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.22),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.28)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget timeBox(String title, TimeOfDay time, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: coffeeMilk),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: coffeeDark)),
            const SizedBox(height: 8),
            Center(
              child: Text(
                time.format(context),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: coffeeDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ⭐ STAR RATING WIDGET
  Widget starRating() {
    return Material(
      color: Colors.transparent, // ⭐ IMPORTANT
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) {
          return IconButton(
            icon: Icon(
              index < rating ? Icons.star : Icons.star_border,
              color: coffeeAccent,
              size: 32,
            ),
            onPressed: () {
              setState(() {
                rating = index + 1;
              });
            },
          );
        }),
      ),
    );
  }
}
