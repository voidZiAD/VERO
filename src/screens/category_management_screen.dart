import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../services/block_service.dart';
import 'app_website_selection_sheet.dart'; 

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final BlockService _blockService = BlockService();

  @override
  void initState() {
    super.initState();
    _blockService.addListener(_onBlockServiceChange);
  }

  @override
  void dispose() {
    _blockService.removeListener(_onBlockServiceChange);
    super.dispose();
  }

  void _onBlockServiceChange() {
    if (mounted) {
      setState(() {}); 
    }
  }

  void _showAddEditCategorySheet({BlockCategory? categoryToEdit}) {
    final TextEditingController nameController = TextEditingController(text: categoryToEdit?.name ?? '');
    Color selectedColor = Color(categoryToEdit?.colorValue ?? Colors.blueAccent.value);
    IconData selectedIcon = IconData(categoryToEdit?.iconCodePoint ?? Icons.folder.codePoint, fontFamily: 'MaterialIcons');
    List<String> selectedPackageNames = List.from(categoryToEdit?.packageNames ?? []);
    List<String> selectedUrls = List.from(categoryToEdit?.urls ?? []);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: EdgeInsets.only(top: 30, left: 24, right: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 30),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0518),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 30),
                  Text(
                    categoryToEdit == null ? "New Category" : "Edit Category",
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontFamily: 'DxSitrus'),
                  ),
                  const SizedBox(height: 30),

                  _buildGlassContainer(
                    child: Row(
                      children: [
                        Icon(selectedIcon, color: selectedColor),
                        const SizedBox(width: 15),
                        Expanded(
                          child: TextFormField(
                            controller: nameController,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(border: InputBorder.none, hintText: "Category Name", hintStyle: TextStyle(color: Colors.grey)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildGlassContainer(
                    child: Column(
                      children: [
                        _buildIconPicker(selectedIcon, (i) => setModalState(() => selectedIcon = i)),
                        const Divider(color: Colors.white10),
                        _buildColorPicker(selectedColor, (c) => setModalState(() => selectedColor = c)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  GestureDetector(
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AppWebsiteSelectionSheet(
                            initialSelectedPackages: selectedPackageNames,
                            initialSelectedUrls: selectedUrls,
                          ),
                        ),
                      );

                      if (result != null && result is Map<String, List<String>>) {
                        setModalState(() {
                          selectedPackageNames = result['packages'] ?? [];
                          selectedUrls = result['urls'] ?? [];
                        });
                      }
                    },
                    child: _buildGlassContainer(
                      child: _buildRow(
                        "Apps & Websites",
                        "${selectedPackageNames.length + selectedUrls.length} Selected",
                        icon: Icons.apps,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () async {
                        HapticFeedback.heavyImpact();
                        if (nameController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Category name cannot be empty."), backgroundColor: Colors.redAccent),
                          );
                          return;
                        }

                        if (categoryToEdit == null) {
                          final newCategory = BlockCategory(
                            id: const Uuid().v4(),
                            name: nameController.text.trim(),
                            colorValue: selectedColor.value,
                            iconCodePoint: selectedIcon.codePoint,
                            packageNames: selectedPackageNames,
                            urls: selectedUrls,
                          );
                          await _blockService.addCategory(newCategory);
                        } else {
                          categoryToEdit.name = nameController.text.trim();
                          categoryToEdit.colorValue = selectedColor.value;
                          categoryToEdit.iconCodePoint = selectedIcon.codePoint;
                          categoryToEdit.packageNames = selectedPackageNames;
                          categoryToEdit.urls = selectedUrls;
                          await _blockService.updateCategory(categoryToEdit);
                        }
                        if (mounted) Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: Text(categoryToEdit == null ? "Create Category" : "Save Changes", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteCategory(String categoryId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A0B2E),
        title: const Text("Delete Category?", style: TextStyle(color: Colors.redAccent, fontFamily: 'DxSitrus')),
        content: const Text(
          "This will permanently delete this category.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () async {
              HapticFeedback.mediumImpact();
              await _blockService.removeCategory(categoryId);
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = _blockService.categories;

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
                      const Text("App Categories", style: TextStyle(fontFamily: 'DxSitrus', fontSize: 24, color: Colors.white)),
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
                      Icon(Icons.folder_open, color: Colors.purpleAccent),
                      SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          "Group apps & websites into categories for easier blocking.",
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: categories.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.folder_off, size: 60, color: Colors.white24),
                              SizedBox(height: 20),
                              Text("No Categories Added", style: TextStyle(color: Colors.white38)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final category = categories[index];
                            return _buildCategoryCard(category);
                          },
                        ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        _showAddEditCategorySheet();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text("Create New Category", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

  Widget _buildCategoryCard(BlockCategory category) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showAddEditCategorySheet(categoryToEdit: category);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(category.colorValue).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Color(category.colorValue).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(category.colorValue).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(IconData(category.iconCodePoint, fontFamily: 'MaterialIcons'), color: Color(category.colorValue), size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(category.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(
                          "${category.packageNames.length + category.urls.length} items",
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _confirmDeleteCategory(category.id);
                    },
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
                ],
              ),
            ),
          ),
        ),
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
      Icons.folder,
      Icons.school,
      Icons.work,
      Icons.videogame_asset,
      Icons.fitness_center,
      Icons.book,
      Icons.brush,
      Icons.code,
      Icons.music_note,
      Icons.movie,
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: icons.length,
      itemBuilder: (context, index) {
        final icon = icons[index];
        return GestureDetector(
          onTap: () => onSelect(icon),
          child: Container(
            decoration: BoxDecoration(
              color: selected == icon ? Colors.white.withOpacity(0.2) : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        );
      },
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
}
