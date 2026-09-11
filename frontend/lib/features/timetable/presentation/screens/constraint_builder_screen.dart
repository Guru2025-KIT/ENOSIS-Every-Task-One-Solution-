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
  String _naturalLanguageText = '';

  // ✅ Only ONE dropdown now!
  String _selectedIntent = 'Block from Slot (Unavailable)'; 
  final List<String> _intents = [
    'Fix to Slot (Force)',
    'Block from Slot (Unavailable)',
    'Fill Empty Slots',
    'Holiday / College Closed',
    'Parallel / Combined Session',
    'Natural Language Rule'
  ];

  final List<String> _selectedFaculties = [];
  final List<String> _selectedSubjects = [];
  final List<String> _selectedClasses = [];
  final List<String> _allDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  final List<String> _selectedDays = [];
  
  final List<int> _allSlots = [1, 2, 3, 4, 5, 6, 7, 8];
  final List<int> _selectedSlots = [];

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
    if (_selectedIntent == 'Natural Language Rule') {
      if (_naturalLanguageText.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please type the rule in English.')),
        );
        return;
      }
      
      context.read<TimetableProvider>().addNaturalLanguageConstraint(_naturalLanguageText);
      
      setState(() {
        _naturalLanguageText = ''; 
        _selectedIntent = 'Block from Slot (Unavailable)'; 
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Natural Language Rule Parsed & Added!'), backgroundColor: Colors.green),
      );
      return;
    }

    if (_selectedDays.isEmpty && _selectedIntent != 'Holiday / College Closed' && _selectedIntent != 'Fill Empty Slots' && _selectedIntent != 'Parallel / Combined Session') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one day.')));
      return;
    }

    String intentCode = 'blacklist';
    if (_selectedIntent == 'Fix to Slot (Force)') intentCode = 'fixed';
    if (_selectedIntent == 'Block from Slot (Unavailable)') intentCode = 'blacklist';
    if (_selectedIntent == 'Fill Empty Slots') intentCode = 'fill';
    if (_selectedIntent == 'Holiday / College Closed') intentCode = 'holiday';
    if (_selectedIntent == 'Parallel / Combined Session') intentCode = 'parallel';

    // ✅ We use the intentCode as the category itself. No more separate category string!
    final newConstraint = TimetableConstraint(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      category: intentCode, 
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

    bool showStandardForm = _selectedIntent != 'Natural Language Rule' && _selectedIntent != 'Holiday / College Closed' && _selectedIntent != 'Fill Empty Slots';

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
                      value: _selectedIntent,
                      decoration: const InputDecoration(labelText: 'Rule Action', border: OutlineInputBorder()),
                      items: _intents.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
                      onChanged: (val) => setState(() => _selectedIntent = val!),
                    ),
                    const SizedBox(height: 16),

                    if (_selectedIntent == 'Natural Language Rule')
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
                    else if (showStandardForm) ...[
                      _buildMultiSelectField(label: 'Faculty / Guest', allOptions: facultyList, selectedItems: _selectedFaculties),
                      const SizedBox(height: 12),
                      _buildMultiSelectField(label: 'Subject', allOptions: subjectList, selectedItems: _selectedSubjects),
                      const SizedBox(height: 12),
                      _buildMultiSelectField(label: 'Class / Batch', allOptions: classList, selectedItems: _selectedClasses),
                    ],

                    if (showStandardForm || _selectedIntent == 'Holiday / College Closed' || _selectedIntent == 'Parallel / Combined Session') ...[
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

                    if (showStandardForm || _selectedIntent == 'Parallel / Combined Session') ...[
                      const SizedBox(height: 16),
                      const Text('Applies to Slots (Select multiple for Labs)', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                    title: Text(
                      c.category.startsWith('NLP|')
                          ? 'NLP Rule: "${c.category.split('|').last}"'
                          : c.category, 
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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