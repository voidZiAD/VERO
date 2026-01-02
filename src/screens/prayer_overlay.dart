import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/prayer_service.dart';
import 'package:flutter/services.dart';

class PrayerOverlay extends StatefulWidget {
  final String prayerName;
  final VoidCallback onDismiss;

  const PrayerOverlay({super.key, required this.prayerName, required this.onDismiss});

  @override
  State<PrayerOverlay> createState() => _PrayerOverlayState();
}

class _PrayerOverlayState extends State<PrayerOverlay> {
  late Map<String, String> _quote;
  String _nextPrayer = "";
  
  int _countdown = 3;
  Timer? _timer;

  final List<Map<String, String>> _quotes = [
    {
      'arabic': 'ٱتْلُ مَآ أُوحِيَ إِلَيْكَ مِنَ ٱلْكِتَٰبِ وَأَقِمِ ٱلصَّلَوٰةَ ۖ إِنَّ ٱلصَّلَوٰةَ تَنْهَىٰ عَنِ ٱلْفَحْشَآءِ وَٱلْمُنْكَرِ',
      'english': 'Recite what has been revealed to you of the Book and establish prayer. Indeed, ˹genuine˺ prayer should deter ˹one˺ from indecency and wickedness. The remembrance of Allah is ˹an˺ even greater ˹deterrent˺. And Allah ˹fully˺ knows what you ˹all˺ do.',
      'source': 'Surah Al-‘Ankabut (29):45',
      'link': 'https://quran.com/29/45'
    },
    {
      'arabic': 'وَٱسْتَعِينُوا۟ بِٱلصَّبْرِ وَٱلصَّلَوٰةِ ۚ وَإِنَّهَا لَكَبِيرَةٌ ۢ إِلَّا عَلَى ٱلْخَـٰشِعِينَ',
      'english': 'And seek help through patience and prayer. Indeed, it is a burden except for the humble',
      'source': 'Surah Al-Baqarah (2):45',
      'link': 'https://quran.com/2/45'
    },
    {
      'arabic': 'إِنَّ ٱلْحَسَنَٰتِ يُذْهِبْنَ ٱلسَّيِّئَاتِ ۚ ذَٰلِكَ ذِكْرَىٰ لِلذَّاكِرِينَ',
      'english': 'Surely good deeds wipe out evil deeds. That is a reminder for the mindful.',
      'source': 'Surah Hud (11):114',
      'link': 'https://quran.com/11/114'
    },
    {
      'arabic': 'قَدْ أَفْلَحَ ٱلْمُؤْمِنُونَ ٱلَّذِينَ هُمْ فِي صَلَاتِهِمْ خَاشِعُونَ',
      'english': 'Successful indeed are the believers: those who humble themselves in prayer.',
      'source': 'Surah Al-Mu’minun (23):1-2',
      'link': 'https://quran.com/23/1-2'
    }
  ];

  @override
  void initState() {
    super.initState();
    _quote = _quotes[Random().nextInt(_quotes.length)];
    _nextPrayer = PrayerService().getNextPrayerInfo();
    _startCountdown();
  }

  void _startCountdown() {
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

  Future<void> _markPrayed() async {
    HapticFeedback.heavyImpact(); 
    await PrayerService().markAsPrayed(widget.prayerName);
    widget.onDismiss();
  }

  Future<void> _openLink(String url) async {
    HapticFeedback.lightImpact(); 
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool canDismiss = _countdown == 0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF001A0F), Colors.black], 
          ),
        ),
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("VERO", style: TextStyle(fontFamily: 'DxSitrus', fontSize: 40, color: Colors.white)),
            const SizedBox(height: 40),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.greenAccent.withOpacity(0.3))
              ),
              child: const Icon(Icons.mosque, size: 60, color: Colors.greenAccent),
            ),
            const SizedBox(height: 30),
            
            Text(
              "It's time for ${widget.prayerName}",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(
              "Next: $_nextPrayer",
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 40),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  Text(
                    _quote['arabic']!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, color: Colors.white, fontFamily: 'Arial'), 
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _quote['english']!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.white70, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 15),
                  GestureDetector(
                    onTap: () => _openLink(_quote['link']!),
                    child: Text(
                      _quote['source']!,
                      style: const TextStyle(fontSize: 12, color: Colors.greenAccent, decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),
            
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: canDismiss ? _markPrayed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canDismiss ? Colors.white : Colors.grey[800],
                  foregroundColor: canDismiss ? Colors.black : Colors.white38,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: Text(
                  canDismiss ? "I have prayed" : "Wait ${_countdown}s",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
