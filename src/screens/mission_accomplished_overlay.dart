import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MissionAccomplishedOverlay extends StatefulWidget {
  final int xpEarned;
  final int durationMinutes;
  final int streak;
  final VoidCallback onDismiss;

  const MissionAccomplishedOverlay({
    super.key,
    required this.xpEarned,
    required this.durationMinutes,
    required this.streak,
    required this.onDismiss,
  });

  @override
  State<MissionAccomplishedOverlay> createState() => _MissionAccomplishedOverlayState();
}

class _MissionAccomplishedOverlayState extends State<MissionAccomplishedOverlay> with SingleTickerProviderStateMixin {
  int _displayXp = 0;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();

    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);

    _startCounting();
  }

  void _startCounting() {
    int totalSteps = widget.xpEarned;
    int stepDuration = (2000 / (totalSteps == 0 ? 1 : totalSteps)).clamp(10, 100).toInt();

    Timer.periodic(Duration(milliseconds: stepDuration), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_displayXp < widget.xpEarned) {
        setState(() {
          _displayXp++;
        });
        HapticFeedback.selectionClick();
      } else {
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 400), () => HapticFeedback.heavyImpact());
        Future.delayed(const Duration(milliseconds: 400), () => HapticFeedback.heavyImpact());
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 40),
              
              ScaleTransition(
                scale: _scaleAnimation,
                child: const Text(
                  "Session\ncomplete!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'DxSitrus',
                    fontSize: 36,
                    color: Colors.amber,
                    height: 1.1,
                  ),
                ),
              ),

              const Spacer(),

              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                    border: Border.all(color: Colors.amber, width: 2),
                    boxShadow: [
                      BoxShadow(color: Colors.amber.withOpacity(0.2), blurRadius: 40, spreadRadius: 5)
                    ]
                  ),
                  child: const Icon(Icons.emoji_events, size: 100, color: Colors.amber),
                ),
              ),

              const Spacer(),

              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      "TOTAL XP",
                      "$_displayXp",
                      Icons.bolt,
                      const Color(0xFFFFC800),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      "TIME",
                      "${widget.durationMinutes}:00",
                      Icons.timer,
                      const Color(0xFF2B70C9),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      "STREAK",
                      "${widget.streak}",
                      Icons.local_fire_department,
                      const Color(0xFF4CAF50),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    widget.onDismiss();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF49C0F8),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: const BorderSide(color: Color(0xFF49C0F8), width: 0), 
                  ).copyWith(
                    elevation: WidgetStateProperty.all(6),
                    shadowColor: WidgetStateProperty.all(const Color(0xFF1899D6)), 
                  ),
                  child: const Text(
                    "CONTINUE",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
