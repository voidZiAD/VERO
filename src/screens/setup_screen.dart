import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:device_apps/device_apps.dart';
import 'package:flutter_background_service/flutter_background_service.dart'; 
import 'home_screen.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/block_service.dart';
import 'package:uuid/uuid.dart';
import 'dart:math' as math;

class SetupScreen extends StatefulWidget {
  final String? ageGroup;
  
  const SetupScreen({super.key, this.ageGroup});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}


class _SetupScreenState extends State<SetupScreen> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController(); 
  
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  
  bool _isAuthLoading = false;
  
  static const platform = MethodChannel('com.example.vero/settings');

  int _currentPage = 0;
  
  bool _notificationGranted = false;
  bool _accessibilityGranted = false;
  bool _overlayGranted = false;
  bool _usageGranted = false;
  bool _batteryGranted = false; 
  bool _permissionsChecked = false;

  bool _isLoadingApps = true;
  bool _hasStartedFetchingApps = false; 
  List<Application> _installedApps = [];
  final List<String> _selectedPackageNames = [];
  final List<String> _selectedUrls = [];
  final List<Map<String, String>> _customWebsites = [];
  int _tabIndex = 0; 
  String _searchQuery = ""; 

  String _dailyTimeStr = "Calculating..."; 
  String _dailyPercentStr = "...";         
  
  String _savedTimeStr = "...";            
  String _savedPercentStr = "30%";         

  bool _calculatingStats = true;
  double _percentValue = 0.0; 

  final List<Map<String, String>> _defaultWebsites = [
    {'name': 'Facebook', 'url': 'facebook.com', 'icon': 'assets/web_icons/facebook.png'},
    {'name': 'Instagram', 'url': 'instagram.com', 'icon': 'assets/web_icons/instagram.png'},
    {'name': 'Reddit', 'url': 'reddit.com', 'icon': 'assets/web_icons/reddit.png'},
    {'name': 'Twitter / X', 'url': 'x.com', 'icon': 'assets/web_icons/x.png'},
    {'name': 'YouTube', 'url': 'youtube.com', 'icon': 'assets/web_icons/youtube.png'},
    {'name': 'TikTok', 'url': 'tiktok.com', 'icon': 'assets/web_icons/tiktok.png'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions(); 
    _calculateUsageStats(); 
    
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase().trim();
      });
    });
  }

  Future<void> _checkPermissions() async {
    _notificationGranted = await _checkNotificationPermission();
    _accessibilityGranted = await _checkAccessibilityPermission();
    _overlayGranted = await Permission.systemAlertWindow.isGranted;
    _usageGranted = await _checkUsagePermission();
    _batteryGranted = await Permission.ignoreBatteryOptimizations.isGranted; 
    
    if (mounted) {
      setState(() {
        _permissionsChecked = true;
      });
    }
  }

  List<Widget> get _pages {
    List<Widget> pages = [];

    pages.add(_buildLoginPage());
    pages.add(_buildSignupPage());
    pages.add(_buildVerificationPage());

    if (!_notificationGranted || !_accessibilityGranted || !_overlayGranted || !_usageGranted || !_batteryGranted) {
      pages.add(_buildPermissionsGatePage());

      if (!_notificationGranted) {
        pages.add(_buildPermissionPage(
          icon: Icons.notifications_active,
          title: "Allow VERO to Block\nNotifications",
          subtitle: "So you are not interrupted during your most important moments.",
          step1: "Find 'VERO' in the list",
          step2: "Toggle switch to Allow",
          buttonText: "Grant Permission",
          onAction: _openNotificationListenerSettings,
        ));
      }

      if (!_accessibilityGranted) {
        pages.add(_buildPermissionPage(
          icon: Icons.accessibility_new,
          title: "Enable Accessibility\nPermission",
          subtitle: "Required to detect and block distracting apps instantly.",
          step1: "Find 'VERO' in Installed Services",
          step2: "Tap it, then select Allow",
          buttonText: "Open Settings",
          onAction: _openAccessibilitySettings,
        ));
      }

      if (!_overlayGranted) {
        pages.add(_buildPermissionPage(
          icon: Icons.layers,
          title: "Display Over\nOther Apps",
          subtitle: "Allows VERO to show the block screen when you open a restricted app.",
          step1: "Find 'VERO' in the list of apps",
          step2: "Select 'Display over other apps'",
          buttonText: "Enable Overlay",
          onAction: _openOverlaySettings,
        ));
      }

      if (!_usageGranted) {
        pages.add(_buildPermissionPage(
          icon: Icons.data_usage,
          title: "Permit Usage\nAccess",
          subtitle: "Needed to measure your screen time and progress accurately.",
          step1: "Find 'VERO' in the list of apps",
          step2: "Select 'Permit usage access'",
          buttonText: "Grant Access",
          onAction: _openUsageSettings,
        ));
      }

      if (!_batteryGranted) {
        pages.add(_buildPermissionPage(
          icon: Icons.battery_alert,
          title: "Ignore Battery\nOptimization",
          subtitle: "Required to keep the timer running when the app is closed for long periods.",
          step1: "Select 'Allow' in the popup",
          step2: "This prevents Android from killing VERO",
          buttonText: "Disable Optimization",
          onAction: _requestBatteryOptimization,
        ));
      }
    }

    pages.add(_buildAppSelectionPage());
    pages.add(_buildAnalysisPage(isBadNews: true));
    pages.add(_buildAnalysisPage(isBadNews: false));
    pages.add(_buildFeaturesPage());
    pages.add(_buildPlanPage());

    return pages;
  }

  Widget _buildPermissionsGatePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shield, size: 80, color: Colors.purpleAccent),
          const SizedBox(height: 30),
          const Text(
            "Permissions Required",
            style: TextStyle(fontFamily: 'DxSitrus', fontSize: 32, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          const Text(
            "VERO needs certain permissions to work properly. "
            "Please grant the required permissions in the next steps to continue.",
            style: TextStyle(fontSize: 16, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 50),
          _buildActionButton("Continue", _nextPage),
        ],
      ),
    );
  }


  Future<bool> _checkNotificationPermission() async {
    try {
      return await platform.invokeMethod('checkNotificationListener');
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkAccessibilityPermission() async {
    try {
      return await platform.invokeMethod('checkAccessibility');
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkUsagePermission() async {
    try {
      return await platform.invokeMethod('checkUsageAccess');
    } catch (e) {
      return false;
    }
  }

  Future<void> _requestBatteryOptimization() async {
    var status = await Permission.ignoreBatteryOptimizations.request();
    if (status.isGranted) {
      setState(() => _batteryGranted = true);
      _checkAndAdvance();
    } else {
      await openAppSettings();
    }
  }

 Future<void> _calculateUsageStats() async {
  setState(() {
    _calculatingStats = true;
    _dailyTimeStr = "Calculating...";
    _dailyPercentStr = "...";
  });

  try {
    final granted = await _checkUsagePermission();
    if (!granted) {
      setState(() {
        _dailyTimeStr = "7h 12m"; 
        _dailyPercentStr = "45%";
        _savedTimeStr = "2h 9m";
        _percentValue = 0.45;
        _calculatingStats = false;
      });
      return;
    }

    final end = DateTime.now();
    final start = end.subtract(const Duration(days: 7));

    final stats = await platform.invokeMethod('getAppUsageStats', {
      'start': start.millisecondsSinceEpoch,
      'end': end.millisecondsSinceEpoch,
    });

    int totalMs = (stats != null && stats['totalTime'] != null) ? stats['totalTime'] : 0;
    int dailyMs = (totalMs / 7).round();

    if (dailyMs < 60000) dailyMs = 7 * 60 * 60 * 1000; 

    Duration daily = Duration(milliseconds: dailyMs);
    double hours = dailyMs / (1000 * 60 * 60);
    double percent = (hours / 16.0).clamp(0.01, 1.0);

    int savedMs = (dailyMs * 0.30).round();
    Duration saved = Duration(milliseconds: savedMs);

    if (mounted) {
      setState(() {
        _dailyTimeStr = "${daily.inHours}h ${daily.inMinutes % 60}m";
        _dailyPercentStr = "${(percent * 100).round()}%"; 
        _savedTimeStr = "${saved.inHours}h ${saved.inMinutes % 60}m";
        _percentValue = percent;
        _calculatingStats = false;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _dailyTimeStr = "7h 12m";
        _dailyPercentStr = "45%";
        _savedTimeStr = "2h 9m";
        _percentValue = 0.45;
        _calculatingStats = false;
      });
    }
  }
}

  List<Application> get _filteredApps {
    if (_searchQuery.isEmpty) return _installedApps;
    return _installedApps.where((app) => 
      app.appName.toLowerCase().contains(_searchQuery)
    ).toList();
  }

  List<Map<String, String>> get _filteredWebsites {
    final allSites = [..._customWebsites, ..._defaultWebsites];
    if (_searchQuery.isEmpty) return allSites;
    return allSites.where((site) => 
      site['name']!.toLowerCase().contains(_searchQuery) || 
      site['url']!.toLowerCase().contains(_searchQuery)
    ).toList();
  }

  Future<void> _fetchInstalledApps() async {
    if (_hasStartedFetchingApps) return; 
    _hasStartedFetchingApps = true;

    final apps = await DeviceApps.getInstalledApplications(
      includeAppIcons: true,
      includeSystemApps: false,
      onlyAppsWithLaunchIntent: true,
    );
    
    apps.sort((a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));

    const socialPackages = [
      'com.instagram.android', 'com.facebook.katana', 'com.zhiliaoapp.musically',
      'com.snapchat.android', 'com.twitter.android', 'com.google.android.youtube',
      'com.whatsapp', 'com.reddit.frontpage',
    ];

    if (mounted) {
      setState(() {
        _installedApps = apps;
        for (var app in apps) {
          if (socialPackages.contains(app.packageName)) {
            _selectedPackageNames.add(app.packageName);
          }
        }
        _isLoadingApps = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndAdvance();
    }
  }

  Future<void> _checkAndAdvance() async {
    bool shouldAdvance = false;

    if (mounted) {
      bool oldNotificationGranted = _notificationGranted;
      bool oldAccessibilityGranted = _accessibilityGranted;
      bool oldOverlayGranted = _overlayGranted;
      bool oldUsageGranted = _usageGranted;
      bool oldBatteryGranted = _batteryGranted; 

      _notificationGranted = await _checkNotificationPermission();
      _accessibilityGranted = await _checkAccessibilityPermission();
      _overlayGranted = await Permission.systemAlertWindow.isGranted;
      _usageGranted = await _checkUsagePermission();
      _batteryGranted = await Permission.ignoreBatteryOptimizations.isGranted; 

      if ((!oldNotificationGranted && _notificationGranted) ||
          (!oldAccessibilityGranted && _accessibilityGranted) ||
          (!oldOverlayGranted && _overlayGranted) ||
          (!oldUsageGranted && _usageGranted) ||
          (!oldBatteryGranted && _batteryGranted)) { 
        shouldAdvance = true;
      }
    }

    if (shouldAdvance) {
      if (_notificationGranted && _accessibilityGranted && 
          _overlayGranted && _usageGranted && _batteryGranted) {
         final service = FlutterBackgroundService();
         if (!(await service.isRunning())) {
            await service.startService();
         }
      }

      await Future.delayed(const Duration(milliseconds: 300));
      setState(() {}); 

      int nextPageIndex = 3; 
      if (_notificationGranted) nextPageIndex++;
      if (_accessibilityGranted) nextPageIndex++;
      if (_overlayGranted) nextPageIndex++;
      if (_usageGranted) nextPageIndex++;
      if (_batteryGranted) nextPageIndex++; 

      final pages = _pages;
      if (nextPageIndex < pages.length) {
        _pageController.jumpToPage(nextPageIndex);
      } else {
        _nextPage();
      }
    }
  }

  Future<void> _completeSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('blocked_packages', _selectedPackageNames);
    
    await prefs.setString('blocked_urls', "LIST:${_selectedUrls.join(',')}");
    
    await prefs.setBool('setup_complete', true);

    final defaultSchedule = BlockSession(
      id: const Uuid().v4(),
      name: "Daily Focus",
      type: BlockType.schedule,
      startTime: const TimeOfDay(hour: 10, minute: 0),
      endTime: const TimeOfDay(hour: 16, minute: 0),
      days: ["M", "T", "W", "T", "F", "S", "S"], 
      appPackages: _selectedPackageNames,
      difficulty: BreakDifficulty.easy,
      colorValue: Colors.blueAccent.value,
      iconCodePoint: Icons.calendar_month.codePoint,
      blockWebsites: true,
    );

    await BlockService().addBlock(defaultSchedule);

    if (!mounted) return;
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(builder: (_) => const HomeScreen())
    );
  }

  void _nextPage() {
    final pages = _pages;
    if (_currentPage == 0 && AuthService().currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please sign in or create an account."),
          backgroundColor: Colors.redAccent,
        )
      );
      return;
    }

    if (_currentPage == 2 && !AuthService().isEmailVerified) { 
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please verify your email first."),
          backgroundColor: Colors.redAccent,
        )
      );
      return;
    }

    if (_currentPage < pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600), 
        curve: Curves.easeInOutCubic
      );
    } else {
      _completeSetup();
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isAuthLoading = true);
    
    try {
      final userCredential = await AuthService().signInWithGoogle();
      
      if (userCredential != null) {
        if (!mounted) return;
        
        await _checkPermissions();

        if (_usageGranted) {
          await _calculateUsageStats();
        }

        int nextPageIndex = 3; 
        if (_notificationGranted) nextPageIndex++;
        if (_accessibilityGranted) nextPageIndex++;
        if (_overlayGranted) nextPageIndex++;
        if (_usageGranted) nextPageIndex++;
        if (_batteryGranted) nextPageIndex++;
        
        final pages = _pages;
        if (nextPageIndex >= pages.length) {
          nextPageIndex = pages.length - 5; 
        }

        _pageController.jumpToPage(nextPageIndex);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isAuthLoading = false);
    }
  }

  Future<void> _handleLogin() async {
  final email = _emailController.text.trim();
  final password = _passwordController.text.trim();

  if (email.isEmpty || password.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Please fill in all fields."),
        backgroundColor: Colors.redAccent,
      ),
    );
    return;
  }

  setState(() => _isAuthLoading = true);

  try {
    await AuthService().signInWithEmail(email, password);

    if (!mounted) return;

    await _checkPermissions();

    if (_usageGranted) {
      await _calculateUsageStats();
    }

    int nextPageIndex = 3; 
    if (_notificationGranted) nextPageIndex++;
    if (_accessibilityGranted) nextPageIndex++;
    if (_overlayGranted) nextPageIndex++;
    if (_usageGranted) nextPageIndex++;
    if (_batteryGranted) nextPageIndex++; 
    
    final pages = _pages;
    if (nextPageIndex >= pages.length) {
      nextPageIndex = pages.length - 5; 
    }

    _pageController.jumpToPage(nextPageIndex);

  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString()),
        backgroundColor: Colors.redAccent,
      ),
    );
  } finally {
    if (mounted) setState(() => _isAuthLoading = false);
  }
}


  Future<void> _handleSignup() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Email and password are required."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (username.isEmpty || username.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Username must be at least 3 characters."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Username can only contain letters, numbers, and underscores (_). No spaces."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isAuthLoading = true);

    try {
      await AuthService().signUpWithEmail(email, password, username);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', username);

      if (widget.ageGroup != null) {
        await _saveAgeGroupToFirestore(widget.ageGroup!);
      }

      if (!mounted) return;

      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    } catch (e) {
      if (!mounted) return;
      String errorMessage = e.toString().replaceAll("Exception: ", "");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isAuthLoading = false);
    }
  }

  Future<void> _checkVerification() async {
    setState(() => _isAuthLoading = true);

    try {
      await AuthService().reloadUser();

      if (AuthService().isEmailVerified) {
        if (!mounted) return;
        _nextPage(); 
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Email not verified yet. Check your inbox."),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isAuthLoading = false);
    }
  }

  Future<void> _resendVerificationEmail() async {
    try {
      await AuthService().resendVerificationEmail();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Verification email sent!"),
          backgroundColor: Colors.greenAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _saveAgeGroupToFirestore(String ageGroup) async {
    try {
      final userId = AuthService().currentUser?.uid;
      if (userId == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'ageGroup': ageGroup});
    } catch (e) {
      print('Failed to save age group: $e');
    }
  }

  Future<void> _openNotificationListenerSettings() async {
    if (Platform.isAndroid) {
      const intent = AndroidIntent(action: 'android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS', flags: [Flag.FLAG_ACTIVITY_NEW_TASK]);
      await intent.launch();
    }
  }

  Future<void> _openAccessibilitySettings() async {
    if (Platform.isAndroid) {
      const intent = AndroidIntent(action: 'android.settings.ACCESSIBILITY_SETTINGS', flags: [Flag.FLAG_ACTIVITY_NEW_TASK]);
      await intent.launch();
    }
  }

  Future<void> _openOverlaySettings() async {
    if (Platform.isAndroid) {
      const intent = AndroidIntent(action: 'android.settings.action.MANAGE_OVERLAY_PERMISSION', data: 'package:com.example.vero', flags: [Flag.FLAG_ACTIVITY_NEW_TASK]);
      await intent.launch();
    }
  }

  Future<void> _openUsageSettings() async {
    if (Platform.isAndroid) {
      const intent = AndroidIntent(action: 'android.settings.USAGE_ACCESS_SETTINGS', flags: [Flag.FLAG_ACTIVITY_NEW_TASK]);
      await intent.launch();
    }
  }

  @override
Widget build(BuildContext context) {
  if (!_permissionsChecked) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(color: Colors.purpleAccent),
      ),
    );
  }

  final pages = _pages;
  final totalPages = pages.length;

  return Stack(
    children: [
      Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
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
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Row(
                      children: [
                        if (_currentPage > 0)
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            ),
                          ),
                        const Spacer(),
                        Row(
                          children: List.generate(
                            totalPages,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              height: 4,
                              width: _currentPage == index ? 20 : 6,
                              decoration: BoxDecoration(
                                color: _currentPage == index
                                    ? Colors.purpleAccent
                                    : Colors.white24,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (p) {
                        setState(() => _currentPage = p);

                        final appSelectionIndex = totalPages - 5;

                        if (p == appSelectionIndex) {
                           _fetchInstalledApps();
                        }

                        if (p == totalPages - 4 && _calculatingStats) {
                          _calculateUsageStats();
                        }
                      },
                      children: pages,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      if (_isAuthLoading)
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.75),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.white,
              ),
            ),
          ),
        ),
    ],
  );
}


  Widget _buildLoginPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "VERO", 
            style: TextStyle(fontFamily: 'DxSitrus', fontSize: 48, color: Colors.white), 
            textAlign: TextAlign.center
          ),
          const SizedBox(height: 10),
          const Text(
            "Welcome back", 
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center
          ),
          const SizedBox(height: 40),
          
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  hintText: "Email",
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                  prefixIcon: const Icon(Icons.email, color: Colors.white38),
                ),
              ),
            ),
          ),
          const SizedBox(height: 15),
          
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  hintText: "Password",
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                  prefixIcon: const Icon(Icons.lock, color: Colors.white38),
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
          
          _isAuthLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Column(
                children: [
                  _buildActionButton("Sign In", _handleLogin),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton.icon(
                      onPressed: _handleGoogleSignIn,
                      icon: const Icon(Icons.g_mobiledata, color: Colors.white, size: 28),
                      label: const Text("Continue with Google", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ),
                ],
              ),
          
          const SizedBox(height: 20),
          
          GestureDetector(
            onTap: () {
              _pageController.jumpToPage(1);
              _emailController.clear();
              _passwordController.clear();
              _usernameController.clear();
            },
            child: const Text(
              "Don't have an account? Sign up", 
              style: TextStyle(
                color: Colors.purpleAccent, 
                fontSize: 14, 
                fontWeight: FontWeight.bold
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignupPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "VERO", 
            style: TextStyle(fontFamily: 'DxSitrus', fontSize: 48, color: Colors.white), 
            textAlign: TextAlign.center
          ),
          const SizedBox(height: 10),
          const Text(
            "Create your account", 
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center
          ),
          const SizedBox(height: 40),
          
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  hintText: "Email",
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                  prefixIcon: const Icon(Icons.email, color: Colors.white38),
                ),
              ),
            ),
          ),
          const SizedBox(height: 15),
          
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  hintText: "Password",
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                  prefixIcon: const Icon(Icons.lock, color: Colors.white38),
                ),
              ),
            ),
          ),
          const SizedBox(height: 15),
          
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: TextField(
                controller: _usernameController,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  hintText: "Username",
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                  prefixIcon: const Icon(Icons.person, color: Colors.white38),
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
          
          _isAuthLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Column(
                children: [
                  _buildActionButton("Create Account", _handleSignup),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton.icon(
                      onPressed: _handleGoogleSignIn,
                      icon: const Icon(Icons.g_mobiledata, color: Colors.white, size: 28),
                      label: const Text("Continue with Google", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ),
                ],
              ),
          
          const SizedBox(height: 20),
          
          GestureDetector(
            onTap: () {
              _pageController.jumpToPage(0);
              _emailController.clear();
              _passwordController.clear();
              _usernameController.clear();
            },
            child: const Text(
              "Already have an account? Sign in",
              style: TextStyle(
                color: Colors.purpleAccent, 
                fontSize: 14, 
                fontWeight: FontWeight.bold
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.mark_email_read, size: 80, color: Colors.purpleAccent),
          const SizedBox(height: 30),
          const Text(
            "Verify Your Email",
            style: TextStyle(fontFamily: 'DxSitrus', fontSize: 32, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            "We sent a verification link to:\n${_emailController.text}",
            style: const TextStyle(fontSize: 16, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          _buildGlassCard(
            child: Column(
              children: const [
                Row(
                  children: [
                    Text("1", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    SizedBox(width: 15),
                    Expanded(child: Text("Open your email inbox", style: TextStyle(color: Colors.white))),
                  ],
                ),
                SizedBox(height: 15),
                Row(
                  children: [
                    Text("2", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    SizedBox(width: 15),
                    Expanded(child: Text("Click the verification link", style: TextStyle(color: Colors.white))),
                  ],
                ),
                SizedBox(height: 15),
                Row(
                  children: [
                    Text("3", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    SizedBox(width: 15),
                    Expanded(child: Text("Come back and tap 'I've Verified'", style: TextStyle(color: Colors.white))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          _buildActionButton("I've Verified", _checkVerification),
          const SizedBox(height: 20),
          TextButton(
            onPressed: _resendVerificationEmail,
            child: const Text(
              "Resend Email",
              style: TextStyle(color: Colors.purpleAccent, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppSelectionPage() {
    if (_installedApps.isEmpty && _isLoadingApps && !_hasStartedFetchingApps) {
      _fetchInstalledApps();
    }

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            "Select Apps to Block",
            style: TextStyle(fontFamily: 'DxSitrus', fontSize: 28, color: Colors.white),
            textAlign: TextAlign.center
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "Select the apps that distract you the most.",
          style: TextStyle(color: Colors.grey, fontSize: 14)
        ),
        const SizedBox(height: 20),
        
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(25)
          ),
          child: Row(
            children: [
              _buildTabButton("Apps ${_selectedPackageNames.length}", 0),
              _buildTabButton("Websites ${_selectedUrls.length}", 1),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15)
            ),
            child: TextField(
              controller: _searchController, 
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                icon: Icon(Icons.search, color: Colors.grey),
                hintText: "Search apps or URLs...",
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        Expanded(
          child: _tabIndex == 0 ? _buildAppList() : _buildWebsiteList(),
        ),

        Padding(
          padding: const EdgeInsets.all(24),
          child: _buildActionButton("Confirm Selection", () {
            _calculateUsageStats();
            _nextPage();
          }),
        )
      ],
    );
  }

  Widget _buildTabButton(String text, int index) {
    bool isSelected = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick(); 
          setState(() {
            _tabIndex = index;
            _searchController.clear(); 
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppList() {
    if (_isLoadingApps) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.purpleAccent)
      );
    }
    
    final apps = _filteredApps;
    if (apps.isEmpty) {
      return const Center(
        child: Text("No apps found", style: TextStyle(color: Colors.grey))
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      itemCount: apps.length,
      itemBuilder: (context, index) {
        Application app = apps[index];
        bool isSelected = _selectedPackageNames.contains(app.packageName);
        return ListTile(
          leading: app is ApplicationWithIcon 
            ? Image.memory(app.icon, width: 32) 
            : const Icon(Icons.android, color: Colors.white),
          title: Text(app.appName, style: const TextStyle(color: Colors.white)),
          trailing: _buildCheckbox(isSelected),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              if (isSelected) {
                _selectedPackageNames.remove(app.packageName);
              } else {
                _selectedPackageNames.add(app.packageName);
              }
            });
          },
        );
      },
    );
  }

  Widget _buildWebsiteList() {
    final sites = _filteredWebsites;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      children: [
        if (_searchQuery.isNotEmpty && !sites.any((s) => s['url'] == _searchQuery))
          ListTile(
            leading: const Icon(Icons.add_circle, color: Colors.purpleAccent),
            title: Text(
              "Add & Block '$_searchQuery'",
              style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)
            ),
            onTap: () {
              setState(() {
                _customWebsites.add({'name': _searchQuery, 'url': _searchQuery, 'icon': ''});
                _selectedUrls.add(_searchQuery);
                _searchController.clear();
              });
            },
          ),
        ...sites.map((site) {
          final url = site['url']!;
          bool isSelected = _selectedUrls.contains(url);
          return ListTile(
            leading: (site['icon'] != null && site['icon']!.isNotEmpty)
              ? Image.asset(
                  site['icon']!,
                  width: 24,
                  height: 24,
                  errorBuilder: (c, o, s) => const Icon(Icons.public, color: Colors.white)
                )
              : const Icon(Icons.public, color: Colors.white),
            title: Text(url, style: const TextStyle(color: Colors.white)),
            trailing: _buildCheckbox(isSelected),
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedUrls.remove(url);
                } else {
                  _selectedUrls.add(url);
                }
              });
            },
          );
        }).toList(),
      ],
    );
  }

  Widget _buildCheckbox(bool isSelected) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white),
      ),
      child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.black) : null,
    );
  }
  
  Widget _buildPermissionPage({
    required IconData icon,
    required String title,
    required String subtitle,
    required String step1,
    required String step2,
    required String buttonText,
    required VoidCallback onAction
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.purpleAccent),
          const SizedBox(height: 30),
          Text(
            title,
            style: const TextStyle(fontFamily: 'DxSitrus', fontSize: 28, color: Colors.white),
            textAlign: TextAlign.center
          ),
          const SizedBox(height: 20),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 16, color: Colors.white70),
            textAlign: TextAlign.center
          ),
          const SizedBox(height: 50),
          _buildGlassCard(
            child: Row(
              children: [
                const Text("1", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(width: 15),
                Expanded(child: Text(step1, style: const TextStyle(color: Colors.white)))
              ]
            )
          ),
          const SizedBox(height: 10),
          _buildGlassCard(
            child: Row(
              children: [
                const Text("2", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(width: 15),
                Expanded(child: Text(step2, style: const TextStyle(color: Colors.white)))
              ]
            )
          ),
          const SizedBox(height: 40),
          _buildActionButton(buttonText, onAction),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _nextPage,
            child: const Text("I have enabled it", style: TextStyle(color: Colors.grey))
          )
        ]
      )
    );
  }
  
  Widget _buildAnalysisPage({required bool isBadNews}) {
  final color = isBadNews ? const Color(0xFFFF4B4B) : const Color(0xFF00FFA3);

  final displayTime = _calculatingStats
      ? "Calculating..."
      : (isBadNews ? _dailyTimeStr : _savedTimeStr);

  final displayPercent = _calculatingStats
      ? "..."
      : (isBadNews ? _dailyPercentStr : _savedPercentStr);

  final label = isBadNews ? "WASTED" : "RECLAIMED";

  final topApps = _selectedPackageNames.take(4).toList();
  final appCount = topApps.isEmpty ? 4 : topApps.length;

  List<double> segmentWeights;
  List<double> iconSegmentWeights;
  
  if (isBadNews) {
    segmentWeights = [1.8, 1.4, 1.0, 0.8].take(appCount).toList();
    iconSegmentWeights = segmentWeights;
  } else {
    final appWeights = [1.8, 1.4, 1.0, 0.8].take(appCount).map((w) => w * 0.7).toList();
    final totalAppWeight = appWeights.fold(0.0, (sum, w) => sum + w);
    final greenWeight = totalAppWeight * (0.30 / 0.70);
    segmentWeights = [...appWeights, greenWeight];
    iconSegmentWeights = appWeights;
  }

  final progressValue = _calculatingStats ? null : 1.0;

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isBadNews ? "Last week, you spent" : "A week with VERO can",
          style: const TextStyle(fontSize: 18, color: Colors.white70, letterSpacing: 1),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          isBadNews ? "$displayPercent of your time daily" : "save $displayPercent of your time daily",
          style: TextStyle(
            fontSize: 28,
            color: color,
            fontWeight: FontWeight.bold,
            fontFamily: 'DxSitrus',
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 50),
        SizedBox(
          height: 280,
          width: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (progressValue == null)
                SizedBox(
                  height: 280,
                  width: 280,
                  child: CircularProgressIndicator(
                    strokeWidth: 25,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              else
                CustomPaint(
                  size: const Size(280, 280),
                  painter: SegmentedCirclePainter(
                    progress: 1.0,
                    progressColor: color,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    segmentWeights: segmentWeights,
                    gapAngle: 0.12,
                    greenSegmentIndex: isBadNews ? -1 : appCount,
                  ),
                ),
              if (progressValue != null)
                ..._buildAppIcons(280, iconSegmentWeights, segmentWeights, topApps, isBadNews),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayTime,
                    style: const TextStyle(
                        fontSize: 42, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      color: color,
                      letterSpacing: 3,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 60),
        _buildActionButton("Continue", _nextPage),
      ],
    ),
  );
}


