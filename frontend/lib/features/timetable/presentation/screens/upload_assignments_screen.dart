import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../models/teaching_assignment.dart';
import '../../providers/timetable_provider.dart';

class UploadAssignmentsScreen extends StatefulWidget {
  const UploadAssignmentsScreen({super.key});

  @override
  State<UploadAssignmentsScreen> createState() => _UploadAssignmentsScreenState();
}

class _UploadAssignmentsScreenState extends State<UploadAssignmentsScreen> {
  String _searchQuery = '';
  bool _isLoading = false;
  String _errorMessage = '';
  String? _selectedFileName;

  String _getCellValue(List<Data?> row, int index) {
    try {
      if (index < 0 || index >= row.length) return '';
      final cell = row[index];
      if (cell == null) return '';
      final val = cell.value;
      if (val == null) return '';
      return val.toString().trim();
    } catch (e) {
      return '';
    }
  }

  // ✅ 100% BULLETPROOF TOKEN-BASED PARSER
  List<String> _extractClasses(String rawClass) {
    if (rawClass.isEmpty) return [];
    String c = rawClass.toUpperCase();

    if (c.contains('FINAL YEAR')) {
      debugPrint('FLAG: Input containing "FINAL YEAR" found -> "$rawClass". Needs manual review.');
    }

    c = c.replaceAll(RegExp(r'[\(\)\-\.]'), ' ');
    c = c.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    c = c.replaceAll('/', ',');
    c = c.replaceAll('&', ',');
    c = c.replaceAll(' AND ', ',');
    
    List<String> segments = c.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    
    List<String> results = [];
    String? lastYear;
    String? lastDept;

    for (String seg in segments) {
      String year = '';
      if (RegExp(r'F\s*Y').hasMatch(seg)) year = 'FY';
      else if (RegExp(r'S\s*Y').hasMatch(seg)) year = 'SY';
      else if (RegExp(r'T\s*Y').hasMatch(seg)) year = 'TY';
      else if (RegExp(r'B\s*TECH').hasMatch(seg)) year = 'BTECH';
      else if (RegExp(r'FINAL\s*YEAR').hasMatch(seg)) year = 'BTECH';

      if (year.isEmpty && lastYear != null) {
        year = lastYear!;
      } else {
        lastYear = year;
      }

      if (year.isEmpty) continue;

      List<String> depts = [];
      if (seg.contains('AIML')) depts.add('AIML');
      if (seg.contains('DS')) depts.add('DS');
      
      if (depts.isEmpty && lastDept != null) {
        depts.add(lastDept!);
      } else if (depts.isEmpty && lastDept == null) {
        depts.add('AIML');
      } else {
        lastDept = depts.join('-');
      }

      List<String> divs = [];
      if (RegExp(r'\bA\b').hasMatch(seg)) divs.add('A');
      if (RegExp(r'\bB\b').hasMatch(seg)) divs.add('B');
      if (RegExp(r'\bC\b').hasMatch(seg)) divs.add('C');

      for (String dept in depts) {
        String baseName = '$year-$dept';
        if (divs.isNotEmpty) {
          for (String d in divs) {
            results.add('$baseName-$d');
          }
        } else {
          results.addAll(_expandDivisions(baseName));
        }
      }
    }
    
    return results.toSet().toList();
  }

  // Expansion Logic
  List<String> _expandDivisions(String baseName) {
    switch (baseName) {
      case 'SY-AIML':
        return ['SY-AIML-A', 'SY-AIML-B', 'SY-AIML-C'];
      case 'TY-AIML':
        return ['TY-AIML-A', 'TY-AIML-B'];
      case 'BTECH-AIML':
        return ['BTECH-AIML-A', 'BTECH-AIML-B']; // Added BTECH expansion!
      default:
        return [baseName]; // TY-DS, FY-AIML stay standalone
    }
  }

