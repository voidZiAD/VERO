import 'dart:ui';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_apps/device_apps.dart';
import 'package:uuid/uuid.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 
import 'profile_screen.dart';
import 'stats_screen.dart';
import '../services/block_service.dart';
import '../services/auth_service.dart';
import '../services/widget_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../services/gamification_service.dart';
import 'debrief_sheet.dart';
import 'reminders_screen.dart';
import '../screens/tutorial_overlay.dart'; 

Future<void> showBlockSelectionModal(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const _BlockTypeSheet(),
  );
}

class _BlockTypeSheet extends StatelessWidget {
  const _BlockTypeSheet();

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0518).withOpacity(0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
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
            const Text(
              "Select your block type",
              style: TextStyle(fontFamily: 'DxSitrus', fontSize: 24, color: Colors.white),
            ),
            const SizedBox(height: 30),
            _buildOption(
              context,
              icon: Icons.timer_outlined,
              title: "Block Now",
              subtitle: "Start a focus timer immediately",
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TimerScreen())),
            ),
            const SizedBox(height: 15),
            _buildOption(
              context,
              icon: Icons.calendar_month_outlined,
              title: "Create Schedule",
              subtitle: "e.g. Work Hours from 9am to 5pm",
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScheduleScreen())),
            ),
            const SizedBox(height: 15),
            _buildOption(
              context,
              icon: Icons.hourglass_empty,
              title: "Set Time Limit",
              subtitle: "e.g. 30min per day for Social Media",
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TimeLimitScreen())),
            ),
            const SizedBox(height: 15),
            _buildOption(
              context,
              icon: Icons.fitness_center,
              title: "Exercise Block",
              subtitle: "Block apps 24/7, unlock by exercising",
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExerciseBlockCreationScreen())),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
          ],
        ),
      ),
    );
  }
}

Widget _buildColorPicker(Color selected, Function(Color) onSelect) {
  final colors = [
    Colors.blueAccent,
    Colors.purpleAccent,
    Colors.redAccent,
    Colors.orangeAccent,
    Colors.greenAccent,
  ];
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: colors.map((c) => GestureDetector(
      onTap: () => onSelect(c),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: selected == c ? Border.all(color: Colors.white, width: 2) : null,
        ),
      ),
    )).toList(),
  );
}

Widget _buildIconPicker(IconData selected, Function(IconData) onSelect) {
  final icons = [
    Icons.work,
    Icons.bed,
    Icons.school,
    Icons.videogame_asset,
    Icons.fitness_center,
  ];
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: icons.map((i) => GestureDetector(
      onTap: () => onSelect(i),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected == i ? Colors.white.withOpacity(0.2) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(i, color: Colors.white),
      ),
    )).toList(),
  );
}

class TimerScreen extends StatefulWidget {
  final VoidCallback? onStart; 
  const TimerScreen({super.key, this.onStart});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  double _sliderValue = 0.0833; 
  int _totalMinutes = 20; 
  bool _blockWebsites = true; 
  bool _phoneDownMode = false;
  BreakDifficulty _difficulty = BreakDifficulty.easy;
  Color _selectedColor = Colors.purpleAccent;
  IconData _selectedIcon = Icons.timer;
  
  List<String> _customApps = []; 
  bool _useCustomApps = false;

  bool _isDragging = false; 

  void _updateTime(double value) {
    setState(() {
      _sliderValue = value;
      _totalMinutes = (value * 240).round().clamp(1, 240);
    });
  }

  bool _isDuplicateSession(List<String> newApps) {
    final activeSessions = BlockService().blocks.where((b) => b.isActive);
    final newSet = Set.from(newApps);
    
    for (var session in activeSessions) {
      final existingSet = Set.from(session.appPackages);
      if (newSet.length == existingSet.length && newSet.containsAll(existingSet)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _showIntentDialog() async {
    final TextEditingController intentController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A0B2E),
        title: const Text("What is your Mission?", style: TextStyle(color: Colors.white, fontFamily: 'DxSitrus')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Define your intent. Be specific.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            TextField(
              controller: intentController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "e.g. Finish Math Assignment",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () {
              if (intentController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                _startTimer(intentController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _selectedColor, foregroundColor: Colors.black),
            child: const Text("Start Mission"),
          ),
        ],
      ),
    );
  }

Future<void> _startTimer(String intent) async {
    HapticFeedback.heavyImpact();
    bool hasPermissions = await BlockService().checkPermissions();
    if (!hasPermissions) return;

    final prefs = await SharedPreferences.getInstance();
    final globalApps = prefs.getStringList('blocked_packages') ?? [];
    
    final appsToBlock = _useCustomApps ? _customApps : globalApps;
    
    if (_isDuplicateSession(appsToBlock)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("A timer for these exact apps is already running!"),
          backgroundColor: Colors.redAccent,
        )
      );
      return;
    }

    final FlutterBackgroundService service = FlutterBackgroundService();
    if (!(await service.isRunning())) {
      await service.startService();
    }
    if (service is AndroidServiceInstance) {
      (service as AndroidServiceInstance).setAsForegroundService();
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("⏲️ Focus Timer is about to start!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _selectedColor,
        duration: const Duration(seconds: 2),
      )
    );

    final session = BlockSession(
      id: const Uuid().v4(),
      name: "Focus Timer",
      type: BlockType.timer,
      durationMinutes: _totalMinutes, 
      appPackages: appsToBlock, 
      difficulty: _difficulty,
      isActive: true,
      colorValue: _selectedColor.value,
      iconCodePoint: _selectedIcon.codePoint,
      intent: intent,
      isPhoneDownMode: _phoneDownMode,
      blockWebsites: _blockWebsites, 
    );

    await BlockService().addBlock(session);
    await BlockService().startSession(session.id);
    
    if (!mounted) return;

    if (widget.onStart != null) {
      widget.onStart!();
    }

    if (Navigator.canPop(context)) {
      Navigator.popUntil(context, (route) => route.isFirst);
    } else {
      setState(() {
        _sliderValue = 0.0833;
        _totalMinutes = 20;
      });
    }
  }

