
import 'dart:async';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';

import 'widgets/app_background.dart';


class CoffeeNapTimer {
  final Duration initial;
  Duration remaining;
  Timer? _timer;

  CoffeeNapTimer({Duration? initial})
      : initial = initial ?? const Duration(minutes: 20),
        remaining = initial ?? const Duration(minutes: 20);

  bool get isRunning => _timer != null;

  void start({
    required void Function(Duration) onTick,
    required VoidCallback onFinished,
  }) {
    _timer?.cancel();
    remaining = initial;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining -= const Duration(seconds: 1);

      if (remaining <= Duration.zero) {
        timer.cancel();
        _timer = null;
        remaining = Duration.zero;
        onTick(remaining);
        onFinished();
      } else {
        onTick(remaining);
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => stop();
}

class CoffeeNapTimerPage extends StatefulWidget {
  const CoffeeNapTimerPage({
    super.key,
    this.initialMinutes = 20,
  });

  final int initialMinutes;

  @override
  State<CoffeeNapTimerPage> createState() => _CoffeeNapTimerPageState();
}

class _CoffeeNapTimerPageState extends State<CoffeeNapTimerPage> {
  CoffeeNapTimer? _timer;
  late Duration _napDuration = Duration(minutes: widget.initialMinutes);
  late Duration _remaining = _napDuration;
  bool _running = false;

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _start() {
    _timer?.dispose();
    _timer = CoffeeNapTimer(initial: _napDuration);

    setState(() {
      _remaining = _napDuration;
      _running = true;
    });

    _timer!.start(
      onTick: (d) {
        if (!mounted) return;
        setState(() => _remaining = d);
      },
      onFinished: () {
        if (!mounted) return;
        setState(() {
          _running = false;
          _remaining = Duration.zero;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('お昼寝おつかれさまです！コーヒーが効き始める時間です☕'),
          ),
        );
      },
    );
  }

  void _stop() {
    _timer?.dispose();
    setState(() => _running = false);
  }

  @override
  void dispose() {
    _timer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(

      appBar: AppBar(
        title: const Text('コーヒーナップタイマー'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),

      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: cs.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'コーヒーを飲んでから'
                          '${_napDuration.inMinutes}分のお昼寝をすると、'
                          '起きる頃にカフェインが効き始めてスッキリしやすいと言われています。',
                      style: TextStyle(color: cs.onPrimaryContainer, height: 1.3),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('お昼寝時間（分）'),
                Slider(
                  min: 10,
                  max: 30,
                  divisions: 4, // 10,15,20,25,30
                  value: _napDuration.inMinutes.toDouble(),
                  label: '${_napDuration.inMinutes}分',
                  onChanged: _running
                      ? null
                      : (v) {
                    final m = v.round();
                    setState(() {
                      _napDuration = Duration(minutes: m);
                      _remaining = _napDuration;
                    });
                  },
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Center(
                    child: Text(
                      _format(_remaining),
                      style: const TextStyle(
                        fontSize: 72,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _running ? _stop : _start,
                  icon: Icon(_running ? Icons.stop_rounded : Icons.play_arrow_rounded),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(_running ? '停止' : 'スタート'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