List<Widget> _buildAppIcons(double size, List<double> iconWeights, List<double> allWeights, List<String> packages, bool isBadNews) {
  if (packages.isEmpty || _installedApps.isEmpty) return [];

  final count = packages.length;
  final radius = size / 2 - 12;
  final gapAngle = 0.12;
  final totalSegments = allWeights.length;
  final totalGapAngle = gapAngle * totalSegments;
  final availableAngle = 2 * math.pi - totalGapAngle;
  final startOffset = -math.pi / 2;

  final totalWeight = allWeights.fold(0.0, (sum, w) => sum + w);

  List<Widget> icons = [];
  double currentAngle = startOffset;

  for (int i = 0; i < count; i++) {
    final segmentAngle = availableAngle * (allWeights[i] / totalWeight);
    final midAngle = currentAngle + (segmentAngle / 2);

    final x = (size / 2) + radius * math.cos(midAngle);
    final y = (size / 2) + radius * math.sin(midAngle);

    final app = _installedApps.firstWhere(
      (a) => a.packageName == packages[i],
      orElse: () => _installedApps.first,
    );

    Widget iconWidget;
    if (app is ApplicationWithIcon) {
      iconWidget = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(app.icon, width: 28, height: 28),
      );
    } else {
      iconWidget = const Icon(Icons.android, color: Colors.white70, size: 28);
    }

    icons.add(
      Positioned(
        left: x - 18,
        top: y - 18,
        child: SizedBox(
          width: 36,
          height: 36,
          child: iconWidget,
        ),
      ),
    );

    currentAngle += segmentAngle + gapAngle;
  }

  return icons;
}

  Widget _buildFeaturesPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "MORE THAN BLOCKING",
            style: TextStyle(fontFamily: 'DxSitrus', fontSize: 32, color: Colors.white),
            textAlign: TextAlign.center
          ),
          const SizedBox(height: 40),
          _buildFeatureRow(
            Icons.fitness_center,
            "Earn Your Breaks",
            "Perform squats or pushups to unlock apps for 5 minutes."
          ),
          _buildFeatureRow(
            Icons.lock,
            "Strict Modes",
            "Choose 'Hard' or 'No Break' mode to prevent early exits."
          ),
          _buildFeatureRow(
            Icons.bar_chart,
            "Deep Insights",
            "Track your focus score and reclaim lost time."
          ),
          const SizedBox(height: 50),
          _buildActionButton("Continue", _nextPage),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purpleAccent.withOpacity(0.2),
              shape: BoxShape.circle
            ),
            child: Icon(icon, color: Colors.purpleAccent, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18
                  )
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.white70, fontSize: 14)
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPlanPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "YOUR FOCUS,\nYOUR RULES.", 
            style: TextStyle(
              fontSize: 32, 
              fontWeight: FontWeight.bold, 
              color: Colors.white, 
              fontFamily: 'DxSitrus'
            ), 
            textAlign: TextAlign.center
          ),
          const SizedBox(height: 40),
          _buildCheckItem("Kill the doom-scroll"),
          _buildCheckItem("Protect your deep work"),
          _buildCheckItem("Earn your dopamine"),
          _buildCheckItem("Live in the real world"),
          const SizedBox(height: 50),
          const Text("🧠", style: TextStyle(fontSize: 60)),
          const SizedBox(height: 20),
          const Text(
            "No more excuses.", 
            style: TextStyle(color: Colors.grey, fontSize: 16, letterSpacing: 1.5)
          ),
          const SizedBox(height: 30),
          _buildActionButton("Initialize VERO", _nextPage)
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          elevation: 10,
          shadowColor: Colors.white.withOpacity(0.2)
        ),
        child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
      )
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white.withOpacity(0.05),
          child: child
        )
      )
    );
  }

  Widget _buildCheckItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.purpleAccent, size: 28),
          const SizedBox(width: 15),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 18))
          )
        ]
      )
    );
  }
}
class SegmentedCirclePainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color backgroundColor;
  final List<double> segmentWeights;
  final double gapAngle;
  final int greenSegmentIndex;

  SegmentedCirclePainter({
    required this.progress,
    required this.progressColor,
    required this.backgroundColor,
    required this.segmentWeights,
    this.gapAngle = 0.12,
    this.greenSegmentIndex = -1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 25.0;

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final segmentCount = segmentWeights.length;
    final totalGapAngle = gapAngle * segmentCount;
    final availableAngle = 2 * math.pi - totalGapAngle;
    final startOffset = -math.pi / 2;

    final totalWeight = segmentWeights.fold(0.0, (sum, w) => sum + w);

    List<double> segmentAngles = [];
    List<double> segmentStarts = [];
    double currentAngle = startOffset;

    for (int i = 0; i < segmentCount; i++) {
      segmentStarts.add(currentAngle);
      final segmentAngle = availableAngle * (segmentWeights[i] / totalWeight);
      segmentAngles.add(segmentAngle);
      currentAngle += segmentAngle + gapAngle;
    }

    for (int i = 0; i < segmentCount; i++) {
      if (greenSegmentIndex == -1) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
          segmentStarts[i],
          segmentAngles[i],
          false,
          progressPaint,
        );
      } else if (i == greenSegmentIndex) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
          segmentStarts[i],
          segmentAngles[i],
          false,
          progressPaint,
        );
      } else {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
          segmentStarts[i],
          segmentAngles[i],
          false,
          backgroundPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant SegmentedCirclePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.greenSegmentIndex != greenSegmentIndex;
  }
}
