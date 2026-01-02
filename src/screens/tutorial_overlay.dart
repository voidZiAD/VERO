import 'package:flutter/material.dart';
import 'dart:ui';

class TutorialOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  const TutorialOverlay({super.key, required this.onComplete});

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(color: Colors.black.withOpacity(0.85)),
          ),
          
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Material( 
                  color: Colors.transparent,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_step == 0) _buildWarningStep(),
                      if (_step == 1) _buildBasicsStep(),
                      if (_step == 2) _buildInteractiveStep(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildWarningStep() {
    return _buildCard(
      icon: Icons.cloud_off,
      iconColor: Colors.orangeAccent,
      title: "Important Data Notice",
      content: "VERO is a free, student-led project. To keep it free for everyone and avoid server costs, we optimize how data is saved.\n\n"
          "Your progress (XP, Streak, Settings) saves to the cloud **ONLY**:\n"
          "1. Overnight (Automatically)\n"
          "2. When you manually **Log Out**\n\n"
          "It does NOT save instantly when you level up or change a setting.\n\n"
          "⚠️ If you uninstall the app or clear data without logging out first, you will lose today's progress.",
      buttonText: "I Understand",
      onNext: () => setState(() => _step++),
    );
  }

  Widget _buildBasicsStep() {
    return _buildCard(
      icon: Icons.school,
      iconColor: Colors.purpleAccent,
      title: "How VERO Works",
      content: "• **Blocks**: Create sessions to block apps/sites completely.\n\n"
          "• **Strict Mode**: If enabled, you cannot cancel a session easily. No cheating.\n\n"
          "• **Partners**: Link with a friend. If you fail a session, they get notified.\n\n"
          "• **XP & Levels**: Earn rewards for every minute of focus.",
      buttonText: "Next",
      onNext: () => setState(() => _step++),
    );
  }

  Widget _buildInteractiveStep() {
    return _buildCard(
      icon: Icons.touch_app,
      iconColor: Colors.greenAccent,
      title: "Your Turn",
      content: "The best way to learn is to do.\n\n"
          "Tap the **+ New Block** button below to create your first focus session or schedule.\n\n"
          "Good luck.",
      buttonText: "Start Using VERO",
      onNext: widget.onComplete,
    );
  }

  Widget _buildCard({required IconData icon, required Color iconColor, required String title, required String content, required String buttonText, required VoidCallback onNext}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0B2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: iconColor.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)
        ]
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 50, color: iconColor),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(fontFamily: 'DxSitrus', fontSize: 24, color: Colors.white), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          _buildRichText(content),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, 
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
              ),
              child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRichText(String text) {
    List<String> parts = text.split("**");
    List<TextSpan> spans = [];

    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 0) {
        spans.add(TextSpan(text: parts[i], style: const TextStyle(fontSize: 15, color: Colors.white70, height: 1.5)));
      } else {
        spans.add(TextSpan(text: parts[i], style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold, height: 1.5)));
      }
    }

    return RichText(
      textAlign: TextAlign.left,
      text: TextSpan(children: spans),
    );
  }
}
