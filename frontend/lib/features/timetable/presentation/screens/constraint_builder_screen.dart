import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/constraint_repository.dart';
import '../../models/timetable_constraint.dart';
import '../../providers/timetable_provider.dart';

class ConstraintBuilderScreen extends StatefulWidget {
  const ConstraintBuilderScreen({super.key});

  @override
  State<ConstraintBuilderScreen> createState() => _ConstraintBuilderScreenState();
}

class _ConstraintBuilderScreenState extends State<ConstraintBuilderScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _nlpController = TextEditingController();
  final ConstraintRepository _constraintRepo = ConstraintRepository();

  String _selectedHardRule = 'Faculty Unavailable (Block Slot)';
  final List<String> _hardRuleOptions = [
    'Faculty Unavailable (Block Slot)',
    'Room Unavailable (Block Room)',
    'Division Unavailable (Block Class)',
    'Fixed Session (Force Slot)',
    'Lab Continuity (Force Consecutive)',
    'Combined / Joint Session',
    'Replacement Rule (Substitute Free)',
  ];

  String _selectedSoftRule = 'Preferred Day / Time';
  final List<String> _softRuleOptions = [
    'Preferred Day / Time',
    'Avoid First Period (Morning)',
    'Avoid Last Period (Evening)',
    'Faculty Workload Balance',
    'Minimize Daily Room Swaps',
  ];

  final List<String> _selectedFaculties = [];
  final List<String> _selectedSubjects = [];
  final List<String> _selectedClasses = [];
  final List<String> _allDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  final List<String> _selectedDays = [];
  
  final List<int> _allSlots = [1, 2, 3, 4, 5, 6, 7, 8];
  final List<int> _selectedSlots = [];

  bool _isParsingNlp = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nlpController.dispose();
    super.dispose();
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
                                if (checked == true) {
                                  tempSelected.add(item);
                                } else {
                                  tempSelected.remove(item);
                                }
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
                        hintText: 'Add custom value...',
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

  void _addStructuredConstraint(bool isHard) {
    if (_selectedDays.isEmpty && _selectedSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select target Days or Slot numbers for the rule.')),
      );
      return;
    }

    String category = isHard ? 'hard|$_selectedHardRule' : 'soft|$_selectedSoftRule';

    final newConstraint = TimetableConstraint(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      category: category,
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${isHard ? "Hard" : "Soft"} constraint added successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _processNaturalLanguageRule() async {
    final text = _nlpController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a natural language rule.')),
      );
      return;
    }

    setState(() => _isParsingNlp = true);

    // Call NLP parsing in provider or backend
    context.read<TimetableProvider>().addNaturalLanguageConstraint(text);
    final parsedConstraint = context.read<TimetableProvider>().constraints.last;

    setState(() => _isParsingNlp = false);

    if (!mounted) return;

    // Show Confirmation Dialog before applying
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.psychology, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Confirm Parsed Constraint'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Original Text:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
              Text('"$text"', style: const TextStyle(fontStyle: FontStyle.italic)),

              const Divider(height: 24),
              Text('Detected Rule Action:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
              Text(parsedConstraint.category, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 8),
              if (parsedConstraint.facultyNames.isNotEmpty)
                Text('Faculty: ${parsedConstraint.facultyNames.join(", ")}'),
              if (parsedConstraint.subjectNames.isNotEmpty)
                Text('Subject: ${parsedConstraint.subjectNames.join(", ")}'),
              if (parsedConstraint.classNames.isNotEmpty)
                Text('Class/Division: ${parsedConstraint.classNames.join(", ")}'),
              if (parsedConstraint.days.isNotEmpty)
                Text('Days: ${parsedConstraint.days.join(", ")}'),
              if (parsedConstraint.slotNumbers.isNotEmpty)
                Text('Slots: ${parsedConstraint.slotNumbers.join(", ")}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                context.read<TimetableProvider>().removeConstraint(parsedConstraint.id);
                Navigator.pop(context);
              },
              child: const Text('Reject / Cancel', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                _nlpController.clear();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('NLP Constraint Applied!'), backgroundColor: Colors.green),
                );
              },
              child: const Text('Confirm & Apply', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHardConstraintsTab(List<String> facultyList, List<String> subjectList, List<String> classList) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hard Constraint Rule Type', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedHardRule,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: _hardRuleOptions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (val) => setState(() => _selectedHardRule = val!),
                  ),
                  const SizedBox(height: 16),
                  _buildMultiSelectField(label: 'Target Faculty', allOptions: facultyList, selectedItems: _selectedFaculties),
                  const SizedBox(height: 12),
                  _buildMultiSelectField(label: 'Target Subject', allOptions: subjectList, selectedItems: _selectedSubjects),
                  const SizedBox(height: 12),
                  _buildMultiSelectField(label: 'Target Class / Division', allOptions: classList, selectedItems: _selectedClasses),
                  const SizedBox(height: 16),
                  const Text('Days Affected', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: _allDays.map((day) {
                      final sel = _selectedDays.contains(day);
                      return FilterChip(
                        label: Text(day.substring(0, 3)),
                        selected: sel,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(color: sel ? Colors.white : Colors.black87),
                        onSelected: (v) => setState(() => v ? _selectedDays.add(day) : _selectedDays.remove(day)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Text('Slots Affected', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: _allSlots.map((slot) {
                      final sel = _selectedSlots.contains(slot);
                      return FilterChip(
                        label: Text('Slot $slot'),
                        selected: sel,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(color: sel ? Colors.white : Colors.black87),
                        onSelected: (v) => setState(() => v ? _selectedSlots.add(slot) : _selectedSlots.remove(slot)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add_moderator),
                      label: const Text('Add Hard Constraint', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                      onPressed: () => _addStructuredConstraint(true),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoftConstraintsTab(List<String> facultyList, List<String> subjectList, List<String> classList) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Soft Preference Rule Type', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedSoftRule,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: _softRuleOptions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (val) => setState(() => _selectedSoftRule = val!),
                  ),
                  const SizedBox(height: 16),
                  _buildMultiSelectField(label: 'Faculty Preference', allOptions: facultyList, selectedItems: _selectedFaculties),
                  const SizedBox(height: 12),
                  _buildMultiSelectField(label: 'Subject Preference', allOptions: subjectList, selectedItems: _selectedSubjects),
                  const SizedBox(height: 16),
                  const Text('Preferred Days', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Wrap(
                    spacing: 6,
                    children: _allDays.map((day) {
                      final sel = _selectedDays.contains(day);
                      return FilterChip(
                        label: Text(day.substring(0, 3)),
                        selected: sel,
                        selectedColor: Colors.orange,
                        labelStyle: TextStyle(color: sel ? Colors.white : Colors.black87),
                        onSelected: (v) => setState(() => v ? _selectedDays.add(day) : _selectedDays.remove(day)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.star_outline),
                      label: const Text('Add Soft Preference', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
                      onPressed: () => _addStructuredConstraint(false),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNaturalLanguageTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.record_voice_over_outlined, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('Natural Language Constraint Engine', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Type your scheduling requirements in plain English. The ENOSIS NLP parser will extract entity names, days, and slot constraints.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nlpController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'e.g. "Dr. Patil is unavailable on Wednesday afternoon."\n'
                          'or "Keep DBMS on Monday at 10 AM."\n'
                          'or "Replace the free period on Friday with LeetCode activity."',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      icon: _isParsingNlp
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.auto_awesome),
                      label: const Text('Parse & Preview Constraint', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                      onPressed: _isParsingNlp ? null : _processNaturalLanguageRule,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimetableProvider>();
    final facultyList = provider.facultyNames;
    final subjectList = provider.subjectNames;
    final classList = provider.classesAndBatches;
    final constraints = provider.constraints;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Constraint Builder'),
        backgroundColor: AppColors.primary,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Hard Constraints'),
            Tab(text: 'Soft Preferences'),
            Tab(text: 'NLP Input'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildHardConstraintsTab(facultyList, subjectList, classList),
                _buildSoftConstraintsTab(facultyList, subjectList, classList),
                _buildNaturalLanguageTab(),
              ],
            ),
          ),
          const Divider(height: 1),
          // ACTIVE CONSTRAINTS FOOTER
          Container(
            height: 180,
            color: Colors.grey.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Active Constraints (${constraints.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    TextButton(
                      onPressed: () {
                        for (var c in List.from(constraints)) {
                          provider.removeConstraint(c.id);
                        }
                      },
                      child: const Text('Clear All', style: TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                  ],
                ),
                Expanded(
                  child: constraints.isEmpty
                      ? const Center(child: Text('No constraints added yet.', style: TextStyle(color: Colors.grey, fontSize: 12)))
                      : ListView.builder(
                          itemCount: constraints.length,
                          itemBuilder: (context, index) {
                            final c = constraints[index];
                            final isSoft = c.category.startsWith('soft|');
                            return Card(
                              elevation: 0.5,
                              margin: const EdgeInsets.only(bottom: 4),
                              child: ListTile(
                                dense: true,
                                leading: Icon(
                                  isSoft ? Icons.star_outline : Icons.push_pin_outlined,
                                  color: isSoft ? Colors.orange : AppColors.primary,
                                  size: 20,
                                ),
                                title: Text(
                                  c.category.startsWith('NLP|')
                                      ? 'NLP: ${c.category.split('|').last}'
                                      : c.category,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                subtitle: Text(
                                  'Days: ${c.days.isEmpty ? "All" : c.days.join(", ")} | Slots: ${c.slotNumbers.isEmpty ? "All" : c.slotNumbers.join(", ")}',
                                  style: const TextStyle(fontSize: 10),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close, size: 16, color: Colors.red),
                                  onPressed: () => provider.removeConstraint(c.id),
                                ),
                              ),
                            );
                          },
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