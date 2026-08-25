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
        final Map<String, int> colMap = {};
        for (int i = 0; i < rows[0].length; i++) {
          final header = _getCellValue(rows[0], i).toLowerCase();
          if (header.contains('faculty') || header.contains('teacher')) {
            colMap['faculty'] = i;
          } else if (header.contains('subject') && !header.contains('code')) {
            colMap['subject'] = i;
          } else if (header.contains('code')) {
            colMap['code'] = i;
          } else if (header.contains('class') || header.contains('div')) {
            colMap['class'] = i;
          } else if (header.contains('batch')) {
            colMap['batch'] = i;
          } else if (header.contains('hour')) {
            colMap['hours'] = i;
          } else if (header.contains('type')) {
            colMap['type'] = i;
          }
        }

        for (int i = 1; i < rows.length; i++) {
          final row = rows[i];
          if (row.isEmpty) continue;

          final faculty = _getCellValue(row, colMap['faculty'] ?? -1);
          final subject = _getCellValue(row, colMap['subject'] ?? -1);
          final code = _getCellValue(row, colMap['code'] ?? -1);
          final className = _getCellValue(row, colMap['class'] ?? -1);
          final batch = _getCellValue(row, colMap['batch'] ?? -1);
          final hoursStr = _getCellValue(row, colMap['hours'] ?? -1);
          final type = _getCellValue(row, colMap['type'] ?? -1);

          if (faculty.isEmpty && subject.isEmpty && className.isEmpty) continue;

          if (faculty.isNotEmpty && subject.isNotEmpty) {
            final hours = int.tryParse(hoursStr) ?? 0;
            parsedAssignments.add(TeachingAssignment(
              facultyName: faculty,
              subjectName: subject,
              subjectCode: code,
              className: className,
              batch: batch,
              weeklyHours: hours,
              type: type.isEmpty ? 'Theory' : type,
            ));
          }
        }
        break;
      }

      if (!mounted) return;

      if (parsedAssignments.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No valid rows found. Ensure your sheet has headers.';
        });
        return;
      }

      // ✅ SAVE DATA TO PROVIDER
      context.read<TimetableProvider>().setAssignments(parsedAssignments);

      setState(() {
        _selectedFileName = file.name;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully loaded ${parsedAssignments.length} assignments!'),
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
    // ✅ READ DATA DIRECTLY FROM PROVIDER (This makes it persist!)
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
                Text('Faculty Subject Assignments', style: AppTypography.h3),
                const SizedBox(height: 8),
                Text('Upload .xlsx file. System auto-detects columns.', textAlign: TextAlign.center, style: AppTypography.bodySecondary),
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
          child: ListView.builder(
            itemCount: filteredAssignments.length,
            itemBuilder: (context, index) {
              final item = filteredAssignments[index];
              return ListTile(
                title: Text(item.subjectName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${item.facultyName} • ${item.className} ${item.batch.isNotEmpty && item.batch != '*' ? '(${item.batch})' : ''}'),
                trailing: Text('${item.weeklyHours} hrs'),
              );
            },
          ),
        ),
      ],
    );
  }
}