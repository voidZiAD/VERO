import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_apps/device_apps.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'onboarding_screen.dart'; 
import 'focus_zones_screen.dart'; 
import 'accountability_screen.dart'; 
import '../services/block_service.dart'; 
import '../services/prayer_service.dart';
import '../services/auth_service.dart';
import 'package:flutter/services.dart';
import '../services/encryption_service.dart';
import 'category_management_screen.dart';
import 'whitelist_apps_sheet.dart';
import 'affirmations_sheet.dart';
import '../widgets/egg_widget.dart';
import '../services/widget_service.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notificationsEnabled = true;
  bool _exerciseNotificationsEnabled = true;
  bool _prayerRemindersEnabled = false;
  bool _prayerAlwaysRemind = false;
  bool _streakRemindersEnabled = true;
  List<String> _selectedPrayers = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"];
  
  int _blockedAppsCount = 0;
  int _blockedSitesCount = 0;
  int _categoriesCount = 0;
  int _whitelistedAppsCount = 0;

  String _username = "Guest User";
  bool _loadingUser = true;
  String _selectedEgg = "purple_normal";

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUserData();
    BlockService().addListener(_onBlockServiceChange);
  }

  @override
  void dispose() {
    BlockService().removeListener(_onBlockServiceChange);
    super.dispose();
  }

  void _handleRestrictedAction(VoidCallback action) {
    final session = BlockService().activeSession;
    if (session != null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("🔒 Settings locked during '${session.name}'!"),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        )
      );
      return;
    }
    action();
  }



  void _onBlockServiceChange() {
    if (mounted) {
      setState(() {
        _categoriesCount = BlockService().categories.length;
      });
    }
  }

  Future<void> _loadUserData() async {
    setState(() => _loadingUser = true);
    
    try {
      final userData = await AuthService().getDecryptedUserData();
      
      if (userData != null && mounted) {
        setState(() {
          _username = userData['username'] ?? 'Guest User';
          _loadingUser = false;
        });

        final prefs = await SharedPreferences.getInstance();
        final blockedList = prefs.getStringList('blocked_packages') ?? [];
        
        final whitelistString = prefs.getString('whitelisted_packages') ?? "";
        List<String> whitelistedList = [];
        if (whitelistString.startsWith("LIST:")) {
          whitelistedList = whitelistString.substring(5).split(",").where((e) => e.isNotEmpty).toList();
        }
        
        final urlString = prefs.getString('blocked_urls') ?? "";
        List<String> blockedUrls = [];
        if (urlString.startsWith("LIST:")) {
          blockedUrls = urlString.substring(5).split(",").where((e) => e.isNotEmpty).toList();
        }
        
        if (mounted) {
          setState(() {
            _blockedAppsCount = blockedList.length;
            _blockedSitesCount = blockedUrls.length;
            _categoriesCount = BlockService().categories.length;
            _whitelistedAppsCount = whitelistedList.length;
          });
        }


      } else {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (mounted) {
          setState(() {
            if (currentUser != null) {
              _username = currentUser.displayName ?? currentUser.email?.split('@')[0] ?? 'Member';
            } else {
              _username = 'Guest User';
            }
            _loadingUser = false;
          });
        }
      }
    } catch (e) {
      print('Failed to load user data: $e');
      if (mounted) {
        setState(() {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            _username = currentUser.displayName ?? currentUser.email?.split('@')[0] ?? 'Member';
          } else {
            _username = 'Guest User';
          }
          _loadingUser = false;
        });
      }
    }
  }

 Future<void> _performLogout() async {
    final service = BlockService();
    if (service.activeSession != null) {
      await service.stopSession(service.activeSession!.id, earlyExit: true);
    }

    await AuthService().syncDataToFirestore();

    await PrayerService().updateSettings(false, false, []);

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    service.reset();

    await AuthService().signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (route) => false,
    );
  }

  void _showAffirmationsManager() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const AffirmationsSheet(),
    );
  }


  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _exerciseNotificationsEnabled = prefs.getBool('exercise_notifications_enabled') ?? true;
        _prayerRemindersEnabled = prefs.getBool('prayer_reminders_enabled') ?? false;
        _prayerAlwaysRemind = prefs.getBool('prayer_always_remind') ?? false;
        _selectedPrayers = prefs.getStringList('selected_prayers') ?? ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"];
        _streakRemindersEnabled = prefs.getBool('streak_reminders_enabled') ?? true;
        _selectedEgg = prefs.getString('profile_egg') ?? "purple_normal";
        final blockedList = prefs.getStringList('blocked_packages') ?? [];
        _blockedAppsCount = blockedList.length;

        final whitelistString = prefs.getString('whitelisted_packages') ?? "";
        List<String> whitelistedList = [];
        if (whitelistString.startsWith("LIST:")) {
          whitelistedList = whitelistString.substring(5).split(",").where((e) => e.isNotEmpty).toList();
        }
        _whitelistedAppsCount = whitelistedList.length;

        final urlString = prefs.getString('blocked_urls') ?? "";
        if (urlString.startsWith("LIST:")) {
           final list = urlString.substring(5).split(",").where((e) => e.isNotEmpty).toList();
           _blockedSitesCount = list.length;
        } else {
           _blockedSitesCount = 0;
        }
        _categoriesCount = BlockService().categories.length;
      });
    }
  }

  void _showCategoryManager() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CategoryManagementScreen()),
    );
  }

  void _showWhitelistManager() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => WhitelistAppsSheet(
        onSaved: () {
          _loadSettings(); 
        },
      ),
    );
  }

  Future<void> _toggleNotifications(bool value) async {
    HapticFeedback.selectionClick();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    setState(() {
      _notificationsEnabled = value;
    });
    await AuthService().updateUserSettings(notificationsEnabled: value);
  }

  Future<void> _toggleExerciseNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('exercise_notifications_enabled', value);
    setState(() {
      _exerciseNotificationsEnabled = value;
    });
  }

  Future<void> _toggleStreakReminders(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('streak_reminders_enabled', value);
    setState(() {
      _streakRemindersEnabled = value;
    });
  }

  Future<void> _togglePrayerReminders(bool value) async {
    setState(() => _prayerRemindersEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prayer_reminders_enabled', value);
    
    await _savePrayerSettings();
    await AuthService().updateUserSettings(prayerRemindersEnabled: value);
  }

  Future<void> _toggleAlwaysRemind(bool value) async {
    setState(() => _prayerAlwaysRemind = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prayer_always_remind', value);

    await _savePrayerSettings();
    await AuthService().updateUserSettings(alwaysRemindEnabled: value);
  }

  Future<void> _savePrayerSettings() async {
    await PrayerService().updateSettings(_prayerRemindersEnabled, _prayerAlwaysRemind, _selectedPrayers);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('selected_prayers', _selectedPrayers);

    await AuthService().updateUserSettings(selectedPrayers: _selectedPrayers);
  }

  void _showPrayerSelectionDialog() {
    final allPrayers = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"];
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A0B2E),
              title: const Text("Select Prayers", style: TextStyle(color: Colors.white, fontFamily: 'DxSitrus')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: allPrayers.map((prayer) {
                  final isSelected = _selectedPrayers.contains(prayer);
                  return CheckboxListTile(
                    title: Text(prayer, style: const TextStyle(color: Colors.white)),
                    value: isSelected,
                    activeColor: Colors.greenAccent,
                    checkColor: Colors.black,
                    onChanged: (val) {
                      setDialogState(() {
                        if (val == true) {
                          _selectedPrayers.add(prayer);
                        } else {
                          _selectedPrayers.remove(prayer);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _savePrayerSettings(); 
                    setState(() {});
                    Navigator.pop(context);
                  },
                  child: const Text("Save", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                )
              ],
            );
          }
        );
      },
    );
  }

  void _showBlockedAppsManager() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => BlockedAppsSheet(
        onSaved: () {
          _loadSettings(); 
        },
      ),
    );
  }

  void _showBlockedWebsitesManager() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => BlockedWebsitesSheet(
        onSaved: () {
          _loadSettings(); 
        },
      ),
    );
  }

  Future<void> _confirmLogout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A0B2E),
        title: const Text("Log Out?", style: TextStyle(color: Colors.white, fontFamily: 'DxSitrus')),
        content: const Text(
          "You will be signed out of your account.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performLogout();
            },
            child: const Text("Log Out", style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A0B2E),
        title: const Text("Delete Account?", style: TextStyle(color: Colors.redAccent, fontFamily: 'DxSitrus')),
        content: const Text(
          "This will permanently delete your account and all associated data.\n\nThis action cannot be undone.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDeleteAccount();
            },
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteAccount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final service = BlockService();
      if (service.activeSession != null) {
        await service.stopSession(service.activeSession!.id, earlyExit: true);
      }

      await PrayerService().updateSettings(false, false, []);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();

      await user.delete(); 

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A0B2E),
            title: const Text("Security Check", style: TextStyle(color: Colors.white, fontFamily: 'DxSitrus')),
            content: const Text(
              "For security, you must log out and log back in before deleting your account.",
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel", style: TextStyle(color: Colors.white)),
              ),
              TextButton(
                onPressed: () {
                   Navigator.pop(context);
                   _performLogout();
                },
                child: const Text("Log Out Now", style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        return;
      }

      print("Delete Account Auth Error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.message}"), backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      print("Delete Account Error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _showEditNameDialog() {
    final TextEditingController nameController = TextEditingController(text: _username);
    String? errorText;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A0B2E),
              title: const Text("Edit Username", style: TextStyle(color: Colors.white, fontFamily: 'DxSitrus')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    maxLength: 20,
                    decoration: InputDecoration(
                      hintText: "Enter new username",
                      hintStyle: const TextStyle(color: Colors.grey),
                      errorText: errorText,
                      errorStyle: const TextStyle(color: Colors.redAccent),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      counterStyle: const TextStyle(color: Colors.grey),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        if (value.isEmpty) {
                          errorText = "Username cannot be empty";
                        } else if (value.length < 3) {
                          errorText = "Username must be at least 3 characters";
                        } else if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                          errorText = "Only letters, numbers, and _ allowed";
                        } else {
                          errorText = null;
                        }
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () async {
                    final newName = nameController.text.trim();
                    
                    if (newName.isEmpty) {
                      setDialogState(() => errorText = "Username cannot be empty");
                      return;
                    }
                    if (newName.length < 3) {
                      setDialogState(() => errorText = "Username must be at least 3 characters");
                      return;
                    }
                    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(newName)) {
                      setDialogState(() => errorText = "Only letters, numbers, and _ allowed");
                      return;
                    }

                    Navigator.pop(context);
                    await _updateUsername(newName);
                  },
                  child: const Text("Save", style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateUsername(String newUsername) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final encryptedUsername = EncryptionService().encrypt(newUsername, user.uid);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'username': encryptedUsername});

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', newUsername);

      if (mounted) {
        setState(() {
          _username = newUsername;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Username updated!"),
            backgroundColor: Colors.greenAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to update: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                _showEggSelectionSheet();
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05),
                      border: Border.all(color: Colors.white10),
                    ),
                  ),
                  EggWidget(eggType: _selectedEgg, size: 100),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.edit, color: Colors.black, size: 16),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),
            _loadingUser
              ? const CircularProgressIndicator(color: Colors.purpleAccent)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _username,
                      style: const TextStyle(fontFamily: 'DxSitrus', fontSize: 28, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _showEditNameDialog();
                      },
                      child: const Icon(Icons.edit, color: Colors.grey, size: 20),
                    ),
                  ],
                ),
            const Text("VERO Member since 2025", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),

            const Align(alignment: Alignment.centerLeft, child: Text("PREFERENCES", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5))),
            const SizedBox(height: 10),
            _buildSettingCard(
              child: Column(
                children: [
                  _buildSwitchRow(Icons.local_fire_department, "Daily Streak Reminders", _streakRemindersEnabled, _toggleStreakReminders),
                  const Divider(color: Colors.white12),
                  _buildSwitchRow(Icons.notifications, "Block Notifications During Sessions", _notificationsEnabled, _toggleNotifications),
                  
                  if (_notificationsEnabled) ...[
                    const Divider(color: Colors.white12),
                    _buildSwitchRow(Icons.fitness_center, "Exercise Notifications", _exerciseNotificationsEnabled, _toggleExerciseNotifications),
                  ],

                  const Divider(color: Colors.white12),
                  
                  GestureDetector(
                    onTap: () => _handleRestrictedAction(_showBlockedAppsManager),
                    child: _buildRow(Icons.apps, "Blocked Apps ($_blockedAppsCount)"),
                  ),
                  const Divider(color: Colors.white12),

                  GestureDetector(
                    onTap: () => _handleRestrictedAction(_showBlockedWebsitesManager),
                    child: _buildRow(Icons.public, "Blocked Websites ($_blockedSitesCount)"),
                  ),
                  const Divider(color: Colors.white12),

                  GestureDetector(
                    onTap: () => _handleRestrictedAction(_showCategoryManager),
                    child: _buildRow(Icons.folder_open, "App Categories ($_categoriesCount)"),
                  ),
                  const Divider(color: Colors.white12),

                  GestureDetector(
                    onTap: () => _handleRestrictedAction(_showWhitelistManager),
                    child: _buildRow(Icons.check_circle_outline, "Whitelisted Apps ($_whitelistedAppsCount)"),
                  ),
                  const Divider(color: Colors.white12),

                  GestureDetector(
                    onTap: _showAffirmationsManager,
                    child: _buildRow(Icons.format_quote, "My Affirmations"),
                  ),
                  const Divider(color: Colors.white12),

                  GestureDetector(
                    onTap: () => _handleRestrictedAction(() => Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusZonesScreen()))),
                    child: _buildRow(Icons.location_on, "Focus Zones"),
                  ),
                  const Divider(color: Colors.white12),

                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountabilityScreen())),
                    child: _buildRow(Icons.handshake, "Accountability Pact"),
                  ),
                  const Divider(color: Colors.white12),

                  _buildSwitchRow(Icons.mosque, "Islamic Prayer Reminders", _prayerRemindersEnabled, _togglePrayerReminders),
                  
                  if (_prayerRemindersEnabled) ...[
                    const Divider(color: Colors.white12),
                    _buildSwitchRow(Icons.bolt, "Always Remind (Even if unblocked)", _prayerAlwaysRemind, _toggleAlwaysRemind),
                    const Divider(color: Colors.white12),
                    GestureDetector(
                      onTap: _showPrayerSelectionDialog,
                      child: _buildRow(Icons.list, "Select Prayers (${_selectedPrayers.length})"),
                    ),
                  ]
                ],
              ),
            ),
            const SizedBox(height: 30),

            const Align(alignment: Alignment.centerLeft, child: Text("SOCIAL", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5))),
            const SizedBox(height: 10),
            _buildSettingCard(
              child: Column(
                children: [
                  _buildRow(Icons.group, "Join our Community"),
                  const Divider(color: Colors.white12),
                  _buildRow(Icons.share, "Share VERO"),
                ],
              ),
            ),

            const SizedBox(height: 60),

            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _handleRestrictedAction(_confirmLogout);
                },                
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.purpleAccent.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: Colors.purpleAccent.withOpacity(0.5))
                  )
                ),
                child: const Text(
                  "Log Out",
                  style: TextStyle(color: Colors.purpleAccent, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 15),

            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => _handleRestrictedAction(_confirmDeleteAccount),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.redAccent.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: Colors.redAccent.withOpacity(0.5))
                  )
                ),
                child: const Text(
                  "Delete Account",
                  style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Text("Version 1.0.0", style: TextStyle(color: Colors.white24, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _showEggSelectionSheet() {
    final eggs = [
      "purple_normal", "blue_normal", "green_normal", 
      "red_normal", "orange_normal", "gold_normal",
      "teal_normal", "pink_normal"
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0518),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Choose Your Style", style: TextStyle(color: Colors.white, fontSize: 20, fontFamily: 'DxSitrus')),
            const SizedBox(height: 20),
            Wrap(
              spacing: 20,
              runSpacing: 20,
              alignment: WrapAlignment.center,
              children: eggs.map((egg) {
                final isSelected = _selectedEgg == egg;
                return GestureDetector(
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    setState(() => _selectedEgg = egg);
                    
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('profile_egg', egg);
                    
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                    ),
                    child: EggWidget(eggType: egg, size: 60),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSwitchRow(IconData icon, String text, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 15),
                Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16))),
              ],
            ),
          ),
          Switch(
            value: value, 
            onChanged: onChanged,
            activeThumbColor: Colors.purpleAccent,
            activeTrackColor: Colors.purpleAccent.withOpacity(0.4),
          ),
        ],
      ),
    );
  }

 Widget _buildRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 15),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const Spacer(),
          const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
        ],
      ),
    );
  }
}


