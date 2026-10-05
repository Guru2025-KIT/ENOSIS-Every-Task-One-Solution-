import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'copo_repository.dart';

class ParsedStudentRow {
  final String rollNo;
  final String name;
  final String? prn;
  final double? singleMark;
  final Map<String, double?> questionMarks;

  ParsedStudentRow({
    required this.rollNo,
    required this.name,
    this.prn,
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
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );

      if (file == null) return null;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;

      return parseFileBytes(bytes, file.name);
    } catch (e) {
      return null;
    }
  }

  /// Parses bytes from either CSV or Excel format
  static ParsedSpreadsheetResult parseFileBytes(
      Uint8List bytes, String fileName) {
    List<List<String>> rawRows = [];

    if (fileName.toLowerCase().endsWith('.csv')) {
      final text = utf8.decode(bytes, allowMalformed: true);
      final lines = const LineSplitter().convert(text);
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        rawRows.add(line
            .split(',')
            .map((cell) => cell.trim().replaceAll('"', ''))
            .toList());
      }
    } else {
      // Excel decode
      final excel = Excel.decodeBytes(bytes);
      for (final table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet != null) {
          for (final row in sheet.rows) {
            final rowStrings = row
                .map((cell) => cell?.value?.toString().trim() ?? '')
                .toList();
            if (rowStrings.any((s) => s.isNotEmpty)) {
              rawRows.add(rowStrings);
            }
          }
          break; // Use the first sheet
        }
      }
    }

    if (rawRows.isEmpty) {
      return ParsedSpreadsheetResult(
          fileName: fileName, totalRows: 0, rows: [], detectedQuestions: []);
    }

    // Locate header row & column indexes
    int headerIdx = 0;
    int rollCol = -1;
    int nameCol = -1;
    int prnCol = -1;
    int markCol = -1;
    final Map<String, int> questionCols = {};

    for (int i = 0; i < rawRows.length && i < 6; i++) {
      final row = rawRows[i].map((s) => s.toLowerCase()).toList();
      for (int c = 0; c < row.length; c++) {
        final val = row[c];
        if (val.contains('roll') ||
            val.contains('r.no') ||
            val.contains('rollno')) {
          rollCol = c;
        } else if (val.contains('prn') ||
            val.contains('p.r.n') ||
            val.contains('reg')) {
          prnCol = c;
        } else if (val.contains('name') || val.contains('student')) {
          nameCol = c;
        } else if (val.contains('mark') ||
            val.contains('total') ||
            val.contains('score')) {
          markCol = c;
        } else if (val.startsWith('q') &&
            (val.length <= 15 || val.contains('question'))) {
          String rawHeader = rawRows[i][c].trim();
          if (rawHeader.contains('(')) {
            rawHeader = rawHeader.split('(')[0].trim();
          }
          questionCols[rawHeader] = c;
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
      if (roll.isEmpty ||
          ['roll no', 'prn', 'sr.no', 'total', 'average']
              .contains(roll.toLowerCase())) {
        continue;
      }

      final name =
          (nameCol != -1 && nameCol < row.length) ? row[nameCol].trim() : '';
      final prn =
          (prnCol != -1 && prnCol < row.length) ? row[prnCol].trim() : null;

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
        prn: prn,
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

  /// Download trigger helper for Web and Desktop
  static void downloadCsvFile(String filename, String content) {
    if (kIsWeb) {
      final bytes = utf8.encode(content);
      final blob = html.Blob([bytes], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  /// Template CSV generation strings for download
  static String getRollCallCsvTemplate() {
    return 'Sr.No,Roll No,Student Name,PRN\n'
        '1,CS001,Student One,20240101\n'
        '2,CS002,Student Two,20240102\n'
        '3,CS003,Student Three,20240103\n';
  }

  static String getIseCsvTemplate(
      String examType, List<StudentRosterItem> roster) {
    final buffer = StringBuffer();
    buffer.writeln('Sr.No,Roll No,Student Name,PRN,Marks (Out of 10)');
    if (roster.isNotEmpty) {
      for (final s in roster) {
        buffer.writeln(
            '${s.srNo},${s.rollNo},${s.name},${s.prn ?? '24250${s.rollNo}'},7.5');
      }
    } else {
      buffer.writeln('1,CS001,Student 1,20240101,7.5');
      buffer.writeln('2,CS002,Student 2,20240102,8.0');
    }
    return buffer.toString();
  }

  static String getIse1MarksCsvTemplate() => getIseCsvTemplate('ISE1', []);
  static String getIse2MarksCsvTemplate() => getIseCsvTemplate('ISE2', []);

  static String getQuestionWiseCsvTemplate(
      List<QuestionConfig> questions, List<StudentRosterItem> roster) {
    final buffer = StringBuffer();
    final qHeaders = questions.isNotEmpty
        ? questions.map((q) => '${q.questionId} (${q.coTag})').join(',')
        : 'Q1 (CO1),Q2 (CO2)';
    buffer.writeln('Sr.No,Roll No,Student Name,PRN,$qHeaders');
    if (roster.isNotEmpty) {
      for (final s in roster) {
        final dummyMarks = (questions.isNotEmpty
                ? questions
                : [
                    QuestionConfig(
                        questionId: 'Q1', coTag: 'CO1', maxMarks: 5.0),
                    QuestionConfig(
                        questionId: 'Q2', coTag: 'CO2', maxMarks: 5.0),
                  ])
            .map((q) => (q.maxMarks * 0.7).toStringAsFixed(1))
            .join(',');
        buffer.writeln(
            '${s.srNo},${s.rollNo},${s.name},${s.prn ?? '24250${s.rollNo}'},$dummyMarks');
      }
    } else {
      buffer.writeln('1,CS001,Student 1,20240101,3.5,3.5');
      buffer.writeln('2,CS002,Student 2,20240102,4.0,4.0');
    }
    return buffer.toString();
  }

  static String getMseMarksCsvTemplate() => getQuestionWiseCsvTemplate([
        QuestionConfig(questionId: 'Q1', coTag: 'CO1', maxMarks: 5.0),
        QuestionConfig(questionId: 'Q2', coTag: 'CO2', maxMarks: 5.0),
        QuestionConfig(questionId: 'Q3', coTag: 'CO3', maxMarks: 10.0),
        QuestionConfig(questionId: 'Q4', coTag: 'CO4', maxMarks: 10.0),
      ], []);

  static String getEseMarksCsvTemplate() => getQuestionWiseCsvTemplate([
        QuestionConfig(questionId: 'Q1', coTag: 'CO1', maxMarks: 10.0),
        QuestionConfig(questionId: 'Q2', coTag: 'CO2', maxMarks: 10.0),
        QuestionConfig(questionId: 'Q3', coTag: 'CO3', maxMarks: 10.0),
        QuestionConfig(questionId: 'Q4', coTag: 'CO4', maxMarks: 10.0),
        QuestionConfig(questionId: 'Q5', coTag: 'CO5', maxMarks: 20.0),
      ], []);
}
