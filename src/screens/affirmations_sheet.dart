import 'package:flutter/material.dart';
import '../services/block_service.dart';

class AffirmationsSheet extends StatefulWidget {
  const AffirmationsSheet({super.key});

  @override
  State<AffirmationsSheet> createState() => _AffirmationsSheetState();
}

class _AffirmationsSheetState extends State<AffirmationsSheet> {
  final TextEditingController _controller = TextEditingController();
  final BlockService _blockService = BlockService();

  @override
  Widget build(BuildContext context) {
    final affirmations = _blockService.affirmations;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(
        top: 24, 
        left: 24, 
        right: 24, 
        bottom: MediaQuery.of(context).viewInsets.bottom + 24
      ),
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
          const Text("Your Why", style: TextStyle(color: Colors.white, fontSize: 24, fontFamily: 'DxSitrus')),
          const SizedBox(height: 10),
          const Text(
            "These messages will appear when you try to open a blocked app.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Add a new affirmation...",
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
                  onPressed: () {
                    if (_controller.text.isNotEmpty) {
                      setState(() {
                        _blockService.addAffirmation(_controller.text.trim());
                        _controller.clear();
                      });
                    }
                  },
                ),
              )
            ],
          ),
          
          const SizedBox(height: 20),

          Expanded(
            child: ListView.builder(
              itemCount: affirmations.length,
              itemBuilder: (context, index) {
                final text = affirmations[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: ListTile(
                    title: Text(text, style: const TextStyle(color: Colors.white)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                      onPressed: () {
                        setState(() {
                          _blockService.removeAffirmation(text);
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
