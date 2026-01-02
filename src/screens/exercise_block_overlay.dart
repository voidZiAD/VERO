import 'package:flutter/material.dart';
import 'exercise_screen.dart'; 
import 'package:flutter/services.dart';

class ExerciseBlockOverlay extends StatelessWidget {
  final dynamic session; 
  final VoidCallback onUnlock;

  const ExerciseBlockOverlay({
    super.key,
    required this.session,
    required this.onUnlock,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2E0404), Colors.black], 
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: SafeArea( 
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, 
            children: [
              const Spacer(), 
              const Icon(Icons.fitness_center, size: 80, color: Colors.redAccent),
              const SizedBox(height: 40),
              const Text(
                "PAY THE PRICE",
                style: TextStyle(
                  fontFamily: 'DxSitrus', 
                  fontSize: 32, 
                  color: Colors.white,
                  letterSpacing: 2
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "You blocked '${session.name}' to stay disciplined.",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: Colors.white70),
              ),
              const SizedBox(height: 10),
              const Text(
                "Want to use it for a break?\nDo the work.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 60), 
              
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ExerciseScreen()),
                    );

                    if (result == true) {
                      onUnlock();
                    }
                  },
                  icon: const Icon(Icons.directions_run, color: Colors.black),
                  label: const Text("START EXERCISE", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ),
              
              const Spacer(), 
            ],
          ),
        ),
      ),
    );
  }
}
