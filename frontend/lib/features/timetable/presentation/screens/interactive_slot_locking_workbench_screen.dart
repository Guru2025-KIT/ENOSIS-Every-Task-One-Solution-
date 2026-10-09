import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/timetable_repository.dart';
import '../../models/teaching_assignment.dart';
import '../../models/time_slot.dart';
import '../../models/timetable_constraint.dart';
import '../../providers/timetable_provider.dart';
import 'generate_timetable_screen.dart';

class InteractiveSlotLockingWorkbenchScreen extends StatefulWidget {
  const InteractiveSlotLockingWorkbenchScreen({super.key});

  @override
  State<InteractiveSlotLockingWorkbenchScreen> createState() =>
      _InteractiveSlotLockingWorkbenchScreenState();
}

class _InteractiveSlotLockingWorkbenchScreenState
    extends State<InteractiveSlotLockingWorkbenchScreen> {
  final _repository = TimetableRepository();

  String? _selectedDivision;
  Map<String, dynamic>? _draggedSubject;

  // Locked slots map: key: "div_day_slot", value: Map of slot data
  final Map<String, Map<String, dynamic>> _lockedSlots = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<TimetableProvider>();
      provider.initializeData();
      _loadExistingLockedConstraints();
    });
  }

  void _loadExistingLockedConstraints() {
    final provider = context.read<TimetableProvider>();
    for (final con in provider.constraints) {
      final cat = con.category.toLowerCase();
      if (cat.contains('locked') || cat.contains('fixed') || cat.contains('force')) {
        for (final day in con.days) {
          for (final slot in con.slotNumbers) {
            for (final cls in con.classNames) {
              final key = '${cls}_${day}_$slot';
              _lockedSlots[key] = {
                'subject': con.subjectNames.isNotEmpty ? con.subjectNames.first : 'Locked Course',
                'faculty': con.facultyNames.isNotEmpty ? con.facultyNames.first : '',
                'className': cls,
                'day': day,
                'slot': slot,
                'isLocked': true,
                'type': 'Theory',
                'category': con.category,
              };
            }
          }
        }
      }
    }
    if (mounted) setState(() {});
  }

  void _lockSlot(String div, String day, int slot, Map<String, dynamic> subjectData) {
    final provider = context.read<TimetableProvider>();
    final subjectName = subjectData['subjectName'] ?? subjectData['subject'] ?? 'Subject';
    final facultyName = subjectData['facultyName'] ?? subjectData['faculty'] ?? '';
    final type = subjectData['type'] ?? 'Theory';
    final subjectCategory = provider.getSubjectCategory(subjectName);

    // Multi-class cohort sync for Institutional & Departmental subjects
    List<String> targetDivs = [div];
    if (subjectCategory == 'institutional' || subjectCategory == 'departmental') {
      targetDivs = provider.getCohortSiblingClasses(div);
      if (targetDivs.isEmpty) targetDivs = [div];
    }

    setState(() {
      for (final d in targetDivs) {
        final key = '${d}_${day}_$slot';
        _lockedSlots[key] = {
          'subject': subjectName,
          'faculty': facultyName,
          'className': d,
          'day': day,
          'slot': slot,
          'isLocked': true,
          'type': type,
          'category': subjectCategory == 'institutional'
              ? 'Fixed Slot | Locked Institutional ($subjectName)'
              : (subjectCategory == 'departmental'
                  ? 'Fixed Slot | Locked Departmental ($subjectName)'
                  : 'Fixed Slot | Locked ($subjectName)'),
        };
      }
    });

    if (targetDivs.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Locked "$subjectName" across all ${targetDivs.length} ${provider.getCohort(div)} classes (${targetDivs.join(", ")}) on $day Period $slot'),
          backgroundColor: const Color(0xFF0F172A),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _unlockSlot(String div, String day, int slot) {
    final provider = context.read<TimetableProvider>();
    final key = '${div}_${day}_$slot';
    final slotData = _lockedSlots[key];
    if (slotData == null) return;

    final subjectName = slotData['subject'] ?? '';
    final subjectCategory = provider.getSubjectCategory(subjectName);

    setState(() {
      if (subjectCategory == 'institutional' || subjectCategory == 'departmental') {
        final siblingDivs = provider.getCohortSiblingClasses(div);
        for (final d in siblingDivs) {
          _lockedSlots.remove('${d}_${day}_$slot');
        }
      } else {
        _lockedSlots.remove(key);
      }
    });
  }

  Future<void> _saveAndExecuteSolver() async {
    final provider = context.read<TimetableProvider>();

    // Clear old lock constraints first
    provider.clearLockConstraints();

    // Add current locked slots as constraints into provider
    _lockedSlots.forEach((key, val) {
      provider.addConstraint(
        TimetableConstraint(
          id: 'lock_$key',
          category: val['category'] ?? 'Fixed Slot | Locked (${val['subject']})',
          facultyNames: val['faculty'].toString().isNotEmpty ? [val['faculty']] : [],
          subjectNames: [val['subject']],
          classNames: [val['className']],
          days: [val['day']],
          slotNumbers: [val['slot']],
        ),
      );
    });

    // Navigate to GenerateTimetableScreen to run CP-SAT with locked anchors
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const GenerateTimetableScreen(),
      ),
    );
  }

  Widget _buildCategoryPill({
    required String label,
    required bool isSelected,
    required Color activeBgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeBgColor : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? activeBgColor : const Color(0xFF475569),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  void _showSubjectClassificationDialog() {
    final provider = context.read<TimetableProvider>();
    final allSubjects = provider.assignments
        .map((a) => a.subjectName.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final Map<String, String> localCategories = {
      for (final s in allSubjects) s: provider.getSubjectCategory(s),
    };

    String searchQuery = '';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredSubjects = allSubjects
                .where((s) => s.toLowerCase().contains(searchQuery.toLowerCase()))
                .toList();

            return Dialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF334155)),
              ),
              child: Container(
                width: 660,
                height: 540,
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF97316).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.category_rounded, color: Color(0xFFF97316), size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Subject Category Classification',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Colors.white),
                              ),
                              Text(
                                'Tap a category badge to instantly classify. Changes sync across sibling divisions.',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                          onPressed: () => Navigator.pop(dialogCtx),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (val) => setDialogState(() => searchQuery = val),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search subjects from workload sheet...',
                        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8), size: 18),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFF97316)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filteredSubjects.isEmpty
                          ? Center(
                              child: Text(
                                allSubjects.isEmpty
                                    ? 'No workload subjects found yet. Tap "+ Add Subject" to create subjects.'
                                    : 'No subjects matching "$searchQuery"',
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredSubjects.length,
                              itemBuilder: (context, index) {
                                final sub = filteredSubjects[index];
                                final currentCat = localCategories[sub] ?? 'class';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFF334155)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          sub,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildCategoryPill(
                                        label: '🌐 Inst (OE)',
                                        isSelected: currentCat == 'institutional',
                                        activeBgColor: const Color(0xFFEA580C),
                                        onTap: () => setDialogState(() => localCategories[sub] = 'institutional'),
                                      ),
                                      const SizedBox(width: 6),
                                      _buildCategoryPill(
                                        label: '🏛️ Dept (MDM)',
                                        isSelected: currentCat == 'departmental',
                                        activeBgColor: const Color(0xFFD97706),
                                        onTap: () => setDialogState(() => localCategories[sub] = 'departmental'),
                                      ),
                                      const SizedBox(width: 6),
                                      _buildCategoryPill(
                                        label: '📚 Class Core',
                                        isSelected: currentCat == 'class',
                                        activeBgColor: const Color(0xFF1E3A8A),
                                        onTap: () => setDialogState(() => localCategories[sub] = 'class'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
                              for (final s in allSubjects) {
                                localCategories[s] = 'class';
                              }
                            });
                          },
                          child: const Text('Reset All to Class Core', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogCtx),
                              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF97316),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              ),
                              onPressed: () {
                                for (final entry in localCategories.entries) {
                                  provider.setSubjectCategory(entry.key, entry.value);
                                }
                                Navigator.pop(dialogCtx);
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Subject categories updated successfully!'),
                                    backgroundColor: Color(0xFF0F172A),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: const Text('Save Classification', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddSubjectDialog() {
    final provider = context.read<TimetableProvider>();
    final divisions = provider.divisions;

    final nameCtrl = TextEditingController();
    final facultyCtrl = TextEditingController();
    final hoursCtrl = TextEditingController(text: '3');
    String selectedType = 'Theory';
    String selectedCategory = 'class'; // 'institutional', 'departmental', 'class'
    final Set<String> selectedDivs = _selectedDivision != null ? {_selectedDivision!} : (divisions.isNotEmpty ? {divisions.first} : {});

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF334155)),
              ),
              title: const Row(
                children: [
                  Icon(Icons.add_circle_outline, color: Color(0xFFF97316), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Quick-Add Subject / Lab',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          isDense: true,
                          labelText: 'Subject / Lab Name',
                          labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          floatingLabelStyle: const TextStyle(color: Color(0xFFFB923C), fontWeight: FontWeight.bold),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: facultyCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          isDense: true,
                          labelText: 'Faculty In-Charge (e.g. Dr. Sharma)',
                          labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          floatingLabelStyle: const TextStyle(color: Color(0xFFFB923C), fontWeight: FontWeight.bold),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Session Type:',
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _buildCategoryPill(
                              label: '📖 Theory Lecture',
                              isSelected: selectedType == 'Theory',
                              activeBgColor: const Color(0xFF1E3A8A),
                              onTap: () => setDialogState(() {
                                selectedType = 'Theory';
                                hoursCtrl.text = '3';
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildCategoryPill(
                              label: '🔬 Lab Practical (2-Hr)',
                              isSelected: selectedType == 'Lab',
                              activeBgColor: const Color(0xFFEA580C),
                              onTap: () => setDialogState(() {
                                selectedType = 'Lab';
                                hoursCtrl.text = '2';
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: hoursCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          isDense: true,
                          labelText: 'Weekly Hours',
                          labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Category:',
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildCategoryPill(
                            label: '🌐 Institutional (OE)',
                            isSelected: selectedCategory == 'institutional',
                            activeBgColor: const Color(0xFFEA580C),
                            onTap: () => setDialogState(() => selectedCategory = 'institutional'),
                          ),
                          _buildCategoryPill(
                            label: '🏛️ Dept (MDM/PE)',
                            isSelected: selectedCategory == 'departmental',
                            activeBgColor: const Color(0xFFD97706),
                            onTap: () => setDialogState(() => selectedCategory = 'departmental'),
                          ),
                          _buildCategoryPill(
                            label: '📚 Class Core Subject',
                            isSelected: selectedCategory == 'class',
                            activeBgColor: const Color(0xFF1E3A8A),
                            onTap: () => setDialogState(() => selectedCategory = 'class'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Assign to Class(es):',
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: divisions.map((div) {
                          final isSel = selectedDivs.contains(div);
                          return FilterChip(
                            label: Text(div),
                            selected: isSel,
                            selectedColor: const Color(0xFFEA580C),
                            checkmarkColor: Colors.white,
                            labelStyle: TextStyle(
                              color: isSel ? Colors.white : Colors.white70,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              fontSize: 11,
                            ),
                            backgroundColor: const Color(0xFF1E293B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: BorderSide(color: isSel ? const Color(0xFFEA580C) : const Color(0xFF475569)),
                            ),
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  selectedDivs.add(div);
                                } else {
                                  selectedDivs.remove(div);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    final sName = nameCtrl.text.trim();
                    if (sName.isEmpty) return;
                    final fName = facultyCtrl.text.trim();
                    final hrs = int.tryParse(hoursCtrl.text.trim()) ?? (selectedType == 'Lab' ? 2 : 3);
                    final divs = selectedDivs.isNotEmpty ? selectedDivs.toList() : (divisions.isNotEmpty ? [divisions.first] : ['Class 1']);

                    provider.setSubjectCategory(sName, selectedCategory);

                    for (final div in divs) {
                      provider.addManualAssignment(
                        TeachingAssignment(
                          facultyName: fName,
                          subjectName: sName,
                          subjectCode: sName.toUpperCase(),
                          className: div,
                          weeklyHours: hrs,
                          type: selectedType,
                          batch: selectedType == 'Lab' ? 'Batch 1' : 'All',
                        ),
                      );
                    }

                    Navigator.pop(context);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added "$sName" ($selectedType, $hrs hrs/wk) to ${divs.join(", ")}'),
                        backgroundColor: const Color(0xFF0F172A),
                      ),
                    );
                  },
                  child: const Text('Add to Workbench', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showQuickAssignSlotDialog(String div, String day, int slotNum) {
    final provider = context.read<TimetableProvider>();
    final allSubjectNames = provider.assignments
        .map((a) => a.subjectName.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final allFacultyNames = provider.assignments
        .map((a) => a.facultyName.trim())
        .where((f) => f.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final nameCtrl = TextEditingController();
    final facultyCtrl = TextEditingController();
    String selectedType = 'Theory';
    String selectedCategory = 'class';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF334155)),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.lock_clock_rounded, color: Color(0xFFEA580C), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lock & Assign Slot: $day Period $slotNum',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white),
                        ),
                        Text(
                          'Class: $div',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Select / Type Subject Name:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Autocomplete<String>(
                        optionsBuilder: (textEditingValue) {
                          if (textEditingValue.text.isEmpty) return allSubjectNames;
                          return allSubjectNames.where((s) => s.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                        },
                        onSelected: (val) {
                          nameCtrl.text = val;
                          final match = provider.assignments.firstWhere(
                            (a) => a.subjectName.trim().toLowerCase() == val.toLowerCase(),
                            orElse: () => provider.assignments.first,
                          );
                          if (match.facultyName.isNotEmpty && facultyCtrl.text.isEmpty) {
                            facultyCtrl.text = match.facultyName;
                          }
                          setDialogState(() {
                            selectedCategory = provider.getSubjectCategory(val);
                            selectedType = match.type;
                          });
                        },
                        fieldViewBuilder: (ctx, controller, focusNode, onFieldSubmitted) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            style: const TextStyle(color: Colors.white, fontSize: 13.5),
                            decoration: InputDecoration(
                              hintText: 'e.g. Operating Systems / PE-1: NLP',
                              hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                              filled: true,
                              fillColor: const Color(0xFF1E293B),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFEA580C))),
                            ),
                            onChanged: (v) => nameCtrl.text = v,
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      const Text('Faculty Name:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Autocomplete<String>(
                        optionsBuilder: (textEditingValue) {
                          if (textEditingValue.text.isEmpty) return allFacultyNames;
                          return allFacultyNames.where((f) => f.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                        },
                        onSelected: (val) => facultyCtrl.text = val,
                        fieldViewBuilder: (ctx, controller, focusNode, onFieldSubmitted) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            style: const TextStyle(color: Colors.white, fontSize: 13.5),
                            decoration: InputDecoration(
                              hintText: 'e.g. Dr. A. Sharma',
                              hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                              filled: true,
                              fillColor: const Color(0xFF1E293B),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFEA580C))),
                            ),
                            onChanged: (v) => facultyCtrl.text = v,
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      const Text('Category (Controls Cohort Auto-Sync):', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildCategoryPill(
                            label: '🌐 Institutional (OE)',
                            isSelected: selectedCategory == 'institutional',
                            activeBgColor: const Color(0xFFEA580C),
                            onTap: () => setDialogState(() => selectedCategory = 'institutional'),
                          ),
                          _buildCategoryPill(
                            label: '🏛️ Dept (MDM/PE)',
                            isSelected: selectedCategory == 'departmental',
                            activeBgColor: const Color(0xFFD97706),
                            onTap: () => setDialogState(() => selectedCategory = 'departmental'),
                          ),
                          _buildCategoryPill(
                            label: '📚 Class Core',
                            isSelected: selectedCategory == 'class',
                            activeBgColor: const Color(0xFF1E3A8A),
                            onTap: () => setDialogState(() => selectedCategory = 'class'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.lock, size: 16),
                  label: const Text('Lock into Slot', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    final sName = nameCtrl.text.trim();
                    if (sName.isEmpty) return;
                    final fName = facultyCtrl.text.trim();
                    provider.setSubjectCategory(sName, selectedCategory);
                    final subjectData = {
                      'subjectName': sName,
                      'facultyName': fName,
                      'type': selectedType,
                      'category': selectedCategory,
                    };
                    Navigator.pop(context);
                    _lockSlot(div, day, slotNum, subjectData);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimetableProvider>();
    final divisions = provider.divisions;
    final assignments = provider.assignments;
    final days = provider.days;
    final timeSlots = provider.timeSlots;

    if (_selectedDivision == null && divisions.isNotEmpty) {
      _selectedDivision = divisions.first;
    }

    final selectedClass = _selectedDivision;
    final cohort = selectedClass != null ? provider.getCohort(selectedClass) : 'TY';
    final siblingDivs = selectedClass != null ? provider.getCohortSiblingClasses(selectedClass) : divisions;

    // Filter assignments dynamically by category
    final Map<String, Map<String, dynamic>> oeMap = {};
    final Map<String, Map<String, dynamic>> mdmMap = {};
    final Map<String, Map<String, dynamic>> classMap = {};

    for (final a in assignments) {
      final s = a.subjectName.trim();
      if (s.isEmpty) continue;
      final cat = provider.getSubjectCategory(s);

      final aCohort = a.className.isNotEmpty ? provider.getCohort(a.className) : '';
      final isCohortMatch = a.className.isEmpty || aCohort == cohort || siblingDivs.contains(a.className);
      final isExactClassMatch = a.className.isEmpty || (selectedClass != null && a.className.toLowerCase() == selectedClass.toLowerCase());

      if (cat == 'institutional') {
        // Only visible if it belongs to this class's year cohort
        if (!isCohortMatch) continue;

        final key = s.toLowerCase();
        if (oeMap.containsKey(key)) {
          final curDivs = oeMap[key]!['divisions'] as List<String>;
          if (a.className.isNotEmpty && !curDivs.contains(a.className)) {
            curDivs.add(a.className);
          }
        } else {
          oeMap[key] = {
            'subjectName': s,
            'facultyName': a.facultyName.trim(),
            'type': a.type,
            'weeklyHours': a.weeklyHours,
            'category': 'Institutional Elective',
            'divisions': a.className.isNotEmpty ? [a.className] : siblingDivs,
          };
        }
      } else if (cat == 'departmental') {
        // Only visible if it belongs to this class's year cohort
        if (!isCohortMatch) continue;

        final key = s.toLowerCase();
        if (mdmMap.containsKey(key)) {
          final curDivs = mdmMap[key]!['divisions'] as List<String>;
          if (a.className.isNotEmpty && !curDivs.contains(a.className)) {
            curDivs.add(a.className);
          }
        } else {
          mdmMap[key] = {
            'subjectName': s,
            'facultyName': a.facultyName.trim(),
            'type': a.type,
            'weeklyHours': a.weeklyHours,
            'category': 'Departmental Elective',
            'divisions': a.className.isNotEmpty ? [a.className] : siblingDivs,
          };
        }
      } else {
        // Class-Level Core Subject: ONLY visible for this specific class
        if (isExactClassMatch) {
          final key = '${s.toLowerCase()}_${a.type}_${a.batch}';
          if (!classMap.containsKey(key)) {
            classMap[key] = {
              'subjectName': s,
              'facultyName': a.facultyName.trim(),
              'type': a.type,
              'weeklyHours': a.weeklyHours,
              'category': 'Class Core Subject',
              'divisions': [a.className],
              'batch': a.batch,
            };
          }
        }
      }
    }

    final openElectivesList = oeMap.values.toList();
    final mdmElectivesList = mdmMap.values.toList();
    final classAssignmentsList = classMap.values.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.lock_clock_outlined, color: Color(0xFFF97316), size: 22),
            SizedBox(width: 8),
            Text(
              'Interactive Pre-Assignment & Locking Workbench',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.category, color: Color(0xFFFB923C), size: 16),
            label: const Text('Classify Subjects', style: TextStyle(color: Color(0xFFFB923C), fontWeight: FontWeight.bold, fontSize: 12)),
            onPressed: _showSubjectClassificationDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── TOP WORKBENCH BANNER ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.14),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.touch_app, color: Color(0xFFFB923C), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Visual Slot Placement & Priority Cohort Locking',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Locking an Institutional (OE) or Dept (MDM) subject on $selectedClass auto-syncs across all $cohort classes. CP-SAT optimizes remaining lectures conflict-free.',
                          style: TextStyle(color: const Color(0xFFFB923C).withValues(alpha: 0.9), fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text('Auto-Generate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: _saveAndExecuteSolver,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ── DIVISION SELECTOR & HOME CLASSROOM BADGE ─────────────────────
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedDivision,
                        hint: const Text('Select Division to Inspect'),
                        items: divisions.map((d) {
                          return DropdownMenuItem(
                            value: d,
                            child: Text(
                              d,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedDivision = val),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.meeting_room, color: Color(0xFFF97316), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Home Classroom: ${_selectedDivision != null ? provider.getHomeClassroomForDivision(_selectedDivision!) : "Assigned"}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // ── SUBJECT PALETTES (TRAY) ──────────────────────────────────────
            _buildSubjectPalettes(
              openElectives: openElectivesList,
              mdmElectives: mdmElectivesList,
              classAssignments: classAssignmentsList,
            ),

            const SizedBox(height: 20),

            // ── INTERACTIVE TIMETABLE GRID WITH LOCKS ────────────────────────
            _buildInteractiveLockingGrid(
              days: days,
              timeSlots: timeSlots,
              selectedDivision: _selectedDivision ?? (divisions.isNotEmpty ? divisions.first : 'Division A'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectPalettes({
    required List<Map<String, dynamic>> openElectives,
    required List<Map<String, dynamic>> mdmElectives,
    required List<Map<String, dynamic>> classAssignments,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.palette_outlined, color: Color(0xFFEA580C), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Subject Tray (Drag & Drop or Tap to Lock)',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.category, size: 15, color: Color(0xFF0F172A)),
                label: const Text('⚙️ Classify', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 11.5)),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _showSubjectClassificationDialog,
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16, color: Color(0xFFEA580C)),
                label: const Text('+ Add Subject', style: TextStyle(color: Color(0xFFEA580C), fontWeight: FontWeight.bold, fontSize: 12)),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF7ED),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _showAddSubjectDialog,
              ),
              const SizedBox(width: 10),
              Text(
                '${_lockedSlots.length} Locked 🔒',
                style: const TextStyle(color: Color(0xFFEA580C), fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DefaultTabController(
            length: 3,
            child: Column(
              children: [
                const TabBar(
                  labelColor: Color(0xFF4F46E5),
                  unselectedLabelColor: Color(0xFF64748B),
                  indicatorColor: Color(0xFF4F46E5),
                  labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  tabs: [
                    Tab(text: '🌐 Institutional (OE)'),
                    Tab(text: '🏛️ Departmental (MDM/PE)'),
                    Tab(text: '📚 Class Core Subjects & Labs'),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 106,
                  child: TabBarView(
                    children: [
                      _buildChipList(openElectives, 'Institutional Elective', const Color(0xFF064E3B), const Color(0xFFECFDF5), const Color(0xFF10B981)),
                      _buildChipList(mdmElectives, 'Departmental Elective', const Color(0xFF581C87), const Color(0xFFFAF5FF), const Color(0xFFA855F7)),
                      _buildChipList(classAssignments, 'Class Core Subject', const Color(0xFF3730A3), const Color(0xFFEEF2FF), const Color(0xFF818CF8)),
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

  Widget _buildChipList(List<Map<String, dynamic>> items, String category, Color textColor, Color bgColor, Color borderColor) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No $category records found. Tap "⚙️ Classify" to organize sheet courses or "+ Add Subject".',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        ),
      );
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (context, index) {
        final a = items[index];
        final subName = a['subjectName'] as String? ?? 'Subject';
        final facName = a['facultyName'] as String? ?? '';
        final hrs = a['weeklyHours'] as int? ?? 3;
        final type = a['type'] as String? ?? 'Theory';
        final divs = (a['divisions'] is List) ? (a['divisions'] as List).join(', ') : '';

        final subjectData = {
          'subjectName': subName,
          'facultyName': facName,
          'weeklyHours': hrs,
          'type': type,
          'category': category,
          'divisions': a['divisions'],
        };

        return Draggable<Map<String, dynamic>>(
          data: subjectData,
          feedback: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor, width: 1.5),
              ),
              child: Text(
                '$subName (${facName.isNotEmpty ? facName : "All"})',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
          child: InkWell(
            onTap: () {
              setState(() => _draggedSubject = subjectData);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Selected "$subName". Tap any grid cell below to lock it!'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              width: 195,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    subName,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    facName.isNotEmpty ? facName : '$type • $hrs hrs/wk',
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (divs.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: borderColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Div: $divs',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: textColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInteractiveLockingGrid({
    required List<String> days,
    required List<TimeSlot> timeSlots,
    required String selectedDivision,
  }) {
    if (days.isEmpty || timeSlots.isEmpty) {
      return const Center(child: Text('Please configure working days and time slots first.'));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.grid_on, color: Color(0xFF0F172A), size: 18),
                const SizedBox(width: 8),
                Text(
                  'Weekly Schedule Grid: $selectedDivision',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                ),
                const Spacer(),
                const Text(
                  'Tap or Drop into a slot to Lock 🔒',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFF0F172A)),
              columns: [
                const DataColumn(label: Text('Day', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                ...timeSlots.map((ts) {
                  final sNum = ts.lectureNumber;
                  final sTime = ts.startTime;
                  final isBreak = ts.isBreak;
                  return DataColumn(
                    label: Text(
                      isBreak ? 'Break\n($sTime)' : 'Period $sNum\n$sTime',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  );
                }),
              ],
              rows: days.map((day) {
                return DataRow(
                  cells: [
                    DataCell(Text(day, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)))),
                    ...timeSlots.map((ts) {
                      final slotNum = ts.lectureNumber;
                      final isBreak = ts.isBreak;
                      final key = '${selectedDivision}_${day}_$slotNum';
                      final lockedData = _lockedSlots[key];

                      if (isBreak) {
                        return DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.coffee_rounded, size: 11, color: Color(0xFF64748B)),
                                SizedBox(width: 3),
                                Text(
                                  'BREAK',
                                  style: TextStyle(color: Color(0xFF475569), fontSize: 9.5, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return DataCell(
                        DragTarget<Map<String, dynamic>>(
                          onAcceptWithDetails: (details) {
                            _lockSlot(selectedDivision, day, slotNum, details.data);
                          },
                          builder: (context, candidateData, rejectedData) {
                            if (lockedData != null) {
                              return InkWell(
                                onTap: () => _unlockSlot(selectedDivision, day, slotNum),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF818CF8), width: 1.5),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.lock, color: Color(0xFF4F46E5), size: 14),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          lockedData['subject'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                            color: Color(0xFF3730A3),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return InkWell(
                              onTap: () {
                                if (_draggedSubject != null) {
                                  _lockSlot(selectedDivision, day, slotNum, _draggedSubject!);
                                } else {
                                  _showQuickAssignSlotDialog(selectedDivision, day, slotNum);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: candidateData.isNotEmpty ? const Color(0xFFF0FDF4) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: candidateData.isNotEmpty ? const Color(0xFF22C55E) : Colors.grey.shade200),
                                ),
                                child: const Center(
                                  child: Text(
                                    '+ Assign',
                                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
