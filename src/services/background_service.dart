import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../firebase_options.dart'; 

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    print("Background Service Firebase Init Error: $e");
  }

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  _startBackgroundPartnerListener(flutterLocalNotificationsPlugin);

  service.on('stopService').listen((event) {
    service.stopSelf();
  });
}

void _startBackgroundPartnerListener(FlutterLocalNotificationsPlugin notifPlugin) async {
  try {
    final auth = FirebaseAuth.instance;
    await Future.delayed(const Duration(seconds: 2));
    
    final user = auth.currentUser;
    if (user == null) {
        print("VERO Background: No user logged in.");
        return;
    }

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('partner_notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        
        notifPlugin.show(
          doc.id.hashCode, 
          data['title'] ?? "Accountability Update",
          data['body'] ?? "Check VERO for details.",
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'vero_partner', 
              'Accountability',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );

        doc.reference.update({'read': true});
      }
    }, onError: (e) {
      print("VERO Background Listener Error: $e");
    });
    
  } catch (e) {
    print("VERO Background Setup Error: $e");
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

class BackgroundService {
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true, 
        isForegroundMode: false, 
        notificationChannelId: 'vero_service_dart', 
        initialNotificationTitle: 'VERO Service',
        initialNotificationContent: 'Running in background',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }
}
