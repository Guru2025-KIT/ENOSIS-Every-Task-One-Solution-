import 'dart:typed_data';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../models/teaching_assignment.dart';
import '../../providers/timetable_provider.dart';

// Helper class for Pass 1 parsing
class _RawRowData {
  final String faculty, rawCode, rawName;
  final int theoryHours, pracHours;
  final List<String> classNames;
  _RawRowData(this.faculty, this.rawCode, this.rawName, this.theoryHours, this.pracHours, this.classNames);
}

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

  Future<void> _downloadTemplate() async {
    try {
      var excel = Excel.createExcel();
      Sheet sheet = excel['Sheet1']; 
      
      sheet.appendRow(['INSTRUCTIONS:']);
      sheet.appendRow(['1. Do not change column order.']);
      sheet.appendRow(['2. Class/Division must be clear (e.g., SY-AIML-A, TY-IT-B, BTECH-COMP).']);
      sheet.appendRow(['3. If lecture is for all divisions, write the year & dept (e.g., TY-AIML).']);
      sheet.appendRow(['4. For joint divisions, use slash (e.g., SY-AIML-A/B).']);
      sheet.appendRow(['5. If faculty is same for next row, leave it blank. System will auto-copy.']);
      sheet.appendRow(['']);

      sheet.appendRow(['Sr. No.', 'Faculty Name', 'Designation', 'Class / Division', 'Course Code', 'Course Name', 'Theory Hours', 'Practical Hours']);
      sheet.appendRow([1, 'Dr. John Doe', 'Professor', 'TY-IT-A', 'IT501', 'Machine Learning', 3, 0]);
      sheet.appendRow(['', '', '', 'TY-IT-A', 'IT501L', 'ML Lab', 0, 4]);

      var bytes = excel.encode();
      if (bytes == null) throw Exception("Failed to encode Excel");

      Uint8List uint8bytes = Uint8List.fromList(bytes);
      final blob = html.Blob([uint8bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)..setAttribute('download', 'HOD_Workload_Template.xlsx');
      
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template downloaded! Check your Downloads folder.'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ✅ 100% DYNAMIC PARSER (No Hardcoded AIML or Divisions)
  List<String> _extractClasses(String rawClass) {
    if (rawClass.isEmpty) return [];
    String c = rawClass.toUpperCase();

    c = c.replaceAll('/', ',');
    c = c.replaceAll('&', ',');
    c = c.replaceAll(' AND ', ',');
    c = c.replaceAll(RegExp(r'[^A-Z0-9,\s]'), ' ');
    c = c.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    List<String> segments = c.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    List<String> results = [];
    String? lastYear;
    String? lastDept;

    for (String seg in segments) {
      String year = '';
      if (RegExp(r'F\s*Y').hasMatch(seg)) year = 'FY';
      else if (RegExp(r'S\s*Y').hasMatch(seg)) year = 'SY';
      else if (RegExp(r'T\s*Y').hasMatch(seg)) year = 'TY';
      else if (RegExp(r'B\s*TECH').hasMatch(seg) || RegExp(r'FINAL\s*YEAR').hasMatch(seg)) year = 'BTECH';

      if (year.isEmpty && lastYear != null) {
        year = lastYear;
      } else if (year.isNotEmpty) {
        lastYear = year;
      }

      if (year.isEmpty) continue;

      List<String> tokens = seg.split(' ');
      List<String> depts = [];
      List<String> divs = [];
      
      for (var t in tokens) {
        if (t == 'A' || t == 'B' || t == 'C' || t == 'D') {
          divs.add(t);
        } else if (t != year && t != 'Y' && t != 'YEAR' && t != 'TECH' && t != 'FINAL') {
          if (t.isNotEmpty) depts.add(t);
        }
      }

      if (depts.isEmpty && lastDept != null) {
        depts.add(lastDept);
      } else if (depts.isNotEmpty) {
        lastDept = depts.join('-');
      }

      if (depts.isEmpty) depts.add('CORE');

      for (String dept in depts) {
        String baseName = '$year-$dept';
        if (divs.isNotEmpty) {
          for (String d in divs) {
            results.add('$baseName-$d');
          }
        } else {
          results.add(baseName); // e.g., "TY-IT". Will be expanded in Pass 2.
        }
      }
    }
    
    return results.toSet().toList();
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
      List<_RawRowData> rawRows = [];

      for (final tableName in excel.tables.keys) {
        final sheet = excel.tables[tableName];
        if (sheet == null || sheet.rows.isEmpty) continue;

        final rows = sheet.rows;
        
        int headerRowIdx = 0;
        for (int i = 0; i < rows.length; i++) {
          if (_getCellValue(rows[i], 0).toLowerCase().contains('sr') && 
              _getCellValue(rows[i], 1).toLowerCase().contains('faculty')) {
            headerRowIdx = i;
            break;
          }
        }

        Map<String, int> colMap = {};
        for (int i = 0; i < rows[headerRowIdx].length; i++) {
          String header = _getCellValue(rows[headerRowIdx], i).toLowerCase();
          if (header.contains('faculty')) colMap['faculty'] = i;
          else if (header.contains('class') || header.contains('div')) colMap['class'] = i;
          else if (header.contains('code') && !header.contains('name')) colMap['code'] = i;
          else if (header.contains('course') || header.contains('name')) colMap['name'] = i;
          else if (header.contains('theory')) colMap['theory'] = i;
          else if (header.contains('pract')) colMap['prac'] = i;
        }

        int facultyCol = colMap['faculty'] ?? 1;
        int classCol = colMap['class'] ?? 3;
        int codeCol = colMap['code'] ?? 4;
        int nameCol = colMap['name'] ?? 5;
        int theoryCol = colMap['theory'] ?? 6;
        int pracCol = colMap['prac'] ?? 7;

        String lastFaculty = '';

        // PASS 1: Read raw data and extract base classes
        for (int i = headerRowIdx + 1; i < rows.length; i++) {
          final row = rows[i];
          
          String faculty = _getCellValue(row, facultyCol);
          if (faculty.isEmpty || faculty == '*' || faculty == 'x') {
            faculty = lastFaculty;
          } else {
            lastFaculty = faculty;
          }

          String rawClass = _getCellValue(row, classCol);
          String rawCode = _getCellValue(row, codeCol);
          String rawName = _getCellValue(row, nameCol);
          String theoryStr = _getCellValue(row, theoryCol);
          String pracStr = _getCellValue(row, pracCol);

          if (faculty.isEmpty && rawClass.isEmpty && rawName.isEmpty) continue;
          if (rawClass.toLowerCase().contains('total') || rawName.toLowerCase().contains('total')) continue;

          List<String> classNames = _extractClasses(rawClass);
          int pracHours = int.tryParse(pracStr) ?? 0;
          int theoryHours = int.tryParse(theoryStr) ?? 0;
          
          rawRows.add(_RawRowData(faculty, rawCode, rawName, theoryHours, pracHours, classNames));
        }
        break;
      }

      // PASS 2: Build dynamic division map and expand combined classes
      Map<String, Set<String>> deptDivisions = {};
      for (var row in rawRows) {
        for (var cName in row.classNames) {
          List<String> parts = cName.split('-');
          if (parts.length == 3) {
            String base = '${parts[0]}-${parts[1]}';
            deptDivisions.putIfAbsent(base, () => <String>{}).add(parts[2]);
          }
        }
      }

      final List<TeachingAssignment> parsedAssignments = [];
      for (var row in rawRows) {
        List<String> finalClassNames = [];
        
        for (var cName in row.classNames) {
          if (cName.split('-').length == 3) {
            finalClassNames.add(cName); // Already has division
          } else if (deptDivisions.containsKey(cName)) {
            // Expand combined class (e.g., "TY-IT" -> "TY-IT-A", "TY-IT-B")
            for (var div in deptDivisions[cName]!) {
              finalClassNames.add('$cName-$div');
            }
          } else {
            // Standalone class with no divisions in the whole sheet (e.g., "TY-DS")
            finalClassNames.add(cName);
          }
        }

        for (String className in finalClassNames) {
          if (row.pracHours > 0) {
            if (row.pracHours >= 4) {
              int batch1Hours = row.pracHours ~/ 2;
              int batch2Hours = row.pracHours - batch1Hours;
              
              parsedAssignments.add(TeachingAssignment(
                facultyName: row.faculty, subjectName: row.rawName, subjectCode: row.rawCode,
                className: className, batch: 'Batch 1', weeklyHours: batch1Hours, type: 'Lab',
              ));
              parsedAssignments.add(TeachingAssignment(
                facultyName: row.faculty, subjectName: row.rawName, subjectCode: row.rawCode,
                className: className, batch: 'Batch 2', weeklyHours: batch2Hours, type: 'Lab',
              ));
            } else {
              parsedAssignments.add(TeachingAssignment(
                facultyName: row.faculty, subjectName: row.rawName, subjectCode: row.rawCode,
                className: className, batch: 'Single Batch', weeklyHours: row.pracHours, type: 'Lab',
              ));
            }
          }

          if (row.theoryHours > 0) {
            parsedAssignments.add(TeachingAssignment(
              facultyName: row.faculty, subjectName: row.rawName, subjectCode: row.rawCode,
              className: className, batch: '-', weeklyHours: row.theoryHours, type: 'Theory',
            ));
          }
        }
      }

      if (!mounted) return;

      if (parsedAssignments.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No valid rows found. Please download and use the template.';
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
          content: Text('Loaded ${parsedAssignments.length} assignments dynamically!'),
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
                Text('Universal Workload Sheet', style: AppTypography.h3),
                const SizedBox(height: 8),
                Text('To ensure perfect reading for ANY department, please download the template, fill it, and upload it back.', textAlign: TextAlign.center, style: AppTypography.bodySecondary),
                const SizedBox(height: 24),
                
                OutlinedButton.icon(
                  onPressed: _downloadTemplate,
                  icon: const Icon(Icons.download, color: AppColors.primary),
                  label: const Text('Download Excel Template', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 16),
                
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