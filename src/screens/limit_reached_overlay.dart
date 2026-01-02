import 'package:flutter/material.dart';
import 'exercise_screen.dart';
import 'package:flutter/services.dart';

class LimitReachedOverlay extends StatelessWidget {
  final String title;
  final int limitMinutes;
  final int usedMinutes;
  final VoidCallback onClose;
  final VoidCallback onExerciseUnlock;

  const LimitReachedOverlay({
    super.key,
    required this.title,
    required this.limitMinutes,
    required this.usedMinutes,
    required this.onClose,
    required this.onExerciseUnlock,
  });

  @override
  Widget build(BuildContext context) {
    final overBy = (usedMinutes - limitMinutes).clamp(0, 999999);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A1400), Colors.black],
          ),
        ),
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("VERO", style: TextStyle(fontFamily: 'DxSitrus', fontSize: 40, color: Colors.white)),
            const SizedBox(height: 60),
            const Icon(Icons.hourglass_bottom, size: 80, color: Colors.orangeAccent),
            const SizedBox(height: 25),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              "Daily limit reached",
              style: TextStyle(color: Colors.orangeAccent.withOpacity(0.9), fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              "Limit: ${limitMinutes}m • Used: ${usedMinutes}m\nOver by: ${overBy}m",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 50),

            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  onClose();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text("Close", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 60,
              child: OutlinedButton.icon(
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ExerciseScreen()),
                  );

                  if (result == true) {
                    onExerciseUnlock();
                  }
                },
                icon: const Icon(Icons.fitness_center, color: Colors.white),
                label: const Text(
                  "Earn +5m (Exercise)",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white38),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
