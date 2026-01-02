import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/auth_service.dart';
import '../services/encryption_service.dart';
import 'package:flutter/services.dart';

class AccountabilityScreen extends StatefulWidget {
  const AccountabilityScreen({super.key});

  @override
  State<AccountabilityScreen> createState() => _AccountabilityScreenState();
}

class _AccountabilityScreenState extends State<AccountabilityScreen> {
  bool _isLoading = false;
  String? _partnerUid;
  String? _partnerName;
  bool _isPartnerFocusing = false;
  
  int _viewIndex = 0; 

  StreamSubscription<DocumentSnapshot>? _userSubscription;

  @override
  void initState() {
    super.initState();
    _setupUserListener();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  void _setupUserListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        
        if (data.containsKey('partnerUid')) {
          final pid = data['partnerUid'];
          if (pid != null && pid != _partnerUid) {
            _loadPartnerDetails(pid);
          } else if (pid == null) {
            if (mounted) {
              setState(() {
                _partnerUid = null;
                _partnerName = null;
              });
            }
          }
        } else {
          if (mounted) {
            setState(() {
              _partnerUid = null;
              _partnerName = null;
            });
          }
        }
      }
    });
  }

  Future<void> _loadPartnerDetails(String pid) async {
    try {
      final pDoc = await FirebaseFirestore.instance.collection('users').doc(pid).get();
      String pName = "Partner";
      
      if (pDoc.exists) {
        pName = EncryptionService().decrypt(pDoc.data()!['username'], pid);
      }

      final sessionDoc = await FirebaseFirestore.instance.collection('active_sessions').doc(pid).get();
      
      if (mounted) {
        setState(() {
          _partnerUid = pid;
          _partnerName = pName;
          _isPartnerFocusing = sessionDoc.exists;
          _viewIndex = 0; 
        });
      }
    } catch (e) {
      print("Error loading partner details: $e");
    }
  }

  Future<void> _linkPartner(String uid) async {
    setState(() => _isLoading = true);
    try {
      await AuthService().linkPartner(uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Partner Linked!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent));
        setState(() => _viewIndex = 0); 
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unlinkPartner() async {
    setState(() => _isLoading = true);
    try {
      await AuthService().unlinkPartner();
    } catch (e) {
      print(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white), 
          onPressed: () {
            if (_viewIndex != 0) {
              setState(() => _viewIndex = 0);
            } else {
              Navigator.pop(context);
            }
          }
        ),
        title: const Text("Accountability Pact", style: TextStyle(fontFamily: 'DxSitrus', color: Colors.white)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));

    if (_viewIndex == 1) return _buildQrView();
    if (_viewIndex == 2) return _buildScannerView();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Icon(Icons.handshake, size: 80, color: _partnerUid != null ? Colors.greenAccent : Colors.grey),
          const SizedBox(height: 30),
          
          if (_partnerUid == null) ...[
            const Text("No Partner Linked", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text(
              "Link with a friend. If you fail a session, they will know.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const Spacer(),
            
            SizedBox(
              width: double.infinity, height: 60,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  setState(() => _viewIndex = 1);
                },
                icon: const Icon(Icons.qr_code, color: Colors.black),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                label: const Text("Show My Code", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity, height: 60,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _viewIndex = 2),
                icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                label: const Text("Scan Partner's Code", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ] else ...[
            Text(_partnerName ?? "Partner", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _isPartnerFocusing ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _isPartnerFocusing ? Colors.greenAccent : Colors.grey),
              ),
              child: Text(
                _isPartnerFocusing ? "Currently Focusing 🔥" : "Slacking 💤",
                style: TextStyle(color: _isPartnerFocusing ? Colors.greenAccent : Colors.grey, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 40),
            const Text("THE PACT", style: TextStyle(color: Colors.purpleAccent, letterSpacing: 2, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildPactItem("If I exit early, notify them."),
            _buildPactItem("If I succeed, notify them."),
            _buildPactItem("No excuses."),
            
            const Spacer(),
            TextButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _unlinkPartner();
              },
              child: const Text("Unlink Partner (Coward's Way Out)", style: TextStyle(color: Colors.redAccent)),
            )
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildQrView() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "error";
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Have your partner scan this", style: TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: QrImageView(
              data: uid,
              version: QrVersions.auto,
              size: 250.0,
            ),
          ),
          const SizedBox(height: 30),
          TextButton(
            onPressed: () => setState(() => _viewIndex = 0),
            child: const Text("Back", style: TextStyle(color: Colors.grey)),
          )
        ],
      ),
    );
  }

  Widget _buildScannerView() {
    return Stack(
      children: [
        MobileScanner(
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue != null) {
                if (_isLoading) return;
                _linkPartner(barcode.rawValue!);
                break; 
              }
            }
          },
        ),
        CustomPaint(
          painter: ScannerOverlayPainter(
            borderColor: Colors.purpleAccent,
            borderRadius: 10,
            borderLength: 30,
            borderWidth: 10,
            cutOutSize: 300,
          ),
          child: Container(),
        ),
        Positioned(
          bottom: 50, left: 0, right: 0,
          child: Center(
            child: TextButton(
              onPressed: () => setState(() => _viewIndex = 0),
              style: TextButton.styleFrom(backgroundColor: Colors.black54),
              child: const Text("Cancel", style: TextStyle(color: Colors.white)),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildPactItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check, color: Colors.white70, size: 18),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(color: Colors.white70, fontSize: 16)),
        ],
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  final Color borderColor;
  final double borderRadius;
  final double borderLength;
  final double borderWidth;
  final double cutOutSize;

  ScannerOverlayPainter({
    required this.borderColor,
    required this.borderRadius,
    required this.borderLength,
    required this.borderWidth,
    required this.cutOutSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scanAreaSize = cutOutSize;
    final double left = (size.width - scanAreaSize) / 2;
    final double top = (size.height - scanAreaSize) / 2;
    final double right = left + scanAreaSize;
    final double bottom = top + scanAreaSize;

    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    
    final cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(left, top, right, bottom),
        Radius.circular(borderRadius),
      ));

    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    canvas.drawPath(
      Path.combine(PathOperation.difference, backgroundPath, cutoutPath),
      backgroundPaint,
    );

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final path = Path();

    path.moveTo(left, top + borderLength);
    path.lineTo(left, top + borderRadius);
    path.quadraticBezierTo(left, top, left + borderRadius, top);
    path.lineTo(left + borderLength, top);

    path.moveTo(right - borderLength, top);
    path.lineTo(right - borderRadius, top);
    path.quadraticBezierTo(right, top, right, top + borderRadius);
    path.lineTo(right, top + borderLength);

    path.moveTo(right, bottom - borderLength);
    path.lineTo(right, bottom - borderRadius);
    path.quadraticBezierTo(right, bottom, right - borderRadius, bottom);
    path.lineTo(right - borderLength, bottom);

    path.moveTo(left + borderLength, bottom);
    path.lineTo(left + borderRadius, bottom);
    path.quadraticBezierTo(left, bottom, left, bottom - borderRadius);
    path.lineTo(left, bottom - borderLength);

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
