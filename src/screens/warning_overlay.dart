import 'package:flutter/material.dart';
import 'package:slide_to_act/slide_to_act.dart';
import 'home_screen.dart';
import 'package:flutter/services.dart';

class WarningOverlay extends StatelessWidget {
  final String scheduleName;
  final String timeRange;
  final String sessionId; 

  const WarningOverlay({
    super.key,
    required this.scheduleName,
    required this.timeRange,
    required this.sessionId, 
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0518),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.access_alarm, size: 80, color: Colors.orangeAccent),
              const SizedBox(height: 40),
              const Text(
                "HEADS UP!",
                style: TextStyle(
                  fontFamily: 'DxSitrus',
                  fontSize: 32,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Your '$scheduleName' session is about to start.",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: Colors.white70),
              ),
              const SizedBox(height: 10),
              Text(
                timeRange,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.orangeAccent,
                ),
              ),
              const Spacer(),
              const Text(
                "Wrap up what you're doing.",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),
              SlideAction(
  borderRadius: 24,
  elevation: 0,
  innerColor: Colors.white,
  outerColor: Colors.orangeAccent.withOpacity(0.2),
  sliderButtonIcon: const Icon(Icons.arrow_forward, color: Colors.orangeAccent),
  text: "I'm Ready",
  textStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
  onSubmit: () {
    HapticFeedback.heavyImpact();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
    return null;
  },
),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
