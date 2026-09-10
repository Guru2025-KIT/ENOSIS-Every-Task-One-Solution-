import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/admin_repository.dart';

class FacultyUploadDialog extends StatefulWidget {
  final VoidCallback onImportSuccess;

  const FacultyUploadDialog({
    super.key,
    required this.onImportSuccess,
  });

  @override
  State<FacultyUploadDialog> createState() => _FacultyUploadDialogState();
}

class _FacultyUploadDialogState extends State<FacultyUploadDialog> with SingleTickerProviderStateMixin {
  final AdminRepository _repository = AdminRepository();

  bool _isLoading = false;
  bool _isImporting = false;
  String? _selectedFileName;
  FacultyValidationResultModel? _validationResult;
  String? _errorMessage;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickAndValidateFile() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );

      if (file == null) return;

      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _selectedFileName = file.name;
        _validationResult = null;
      });

      final bytes = await file.readAsBytes();

      final validation = await _repository.validateFacultyUpload(
        bytes: bytes,
        filePath: file.path,
        fileName: file.name,
      );

      setState(() {
        _isLoading = false;
        _validationResult = validation;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _executeImport() async {
    if (_validationResult == null || _validationResult!.validRows.isEmpty) return;

    setState(() {
      _isImporting = true;
      _errorMessage = null;
    });

    try {
      final importedCount = await _repository.bulkImportFaculty(_validationResult!.validRows);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onImportSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported $importedCount faculty records into Master Data!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 860,
        height: 640,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Import Faculty Master Data',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Upload Excel (.xlsx, .xls) or CSV with automatic pre-import verification',
                        style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 28),

            // Main Content Area
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Validating and inspecting spreadsheet structure...', style: TextStyle(fontWeight: FontWeight.w600)),
                          SizedBox(height: 6),
                          Text('Checking emails, employee IDs, and duplicates against Master Data', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    )
                  : _validationResult == null
                      ? _buildInitialUploadView()
                      : _buildValidationBreakdownView(),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.error, fontSize: 12.5, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Divider(height: 28),

            // Actions Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_validationResult != null)
                  TextButton.icon(
                    icon: const Icon(Icons.replay, size: 16),
                    label: const Text('Pick Another File'),
                    onPressed: _isImporting ? null : _pickAndValidateFile,
                  )
                else
                  const SizedBox(),
                Row(
                  children: [
                    TextButton(
                      onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    if (_validationResult != null)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _validationResult!.validCount > 0 ? AppColors.success : Colors.grey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        icon: _isImporting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle_outline, size: 18),
                        label: Text(
                          _isImporting
                              ? 'Importing...'
                              : 'Commit Import (${_validationResult!.validCount} Valid Records)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: (_validationResult!.validCount > 0 && !_isImporting) ? _executeImport : null,
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialUploadView() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.table_chart_outlined, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Faculty Spreadsheet for Verification',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Supported formats: .xlsx, .xls, .csv\nRequired Columns: Name / Full Name, Email, Employee ID, Department',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.folder_open, size: 20),
              label: const Text('Browse Files & Run Dry-Run Check', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _pickAndValidateFile,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValidationBreakdownView() {
    final v = _validationResult!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top summary metrics
        Row(
          children: [
            _buildMetricPill('Total Rows', '${v.totalRows}', AppColors.textPrimary, Colors.grey.shade200),
            const SizedBox(width: 10),
            _buildMetricPill('Valid to Import', '${v.validCount}', AppColors.success, AppColors.success.withOpacity(0.12)),
            const SizedBox(width: 10),
            _buildMetricPill('Duplicate Records', '${v.duplicateCount}', Colors.deepOrange, Colors.deepOrange.withOpacity(0.12)),
            const SizedBox(width: 10),
            _buildMetricPill('Missing Fields', '${v.missingFieldsCount}', Colors.amber.shade900, Colors.amber.withOpacity(0.15)),
            const SizedBox(width: 10),
            _buildMetricPill('Invalid Email/Format', '${v.invalidCount}', AppColors.error, AppColors.error.withOpacity(0.12)),
          ],
        ),
        const SizedBox(height: 14),

        // Tabs for the 4 diagnostic categories
        TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: '1. Valid Records (${v.validCount})'),
            Tab(text: '2. Duplicate Records (${v.duplicateCount})'),
            Tab(text: '3. Missing Required Fields (${v.missingFieldsCount})'),
            Tab(text: '4. Format Errors (${v.invalidCount})'),
          ],
        ),
        const SizedBox(height: 10),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildRowsTable(v.validRows, isError: false),
              _buildRowsTable(v.duplicateRows, isError: true),
              _buildRowsTable(v.missingFieldsRows, isError: true),
              _buildRowsTable(v.invalidRows, isError: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricPill(String label, String value, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, color: textColor.withOpacity(0.85), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildRowsTable(List<FacultyImportRowModel> rows, {required bool isError}) {
    if (rows.isEmpty) {
      return Center(
        child: Text(
          isError ? 'No issues found in this category.' : 'No valid records found in spreadsheet.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 38,
          dataRowMinHeight: 42,
          dataRowMaxHeight: 48,
          columns: [
            const DataColumn(label: Text('Row #', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            const DataColumn(label: Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            const DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            const DataColumn(label: Text('Employee ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            const DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            const DataColumn(label: Text('Designation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            if (isError)
              const DataColumn(label: Text('Diagnostic Reason', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.error))),
          ],
          rows: rows.map((r) {
            return DataRow(
              cells: [
                DataCell(Text('${r.rowNumber}', style: const TextStyle(fontSize: 12))),
                DataCell(Text(r.fullName.isNotEmpty ? r.fullName : '(Missing)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: r.fullName.isEmpty ? AppColors.error : AppColors.textPrimary))),
                DataCell(Text(r.email.isNotEmpty ? r.email : '(Missing)', style: TextStyle(fontSize: 12, color: r.email.isEmpty ? AppColors.error : AppColors.textSecondary))),
                DataCell(Text(r.employeeId.isNotEmpty ? r.employeeId : '(Missing)', style: TextStyle(fontSize: 12, color: r.employeeId.isEmpty ? AppColors.error : AppColors.textSecondary))),
                DataCell(Text(r.department.isNotEmpty ? r.department : '(Missing)', style: const TextStyle(fontSize: 12))),
                DataCell(Text(r.designation, style: const TextStyle(fontSize: 12))),
                if (isError)
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        r.error ?? 'Unknown error',
                        style: const TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