  void _showAppPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _AppSelectionSheet(
        initialSelection: _customApps,
        onConfirm: (apps) => setState(() {
          _customApps = apps;
          _useCustomApps = true;
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isModal = Navigator.canPop(context);

    String timeText;
    List<Widget> labels;

    if (_totalMinutes >= 60) {
      int h = _totalMinutes ~/ 60;
      int m = _totalMinutes % 60;
      timeText = "$h:${m.toString().padLeft(2, '0')}";
      labels = [
        Text("Hr", style: TextStyle(color: Colors.white.withOpacity(0.5))),
        const SizedBox(width: 10),
        Text("Min", style: TextStyle(color: Colors.white.withOpacity(0.5))),
      ];
    } else {
      timeText = "$_totalMinutes";
      labels = [
        Text("Min", style: TextStyle(color: Colors.white.withOpacity(0.5))),
      ];
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1A0B2E), Colors.black],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context, "TIMER", showBackButton: isModal),
                
                Expanded(
                  child: SingleChildScrollView(
                    physics: _isDragging ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        
                        Listener(
                          onPointerDown: (_) => setState(() => _isDragging = true),
                          onPointerUp: (_) => setState(() => _isDragging = false),
                          onPointerCancel: (_) => setState(() => _isDragging = false),
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              double delta = -details.delta.dy / 300;
                              _updateTime((_sliderValue + delta).clamp(0.004, 1.0));
                            },
                            child: SizedBox(
                              width: 300, 
                              height: 300,
                              child: CustomPaint(
                                painter: _CircularSliderPainter(_sliderValue, _selectedColor),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      timeText,
                                      style: TextStyle(
                                        fontSize: _totalMinutes >= 60 ? 50 : 60, 
                                        fontWeight: FontWeight.bold, 
                                        color: Colors.white
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: labels,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              _buildGlassContainer(
                                child: _buildColorPicker(_selectedColor, (c) => setState(() => _selectedColor = c)),
                              ),
                              const SizedBox(height: 15),

                              const Align(alignment: Alignment.centerLeft, child: Text("BREAKS", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5))),
                              const SizedBox(height: 10),
                              _buildGlassContainer(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<BreakDifficulty>(
                                    value: _difficulty,
                                    dropdownColor: const Color(0xFF1A0B2E),
                                    isExpanded: true,
                                    items: BreakDifficulty.values.map((d) {
                                      String txt = d == BreakDifficulty.easy ? "Easy (Cancel anytime)" : d == BreakDifficulty.hard ? "Hard (15s delay)" : "No Breaks";
                                      return DropdownMenuItem(value: d, child: Text(txt, style: const TextStyle(color: Colors.white)));
                                    }).toList(),
                                    onChanged: (v) => setState(() => _difficulty = v!),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              _buildGlassContainer(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("Phone Down Mode 📵", style: TextStyle(color: Colors.white, fontSize: 16)),
                                    Switch(
                                      value: _phoneDownMode,
                                      onChanged: (v) => setState(() => _phoneDownMode = v),
                                      activeThumbColor: Colors.redAccent,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 15),

                              _buildGlassContainer(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("Block Websites 🌐", style: TextStyle(color: Colors.white, fontSize: 16)),
                                    Switch(
                                      value: _blockWebsites,
                                      onChanged: (v) => setState(() => _blockWebsites = v),
                                      activeThumbColor: _selectedColor,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 15),
                              GestureDetector(
                                onTap: _showAppPicker,
                                child: _buildGlassContainer(
                                  child: _buildRow(
                                    "Apps to Block", 
                                    _useCustomApps ? "${_customApps.length} Apps" : "Global List",
                                    icon: Icons.apps
                                  ),
                                ),
                              ),
                              const SizedBox(height: 30),
                              SizedBox(
                                width: double.infinity,
                                height: 60,
                                child: ElevatedButton(
                                  onPressed: _showIntentDialog, 
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                  ),
                                  child: const Text("Start Timer", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final TextEditingController _nameController = TextEditingController(text: "Work Fortress");
  TimeOfDay _from = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _to = const TimeOfDay(hour: 17, minute: 0);
  List<int> _selectedDayIndices = [0, 1, 2, 3, 4];
  final List<String> _days = ["M", "T", "W", "T", "F", "S", "S"];
  BreakDifficulty _difficulty = BreakDifficulty.easy;
  Color _selectedColor = Colors.blueAccent;
  IconData _selectedIcon = Icons.work;
  bool _blockWebsites = true;

  List<String> _customApps = [];
  bool _useCustomApps = false;

  void _showAppPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _AppSelectionSheet(
        initialSelection: _customApps,
        onConfirm: (apps) => setState(() {
          _customApps = apps;
          _useCustomApps = true;
        }),
      ),
    );
  }

  Future<void> _saveSchedule() async {
    HapticFeedback.mediumImpact();
    if (!await BlockService().checkPermissions()) return;

    final prefs = await SharedPreferences.getInstance();
    
    final globalApps = prefs.getStringList('blocked_packages') ?? [];
    final appsToBlock = _useCustomApps ? _customApps : globalApps;

    List<String> daysAsStrings = _selectedDayIndices.map((i) => _days[i]).toList();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("📅 ${_nameController.text} schedule saved!", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _selectedColor,
        duration: const Duration(seconds: 2),
      )
    );

    final session = BlockSession(
      id: const Uuid().v4(),
      name: _nameController.text,
      type: BlockType.schedule,
      startTime: _from,
      endTime: _to,
      days: daysAsStrings,
      appPackages: appsToBlock, 
      difficulty: _difficulty,
      colorValue: _selectedColor.value,
      iconCodePoint: _selectedIcon.codePoint,
      blockWebsites: _blockWebsites,
    );
    await BlockService().addBlock(session);
    if(mounted) Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return _buildBaseScreen(
      context,
      title: "Schedule",
      child: Column(
        children: [
          _buildGlassContainer(
            child: Row(
              children: [
                Icon(_selectedIcon, color: _selectedColor),
                const SizedBox(width: 15),
                Expanded(
                  child: TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(border: InputBorder.none),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildGlassContainer(
            child: Column(
              children: [
                _buildIconPicker(_selectedIcon, (i) => setState(() => _selectedIcon = i)),
                const Divider(color: Colors.white10),
                _buildColorPicker(_selectedColor, (c) => setState(() => _selectedColor = c)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildGlassContainer(
            child: Column(
              children: [
                _buildTimePicker("From", _from, (t) => setState(() => _from = t)),
                const Divider(color: Colors.white10),
                _buildTimePicker("To", _to, (t) => setState(() => _to = t)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Align(alignment: Alignment.centerLeft, child: Text("On these days:", style: TextStyle(color: Colors.grey, fontSize: 14))),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_days.length, (index) {
              final isSelected = _selectedDayIndices.contains(index);
              return GestureDetector(
                onTap: () => setState(() => isSelected ? _selectedDayIndices.remove(index) : _selectedDayIndices.add(index)),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: isSelected ? Colors.white : Colors.grey),
                  ),
                  child: Center(
                    child: Text(
                      _days[index],
                      style: TextStyle(color: isSelected ? Colors.black : Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 30),
          const Align(alignment: Alignment.centerLeft, child: Text("SETTINGS", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5))),
          const SizedBox(height: 10),
          _buildGlassContainer(
            child: Column(
              children: [
                DropdownButtonHideUnderline(
                  child: DropdownButton<BreakDifficulty>(
                    value: _difficulty,
                    dropdownColor: const Color(0xFF1A0B2E),
                    isExpanded: true,
                    items: BreakDifficulty.values.map((d) => DropdownMenuItem(value: d, child: Text(d == BreakDifficulty.easy ? "Easy Breaks" : d == BreakDifficulty.hard ? "Hard Breaks" : "No Breaks", style: const TextStyle(color: Colors.white)))).toList(),
                    onChanged: (v) => setState(() => _difficulty = v!),
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Block Websites 🌐", style: TextStyle(color: Colors.white, fontSize: 16)),
                    Switch(
                      value: _blockWebsites,
                      onChanged: (v) => setState(() => _blockWebsites = v),
                      activeThumbColor: _selectedColor,
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                GestureDetector(
                  onTap: _showAppPicker,
                  child: _buildRow(
                    "Selected Apps", 
                    _useCustomApps ? "${_customApps.length} Apps" : "Global List",
                    icon: Icons.apps
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      buttonText: "Create Schedule",
      onButtonTap: _saveSchedule,
    );
  }

  Widget _buildTimePicker(String label, TimeOfDay time, Function(TimeOfDay) onPick) {
    return GestureDetector(
      onTap: () async {
        final t = await showTimePicker(context: context, initialTime: time);
        if (t != null) onPick(t);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
            Row(
              children: [
                Text(time.format(context), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class TimeLimitScreen extends StatefulWidget {
  final VoidCallback? onStart; 
  const TimeLimitScreen({super.key, this.onStart});
  @override
  State<TimeLimitScreen> createState() => _TimeLimitScreenState();
}

class _TimeLimitScreenState extends State<TimeLimitScreen> {
  int _duration = 30;
  BreakDifficulty _difficulty = BreakDifficulty.hard;
  Color _selectedColor = Colors.orangeAccent;
  List<String> _selectedApps = [];
  bool _blockWebsites = true;

  @override
  void initState() {
    super.initState();
    _loadDefaultApps();
  }

  Future<void> _loadDefaultApps() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedApps = prefs.getStringList('blocked_packages') ?? [];
    });
  }
  
  Future<void> _saveLimit() async {
    if (!await BlockService().checkPermissions()) return;

    final FlutterBackgroundService service = FlutterBackgroundService();
    if (!(await service.isRunning())) {
      await service.startService();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("⏳ Daily Limit saved!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _selectedColor,
        duration: const Duration(seconds: 2),
      )
    );

    final session = BlockSession(
      id: const Uuid().v4(),
      name: "Daily Limit",
      type: BlockType.limit,
      durationMinutes: _duration,
      appPackages: _selectedApps,
      difficulty: _difficulty,
      colorValue: _selectedColor.value,
      iconCodePoint: Icons.hourglass_bottom.codePoint,
      isActive: false, 
      blockWebsites: _blockWebsites,
    );
    await BlockService().addBlock(session);
    
    if(!mounted) return;
    
    if (widget.onStart != null) widget.onStart!();
    
    if (Navigator.canPop(context)) {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  void _showAppPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _AppSelectionSheet(
        initialSelection: _selectedApps,
        onConfirm: (apps) => setState(() => _selectedApps = apps),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildBaseScreen(
      context,
      title: "Time Limit",
      child: Column(
        children: [
          _buildGlassContainer(
            child: Row(
              children: [
                Icon(Icons.hourglass_bottom, color: _selectedColor),
                const SizedBox(width: 15),
                Expanded(
                  child: TextFormField(
                    initialValue: "Social Media Limit",
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(border: InputBorder.none),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildGlassContainer(
            child: _buildColorPicker(_selectedColor, (c) => setState(() => _selectedColor = c)),
          ),
          const SizedBox(height: 20),
          _buildGlassContainer(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Limit Duration", style: TextStyle(color: Colors.white, fontSize: 16)),
                DropdownButton<int>(
                  value: _duration,
                  dropdownColor: const Color(0xFF1A0B2E),
                  items: [15, 30, 45, 60, 90, 120].map((e) => DropdownMenuItem(value: e, child: Text("$e min", style: const TextStyle(color: Colors.white)))).toList(),
                  onChanged: (v) => setState(() => _duration = v!),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Align(alignment: Alignment.centerLeft, child: Text("SETTINGS", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5))),
          const SizedBox(height: 10),
          _buildGlassContainer(
            child: Column(
              children: [
                DropdownButtonHideUnderline(
                  child: DropdownButton<BreakDifficulty>(
                    value: _difficulty,
                    dropdownColor: const Color(0xFF1A0B2E),
                    isExpanded: true,
                    items: BreakDifficulty.values.map((d) => DropdownMenuItem(value: d, child: Text(d == BreakDifficulty.easy ? "Easy Breaks" : d == BreakDifficulty.hard ? "Hard Breaks" : "No Breaks", style: const TextStyle(color: Colors.white)))).toList(),
                    onChanged: (v) => setState(() => _difficulty = v!),
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Block Websites 🌐", style: TextStyle(color: Colors.white, fontSize: 16)),
                    Switch(
                      value: _blockWebsites,
                      onChanged: (v) => setState(() => _blockWebsites = v),
                      activeThumbColor: _selectedColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _showAppPicker,
            child: _buildGlassContainer(
              child: _buildRow("Apps", "${_selectedApps.length} Selected", icon: Icons.apps),
            ),
          ),
        ],
      ),
      buttonText: "Set Limit",
      onButtonTap: _saveLimit,
    );
  }
}


class _AppSelectionSheet extends StatefulWidget {
  final List<String> initialSelection;
  final Function(List<String>)? onConfirm;
  const _AppSelectionSheet({required this.initialSelection, required this.onConfirm});

  @override
  State<_AppSelectionSheet> createState() => _AppSelectionSheetState();
}

class _AppSelectionSheetState extends State<_AppSelectionSheet> {
  List<Application> _apps = [];
  late List<String> _selected;
  List<BlockCategory> _categories = [];

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initialSelection);
    _categories = BlockService().categories;
    _loadApps();
  }

  Future<void> _loadApps() async {
    final apps = await DeviceApps.getInstalledApplications(includeAppIcons: true, includeSystemApps: false, onlyAppsWithLaunchIntent: true);
    apps.sort((a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));
    if (mounted) setState(() => _apps = apps);
  }

  void _toggleCategory(BlockCategory category) {
    setState(() {
      bool allSelected = category.packageNames.every((pkg) => _selected.contains(pkg));
      
      if (allSelected) {
        for (var pkg in category.packageNames) {
          _selected.remove(pkg);
        }
      } else {
        for (var pkg in category.packageNames) {
          if (!_selected.contains(pkg)) {
            _selected.add(pkg);
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0518),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Column(
        children: [
          const Text("Select Apps", style: TextStyle(color: Colors.white, fontSize: 24, fontFamily: 'DxSitrus')),
          const SizedBox(height: 20),
          
          if (_categories.isNotEmpty) ...[
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isFullySelected = category.packageNames.isNotEmpty && category.packageNames.every((pkg) => _selected.contains(pkg));
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: FilterChip(
                      label: Text(category.name),
                      selected: isFullySelected,
                      onSelected: (_) => _toggleCategory(category),
                      backgroundColor: Colors.white.withOpacity(0.1),
                      selectedColor: Color(category.colorValue).withOpacity(0.5),
                      labelStyle: TextStyle(color: isFullySelected ? Colors.white : Colors.grey),
                      checkmarkColor: Colors.white,
                      avatar: Icon(IconData(category.iconCodePoint, fontFamily: 'MaterialIcons'), size: 16, color: isFullySelected ? Colors.white : Color(category.colorValue)),
                    ),
                  );
                },
              ),
            ),
            const Divider(color: Colors.white10, height: 30),
          ],

          Expanded(
            child: _apps.isEmpty 
              ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
              : ListView.builder(
                  itemCount: _apps.length,
                  itemBuilder: (context, index) {
                    final app = _apps[index];
                    final isSelected = _selected.contains(app.packageName);
                    return ListTile(
                      leading: app is ApplicationWithIcon ? Image.memory(app.icon, width: 32) : const Icon(Icons.android),
                      title: Text(app.appName, style: const TextStyle(color: Colors.white)),
                      trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.purpleAccent) : const Icon(Icons.circle_outlined, color: Colors.grey),
                      onTap: () => setState(() => isSelected ? _selected.remove(app.packageName) : _selected.add(app.packageName)),
                    );
                  },
                ),
          ),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: () { 
                if (widget.onConfirm != null) {
                   widget.onConfirm!(_selected); 
                }
                Navigator.pop(context); 
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
              child: const Text("Confirm", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}


class ExerciseBlockCreationScreen extends StatefulWidget {
  const ExerciseBlockCreationScreen({super.key});

  @override
  State<ExerciseBlockCreationScreen> createState() => _ExerciseBlockCreationScreenState();
}

class _ExerciseBlockCreationScreenState extends State<ExerciseBlockCreationScreen> {
  final TextEditingController _nameController = TextEditingController(text: "Social Media Workout");
  List<String> _selectedApps = [];
  Color _selectedColor = Colors.orangeAccent;
  IconData _selectedIcon = Icons.fitness_center;
  bool _blockWebsites = true;

  @override
  void initState() {
    super.initState();
    _loadDefaultApps();
  }

  Future<void> _loadDefaultApps() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedApps = prefs.getStringList('blocked_packages') ?? [];
    });
  }

  Future<void> _saveExerciseBlock() async {
    HapticFeedback.mediumImpact();
    if (!await BlockService().checkPermissions()) return;

    final FlutterBackgroundService service = FlutterBackgroundService();
    if (!(await service.isRunning())) {
      await service.startService();
    }

    if (_selectedApps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one app to block."), backgroundColor: Colors.redAccent)
      );
      return;
    }

    final session = BlockSession(
      id: const Uuid().v4(),
      name: _nameController.text,
      type: BlockType.exercise,
      appPackages: _selectedApps,
      difficulty: BreakDifficulty.hard,
      colorValue: _selectedColor.value,
      iconCodePoint: _selectedIcon.codePoint,
      isActive: true, 
      blockWebsites: _blockWebsites,
    );

    await BlockService().addBlock(session);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("💪 Exercise Block Created!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _selectedColor,
        duration: const Duration(seconds: 2),
      )
    );

    if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
  }

  void _showAppPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _AppSelectionSheet(
        initialSelection: _selectedApps,
        onConfirm: (apps) => setState(() => _selectedApps = apps),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildBaseScreen(
      context,
      title: "Exercise Block",
      child: Column(
        children: [
          _buildGlassContainer(
            child: Row(
              children: [
                Icon(_selectedIcon, color: _selectedColor),
                const SizedBox(width: 15),
                Expanded(
                  child: TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(border: InputBorder.none, hintText: "Block Name", hintStyle: TextStyle(color: Colors.grey)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildGlassContainer(
            child: Column(
              children: [
                _buildIconPicker(_selectedIcon, (i) => setState(() => _selectedIcon = i)),
                const Divider(color: Colors.white10),
                _buildColorPicker(_selectedColor, (c) => setState(() => _selectedColor = c)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _showAppPicker,
            child: _buildGlassContainer(
              child: _buildRow("Apps to Block", "${_selectedApps.length} Selected", icon: Icons.apps),
            ),
          ),
          const SizedBox(height: 20),
          
          _buildGlassContainer(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Block Websites 🌐", style: TextStyle(color: Colors.white, fontSize: 16)),
                Switch(
                  value: _blockWebsites,
                  onChanged: (v) => setState(() => _blockWebsites = v),
                  activeThumbColor: _selectedColor,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          const Text(
            "How it works: These apps will be blocked 24/7. To use them for 5 minutes, you must complete an exercise challenge.",
            style: TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      buttonText: "Create Block",
      onButtonTap: _saveExerciseBlock,
    );
  }
}


Widget _buildHeader(BuildContext context, String title, {bool showBackButton = true}) { 
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), 
    child: Row(
      children: [
        if (showBackButton) 
          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context))
        else 
          const SizedBox(width: 48), 
        const Spacer(), 
        Text(title, style: const TextStyle(fontFamily: 'DxSitrus', fontSize: 24, color: Colors.white)), 
        const Spacer(), 
        const SizedBox(width: 48)
      ]
    )
  ); 
}

Widget _buildBaseScreen(BuildContext context, {required String title, required Widget child, required String buttonText, required VoidCallback onButtonTap}) {
  return Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F0518), Colors.black],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              _buildHeader(context, "VERO"),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: child,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: onButtonTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: Text(buttonText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildGlassContainer({required Widget child}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: child,
      ),
    ),
  );
}

Widget _buildRow(String label, String value, {IconData? icon}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
      Row(
        children: [
          if (icon != null) Icon(icon, color: Colors.purpleAccent, size: 20),
          if (icon != null) const SizedBox(width: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
        ],
      ),
    ],
  );
}

class _CircularSliderPainter extends CustomPainter {
  final double value;
  final Color color;
  _CircularSliderPainter(this.value, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    
    final trackPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;
      
    canvas.drawCircle(center, radius, trackPaint);
    
    final progressPaint = Paint()
      ..shader = LinearGradient(colors: [color, Colors.blueAccent])
        .createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;
      
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, 2 * math.pi * value, false, progressPaint);
    
    final angle = -math.pi / 2 + (2 * math.pi * value);
    final handleX = center.dx + radius * math.cos(angle);
    final handleY = center.dy + radius * math.sin(angle);
    
    canvas.drawCircle(Offset(handleX, handleY), 15, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(handleX, handleY), 25, Paint()..color = Colors.white.withOpacity(0.3));
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedIndex = 0;
  late AnimationController _controller;
  late Animation<double> _glowAnimation;
  final BlockService _blockService = BlockService();
  Timer? _uiTimer;
  Timer? _statsTimer;

  int _activeGlobalSessionsCount = 0;

  final Set<String> _handledCompletedSessions = {};

  bool _isDialogShowing = false;
  bool _showTutorial = false;

  static const platform = MethodChannel('com.example.vero/settings');


  String _screenTimeStr = "--";
  String _focusScoreStr = "--";
  int _currentFocusScore = 0;
  Duration _currentScreenTimeDuration = Duration.zero;
  List<String> _culpritPackages = []; 
  int _lastSavedScore = -1; 
  int _xp = 0;
  int _level = 1;
  double _levelProgress = 0.0;

  List<Map<String, dynamic>> _smartSuggestions = [];

  List<Map<String, dynamic>> _dailyChecklist = [
    {'title': 'Plan daily goals', 'done': false},
    {'title': 'Drink water', 'done': false},
    {'title': 'Clear workspace', 'done': false},
  ];  

  final List<Map<String, dynamic>> _staticSuggestions = [
    {
      'id': 'morning_routine',
      'title': 'Morning Routine',
      'subtitle': 'Every day, 6:00 AM - 9:00 AM',
      'icon': Icons.wb_sunny,
      'start': const TimeOfDay(hour: 6, minute: 0),
      'end': const TimeOfDay(hour: 9, minute: 0),
      'days': ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
      'color': Colors.orangeAccent
    },
    {
      'id': 'deep_work',
      'title': 'Deep Work',
      'subtitle': 'Weekdays, 2:00 PM - 4:00 PM',
      'icon': Icons.psychology,
      'start': const TimeOfDay(hour: 14, minute: 0),
      'end': const TimeOfDay(hour: 16, minute: 0),
      'days': ['M', 'T', 'W', 'T', 'F'],
      'color': Colors.blueAccent
    },
    {
      'id': 'wind_down',
      'title': 'Wind Down',
      'subtitle': 'Weekdays, 8:00 PM - 9:00 PM',
      'icon': Icons.weekend,
      'start': const TimeOfDay(hour: 20, minute: 0),
      'end': const TimeOfDay(hour: 21, minute: 0),
      'days': ['M', 'T', 'W', 'T', 'F'],
      'color': Colors.purpleAccent
    },
    {
      'id': 'sleep_shield',
      'title': 'Sleep Shield',
      'subtitle': 'Every day, 10:30 PM - 7:00 AM',
      'icon': Icons.bed,
      'start': const TimeOfDay(hour: 22, minute: 30),
      'end': const TimeOfDay(hour: 7, minute: 0),
      'days': ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
      'color': Colors.indigoAccent
    },
  ];

  Color _getFocusColor(int score) {
    if (score < 20) return Colors.redAccent;
    if (score < 60) return Colors.yellowAccent;
    if (score < 90) return Colors.greenAccent;
    return Colors.purpleAccent; 
  }

  Color _getScreenTimeColor(Duration duration) {
    if (duration.inHours < 2) return Colors.greenAccent;
    if (duration.inHours < 5) return Colors.yellowAccent;
    return Colors.redAccent; 
  }

Future<void> _fetchUserData() async {
    try {
      final userData = await AuthService().getDecryptedUserData();
      
      final prefs = await SharedPreferences.getInstance();
      
      int localXp = prefs.getInt('user_xp') ?? userData?['xp'] ?? 0;

      if (mounted) {
        setState(() {
          _xp = localXp;
          _level = GamificationService().getLevel(_xp);
          _levelProgress = GamificationService().getLevelProgress(_xp);
        });
      }
    } catch (e) {
      print("User Data Fetch Error: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _blockService.init().then((_) {
      if (mounted) {
        setState(() {});
        _checkFinishedSessions().then((_) {
           _blockService.checkAndShowPendingMission(context);
           _checkTutorial();
           _fetchUserData(); 
           _generateSmartSuggestions();
        });
      }
    });
    
    _blockService.addListener(_onBlockServiceChange);
    _blockService.showStreakCongrats.addListener(_showStreakCongratsDialog);
    _blockService.stopRequestFromNotification.addListener(_handleStopRequestFromNotification);

    _controller = AnimationController(duration: const Duration(seconds: 4), vsync: this)..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _fetchGlobalFocusCount(); 
    
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkFinishedSessions().then((_) {
        _fetchUserData();
        _generateSmartSuggestions();
      });
    }
  }

  Future<void> _checkFinishedSessions() async {
    if (_isDialogShowing) return;

    if (_blockService.isSnoozed()) return;

    final currentFinishedIds = <String>{};

    for (var session in _blockService.blocks) {
      if (session.isActive && session.type == BlockType.timer && session.activeStartTime != null) {
        final elapsed = DateTime.now().difference(session.activeStartTime!);
        final total = Duration(minutes: session.durationMinutes);
        
        if (elapsed >= total) {
          currentFinishedIds.add(session.id);
          
          if (!_handledCompletedSessions.contains(session.id)) {
            _handledCompletedSessions.add(session.id);

            await _blockService.stopSession(session.id, earlyExit: true, wasCompleted: true);
            break;
          }
        }
      }
    }

    _handledCompletedSessions.removeWhere((id) => !currentFinishedIds.contains(id));
  }

  Future<void> _checkTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    bool tutorialShown = prefs.getBool('tutorial_shown_v1') ?? false;
    
    if (!tutorialShown) {
      if (mounted) {
        setState(() {
          _showTutorial = true;
        });
      }
    }
  }

  Future<void> _completeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_shown_v1', true);
    if (mounted) {
      setState(() {
        _showTutorial = false;
      });
    }
  }

  Future<void> _generateSmartSuggestions() async {
    try {
      
      List<Map<String, dynamic>> newSmartSuggestions = [];
      final prefs = await SharedPreferences.getInstance();
      final ignoredPackages = prefs.getStringList('ignored_suggestions') ?? [];
      final alreadyBlockedPackages = prefs.getStringList('blocked_packages') ?? [];

      final excludedPackages = [
        'com.example.vero',
        'com.android.phone',
        'com.android.server.telecom',
        'com.android.settings',
        'com.android.systemui',
        'com.google.android.packageinstaller',
        'com.android.vending',
        'com.google.android.dialer',
        'com.samsung.android.dialer',
        'com.android.contacts',
      ];

      if (_blockService.rawUsageStats.isNotEmpty) {
        for (var appData in _blockService.rawUsageStats.take(10)) {
            String pkg = appData['package'];
            int timeMs = appData['time'];
            int minutes = (timeMs / 60000).round();

            if (minutes > 30) {
              if (!alreadyBlockedPackages.contains(pkg) && 
                  !ignoredPackages.contains(pkg) &&
                  !excludedPackages.contains(pkg)) {
                
                String appName = pkg;
                try {
                  if (await DeviceApps.isAppInstalled(pkg)) {
                    final app = await DeviceApps.getApp(pkg, true);
                    if (app != null) appName = app.appName;
                  }
                } catch (_) {}

                if (appName != pkg && 
                    !appName.toLowerCase().contains("service") && 
                    !appName.toLowerCase().contains("system") &&
                    !appName.toLowerCase().contains("phone") &&
                    !appName.toLowerCase().contains("call") &&
                    appName != "Vero" &&
                    appName != "Settings") {
                   newSmartSuggestions.add({
                    'type': 'smart',
                    'package': pkg,
                    'title': 'High Usage: $appName',
                    'subtitle': 'You used this for ${minutes}m today. Block it?',
                    'icon': Icons.warning_amber_rounded,
                    'color': Colors.redAccent,
                    'appName': appName
                  });
                }
              }
            }
          }
      }

      if (mounted) {
        setState(() {
          _smartSuggestions = newSmartSuggestions.take(3).toList(); 
        });
      }
    } catch (e) {
      print("Suggestion Gen Error: $e");
    }
  }

  Future<void> _fetchGlobalFocusCount() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('active_sessions').count().get(source: AggregateSource.server);
      if (mounted) {
        setState(() {
          _activeGlobalSessionsCount = (snapshot.count ?? 0) * 5;
        });
      }
    } catch (e) {
      print("Error fetching focus count: $e");
    }
  }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _uiTimer?.cancel();
    _statsTimer?.cancel();
    _blockService.removeListener(_onBlockServiceChange);
    _blockService.showStreakCongrats.removeListener(_showStreakCongratsDialog);
    _blockService.stopRequestFromNotification.removeListener(_handleStopRequestFromNotification);
    super.dispose();
  }


void _onBlockServiceChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _showStreakCongratsDialog() {
    if (_blockService.showStreakCongrats.value && mounted) {
      _blockService.showStreakCongrats.value = false; 
      showDialog(
        context: context,
        builder: (_) => const _StreakCongratsDialog(),
      );
    }
  }
  
  void _handleStopRequestFromNotification() {
    if (_blockService.stopRequestFromNotification.value && mounted) {
      final session = _blockService.activeSession;
      if (session != null) {
        _showStopSessionModal(session);
      }
    }
  }

  Future<void> _updateStats() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      
      final stats = await platform.invokeMethod('getAppUsageStats', {
        'start': startOfDay.millisecondsSinceEpoch,
        'end': now.millisecondsSinceEpoch,
      });

      int totalScreenMs = 0;
      List<String> topAppNames = [];
      
      List<Map<String, dynamic>> newSmartSuggestions = [];
      final prefs = await SharedPreferences.getInstance();
      final ignoredPackages = prefs.getStringList('ignored_suggestions') ?? [];
      final alreadyBlockedPackages = prefs.getStringList('blocked_packages') ?? [];

      final excludedPackages = [
        'com.example.vero',
        'com.android.phone',
        'com.android.server.telecom',
        'com.android.settings',
        'com.android.systemui',
        'com.google.android.packageinstaller',
        'com.android.vending',
        'com.google.android.dialer',
        'com.samsung.android.dialer',
        'com.android.contacts',
      ];

      if (stats != null) {
        totalScreenMs = stats['totalTime'] ?? 0;
        
        if (stats['apps'] != null) {
          List<dynamic> rawApps = stats['apps'];
          rawApps.sort((a, b) => (b['time'] as int).compareTo(a['time'] as int));
          
          _culpritPackages = rawApps.take(3).map<String>((e) => e['package'] as String).toList();
          
          for (String pkg in _culpritPackages) {
             String name = pkg.split('.').last; 
             try {
               if (await DeviceApps.isAppInstalled(pkg)) {
                 final app = await DeviceApps.getApp(pkg, true);
                 if (app != null) name = app.appName;
               }
             } catch (_) {}
             topAppNames.add(name);
          }

          for (var appData in rawApps.take(10)) {
            String pkg = appData['package'];
            int timeMs = appData['time'];
            int minutes = (timeMs / 60000).round();

            if (minutes > 30) {
              if (!alreadyBlockedPackages.contains(pkg) && 
                  !ignoredPackages.contains(pkg) &&
                  !excludedPackages.contains(pkg)) {
                
                String appName = pkg;
                try {
                  if (await DeviceApps.isAppInstalled(pkg)) {
                    final app = await DeviceApps.getApp(pkg, true);
                    if (app != null) appName = app.appName;
                  }
                } catch (_) {}

                if (appName != pkg && 
                    !appName.toLowerCase().contains("service") && 
                    !appName.toLowerCase().contains("system") &&
                    !appName.toLowerCase().contains("phone") &&
                    !appName.toLowerCase().contains("call") &&
                    appName != "Vero" &&
                    appName != "Settings") {
                   newSmartSuggestions.add({
                    'type': 'smart',
                    'package': pkg,
                    'title': 'High Usage: $appName',
                    'subtitle': 'You used this for ${minutes}m today. Block it?',
                    'icon': Icons.warning_amber_rounded,
                    'color': Colors.redAccent,
                    'appName': appName
                  });
                }
              }
            }
          }
        }
      }

      final duration = Duration(milliseconds: totalScreenMs);
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      _screenTimeStr = "${hours}h ${minutes}m";

      int activeFocusMinutes = 0;
      final activeSessions = _blockService.blocks.where((b) => b.isActive);
      for (var session in activeSessions) {
        activeFocusMinutes += session.durationMinutes; 
      }

      int totalScreenMinutes = duration.inMinutes;
      if (totalScreenMinutes == 0) totalScreenMinutes = 1;

      int score = ((activeFocusMinutes / totalScreenMinutes) * 100).round().clamp(0, 100);
      if (activeFocusMinutes == 0 && _blockService.streak > 0) {
        score = 10 + (_blockService.streak * 2).clamp(0, 20);
      }
      _focusScoreStr = "$score%";
      
      if (score != _lastSavedScore) {
        _lastSavedScore = score;
        AuthService().updateFocusScore(score);
      }
      
      await WidgetService().updateStats(
        focusScore: score, 
        screenTimeStr: _screenTimeStr, 
        culprits: topAppNames
      );

      final userData = await AuthService().getDecryptedUserData();
      int fetchedXp = userData?['xp'] ?? 0;
      
      if(mounted) {
        setState(() {
          _currentFocusScore = score;
          _currentScreenTimeDuration = duration;
          _smartSuggestions = newSmartSuggestions.take(3).toList(); 
          _xp = fetchedXp;
          _level = GamificationService().getLevel(fetchedXp);
          _levelProgress = GamificationService().getLevelProgress(fetchedXp);
        });
      }

    } catch (e) {
      print("Stats Update Error: $e");
      _screenTimeStr = "0h 0m";
      _focusScoreStr = "--";
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "Unknown";
    final now = DateTime.now();
    final String time = "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return "Today, $time";
    } else if (date.year == now.year && date.month == now.month && date.day == now.day - 1) {
      return "Yesterday, $time";
    } else {
      return "${date.day}/${date.month}, $time";
    }
  }

    String _getScheduleSubtitle(BlockSession session) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, session.startTime!.hour, session.startTime!.minute);
    final end = DateTime(now.year, now.month, now.day, session.endTime!.hour, session.endTime!.minute);

    if (session.isActive) {
      DateTime actualEnd = end.isBefore(start) ? end.add(const Duration(days: 1)) : end;
      final diff = actualEnd.difference(now);
      if (diff.isNegative) return "Finishing...";
      return "Ends in ${diff.inHours}h ${diff.inMinutes % 60}m ${diff.inSeconds % 60}s";
    } else {
      const dayChars = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      int currentDayIndex = now.weekday - 1;

      if (session.days.contains(dayChars[currentDayIndex]) && now.isBefore(start)) {
        final diff = start.difference(now);
        if (diff.inHours == 0) return "Starts in ${diff.inMinutes}m ${diff.inSeconds % 60}s";
        return "Starts in ${diff.inHours}h ${diff.inMinutes % 60}m";
      } else {
        int nextDayIndex = -1;
        for (int i = 1; i <= 7; i++) {
          int checkIndex = (currentDayIndex + i) % 7;
          if (session.days.contains(dayChars[checkIndex])) {
            nextDayIndex = checkIndex;
            break;
          }
        }
        if (nextDayIndex != -1) {
          String dayName = (nextDayIndex == (currentDayIndex + 1) % 7) ? "Tomorrow" : dayNames[nextDayIndex];
          return "Starts $dayName at ${session.startTime!.format(context)}";
        }
        return "Not scheduled to run soon";
      }
    }
  }

  Future<void> _addSuggestion(Map<String, dynamic> data) async {
    final session = BlockSession(
      id: const Uuid().v4(),
      name: data['title'],
      type: BlockType.schedule,
      startTime: data['start'],
      endTime: data['end'],
      days: data['days'],
      appPackages: [], 
      difficulty: BreakDifficulty.easy,
      colorValue: (data['color'] as Color).value,
      iconCodePoint: (data['icon'] as IconData).codePoint,
    );

    await _blockService.addBlock(session);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${data['title']} added to Upcoming!"),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      )
    );
  }

  Future<void> _handleSmartSuggestion(Map<String, dynamic> suggestion, bool block) async {
    final prefs = await SharedPreferences.getInstance();
    final pkg = suggestion['package'];

    if (block) {
      final currentBlocked = prefs.getStringList('blocked_packages') ?? [];
      if (!currentBlocked.contains(pkg)) {
        currentBlocked.add(pkg);
        await prefs.setStringList('blocked_packages', currentBlocked);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Blocked ${suggestion['appName']}"), backgroundColor: Colors.redAccent)
        );
      }
    } else {
      final ignored = prefs.getStringList('ignored_suggestions') ?? [];
      if (!ignored.contains(pkg)) {
        ignored.add(pkg);
        await prefs.setStringList('ignored_suggestions', ignored);
      }
    }
    
    _updateStats();
  }

  void _showPreviousSessionModal(BlockSession session) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(top: 30, left: 24, right: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 30),
          decoration: BoxDecoration(color: const Color(0xFF0F0518).withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(30)), border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1)))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 30),
              Text(session.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontFamily: 'DxSitrus')),
              const SizedBox(height: 10),
              Text("Finished: ${_formatDate(session.completedAt)}", style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 10),
              Text(session.isCompleted == true ? "✅ Mission Accomplished" : "❌ Failed / Given Up", style: TextStyle(color: session.isCompleted == true ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold)),
              
              if (session.notes != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15)),
                  child: Column(
                    children: [
                      if (session.rating != null) 
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(session.rating!, (i) => const Icon(Icons.star, color: Colors.amber, size: 20))),
                      if (session.rating != null) const SizedBox(height: 10),
                      Text(session.notes!, style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 30),
              _buildActionButton(
                text: "Restart Session", 
                color: Colors.white, 
                textColor: Colors.black, 
                onTap: () async {
                  await _blockService.startSession(session.id);
                  Navigator.pop(context);
                }
              ),
              const SizedBox(height: 15),
              _buildActionButton(
                text: "Delete Record", 
                color: Colors.white.withOpacity(0.1), 
                textColor: Colors.redAccent, 
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  await _blockService.deleteBlock(session.id);
                  Navigator.pop(context);
                }
              ),
            ],
          ),
        ),
      ),
    );
  }

    void _showEditSessionModal(BlockSession session) {
    if (session.difficulty == BreakDifficulty.none && session.type != BlockType.exercise) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No Breaks Mode: You cannot edit this session."), backgroundColor: Colors.redAccent));
      return;
    }

    TextEditingController nameCtrl = TextEditingController(text: session.name);
    
    TimeOfDay tempStart = session.startTime ?? const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay tempEnd = session.endTime ?? const TimeOfDay(hour: 17, minute: 0);
    
    final List<String> dayLabels = ["M", "T", "W", "T", "F", "S", "S"];
    Set<int> selectedIndices = {};

    if (session.type == BlockType.schedule) {
      List<String> tempDays = List.from(session.days);
      for (int i = 0; i < dayLabels.length; i++) {
        if (tempDays.contains(dayLabels[i])) {
          selectedIndices.add(i);
          tempDays.remove(dayLabels[i]); 
        }
      }
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder( 
        builder: (context, setModalState) {
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: EdgeInsets.only(top: 30, left: 24, right: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 30),
              decoration: BoxDecoration(color: const Color(0xFF0F0518).withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(30)), border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1)))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 30),
                  const Text("Manage Session", style: TextStyle(color: Colors.white, fontSize: 24, fontFamily: 'DxSitrus')),
                  const SizedBox(height: 30),
                  
                  _buildGlassContainer(child: TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white, fontSize: 18), decoration: const InputDecoration(border: InputBorder.none, labelText: "Session Name", labelStyle: TextStyle(color: Colors.grey)))),
                  const SizedBox(height: 20),

                  if (session.type == BlockType.schedule) ...[
                    _buildGlassContainer(
                      child: Column(
                        children: [
                          _buildTimePickerRow("From", tempStart, (t) => setModalState(() => tempStart = t)),
                          const Divider(color: Colors.white10),
                          _buildTimePickerRow("To", tempEnd, (t) => setModalState(() => tempEnd = t)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Align(alignment: Alignment.centerLeft, child: Text("Days", style: TextStyle(color: Colors.grey, fontSize: 14))),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(dayLabels.length, (index) {
                        final isSelected = selectedIndices.contains(index);
                        return GestureDetector(
                          onTap: () => setModalState(() {
                            if (isSelected) {
                              selectedIndices.remove(index);
                            } else {
                              selectedIndices.add(index);
                            }
                          }),
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(color: isSelected ? Colors.white : Colors.grey),
                            ),
                            child: Center(child: Text(dayLabels[index], style: TextStyle(color: isSelected ? Colors.black : Colors.grey, fontWeight: FontWeight.bold))),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                  ],

                  Row(
                    children: [
                      Expanded(child: _buildActionButton(
                        text: "Save", 
                        color: Colors.white, 
                        textColor: Colors.black, 
                        onTap: () async {
                          session.name = nameCtrl.text;
                          if (session.type == BlockType.schedule) {
                            session.startTime = tempStart;
                            session.endTime = tempEnd;
                            session.days.clear();
                            for (int i = 0; i < dayLabels.length; i++) {
                              if (selectedIndices.contains(i)) {
                                session.days.add(dayLabels[i]);
                              }
                            }
                          }
                          await _blockService.updateBlock(session);
                          Navigator.pop(context);
                        }
                      )),
                      const SizedBox(width: 15),
                      Expanded(child: _buildActionButton(
                        text: "Delete", 
                        color: Colors.white.withOpacity(0.1), 
                        textColor: Colors.redAccent, 
                        onTap: () async { 
                          Navigator.pop(context);
                          
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            isScrollControlled: true,
                            builder: (context) => StopSessionDialog(
                              session: session,
                              onStop: (bool completed) async {
                                await _blockService.deleteBlock(session.id);
                                if (mounted) Navigator.pop(context);
                              },
                            ),
                          );
                        }
                      )),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }


  void _showStopSessionModal(BlockSession session) {
    if (_isDialogShowing) return; 
    _isDialogShowing = true;

    if (session.difficulty == BreakDifficulty.none) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1A0B2E),
          title: const Text("NO BREAKS MODE", style: TextStyle(color: Colors.redAccent, fontFamily: 'DxSitrus')),
          content: const Text("You committed to this. You cannot stop the session until the timer runs out.", style: TextStyle(color: Colors.white70)),
          actions: [TextButton(onPressed: () { 
            Navigator.pop(context);
            _isDialogShowing = false;
          }, child: const Text("I'll Keep Going", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))],
        ),
      ).then((_) => _isDialogShowing = false);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StopSessionDialog(
        session: session, 
        onStop: (bool completed) async {
          Navigator.pop(context); 
          _isDialogShowing = false;
          
          if (completed) {
            await showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (context) => DebriefSheet(
                onSubmit: (rating, notes) async {
                  await _blockService.stopSession(session.id, earlyExit: true, wasCompleted: true, rating: rating, notes: notes);
                }
              )
            );
          } else {
            await _blockService.stopSession(session.id, earlyExit: true, wasCompleted: false);
          }
        }
      ),
    ).then((_) => _isDialogShowing = false);
  }

  Widget _buildTimePickerRow(String label, TimeOfDay time, Function(TimeOfDay) onPick) {
    return GestureDetector(
      onTap: () async {
        final t = await showTimePicker(context: context, initialTime: time);
        if (t != null) onPick(t);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
            Row(
              children: [
                Text(time.format(context), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required String text, required Color color, required VoidCallback onTap, Color textColor = Colors.white}) {
    return SizedBox(
      width: double.infinity, height: 55,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color, 
          foregroundColor: textColor, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
        ),
        child: Text(text, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.black,
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          floatingActionButton: _selectedIndex == 0 ? FloatingActionButton.extended(
            onPressed: () async { await showBlockSelectionModal(context); }, 
            backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 10, icon: const Icon(Icons.add), label: const Text("New Block", style: TextStyle(fontWeight: FontWeight.bold)),
          ) : null,
          body: IndexedStack(index: _selectedIndex, children: [_buildDashboard(), const TimerScreen(), const StatsScreen()]),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex, onTap: (i) {
              HapticFeedback.selectionClick();
              HapticFeedback.mediumImpact();
              setState(() => _selectedIndex = i);
            },
            backgroundColor: Colors.black, selectedItemColor: Colors.purpleAccent, unselectedItemColor: Colors.white24, type: BottomNavigationBarType.fixed, showSelectedLabels: false, showUnselectedLabels: false,
            items: const [BottomNavigationBarItem(icon: Icon(Icons.home_filled, size: 28), label: "Home"), BottomNavigationBarItem(icon: Icon(Icons.timer, size: 28), label: "Timer"), BottomNavigationBarItem(icon: Icon(Icons.bar_chart, size: 28), label: "Stats")],
          ),
        ),
        if (_showTutorial)
          TutorialOverlay(
            onComplete: _completeTutorial,
          ),
      ],
    );
  }

  Widget _buildDashboard() {
    final activeSessions = _blockService.blocks.where((b) => b.isActive || b.type == BlockType.limit || b.type == BlockType.exercise).toList();
    final upcoming = _blockService.blocks.where((b) => !b.isActive && b.type == BlockType.schedule).toList();
    final previous = _blockService.blocks.where((b) => !b.isActive && b.type != BlockType.schedule && b.type != BlockType.limit && b.type != BlockType.exercise && b.completedAt != null).toList();
    previous.sort((a, b) => b.completedAt!.compareTo(a.completedAt!));

    final bool isBreak = _blockService.isSnoozed();
    final allSuggestions = [..._smartSuggestions, ..._staticSuggestions];

    return Stack(
      children: [
        Positioned.fill(child: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF120520), Colors.black])))),
        SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(top: 80, bottom: 100), 
            child: Column(
              children: [
                const SizedBox(height: 20),
                Center(
                  child: FireStreakWidget(streak: _blockService.streak),
                ),
                const SizedBox(height: 50),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24), 
                  child: Row(
                    children: [
                      Expanded(child: _buildLevelCard()), 
                      const SizedBox(width: 12), 
                        Expanded(child: _buildCulpritCard()),
                    ]
                  )
                ),
                const SizedBox(height: 40),

                const Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Align(alignment: Alignment.centerLeft, child: Text("DAILY GOALS", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)))),
                const SizedBox(height: 15),
                _buildChecklist(),
                const SizedBox(height: 30),
                
                if (activeSessions.isNotEmpty) ...[
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Align(alignment: Alignment.centerLeft, child: Text("NOW", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)))),
                  const SizedBox(height: 15),
                  
                  ...activeSessions.map((session) {
                    final String title = isBreak ? "ON BREAK (${session.name})" : session.name;
                    
                    String subtitle;
                    double progress = 0.0; 

                    if (isBreak) {
                        subtitle = "Break ends in: ${_blockService.getBreakRemainingTime()}";
                        progress = 1.0; 
                    } else if (session.type == BlockType.schedule) {
                        subtitle = _getScheduleSubtitle(session);
                        
                        if (session.startTime != null && session.endTime != null) {
                          final now = DateTime.now();
                          final start = DateTime(now.year, now.month, now.day, session.startTime!.hour, session.startTime!.minute);
                          final end = DateTime(now.year, now.month, now.day, session.endTime!.hour, session.endTime!.minute);
                          DateTime actualEnd = end.isBefore(start) ? end.add(const Duration(days: 1)) : end;
                          
                          int totalSeconds = actualEnd.difference(start).inSeconds;
                          int elapsedSeconds = now.difference(start).inSeconds;
                          
                          if (totalSeconds > 0) {
                            progress = (elapsedSeconds / totalSeconds).clamp(0.0, 1.0);
                          }
                        }
                    } else if (session.type == BlockType.location) {
                        subtitle = "Active in this zone";
                        progress = 1.0; 
                    } else if (session.type == BlockType.limit) {
                        subtitle = "Limit: ${session.durationMinutes}m/day";
                        progress = 1.0;
                    } else if (session.type == BlockType.exercise) {
                        subtitle = "Block & Burn 🔥";
                        progress = 1.0;
                    } else {
                        subtitle = _blockService.getRemainingTime(session);
                        if (session.activeStartTime != null && session.durationMinutes > 0) {
                          final elapsed = DateTime.now().difference(session.activeStartTime!).inSeconds;
                          final total = session.durationMinutes * 60;
                          progress = (elapsed / total).clamp(0.0, 1.0);
                        }
                    }

                    final Color cardColor = isBreak ? Colors.greenAccent : Color(session.colorValue);
                    final IconData cardIcon = isBreak ? Icons.coffee : IconData(session.iconCodePoint, fontFamily: 'MaterialIcons');

                    return GestureDetector(
                      onTap: () => session.type == BlockType.limit || session.type == BlockType.exercise
                        ? _showEditSessionModal(session) 
                        : _showStopSessionModal(session),
                      child: _buildSessionCard(
                        icon: cardIcon, 
                        title: title, 
                        subtitle: subtitle, 
                        color: cardColor, 
                        isNow: true, 
                        apps: session.appPackages,
                        blockWebsites: session.blockWebsites,
                        progress: progress 
                      ),
                    );
                  }).toList(),
                  
                  const SizedBox(height: 30),
                ],

                const Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Align(alignment: Alignment.centerLeft, child: Text("UPCOMING", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)))),
                const SizedBox(height: 15),
                ...upcoming.map((b) => GestureDetector(
                  onTap: () => _showEditSessionModal(b), 
                  child: _buildSessionCard(
                    icon: IconData(b.iconCodePoint, fontFamily: 'MaterialIcons'), 
                    title: b.name, 
                    subtitle: _getScheduleSubtitle(b),
                    color: Color(b.colorValue)
                  ),
                )).toList(),
                
                if (upcoming.isEmpty) const Padding(padding: EdgeInsets.only(top: 10, bottom: 20), child: Text("No upcoming schedules", style: TextStyle(color: Colors.grey))),

                const SizedBox(height: 30),
                
                if (previous.isNotEmpty) ...[
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Align(alignment: Alignment.centerLeft, child: Text("PREVIOUS", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)))),
                  const SizedBox(height: 15),
                  ...previous.map((b) {
                    String subtitle = "${b.durationMinutes}m • Finished: ${_formatDate(b.completedAt)}";
                    if (b.notes != null && b.notes!.isNotEmpty) {
                      subtitle += "\n📝 ${b.notes}";
                    }
                    if (b.rating != null && b.rating! > 0) {
                      subtitle += "\n${'⭐' * b.rating!}";
                    }

                    return GestureDetector(
                      onTap: () => _showPreviousSessionModal(b), 
                      child: _buildSessionCard(
                        icon: IconData(b.iconCodePoint, fontFamily: 'MaterialIcons'), 
                        title: b.name, 
                        subtitle: subtitle,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 30),
                ],

                const Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Align(alignment: Alignment.centerLeft, child: Text("SUGGESTIONS", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)))),
                const SizedBox(height: 15),
                
                ...allSuggestions.map((s) {
                  final isSmart = s.containsKey('type') && s['type'] == 'smart';
                  
                  return GestureDetector(
                    onTap: () {}, 
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12, left: 24, right: 24),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isSmart ? Colors.redAccent.withOpacity(0.1) : Colors.white.withOpacity(0.05), 
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSmart ? Colors.redAccent.withOpacity(0.5) : Colors.white10),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: (s['color'] as Color).withOpacity(0.2),
                                    shape: BoxShape.circle
                                  ),
                                  child: Icon(s['icon'], color: s['color'], size: 20),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s['title'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                      const SizedBox(height: 4),
                                      Text(s['subtitle'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                
                                if (isSmart) ...[
                                  IconButton(
                                    icon: const Text("❌", style: TextStyle(fontSize: 20)),
                                    onPressed: () {
                                      HapticFeedback.mediumImpact();
                                      _handleSmartSuggestion(s, false);
                                    }, 
                                  ),
                                  IconButton(
                                    icon: const Text("✅", style: TextStyle(fontSize: 20)),
                                    onPressed: () {
                                      HapticFeedback.mediumImpact();
                                      _handleSmartSuggestion(s, true);
                                    }, 
                                  ),
                                ] else ...[
                                  SizedBox(
                                    height: 32,
                                    child: ElevatedButton(
                                     onPressed: () {
                                        HapticFeedback.lightImpact();
                                        _addSuggestion(s);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white.withOpacity(0.1),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                      ),
                                      child: const Text("+ Add", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
        
        Positioned(
          top: 0, left: 0, right: 0, 
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), 
              color: Colors.transparent, 
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("VERO", style: TextStyle(fontFamily: 'DxSitrus', fontSize: 28, color: Colors.white)),
                      _buildLiveFocusCounter(),
                    ],
                  ),
                                    Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.bolt, color: Colors.greenAccent, size: 14),
                              const SizedBox(width: 4),
                              Text("${_blockService.statsFocusScore}%", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.smartphone, color: Colors.grey, size: 14),
                              const SizedBox(width: 4),
                              Text(_blockService.statsScreenTime, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(width: 15),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const RemindersScreen()));
                        }, 
                        child: Container(
                          padding: const EdgeInsets.all(8), 
                          margin: const EdgeInsets.only(right: 15),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle), 
                          child: const Icon(Icons.notifications_active, color: Colors.white, size: 24)
                        )
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                          HapticFeedback.mediumImpact();
                        }, 
                        child: Container(
                          padding: const EdgeInsets.all(8), 
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle), 
                          child: const Icon(Icons.person, color: Colors.white, size: 24)
                        )
                      ),
                    ],
                  )
                ]
              )
            )
          )
        ),
      ],
    );
  }

  Widget _buildChecklist() {
    final checklist = _blockService.checklist;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          ...checklist.asMap().entries.map((entry) {
            int index = entry.key;
            Map<String, dynamic> item = entry.value;
            bool isDone = item['done'];

            return Dismissible(
              key: Key("${item['title']}_$index"),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => _blockService.deleteCheckItem(index),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                color: Colors.redAccent,
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _blockService.toggleCheckItem(index);
                },
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  _showEditChecklistItemDialog(index, item['title']);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDone ? Colors.greenAccent.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: isDone ? Colors.greenAccent.withOpacity(0.5) : Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isDone ? Icons.check_circle : Icons.circle_outlined,
                        color: isDone ? Colors.greenAccent : Colors.grey,
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          item['title'],
                          style: TextStyle(
                            color: isDone ? Colors.white : Colors.white70,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                            fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.grey, size: 18),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          _showEditChecklistItemDialog(index, item['title']);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          _blockService.deleteCheckItem(index);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
          
          GestureDetector(
            onTap: () => _showEditChecklistItemDialog(-1, ""),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white10, style: BorderStyle.solid),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.add, color: Colors.grey, size: 20),
                  SizedBox(width: 8),
                  Text("Add Goal", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditChecklistItemDialog(int index, String currentTitle) {
    final TextEditingController textCtrl = TextEditingController(text: currentTitle);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A0B2E),
        title: Text(index == -1 ? "New Goal" : "Edit Goal", style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "e.g. Drink Water",
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (textCtrl.text.isNotEmpty) {
                if (index == -1) {
                  _blockService.addCheckItem(textCtrl.text.trim());
                } else {
                  _blockService.updateCheckItem(index, textCtrl.text.trim());
                }
                Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  Widget _buildLiveFocusCounter() {
    if (_activeGlobalSessionsCount == 0) return const SizedBox.shrink();
    
    return Row(
      children: [
        Container(
          width: 8, height: 8,
          decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text("$_activeGlobalSessionsCount Focusing Now", style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildInfoCard({required String title, required String value, required Color color}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 100,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10)
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(fontSize: 9, color: Colors.grey, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
                const SizedBox(height: 5),
                Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              ]
            ),
          )
        )
      )
    );
  }

    Widget _buildLevelCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 100,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10)
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("LEVEL", style: TextStyle(fontSize: 9, color: Colors.grey, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
                  Text("${_xp} XP", style: const TextStyle(fontSize: 9, color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 5),
              Text("$_level", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, height: 1)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: _levelProgress,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
                  minHeight: 4,
                ),
              )
            ]
          ),
        )
      )
    );
  }

  Widget _buildCulpritCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 100,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10)
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("CULPRITS", style: TextStyle(fontSize: 9, color: Colors.grey, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              SizedBox(
                height: 30,
                child: _blockService.statsCulprits.isEmpty 
                  ? const Text("--", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)) 
                  : FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: BlockedAppIcons(packages: _blockService.statsCulprits, size: 24), 
                    ),
              )
            ]
          )
        )
      )
    );
  }

  Widget _buildSessionCard({
    required IconData icon, 
    required String title, 
    required String subtitle, 
    required Color color, 
    bool isNow = false, 
    List<String>? apps,
    bool blockWebsites = false,
    double? progress 
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 24, right: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: isNow ? color.withOpacity(0.1) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isNow ? color : Colors.white10)
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
                            child: Icon(icon, color: color, size: 20)
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                const SizedBox(height: 4),
                                Text(
                                  subtitle, 
                                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                )
                              ]
                            )
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14)
                        ]
                      ),
                      if (isNow && ((apps != null && apps.isNotEmpty) || blockWebsites)) ...[
                        const SizedBox(height: 15),
                        BlockedAppIcons(packages: apps ?? [], blockWebsites: blockWebsites),
                      ]
                    ],
                  ),
                ),
                if (progress != null)
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.5)),
                    minHeight: 3,
                  ),
              ],
            ),
          )
        )
      )
    );
  }

  Widget _buildGlassContainer({required Widget child}) {
    return ClipRRect(borderRadius: BorderRadius.circular(20), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)), child: child)));
  }
}

