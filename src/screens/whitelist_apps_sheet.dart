import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WhitelistAppsSheet extends StatefulWidget {
  final VoidCallback onSaved;
  const WhitelistAppsSheet({super.key, required this.onSaved});

  @override
  State<WhitelistAppsSheet> createState() => _WhitelistAppsSheetState();
}

class _WhitelistAppsSheetState extends State<WhitelistAppsSheet> {
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
    
    final String savedString = prefs.getString('whitelisted_packages') ?? "";
    List<String> saved = [];
    if (savedString.startsWith("LIST:")) {
      saved = savedString.substring(5).split(",").where((e) => e.isNotEmpty).toList();
    }
    
    final apps = await DeviceApps.getInstalledApplications(
      includeAppIcons: true, 
      includeSystemApps: true, 
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
    
    final String formattedString = "LIST:${_selected.join(',')}";
    await prefs.setString('whitelisted_packages', formattedString);
    
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
          const Text("Whitelist Apps", style: TextStyle(color: Colors.white, fontSize: 24, fontFamily: 'DxSitrus')),
          const SizedBox(height: 10),
          const Text(
            "These apps will NEVER be blocked.",
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
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
                        activeColor: Colors.greenAccent,
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
              child: Text("Save Whitelist (${_selected.length})", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