  Future<void> _pickAndReadExcel() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final file = result.files.single;
      final bytes = file.bytes;

      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Could not read file data. Please try again.';
          });
        }
        return;
      }

      final excel = Excel.decodeBytes(bytes);
      final List<TeachingAssignment> parsedAssignments = [];

      for (final tableName in excel.tables.keys) {
        final sheet = excel.tables[tableName];
        if (sheet == null || sheet.rows.isEmpty) continue;

        final rows = sheet.rows;
        int facultyCol = 1;
        int classCol = 3;
        int courseCol = 4;
        int theoryCol = 5;
        int pracCol = 7;

        String lastFaculty = '';

        for (int i = 5; i < rows.length; i++) {
          final row = rows[i];
          
          String faculty = _getCellValue(row, facultyCol);
          if (faculty.isEmpty || faculty == '*' || faculty == 'x') {
            faculty = lastFaculty;
          } else {
            lastFaculty = faculty;
          }

          String rawClass = _getCellValue(row, classCol);
          String rawCourse = _getCellValue(row, courseCol);
          String theoryStr = _getCellValue(row, theoryCol);
          String pracStr = _getCellValue(row, pracCol);

          if (faculty.isEmpty && rawClass.isEmpty && rawCourse.isEmpty) continue;
          if (rawClass.toLowerCase().contains('total') || rawCourse.toLowerCase().contains('total')) continue;

          String subjectCode = '';
          String subjectName = rawCourse;
          
          RegExp exp = RegExp(r'^([A-Z]{2,}\d*[A-Z]*\d+)\s*(.*)');
          Match? match = exp.firstMatch(rawCourse);
          if (match != null) {
            subjectCode = match.group(1) ?? '';
            subjectName = match.group(2) ?? rawCourse;
          } else {
            subjectCode = 'N/A';
            subjectName = rawCourse;
          }

          List<String> classNames = _extractClasses(rawClass);
          
          int pracHours = int.tryParse(pracStr) ?? 0;
          int theoryHours = int.tryParse(theoryStr) ?? 0;

          for (String className in classNames) {
            if (pracHours > 0) {
              if (pracHours >= 4) {
                int batch1Hours = pracHours ~/ 2;
                int batch2Hours = pracHours - batch1Hours;
                
                parsedAssignments.add(TeachingAssignment(
                  facultyName: faculty, subjectName: subjectName, subjectCode: subjectCode,
                  className: className, batch: 'Batch 1', weeklyHours: batch1Hours, type: 'Lab',
                ));
                parsedAssignments.add(TeachingAssignment(
                  facultyName: faculty, subjectName: subjectName, subjectCode: subjectCode,
                  className: className, batch: 'Batch 2', weeklyHours: batch2Hours, type: 'Lab',
                ));
              } else {
                parsedAssignments.add(TeachingAssignment(
                  facultyName: faculty, subjectName: subjectName, subjectCode: subjectCode,
                  className: className, batch: 'Single Batch', weeklyHours: pracHours, type: 'Lab',
                ));
              }
            }

            if (theoryHours > 0) {
              parsedAssignments.add(TeachingAssignment(
                facultyName: faculty, subjectName: subjectName, subjectCode: subjectCode,
                className: className, batch: '-', weeklyHours: theoryHours, type: 'Theory',
              ));
            }
          }
        }
        break;
      }

      if (!mounted) return;

      if (parsedAssignments.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No valid rows found. Ensure this is the HOD Workload sheet.';
        });
        return;
      }

      context.read<TimetableProvider>().setAssignments(parsedAssignments);

      setState(() {
        _selectedFileName = file.name;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loaded ${parsedAssignments.length} assignments. Classes expanded!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error reading file: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final _assignments = context.watch<TimetableProvider>().assignments;

    List<TeachingAssignment> filteredAssignments = _assignments;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      filteredAssignments = _assignments.where((a) {
        return a.facultyName.toLowerCase().contains(q) ||
            a.subjectName.toLowerCase().contains(q) ||
            a.className.toLowerCase().contains(q);
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Master Data'),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          if (_assignments.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _pickAndReadExcel,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _assignments.isEmpty
              ? _buildEmptyState()
              : _buildLoadedState(filteredAssignments),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const Icon(Icons.table_view_rounded, size: 48, color: AppColors.primary),
                const SizedBox(height: 16),
                Text('HOD Workload Sheet', style: AppTypography.h3),
                const SizedBox(height: 8),
                Text('Upload the raw .xlsx file. The token-based parser will handle joint lectures, missing divisions, and AIML/DS mixes.', textAlign: TextAlign.center, style: AppTypography.bodySecondary),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _pickAndReadExcel,
                  icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
                  label: const Text('Choose .xlsx File', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                ),
              ],
            ),
          ),
          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withOpacity(0.4)),
              ),
              child: Text(_errorMessage, style: TextStyle(color: AppColors.error)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadedState(List<TeachingAssignment> filteredAssignments) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (_selectedFileName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, size: 16, color: AppColors.success),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Loaded File: $_selectedFileName',
                          style: AppTypography.captionBold.copyWith(color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search faculty, subject, or class...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20.0,
                columns: const [
                  DataColumn(label: Text('Faculty', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Subject', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Class', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Batch Info', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Type / Hours', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: filteredAssignments.map((item) {
                  final isLab = item.type == 'Lab';
                  return DataRow(cells: [
                    DataCell(Text(item.facultyName, style: const TextStyle(fontSize: 13))),
                    DataCell(Text(item.subjectName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(item.className, style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold))
                    )),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isLab ? Colors.purple.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(item.batch, style: TextStyle(fontSize: 12, color: isLab ? Colors.purple : Colors.grey, fontWeight: FontWeight.bold)),
                      )
                    ),
                    DataCell(
                      Text('${item.type} (${item.weeklyHours}h)', style: TextStyle(fontSize: 13, color: isLab ? Colors.purple : AppColors.primary, fontWeight: FontWeight.bold))
                    ),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}