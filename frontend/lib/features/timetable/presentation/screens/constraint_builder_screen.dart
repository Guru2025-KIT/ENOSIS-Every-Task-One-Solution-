import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/timetable_constraint.dart';
import '../../providers/timetable_provider.dart';

class ConstraintBuilderScreen extends StatefulWidget {
  const ConstraintBuilderScreen({super.key});

  @override
  State<ConstraintBuilderScreen> createState() => _ConstraintBuilderScreenState();
}

class _ConstraintBuilderScreenState extends State<ConstraintBuilderScreen> {
  final List<String> _constraintCategories = [
    'Faculty Unavailable',
    'Fixed Subject Slot',
    'No Theory After Lunch',
    'Holiday / College Closed', // Added Holiday Option
    'Natural Language Rule', 
  ];
  
  String _selectedCategory = 'Faculty Unavailable';
  String _naturalLanguageText = '';

  final List<String> _selectedFaculties = [];
  final List<String> _selectedSubjects = [];
  final List<String> _selectedClasses = [];
  final List<String> _allDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  final List<String> _selectedDays = [];
  
  final List<int> _allSlots = [1, 2, 3, 4, 5, 6, 7, 8];
  final List<int> _selectedSlots = [];

  Future<void> _addCustomCategory() async {
    final customController = TextEditingController();
    String? newCategory = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Custom Constraint Type'),
          content: TextField(
            controller: customController,
            decoration: const InputDecoration(hintText: 'e.g., Guest Lecture', border: OutlineInputBorder()),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                if (customController.text.trim().isNotEmpty) Navigator.pop(context, customController.text.trim());
              },
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (newCategory != null && !_constraintCategories.contains(newCategory)) {
      setState(() {
        _constraintCategories.add(newCategory);
        _selectedCategory = newCategory;
      });
    }
  }

