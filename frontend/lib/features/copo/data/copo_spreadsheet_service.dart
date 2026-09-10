import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

class ParsedStudentRow {
  final String rollNo;
  final String name;
  final double? singleMark;
  final Map<String, double?> questionMarks;

  ParsedStudentRow({
    required this.rollNo,
    required this.name,
    this.singleMark,
    required this.questionMarks,
  });
}

class ParsedSpreadsheetResult {
  final String fileName;
  final int totalRows;
  final List<ParsedStudentRow> rows;
  final List<String> detectedQuestions;

  ParsedSpreadsheetResult({
    required this.fileName,
    required this.totalRows,
    required this.rows,
    required this.detectedQuestions,
  });
}

class CopoSpreadsheetService {
  /// Picks a file from user's device and extracts student marks.
  static Future<ParsedSpreadsheetResult?> pickAndParseMarksSheet() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) return null;

      return parseFileBytes(bytes, file.name);
    } catch (e) {
      return null;
    }
  }

  /// Parses bytes from either CSV or Excel format
  static ParsedSpreadsheetResult parseFileBytes(Uint8List bytes, String fileName) {
    List<List<String>> rawRows = [];

    if (fileName.toLowerCase().endsWith('.csv')) {
      final text = utf8.decode(bytes, allowMalformed: true);
      final lines = const LineSplitter().convert(text);
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        rawRows.add(line.split(',').map((cell) => cell.trim().replaceAll('"', '')).toList());
      }
    } else {
      // Excel decode
      final excel = Excel.decodeBytes(bytes);
      for (final table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet != null) {
          for (final row in sheet.rows) {
            final rowStrings = row.map((cell) => cell?.value?.toString().trim() ?? '').toList();
            if (rowStrings.any((s) => s.isNotEmpty)) {
              rawRows.add(rowStrings);
            }
          }
          break; // Use the first sheet
        }
      }
    }

    if (rawRows.isEmpty) {
      return ParsedSpreadsheetResult(fileName: fileName, totalRows: 0, rows: [], detectedQuestions: []);
    }

    // Locate header row & column indexes
    int headerIdx = 0;
    int rollCol = -1;
    int nameCol = -1;
    int markCol = -1;
    final Map<String, int> questionCols = {};

    for (int i = 0; i < rawRows.length && i < 6; i++) {
      final row = rawRows[i].map((s) => s.toLowerCase()).toList();
      for (int c = 0; c < row.length; c++) {
        final val = row[c];
        if (val.contains('roll') || val.contains('prn') || val.contains('r.no')) {
          rollCol = c;
        } else if (val.contains('name') || val.contains('student')) {
          nameCol = c;
        } else if (val.contains('mark') || val.contains('total') || val.contains('score')) {
          markCol = c;
        } else if (val.startsWith('q') && (val.length <= 5 || val.contains('question'))) {
          questionCols[rawRows[i][c].trim()] = c;
        }
      }
      if (rollCol != -1) {
        headerIdx = i;
        break;
      }
    }

    // Fallbacks if header wasn't labeled
    if (rollCol == -1) {
      rollCol = 0;
      if (rawRows[0].length > 1) nameCol = 1;
      if (rawRows[0].length > 2) markCol = 2;
    }

    final List<ParsedStudentRow> parsedStudents = [];

    for (int r = headerIdx + 1; r < rawRows.length; r++) {
      final row = rawRows[r];
      if (rollCol >= row.length) continue;

      final roll = row[rollCol].trim();
      if (roll.isEmpty || ['roll no', 'prn', 'sr.no', 'total', 'average'].contains(roll.toLowerCase())) {
        continue;
      }

      final name = (nameCol != -1 && nameCol < row.length) ? row[nameCol].trim() : '';

      double? singleMark;
      if (markCol != -1 && markCol < row.length) {
        singleMark = double.tryParse(row[markCol].trim());
      }

      final Map<String, double?> qScores = {};
      for (final entry in questionCols.entries) {
        if (entry.value < row.length) {
          qScores[entry.key] = double.tryParse(row[entry.value].trim());
        }
      }

      parsedStudents.add(ParsedStudentRow(
        rollNo: roll,
        name: name,
        singleMark: singleMark,
        questionMarks: qScores,
      ));
    }

    return ParsedSpreadsheetResult(
      fileName: fileName,
      totalRows: parsedStudents.length,
      rows: parsedStudents,
      detectedQuestions: questionCols.keys.toList(),
    );
  }

  /// Template CSV generation strings for download
  static String getRollCallCsvTemplate() {
    return 'Sr.No,Roll No,Student Name,PRN\n'
        '1,CS001,Aarav Sharma,20240101\n'
        '2,CS002,Aditi Patel,20240102\n'
        '3,CS003,Ananya Iyer,20240103\n'
        '4,CS004,Aryan Verma,20240104\n'
        '5,CS005,Bhavya Deshmukh,20240105\n';
  }

  static String getIseMarksCsvTemplate() {
    return 'Roll No,Student Name,Marks (Out of 10)\n'
        'CS001,Aarav Sharma,8.5\n'
        'CS002,Aditi Patel,7.0\n'
        'CS003,Ananya Iyer,9.0\n'
        'CS004,Aryan Verma,6.5\n'
        'CS005,Bhavya Deshmukh,8.0\n';
  }

  static String getQuestionWiseMarksCsvTemplate() {
    return 'Roll No,Student Name,Q1,Q2,Q3,Q4\n'
        'CS001,Aarav Sharma,4.5,4.0,8.5,7.5\n'
        'CS002,Aditi Patel,3.5,4.5,7.0,8.0\n'
        'CS003,Ananya Iyer,5.0,4.0,9.0,8.5\n'
        'CS004,Aryan Verma,4.0,3.5,6.5,7.0\n'
        'CS005,Bhavya Deshmukh,4.5,4.0,8.0,8.5\n';
  }
}
