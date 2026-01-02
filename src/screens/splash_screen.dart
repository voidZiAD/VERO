import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'home_screen.dart';
import 'onboarding_screen.dart';
import 'blocking_overlay.dart'; 
import 'prayer_overlay.dart'; 
import '../services/block_service.dart';
import '../services/auth_service.dart';
import '../services/widget_service.dart'; 
import '../screens/reminder_alarm_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(seconds: 1), 
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 100.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _checkLaunch();
  }

  Future<void> _checkAndStartService() async {
    if (await Permission.location.isGranted && 
        await Permission.notification.isGranted) {
      final service = FlutterBackgroundService();
      if (!(await service.isRunning())) {
        await service.startService();
      }
    }
  }

  Future<void> _checkLaunch() async {
    await _checkAndStartService();

    final blockService = BlockService();
    await blockService.init();

    final String? blockedApp = await blockService.getStartupBlockedApp();
    final String? prayerName = await blockService.getStartupPrayer();
    final String? reminderTitle = await blockService.getStartupReminder();

    if (!mounted) return;

    if (reminderTitle != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ReminderAlarmScreen(title: reminderTitle))
      );
      return; 
    }

    if (blockedApp != null) {
      BlockSession? session;
      try {
        session = blockService.blocks.firstWhere((b) => b.isActive && b.appPackages.contains(blockedApp));
      } catch (_) {}

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => BlockingOverlay(
            appName: blockedApp,
            session: session,
            onRefocus: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const HomeScreen())
              );
            },
            onStopSession: () async {
              if (session != null) {
                await blockService.stopSession(session.id, earlyExit: true, wasCompleted: false);
              }
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const HomeScreen())
                );
              }
            },
          ),
          transitionDuration: Duration.zero,
        ),
      );
      return; 
    } 
    else if (prayerName != null) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => PrayerOverlay(
            prayerName: prayerName,
            onDismiss: () async {
              await blockService.setPrayerReminded(prayerName);
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const HomeScreen())
              );
            },
          ),
          transitionDuration: Duration.zero,
        ),
      );
      return; 
    }

    _startNormalSplash();
  }


  void _startNormalSplash() {
    if (mounted) _controller.forward();

    Future.delayed(const Duration(seconds: 2), () async {
      if (!mounted) return;

      final authService = AuthService();
      final prefs = await SharedPreferences.getInstance();
      final bool isSetupComplete = prefs.getBool('setup_complete') ?? false;

      Widget destination;

      if (authService.currentUser != null) {
        if (authService.isEmailVerified) {
          if (isSetupComplete) {
            await WidgetService().updateAuthStatus(true);
            
            try {
              final doc = await FirebaseFirestore.instance.collection('users').doc(authService.currentUser!.uid).get();
              if (doc.exists) {
                int streak = doc.data()?['dayStreak'] ?? 0;
                await WidgetService().updateStreak(streak);
              }
            } catch (e) {
              print("Splash DB Error: $e");
            }
            
            destination = const HomeScreen();
          } else {
            await authService.signOut();
            await prefs.clear();
            destination = const OnboardingScreen();
          }
        } else {
          await authService.signOut();
          await prefs.clear();
          destination = const OnboardingScreen();
        }
      } else {
        await WidgetService().updateAuthStatus(false);
        destination = const OnboardingScreen();
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, __, ___) => destination,
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
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
      body: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          alignment: const Alignment(0.78, -0.13),
          child: const Text(
            "VERO",
            style: TextStyle(
              fontFamily: 'DxSitrus',
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 4,
            ),
          ),
        ),
      ),
    );
  }
}
