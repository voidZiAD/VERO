import 'dart:async';
import 'package:flutter/material.dart';
import '../services/block_service.dart';
import 'exercise_screen.dart';
import 'package:flutter/services.dart';

class BlockingOverlay extends StatefulWidget {
  final String appName;
  final BlockSession? session;
  final VoidCallback onRefocus;
  final VoidCallback onStopSession;

  const BlockingOverlay({
    super.key,
    required this.appName,
    required this.onRefocus,
    required this.onStopSession,
    this.session,
  });

  @override
  State<BlockingOverlay> createState() => _BlockingOverlayState();
}

class _BlockingOverlayState extends State<BlockingOverlay> {
  void _showEmergencyDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _EmergencyExitDialog(onConfirm: widget.onStopSession),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isTimeLimit = widget.session?.type == BlockType.limit;
    String title = isTimeLimit ? "Time Limit Reached" : "App Blocked";
    
    String affirmation = BlockService().getRandomAffirmation();
    
    String subtitle = isTimeLimit
      ? "You've reached your daily limit of ${widget.session!.durationMinutes} minutes for your '${widget.session!.name}' app group."
      : affirmation; 

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A0000), Colors.black],
          ),
        ),
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("VERO", style: TextStyle(fontFamily: 'DxSitrus', fontSize: 40, color: Colors.white)),
            const SizedBox(height: 60),
            Icon(isTimeLimit ? Icons.hourglass_disabled : Icons.block, size: 80, color: Colors.redAccent),
            const SizedBox(height: 40),
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, color: Colors.white, height: 1.5, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 60),
            
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  widget.onRefocus();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: Text(isTimeLimit ? "I'll take a break" : "I'll get back to focus", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 60,
              child: OutlinedButton.icon(
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  final result = await Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (_) => const ExerciseScreen())
                  );
                  
                  if (result == true) {
                    widget.onRefocus(); 
                  }
                },
                icon: const Icon(Icons.fitness_center, color: Colors.white),
                label: Text(isTimeLimit ? "Get 15m more (Exercise)" : "Unlock for 5m (Exercise)", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white38),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),

            const SizedBox(height: 30),
            
            TextButton(
              onPressed: _showEmergencyDialog,
              child: const Text(
                "Emergency Unlock", 
                style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyExitDialog extends StatefulWidget {
  final VoidCallback onConfirm;
  const _EmergencyExitDialog({required this.onConfirm});

  @override
  State<_EmergencyExitDialog> createState() => _EmergencyExitDialogState();
}

class _EmergencyExitDialogState extends State<_EmergencyExitDialog> {
  int _countdown = 15;
  Timer? _timer;
  final TextEditingController _controller = TextEditingController();
  bool _canSubmit = false;
  static const String _phrase = "I am breaking my promise";

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_countdown > 0) {
            _countdown--;
          } else {
            _timer?.cancel();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isLocked = _countdown > 0;

    return AlertDialog(
      backgroundColor: const Color(0xFF1A0B2E),
      title: const Text("Emergency Unlock", style: TextStyle(color: Colors.redAccent, fontFamily: 'DxSitrus')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "To stop this session early, you must wait and type the phrase below.",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.redAccent.withOpacity(0.3))
            ),
            child: const Text(
              _phrase,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            enabled: !isLocked,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: isLocked ? "Wait ${_countdown}s..." : "Type phrase here",
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
            onChanged: (val) {
              setState(() {
                _canSubmit = val.trim().toLowerCase() == _phrase.toLowerCase();
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.white)),
        ),
        ElevatedButton(
          onPressed: _canSubmit 
            ? () {
                Navigator.pop(context);
                widget.onConfirm();
              } 
            : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.white10,
            disabledForegroundColor: Colors.white38
          ),
          child: const Text("Unlock"),
        ),
      ],
    );
  }
}
