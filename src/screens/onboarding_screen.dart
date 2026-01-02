import 'dart:ui';
import 'package:flutter/material.dart';
import 'setup_screen.dart'; 
import 'package:flutter/services.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late AnimationController _orbController;
  int _currentPage = 0;

  int? _selectedScreenTimeIndex;
  int? _selectedAgeIndex;

  String _calculatedLoss = "-- YEARS";
  String _calculatedGain = "-- YEARS";

  final List<String> _screenTimeOptions = [
    "< 1 hr", "1-3 hrs", "3-5 hrs", "5-7 hrs", "7+ hrs"
  ];

  final List<String> _ageOptions = [
    "<18", "18-24", "25-34", "35-44", "45+"
  ];

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _orbController.dispose();
    super.dispose();
  }

  void _calculateStats() {
    if (_selectedScreenTimeIndex == null || _selectedAgeIndex == null) return;

    final double dailyHours = [0.5, 2.0, 4.0, 6.0, 9.0][_selectedScreenTimeIndex!];

    final int currentAge = [16, 21, 30, 40, 55][_selectedAgeIndex!];
    
    final int remainingYears = 80 - currentAge;
    if (remainingYears <= 0) {
      _calculatedLoss = "0 YEARS";
      _calculatedGain = "0 YEARS";
      return;
    }

    final double lossYears = (dailyHours / 16) * remainingYears;

    final double gainYears = lossYears * 0.50;

    setState(() {
      _calculatedLoss = "${lossYears.toStringAsFixed(1)} YEARS";
      _calculatedGain = "${gainYears.toStringAsFixed(1)} YEARS";
    });
  }

  void _nextPage() {
    HapticFeedback.mediumImpact(); 
  if (_currentPage == 1) {
    if (_selectedScreenTimeIndex == null) {
      _showError("Please select your average screen time.");
      return;
    }
  }

  if (_currentPage == 2) {
    if (_selectedAgeIndex == null) {
      _showError("Please select your age group.");
      return;
    }
    _calculateStats();
  }

  if (_currentPage < 4) {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 800),
      curve: Curves.fastLinearToSlowEaseIn,
    );
  } else {
    final selectedAge = _ageOptions[_selectedAgeIndex!];
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SetupScreen(ageGroup: selectedAge),
      ),
    );
  }
}


  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent, duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F0518), Colors.black],
                ),
              ),
            ),
          ),
          
          AnimatedBuilder(
            animation: _orbController,
            builder: (context, child) {
              return AnimatedPositioned(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOut,
                top: _currentPage % 2 == 0 ? -100 : MediaQuery.of(context).size.height * 0.4,
                left: _currentPage % 2 == 0 ? -50 : MediaQuery.of(context).size.width * 0.5,
                child: Container(
                  width: 400, height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Colors.purpleAccent.withOpacity(0.4), Colors.transparent],
                      radius: 0.7,
                    ),
                  ),
                ),
              );
            },
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("VERO", style: TextStyle(fontFamily: 'DxSitrus', fontSize: 24, color: Colors.white)),
                      Row(
                        children: List.generate(5, (index) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(left: 6),
                            height: 4,
                            width: _currentPage == index ? 24 : 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index ? Colors.purpleAccent : Colors.white24,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      )
                    ],
                  ),
                ),

                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (p) => setState(() => _currentPage = p),
                    children: [
                      _buildIntroPage(),
                      _buildGridSelectionPage(
                        "Screen Time",
                        "Be honest.",
                        _screenTimeOptions,
                        _selectedScreenTimeIndex,
                        (i) => setState(() => _selectedScreenTimeIndex = i),
                      ),
                      _buildHorizontalSelectionPage(
                        "Age Group",
                        "Tailoring your experience.",
                        _ageOptions,
                        _selectedAgeIndex,
                        (i) => setState(() => _selectedAgeIndex = i),
                      ),
                      _buildImpactPage(),
                      _buildGainPage(),
                    ],
                  ),
                ),

                _buildBottomBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _currentPage == 0 ? "Start Journey" : "Next Step",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                GestureDetector(
                  onTap: _nextPage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_forward, color: Colors.black),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntroPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("RECLAIM\nYOUR\nFOCUS", style: TextStyle(fontFamily: 'DxSitrus', fontSize: 64, color: Colors.white, height: 0.9)),
          const SizedBox(height: 20),
          Text("Don't let the algorithm control you.\nTake back your time with VERO.", style: TextStyle(fontSize: 18, color: Colors.white.withOpacity(0.7), height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildGridSelectionPage(String title, String sub, List<String> opts, int? selected, Function(int) onSelect) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontFamily: 'DxSitrus', fontSize: 40, color: Colors.white)),
          Text(sub, style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.5))),
          const SizedBox(height: 40),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(opts.length, (index) {
              final isSelected = selected == index;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelect(index);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.purpleAccent : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? Colors.purpleAccent : Colors.white12),
                  ),
                  child: Text(opts[index], style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.white70)),
                ),
              );
            }),
          )
        ],
      ),
    );
  }

  Widget _buildHorizontalSelectionPage(String title, String sub, List<String> opts, int? selected, Function(int) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(title, style: const TextStyle(fontFamily: 'DxSitrus', fontSize: 40, color: Colors.white)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(sub, style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.5))),
        ),
        const SizedBox(height: 40),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: opts.length,
            itemBuilder: (context, index) {
              final isSelected = selected == index;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelect(index);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 120,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? Colors.white : Colors.white12),
                  ),
                  child: Center(
                    child: Text(opts[index], style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isSelected ? Colors.black : Colors.white)),
                  ),
                ),
              );
            },
          ),
        )
      ],
    );
  }

  Widget _buildImpactPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                const Text("YOUR POTENTIAL LOSS", style: TextStyle(fontSize: 12, letterSpacing: 2, color: Colors.grey)),
                const SizedBox(height: 10),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(colors: [Colors.redAccent, Colors.orangeAccent]).createShader(bounds),
                  child: Text(_calculatedLoss, style: const TextStyle(fontFamily: 'DxSitrus', fontSize: 56, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
                const Text("spent looking at screens.", textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGainPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.purpleAccent.withOpacity(0.1), 
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Text("YOUR POTENTIAL GAIN", style: TextStyle(fontSize: 12, letterSpacing: 2, color: Colors.white70)),
                const SizedBox(height: 10),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(colors: [Colors.purpleAccent, Colors.cyanAccent]).createShader(bounds),
                  child: Text(_calculatedGain, style: const TextStyle(fontFamily: 'DxSitrus', fontSize: 56, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
                const Text("reclaimed for your dreams.", textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
