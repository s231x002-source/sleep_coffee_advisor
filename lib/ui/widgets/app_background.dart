
import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage("assets/images/background.png"),
          fit: BoxFit.cover,
          opacity: 0.32,
        ),
        gradient: LinearGradient(
          colors: [
            Colors.brown.shade900.withOpacity(0.60),
            Colors.brown.shade400.withOpacity(0.40),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: child,
    );
  }
}