class BlockedAppIcons extends StatefulWidget {
  final List<String> packages;
  final bool blockWebsites;
  final double size; 
  const BlockedAppIcons({
    super.key, 
    required this.packages, 
    this.blockWebsites = false,
    this.size = 24
  });

  @override
  State<BlockedAppIcons> createState() => _BlockedAppIconsState();
}

class _BlockedAppIconsState extends State<BlockedAppIcons> {
  List<Widget> _icons = [];

  @override
  void initState() {
    super.initState();
    _loadIcons();
  }

  @override
  void didUpdateWidget(covariant BlockedAppIcons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.packages, widget.packages) || oldWidget.blockWebsites != widget.blockWebsites) {
      _loadIcons();
    }
  }

  Future<void> _loadIcons() async {
    List<Widget> children = [];
    
    int appCount = widget.packages.length;
    int maxApps = 3;
    
    for (int i = 0; i < appCount && i < maxApps; i++) {
      String pkg = widget.packages[i];
      try {
        final app = await DeviceApps.getApp(pkg, true);
        if (app is ApplicationWithIcon) {
          children.add(Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Image.memory(app.icon, width: widget.size, height: widget.size),
          ));
        } else {
          throw Exception();
        }
      } catch (e) {
        children.add(Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Icon(Icons.android, size: widget.size, color: Colors.grey),
        ));
      }
    }

    if (appCount > maxApps) {
      children.add(Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Text(
          "+${appCount - maxApps}", 
          style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)
        ),
      ));
    }

    if (widget.blockWebsites) {
      final prefs = await SharedPreferences.getInstance();
      final urlString = prefs.getString('blocked_urls') ?? "";
      int webCount = 0;
      if (urlString.startsWith("LIST:")) {
        webCount = urlString.substring(5).split(",").where((e) => e.isNotEmpty).length;
      }

      if (webCount > 0) {
        children.add(Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Icon(Icons.public, size: widget.size, color: Colors.blueAccent),
        ));

        if (webCount > 1) {
          children.add(Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              "+${webCount - 1}", 
              style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)
            ),
          ));
        }
      }
    }

    if (mounted) setState(() => _icons = children);
  }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: _icons);
  }
}

