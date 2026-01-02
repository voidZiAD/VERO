import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_apps/device_apps.dart';

class DoomScrollOverlay extends StatefulWidget {
  final String packageName;
  final VoidCallback onBlock;

  const DoomScrollOverlay({
    super.key,
    required this.packageName,
    required this.onBlock,
  });

  @override
  State<DoomScrollOverlay> createState() => _DoomScrollOverlayState();
}

class _DoomScrollOverlayState extends State<DoomScrollOverlay> {
  String _appName = "This App";

  @override
  void initState() {
    super.initState();
    _loadAppName();
  }

  Future<void> _loadAppName() async {
    try {
      final app = await DeviceApps.getApp(widget.packageName, true);
      if (app != null) {
        setState(() => _appName = app.appName);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A0B2E).withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border(top: BorderSide(color: Colors.redAccent.withOpacity(0.3))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 30),
            const Icon(Icons.warning_amber_rounded, size: 60, color: Colors.redAccent),
            const SizedBox(height: 20),
            const Text(
              "Doom Scroll Detected",
              style: TextStyle(fontFamily: 'DxSitrus', fontSize: 24, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(
              "You've been using $_appName for 10 minutes continuously.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  widget.onBlock();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text("Block for 30 min", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 15),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Ignore", style: TextStyle(color: Colors.grey)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