class BlockedAppsSheet extends StatefulWidget {
  final VoidCallback onSaved;
  const BlockedAppsSheet({super.key, required this.onSaved});

  @override
  State<BlockedAppsSheet> createState() => _BlockedAppsSheetState();
}

class _BlockedAppsSheetState extends State<BlockedAppsSheet> {
  List<Application> _apps = [];
  List<String> _selected = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('blocked_packages') ?? [];
    
    final apps = await DeviceApps.getInstalledApplications(
      includeAppIcons: true, 
      includeSystemApps: false, 
      onlyAppsWithLaunchIntent: true
    );
    apps.sort((a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));
    
    if (mounted) {
      setState(() {
        _selected = saved;
        _apps = apps;
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('blocked_packages', _selected);
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0518),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Column(
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          const Text("Manage Blocked Apps", style: TextStyle(color: Colors.white, fontSize: 24, fontFamily: 'DxSitrus')),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
              : ListView.builder(
                  itemCount: _apps.length,
                  itemBuilder: (context, index) {
                    final app = _apps[index];
                    final isSelected = _selected.contains(app.packageName);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: app is ApplicationWithIcon 
                        ? Image.memory(app.icon, width: 32) 
                        : const Icon(Icons.android, color: Colors.white),
                      title: Text(app.appName, style: const TextStyle(color: Colors.white)),
                      trailing: Checkbox(
                        value: isSelected,
                        activeColor: Colors.purpleAccent,
                        checkColor: Colors.black,
                        side: const BorderSide(color: Colors.grey),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selected.add(app.packageName);
                            } else {
                              _selected.remove(app.packageName);
                            }
                          });
                        },
                      ),
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selected.remove(app.packageName);
                          } else {
                            _selected.add(app.packageName);
                          }
                        });
                      },
                    );
                  },
                ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, 
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
              ),
              child: Text("Save List (${_selected.length})", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class BlockedWebsitesSheet extends StatefulWidget {
  final VoidCallback onSaved;
  const BlockedWebsitesSheet({super.key, required this.onSaved});

  @override
  State<BlockedWebsitesSheet> createState() => _BlockedWebsitesSheetState();
}

class _BlockedWebsitesSheetState extends State<BlockedWebsitesSheet> {
  final TextEditingController _urlController = TextEditingController();
  List<String> _blockedUrls = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final urlString = prefs.getString('blocked_urls') ?? "";
    if (urlString.startsWith("LIST:")) {
      setState(() {
        _blockedUrls = urlString.substring(5).split(",").where((e) => e.isNotEmpty).toList();
      });
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('blocked_urls', "LIST:${_blockedUrls.join(',')}");
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  void _addUrl() {
    String url = _urlController.text.trim().toLowerCase();
    if (url.isNotEmpty) {
      if (!url.contains(".")) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a valid URL (e.g. facebook.com)")));
        return;
      }
      setState(() {
        if (!_blockedUrls.contains(url)) {
          _blockedUrls.add(url);
        }
        _urlController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0518),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Column(
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          const Text("Manage Blocked Sites", style: TextStyle(color: Colors.white, fontSize: 24, fontFamily: 'DxSitrus')),
          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "e.g. facebook.com",
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20)
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: const BoxDecoration(color: Colors.purpleAccent, shape: BoxShape.circle),
                child: IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: _addUrl,
                ),
              )
            ],
          ),
          
          const SizedBox(height: 20),
          
          Expanded(
            child: _blockedUrls.isEmpty 
              ? const Center(child: Text("No websites blocked yet.", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: _blockedUrls.length,
                  itemBuilder: (context, index) {
                    final url = _blockedUrls[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.public, color: Colors.white),
                      title: Text(url, style: const TextStyle(color: Colors.white)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () {
                          setState(() {
                            _blockedUrls.removeAt(index);
                          });
                        },
                      ),
                    );
                  },
                ),
          ),
          
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, 
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
              ),
              child: Text("Save List (${_blockedUrls.length})", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
