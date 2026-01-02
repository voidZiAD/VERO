import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class AppWebsiteSelectionSheet extends StatefulWidget {
  final List<String> initialSelectedPackages;
  final List<String> initialSelectedUrls;

  const AppWebsiteSelectionSheet({
    super.key,
    required this.initialSelectedPackages,
    required this.initialSelectedUrls,
  });

  @override
  State<AppWebsiteSelectionSheet> createState() => _AppWebsiteSelectionSheetState();
}

class _AppWebsiteSelectionSheetState extends State<AppWebsiteSelectionSheet> {
  List<Application> _installedApps = [];
  late List<String> _selectedPackageNames;
  late List<String> _selectedUrls;
  final List<Map<String, String>> _defaultWebsites = [
    {'name': 'Facebook', 'url': 'facebook.com', 'icon': 'assets/web_icons/facebook.png'},
    {'name': 'Instagram', 'url': 'instagram.com', 'icon': 'assets/web_icons/instagram.png'},
    {'name': 'Reddit', 'url': 'reddit.com', 'icon': 'assets/web_icons/reddit.png'},
    {'name': 'Twitter / X', 'url': 'x.com', 'icon': 'assets/web_icons/x.png'},
    {'name': 'YouTube', 'url': 'youtube.com', 'icon': 'assets/web_icons/youtube.png'},
    {'name': 'TikTok', 'url': 'tiktok.com', 'icon': 'assets/web_icons/tiktok.png'},
  ];
  List<Map<String, String>> _customWebsites = [];

  bool _isLoadingApps = true;
  int _tabIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _selectedPackageNames = List.from(widget.initialSelectedPackages);
    _selectedUrls = List.from(widget.initialSelectedUrls);
    _fetchInstalledApps();
    _loadCustomWebsites();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase().trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchInstalledApps() async {
    final apps = await DeviceApps.getInstalledApplications(
      includeAppIcons: true,
      includeSystemApps: false,
      onlyAppsWithLaunchIntent: true,
    );
    apps.sort((a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));

    if (mounted) {
      setState(() {
        _installedApps = apps;
        _isLoadingApps = false;
      });
    }
  }

  Future<void> _loadCustomWebsites() async {
    final prefs = await SharedPreferences.getInstance();
    final customWebsitesJson = prefs.getString('flutter.custom_websites') ?? "[]";
    try {
      final List<dynamic> jsonList = List.from(jsonDecode(customWebsitesJson));
      _customWebsites = jsonList.map((e) => Map<String, String>.from(e)).toList();
    } catch (e) {
      _customWebsites = [];
    }
    if (mounted) setState(() {});
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

  void _addCustomUrl(String url) {
    if (url.isNotEmpty) {
      if (!url.contains(".")) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a valid URL (e.g. example.com)")));
        return;
      }
      setState(() {
        final newSite = {'name': url, 'url': url, 'icon': ''};
        if (!_customWebsites.any((site) => site['url'] == url)) {
          _customWebsites.add(newSite);
        }
        if (!_selectedUrls.contains(url)) {
          _selectedUrls.add(url);
        }
        _searchController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold( 
      backgroundColor: Colors.transparent, 
      resizeToAvoidBottomInset: false, 
      body: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.only(top: 24, left: 24, right: 24), 
        decoration: BoxDecoration(
          color: const Color(0xFF0F0518),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
        ),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 30),
            const Text("Select Apps & Websites", style: TextStyle(color: Colors.white, fontSize: 24, fontFamily: 'DxSitrus')),
            const SizedBox(height: 20),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 0),
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
              padding: const EdgeInsets.symmetric(horizontal: 0),
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
              padding: EdgeInsets.only(top: 10, bottom: MediaQuery.of(context).padding.bottom), 
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    Navigator.pop(context, {
                      'packages': _selectedPackageNames,
                      'urls': _selectedUrls,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text("Confirm Selection", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            )
          ],
        ),
      ),
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
              "Add & Block '${_searchQuery}'",
              style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)
            ),
            onTap: () {
              HapticFeedback.selectionClick();
              _addCustomUrl(_searchQuery);
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
              HapticFeedback.selectionClick();
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
}