class _StreakCongratsDialog extends StatefulWidget {
  const _StreakCongratsDialog();

  @override
  State<_StreakCongratsDialog> createState() => _StreakCongratsDialogState();
}

class _StreakCongratsDialogState extends State<_StreakCongratsDialog> with SingleTickerProviderStateMixin {
  late AnimationController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(duration: const Duration(seconds: 3), vsync: this)..forward();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: ConfettiPainter(_confettiController),
          ),
        ),
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0518),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.purpleAccent.withOpacity(0.5), width: 2),
              boxShadow: [BoxShadow(color: Colors.purpleAccent.withOpacity(0.3), blurRadius: 30, spreadRadius: 5)]
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 60),
                const SizedBox(height: 20),
                const Text("STREAK UP!", style: TextStyle(fontFamily: 'DxSitrus', fontSize: 32, color: Colors.white, decoration: TextDecoration.none)),
                const SizedBox(height: 10),
                const Text("You kept your focus yesterday. Keep it up!", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 14, decoration: TextDecoration.none, fontWeight: FontWeight.normal)),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
                    child: const Text("LET'S GO", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ConfettiPainter extends CustomPainter {
  final AnimationController controller;
  final List<ConfettiParticle> particles = [];

  ConfettiPainter(this.controller) : super(repaint: controller) {
    for (int i = 0; i < 50; i++) {
      particles.add(ConfettiParticle());
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var p in particles) {
      p.update(controller.value, size);
      paint.color = p.color;
      canvas.drawCircle(p.position, p.size, paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ConfettiParticle {
  late Offset position;
  late Color color;
  late double size;
  late double speed;
  late double angle;

  ConfettiParticle() {
    final r = math.Random();
    position = const Offset(200, 200); 
    color = [Colors.red, Colors.blue, Colors.green, Colors.yellow, Colors.purple][r.nextInt(5)];
    size = r.nextDouble() * 5 + 2;
    speed = r.nextDouble() * 10 + 2;
    angle = r.nextDouble() * 2 * math.pi;
  }

  void update(double t, Size canvasSize) {
    double dx = math.cos(angle) * speed;
    double dy = math.sin(angle) * speed;
    position += Offset(dx, dy);
  }
}
class FireStreakWidget extends StatefulWidget {
  final int streak;
  const FireStreakWidget({super.key, required this.streak});

  @override
  State<FireStreakWidget> createState() => _FireStreakWidgetState();
}

class _FireStreakWidgetState extends State<FireStreakWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<FireParticle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
    _controller.addListener(_updateParticles);
  }

  void _updateParticles() {
    int spawnCount = _random.nextInt(5) + 2; 
    for (int i = 0; i < spawnCount; i++) {
      _particles.add(FireParticle());
    }

    for (int i = _particles.length - 1; i >= 0; i--) {
      _particles[i].update();
      if (_particles[i].isDead) {
        _particles.removeAt(i);
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: FirePainter(_particles),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "${widget.streak}",
                style: const TextStyle(
                  fontSize: 80,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'DxSitrus',
                  shadows: [
                    Shadow(color: Colors.orangeAccent, blurRadius: 20),
                    Shadow(color: Colors.black, blurRadius: 5),
                  ],
                ),
              ),
              const Text(
                "DAY STREAK",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
}

class FirePainter extends CustomPainter {
  final List<FireParticle> particles;
  FirePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      var paint = Paint()..color = p.color.withOpacity(p.life);
      canvas.drawCircle(Offset(size.width / 2 + p.x, size.height - 40 - p.y), p.size, paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class FireParticle {
  double x;
  double y;
  double size;
  double life;
  double decay;
  double speedY;
  double wobbleFreq;
  double wobblePhase;
  Color color;

  bool get isDead => life <= 0;

  FireParticle() 
      : x = (math.Random().nextDouble() - 0.5) * 160,
        y = 0,
        size = math.Random().nextDouble() * 14 + 6,
        life = 1.0,
        decay = math.Random().nextDouble() * 0.03 + 0.01,
        speedY = math.Random().nextDouble() * 2 + 1.5,
        wobbleFreq = math.Random().nextDouble() * 0.1 + 0.05,
        wobblePhase = math.Random().nextDouble() * math.pi * 2,
        color = Colors.yellowAccent;

  void update() {
    life -= decay;
    y += speedY;
    
    x += math.sin(y * wobbleFreq + wobblePhase) * 0.5;
    
    size *= 0.97;

    if (life > 0.7) {
      color = Colors.white; 
    } else if (life > 0.5) {
      color = Colors.yellowAccent;
    } else if (life > 0.3) {
      color = Colors.orangeAccent;
    } else {
      color = Colors.deepOrange;
    }
  }
}
