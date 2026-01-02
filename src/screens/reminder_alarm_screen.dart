import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/block_service.dart';
import '../screens/home_screen.dart';

class ReminderAlarmScreen extends StatefulWidget {
  final String title;

  const ReminderAlarmScreen({super.key, required this.title});

  @override
  State<ReminderAlarmScreen> createState() => _ReminderAlarmScreenState();
}

class _ReminderAlarmScreenState extends State<ReminderAlarmScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _vibrationTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 200), () => HapticFeedback.heavyImpact());
      Future.delayed(const Duration(milliseconds: 400), () => HapticFeedback.heavyImpact());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _vibrationTimer?.cancel();
    super.dispose();
  }

    @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.purpleAccent.withOpacity(0.4 * _controller.value),
                      Colors.black
                    ],
                    radius: 1.5,
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                const Icon(Icons.alarm, size: 80, color: Colors.white),
                const SizedBox(height: 30),
                const Text(
                  "REMINDER",
                  style: TextStyle(
                    fontFamily: 'DxSitrus',
                    fontSize: 32,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.purpleAccent,
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        await BlockService().stopNativeAlarm();
                        if (mounted) {
                            Navigator.pushReplacement(
                              context, 
                              MaterialPageRoute(builder: (_) => const HomeScreen())
                            );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        "Dismiss",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