  Future<void> _showMultiSelectDialog({
    required String title,
    required List<String> allOptions,
    required List<String> selectedItems,
  }) async {
    final List<String> tempSelected = List.from(selectedItems);
    final TextEditingController customController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Select $title'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: allOptions.length,
                        itemBuilder: (context, index) {
                          final item = allOptions[index];
                          return CheckboxListTile(
                            title: Text(item),
                            value: tempSelected.contains(item),
                            activeColor: AppColors.primary,
                            onChanged: (bool? checked) {
                              setDialogState(() {
                                if (checked == true) tempSelected.add(item);
                                else tempSelected.remove(item);
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    TextField(
                      controller: customController,
                      decoration: InputDecoration(
                        hintText: 'Add custom (e.g., Guest Faculty)...',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add_circle, color: AppColors.primary),
                          onPressed: () {
                            if (customController.text.trim().isNotEmpty) {
                              setDialogState(() {
                                tempSelected.add(customController.text.trim());
                                customController.clear();
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () {
                    setState(() {
                      selectedItems.clear();
                      selectedItems.addAll(tempSelected);
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Done', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMultiSelectField({
    required String label,
    required List<String> allOptions,
    required List<String> selectedItems,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _showMultiSelectDialog(title: label, allOptions: allOptions, selectedItems: selectedItems),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Expanded(
                  child: selectedItems.isEmpty
                      ? Text('Select $label...', style: TextStyle(color: Colors.grey.shade500))
                      : Wrap(
                          spacing: 6.0,
                          runSpacing: 4.0,
                          children: selectedItems.map((item) {
                            return Chip(
                              label: Text(item, style: const TextStyle(fontSize: 11)),
                              backgroundColor: AppColors.primary.withOpacity(0.1),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            );
                          }).toList(),
                        ),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _addConstraint() {
    // Handle Natural Language Rule separately
    if (_selectedCategory == 'Natural Language Rule') {
      if (_naturalLanguageText.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please type the rule in English.')),
        );
        return;
      }
      
      context.read<TimetableProvider>().addNaturalLanguageConstraint(_naturalLanguageText);
      
      setState(() {
        _naturalLanguageText = ''; 
        _selectedCategory = 'Faculty Unavailable'; 
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Natural Language Rule Parsed & Added!'), backgroundColor: Colors.green),
      );
      return;
    }

    // REMOVED compulsory validations. You can add a rule with just Days, or just Faculty, etc.
    if (_selectedDays.isEmpty && _selectedCategory != 'Holiday / College Closed') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one day.')));
      return;
    }

    final newConstraint = TimetableConstraint(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      category: _selectedCategory,
      facultyNames: List.from(_selectedFaculties),
      subjectNames: List.from(_selectedSubjects),
      classNames: List.from(_selectedClasses),
      days: List.from(_selectedDays),
      slotNumbers: List.from(_selectedSlots),
    );

    context.read<TimetableProvider>().addConstraint(newConstraint);
    setState(() {
      _selectedFaculties.clear();
      _selectedSubjects.clear();
      _selectedClasses.clear();
      _selectedDays.clear();
      _selectedSlots.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimetableProvider>();
    final facultyList = provider.facultyNames;
    final subjectList = provider.subjectNames;
    final classList = provider.classesAndBatches; 
    final constraints = provider.constraints;

    // Hide form fields if Holiday or NLP is selected
    bool showStandardForm = _selectedCategory != 'Natural Language Rule' && _selectedCategory != 'Holiday / College Closed';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Constraints'),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add New Constraint', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(labelText: 'Constraint Type', border: OutlineInputBorder()),
                      items: [
                        ..._constraintCategories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                        const DropdownMenuItem(value: '__add_new__', child: Text('➕ Add Custom Type...', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
                      ],
                      onChanged: (val) {
                        if (val == '__add_new__') _addCustomCategory();
                        else if (val != null) setState(() => _selectedCategory = val);
                      },
                    ),
                    const SizedBox(height: 16),

                    if (_selectedCategory == 'Natural Language Rule')
                      TextFormField(
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Type Rule in English',
                          hintText: 'e.g., Vajreshwari should have 1st lecture on Monday for Btech AIML A',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        onChanged: (val) => _naturalLanguageText = val,
                      )
                    else if (_selectedCategory == 'Holiday / College Closed')
                      const Text('Select the days below that are holidays. The generator will leave these days blank.', style: TextStyle(color: Colors.grey))
                    else ...[
                      _buildMultiSelectField(label: 'Faculty / Guest', allOptions: facultyList, selectedItems: _selectedFaculties),
                      const SizedBox(height: 12),
                      _buildMultiSelectField(label: 'Subject', allOptions: subjectList, selectedItems: _selectedSubjects),
                      const SizedBox(height: 12),
                      _buildMultiSelectField(label: 'Class / Batch', allOptions: classList, selectedItems: _selectedClasses),
                    ],

                    if (showStandardForm || _selectedCategory == 'Holiday / College Closed') ...[
                      const SizedBox(height: 16),
                      const Text('Select Days', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: _allDays.map((day) {
                          return FilterChip(
                            label: Text(day.substring(0, 3)),
                            selected: _selectedDays.contains(day),
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(color: _selectedDays.contains(day) ? Colors.white : Colors.black),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) _selectedDays.add(day);
                                else _selectedDays.remove(day);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],

                    if (showStandardForm) ...[
                      const SizedBox(height: 16),
                      const Text('Applies to Slots (Optional: Select multiple for Labs)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: _allSlots.map((slot) {
                          return FilterChip(
                            label: Text('Slot $slot'),
                            selected: _selectedSlots.contains(slot),
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(color: _selectedSlots.contains(slot) ? Colors.white : Colors.black),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) _selectedSlots.add(slot);
                                else _selectedSlots.remove(slot);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                    
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add Constraint'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                      onPressed: _addConstraint,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Active Constraints', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            
            if (constraints.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: Center(child: Text('No constraints added yet.', style: TextStyle(color: Colors.grey))),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: constraints.length,
                itemBuilder: (context, index) {
                  final c = constraints[index];
                  List<String> details = [];
                  if (c.facultyNames.isNotEmpty) details.add('Faculty: ${c.facultyNames.join(", ")}');
                  if (c.subjectNames.isNotEmpty) details.add('Subject: ${c.subjectNames.join(", ")}');
                  if (c.classNames.isNotEmpty) details.add('Class: ${c.classNames.join(", ")}');
                  
                  return ListTile(
                    leading: const Icon(Icons.push_pin_outlined, color: AppColors.secondary),
                    title: Text(c.category, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      details.isEmpty ? 'Applied to selected days/slots.' : '${details.join("\n")}\nDays: ${c.days.join(", ")} | Slots: ${c.slotNumbers.join(", ")}', 
                      style: const TextStyle(height: 1.4)
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => context.read<TimetableProvider>().removeConstraint(c.id),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}