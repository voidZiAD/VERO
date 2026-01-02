import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DebriefSheet extends StatefulWidget {
  final Function(int rating, String notes) onSubmit;
  const DebriefSheet({super.key, required this.onSubmit});

  @override
  State<DebriefSheet> createState() => _DebriefSheetState();
}

class _DebriefSheetState extends State<DebriefSheet> {
  int _rating = 0;
  final TextEditingController _notesController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: EdgeInsets.only(
          top: 30, left: 24, right: 24, 
          bottom: MediaQuery.of(context).viewInsets.bottom + 30
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0518).withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 30),
            const Text("Session Debrief", style: TextStyle(color: Colors.white, fontSize: 24, fontFamily: 'DxSitrus')),
            const SizedBox(height: 10),
            const Text("How focused were you?", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 36,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _rating = index + 1);
                  },
                );
              }),
            ),
            
            const SizedBox(height: 30),
            
            TextField(
              controller: _notesController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "What did you accomplish? (Optional)",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  widget.onSubmit(_rating, _notesController.text.trim());
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text("Save Entry", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
