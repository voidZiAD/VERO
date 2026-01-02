import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart'; 
import '../services/block_service.dart';
import 'package:geocoding/geocoding.dart';

class FocusZonesScreen extends StatefulWidget {
  const FocusZonesScreen({super.key});

  @override
  State<FocusZonesScreen> createState() => _FocusZonesScreenState();
}

class _FocusZonesScreenState extends State<FocusZonesScreen> {
  final BlockService _blockService = BlockService();
  bool _isLoading = false;

  Future<void> _addCurrentLocation() async {
    setState(() => _isLoading = true);
    
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError("Location permission denied.");
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        _showError("Location permission permanently denied.");
        openAppSettings();
        return;
      }
      
      if (permission == LocationPermission.whileInUse) {
        bool granted = await Permission.locationAlways.request().isGranted;
        if (!granted) {
           print("VERO: Background location not granted.");
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        forceAndroidLocationManager: true 
      );

      if (!mounted) return;
      _showNameDialog(position.latitude, position.longitude, defaultName: "Current Location");

    } catch (e) {
      _showError("Failed to get location: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openSearchModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SearchLocationSheet(
        onSelect: (lat, lng, name) {
          _showNameDialog(lat, lng, defaultName: name);
        }
      ),
    );
  }

  void _showNameDialog(double lat, double lng, {String? defaultName}) {
    final TextEditingController nameCtrl = TextEditingController(text: defaultName);
    double selectedRadius = 100.0; 

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A0B2E),
              title: const Text("Name this Zone", style: TextStyle(color: Colors.white, fontFamily: 'DxSitrus')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "e.g. Library, Office",
                      hintStyle: TextStyle(color: Colors.white38),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.purpleAccent)),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    "Coordinates: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}",
                    style: const TextStyle(color: Colors.grey, fontSize: 10, fontFamily: 'Courier'),
                  ),
                  const SizedBox(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Radius:", style: TextStyle(color: Colors.grey)),
                      Text("${selectedRadius.toInt()}m", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: selectedRadius,
                    min: 50,
                    max: 500,
                    divisions: 9,
                    activeColor: Colors.purpleAccent,
                    inactiveColor: Colors.white24,
                    label: "${selectedRadius.toInt()}m",
                    onChanged: (val) {
                      setDialogState(() {
                        selectedRadius = val;
                      });
                    },
                  ),
                  const Center(
                    child: Text(
                      "50m = Room | 100m = Building | 500m = Campus",
                      style: TextStyle(color: Colors.white24, fontSize: 10),
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
                  onPressed: () async {
                    if (nameCtrl.text.isNotEmpty) {
                      final zone = FocusZone(
                        id: const Uuid().v4(),
                        name: nameCtrl.text.trim(),
                        latitude: lat, 
                        longitude: lng, 
                        radius: selectedRadius, 
                      );
                      await _blockService.addFocusZone(zone);
                      if (mounted) {
                        Navigator.pop(context);
                        setState(() {}); 
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, foregroundColor: Colors.black),
                  child: const Text("Save Zone"),
                )
              ],
            );
          }
        );
      },
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    final zones = _blockService.focusZones;

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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 10),
                      const Text("Focus Zones", style: TextStyle(fontFamily: 'DxSitrus', fontSize: 24, color: Colors.white)),
                    ],
                  ),
                ),
                
                Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.location_on, color: Colors.purpleAccent),
                      SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          "VERO will automatically start a blocking session when you enter these zones.",
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: zones.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.map_outlined, size: 60, color: Colors.white24),
                              SizedBox(height: 20),
                              Text("No Zones Added", style: TextStyle(color: Colors.white38)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: zones.length,
                          itemBuilder: (context, index) {
                            final zone = zones[index];
                            return ListTile(
                              leading: const Icon(Icons.location_city, color: Colors.white),
                              title: Text(zone.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              subtitle: Text("Radius: ${zone.radius.toInt()}m • ${zone.latitude.toStringAsFixed(4)}, ${zone.longitude.toStringAsFixed(4)}", style: const TextStyle(color: Colors.grey)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () async {
                                  await _blockService.removeFocusZone(zone.id);
                                  setState(() {});
                                },
                              ),
                            );
                          },
                        ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 60,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _addCurrentLocation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            icon: _isLoading 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                              : const Icon(Icons.my_location),
                            label: const Text("Current", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: SizedBox(
                          height: 60,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _openSearchModal,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purpleAccent.withOpacity(0.2),
                              foregroundColor: Colors.purpleAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: const BorderSide(color: Colors.purpleAccent)
                              ),
                            ),
                            icon: const Icon(Icons.search),
                            label: const Text("Search", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
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

class _SearchLocationSheet extends StatefulWidget {
  final Function(double, double, String) onSelect;
  const _SearchLocationSheet({required this.onSelect});

  @override
  State<_SearchLocationSheet> createState() => _SearchLocationSheetState();
}

class _SearchLocationSheetState extends State<_SearchLocationSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = []; 
  bool _isSearching = false;
  Timer? _debounce;

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      if (query.length > 2) {
        _performSearch(query);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);
    try {
      List<Location> locations = await locationFromAddress(query);
      List<Map<String, dynamic>> enrichedResults = [];

      for (var loc in locations.take(5)) {
        String displayName = "${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}"; 
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(loc.latitude, loc.longitude);
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            displayName = [p.street, p.locality, p.administrativeArea, p.country]
                .where((s) => s != null && s.isNotEmpty)
                .join(", ");
            if (displayName.isEmpty) displayName = p.name ?? displayName;
          }
        } catch (_) {}
        
        enrichedResults.add({
          'name': displayName,
          'lat': loc.latitude,
          'lng': loc.longitude
        });
      }

      if (mounted) {
        setState(() {
          _results = enrichedResults;
        });
      }
    } catch (e) {
      print("Search Error: $e");
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
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
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text("Search Location", style: TextStyle(color: Colors.white, fontSize: 24, fontFamily: 'DxSitrus')),
          const SizedBox(height: 20),
          TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Type an address...",
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.purpleAccent),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
                : _results.isEmpty
                    ? const Center(child: Text("No results found", style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          return ListTile(
                            leading: const Icon(Icons.location_on, color: Colors.white70),
                            title: Text(item['name'], style: const TextStyle(color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
                            onTap: () {
                              Navigator.pop(context);
                              widget.onSelect(item['lat'], item['lng'], item['name']);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}