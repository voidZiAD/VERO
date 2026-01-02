import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/block_service.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final BlockService _blockService = BlockService();

  @override
  void initState() {
    super.initState();
    _blockService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _blockService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  void _showAddEditReminderDialog({Reminder? reminder}) {
    final TextEditingController titleCtrl = TextEditingController(text: reminder?.title ?? "");
    TimeOfDay selectedTime = reminder?.time ?? TimeOfDay.now();
    List<int> selectedDays = reminder?.days != null ? List.from(reminder!.days) : [1, 2, 3, 4, 5];
    DateTime? selectedDate = reminder?.specificDate;
    bool isOneTime = selectedDate != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.only(
                top: 24, left: 24, right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0518),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  Text(reminder == null ? "New Reminder" : "Edit Reminder", style: const TextStyle(color: Colors.white, fontSize: 20, fontFamily: 'DxSitrus')),
                  const SizedBox(height: 20),
                  
                  _buildGlassContainer(
                    child: TextField(
                      controller: titleCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(hintText: "Title", border: InputBorder.none, hintStyle: TextStyle(color: Colors.grey)),
                    )
                  ),
                  const SizedBox(height: 15),
                  
                  GestureDetector(
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: selectedTime);
                      if (t != null) setModalState(() => selectedTime = t);
                    },
                    child: _buildGlassContainer(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Time", style: TextStyle(color: Colors.white)),
                          Text(selectedTime.format(context), style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => isOneTime = false),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: !isOneTime ? Colors.purpleAccent : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.purpleAccent)
                            ),
                            child: const Center(child: Text("Repeats", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => isOneTime = true),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isOneTime ? Colors.purpleAccent : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.purpleAccent)
                            ),
                            child: const Center(child: Text("One Time", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  if (isOneTime)
                    GestureDetector(
                      onTap: () async {
                        final d = await showDatePicker(context: context, initialDate: selectedDate ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030));
                        if (d != null) setModalState(() => selectedDate = d);
                      },
                      child: _buildGlassContainer(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Date", style: TextStyle(color: Colors.white)),
                            Text(selectedDate != null ? "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}" : "Select Date", style: const TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: ["M","T","W","T","F","S","S"].asMap().entries.map((e) {
                        int dayIdx = e.key + 1;
                        bool selected = selectedDays.contains(dayIdx);
                        return GestureDetector(
                          onTap: () => setModalState(() {
                            selected ? selectedDays.remove(dayIdx) : selectedDays.add(dayIdx);
                          }),
                          child: Container(
                            width: 35, height: 35,
                            decoration: BoxDecoration(
                              color: selected ? Colors.white : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white)
                            ),
                            child: Center(child: Text(e.value, style: TextStyle(color: selected ? Colors.black : Colors.white, fontWeight: FontWeight.bold))),
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 30),
                  Row(
                    children: [
                      if (reminder != null)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () {
                            _blockService.deleteReminder(reminder.id);
                            Navigator.pop(context);
                          },
                        ),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (titleCtrl.text.isEmpty) return;
                            final newReminder = Reminder(
                              id: reminder?.id ?? const Uuid().v4(),
                              title: titleCtrl.text,
                              time: selectedTime,
                              days: isOneTime ? [] : selectedDays,
                              specificDate: isOneTime ? selectedDate : null,
                              isEnabled: true
                            );
                            
                            if (reminder == null) {
                              _blockService.addReminder(newReminder);
                            } else {
                              _blockService.updateReminder(newReminder);
                            }
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 15)),
                          child: const Text("Save Reminder", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        }
      )
    );
  }

  Widget _buildGlassContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final reminders = _blockService.reminders;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Reminders", style: TextStyle(fontFamily: 'DxSitrus', color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditReminderDialog(),
        backgroundColor: Colors.purpleAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: reminders.isEmpty 
        ? const Center(child: Text("No reminders set", style: TextStyle(color: Colors.grey)))
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: reminders.length,
            itemBuilder: (context, index) {
              final r = reminders[index];
              return GestureDetector(
                onTap: () => _showAddEditReminderDialog(reminder: r),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: r.isEnabled ? Colors.purpleAccent.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: r.isEnabled ? Colors.purpleAccent.withOpacity(0.5) : Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${r.time.hour.toString().padLeft(2,'0')}:${r.time.minute.toString().padLeft(2,'0')}",
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            r.title,
                            style: const TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            r.specificDate != null 
                              ? "${r.specificDate!.day}/${r.specificDate!.month}/${r.specificDate!.year}"
                              : r.days.map((d) => ["M","T","W","T","F","S","S"][d-1]).join(" "),
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Switch(
                        value: r.isEnabled,
                        onChanged: (v) => _blockService.toggleReminder(r.id, v),
                        activeThumbColor: Colors.purpleAccent,
                        activeTrackColor: Colors.purpleAccent.withOpacity(0.3),
                      )
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }
}