import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrayerService {
  static final PrayerService _instance = PrayerService._internal();
  factory PrayerService() => _instance;
  PrayerService._internal();

  Map<String, dynamic>? _prayerTimings;
  DateTime? _lastFetch;
  
  bool isEnabled = false;
  bool alwaysRemind = false; 
  List<String> activePrayers = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    isEnabled = prefs.getBool('prayer_reminders_enabled') ?? false;
    alwaysRemind = prefs.getBool('prayer_always_remind') ?? false;
    activePrayers = prefs.getStringList('selected_prayers') ?? ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"];
    
    await clearOldReminders();
    
    if (isEnabled) {
      await _fetchPrayerTimes();
    }
  }

  Future<void> updateSettings(bool enabled, bool always, List<String> prayers) async {
    final prefs = await SharedPreferences.getInstance();
    isEnabled = enabled;
    alwaysRemind = always;
    activePrayers = prayers;
    
    await prefs.setBool('prayer_reminders_enabled', enabled);
    await prefs.setBool('prayer_always_remind', always);
    await prefs.setStringList('selected_prayers', prayers);
    
    if (enabled && _prayerTimings == null) {
      await _fetchPrayerTimes();
    }
  }

  Future<Map<String, DateTime>?> getTimingsMap() async {
    if (_prayerTimings == null) await _fetchPrayerTimes();
    if (_prayerTimings == null) return null;
    
    Map<String, DateTime> schedule = {};
    _prayerTimings!.forEach((k, v) {
      if (["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"].contains(k)) {
        schedule[k] = _parseTime(v);
      }
    });
    return schedule;
  }

  Future<void> _fetchPrayerTimes() async {
    try {
      double? lat;
      double? long;

      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission != LocationPermission.denied && permission != LocationPermission.deniedForever) {
          Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
          lat = position.latitude;
          long = position.longitude;
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble('cached_lat', lat);
          await prefs.setDouble('cached_long', long);
        }
      } catch (e) {
        print("Geolocator failed (likely in background): $e");
      }

      if (lat == null || long == null) {
        final prefs = await SharedPreferences.getInstance();
        lat = prefs.getDouble('cached_lat');
        long = prefs.getDouble('cached_long');
      }

      if (lat == null || long == null) return;

      final date = DateTime.now();
      final String dateStr = "${date.day}-${date.month}-${date.year}";
      
      final url = Uri.parse(
          "http://api.aladhan.com/v1/timings/$dateStr?latitude=$lat&longitude=$long&method=2");
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _prayerTimings = data['data']['timings'];
        _lastFetch = DateTime.now();
      }
    } catch (e) {
      print("Prayer API Error: $e");
    }
  }

  Future<String?> getCurrentActivePrayer() async {
    if (!isEnabled || _prayerTimings == null) {
      if (isEnabled) await _fetchPrayerTimes();
      if (_prayerTimings == null) return null;
    }

    final now = DateTime.now();
    Map<String, DateTime> schedule = {};
    _prayerTimings!.forEach((k, v) {
      if (["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"].contains(k)) {
        schedule[k] = _parseTime(v);
      }
    });

    var sorted = schedule.entries.toList()..sort((a, b) => a.value.compareTo(b.value));

    for (int i = 0; i < sorted.length; i++) {
      final current = sorted[i];
      DateTime end;

      if (i + 1 < sorted.length) {
        end = sorted[i + 1].value;
      } else {
        end = current.value.add(const Duration(hours: 4)); 
      }

      if (now.isAfter(current.value) && now.isBefore(end)) {
        String currentPeriod = current.key;

        if (currentPeriod == "Sunrise") return null;

        if (activePrayers.contains(currentPeriod)) {
          return currentPeriod; 
        }
      }
    }
    return null;
  }

  Future<bool> isPrayerReminded(String prayer) async {
    final prefs = await SharedPreferences.getInstance();
    final today = "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";
    return prefs.getBool('reminded_${prayer}_$today') ?? false;
  }

  Future<void> setPrayerReminded(String prayer) async {
    final prefs = await SharedPreferences.getInstance();
    final today = "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";
    await prefs.setBool('reminded_${prayer}_$today', true);
  }
  
  Future<void> clearOldReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final today = "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";
    
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('reminded_') && !key.endsWith('_$today')) {
        await prefs.remove(key);
      }
    }
  }

  String getNextPrayerInfo() {
    if (_prayerTimings == null) return "";
    final now = DateTime.now();
    
    Map<String, DateTime> sorted = {};
    _prayerTimings!.forEach((k, v) {
      if (["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"].contains(k)) {
        sorted[k] = _parseTime(v);
      }
    });

    String nextName = "";
    DateTime? nextTime;

    var entries = sorted.entries.toList()..sort((a, b) => a.value.compareTo(b.value));

    for (var entry in entries) {
      if (entry.value.isAfter(now)) {
        nextName = entry.key;
        nextTime = entry.value;
        break;
      }
    }

    if (nextTime == null) {
      nextName = "Fajr";
      return "Fajr is tomorrow";
    }

    final diff = nextTime.difference(now);
    return "$nextName in ${diff.inHours}h ${diff.inMinutes % 60}m";
  }

  DateTime _parseTime(String time) {
    final now = DateTime.now();
    final parts = time.split(':');
    return DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
  }

  Future<void> markAsPrayed(String prayer) async {
    await setPrayerReminded(prayer);
  }
}
