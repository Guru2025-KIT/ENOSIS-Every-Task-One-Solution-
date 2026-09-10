import 'dart:convert';
import 'package:universal_html/html.dart' as html;
import 'copo_repository.dart';

/// Service to generate and export an audit-ready, full-page printable PDF report
/// of the entire NBA Course Outcome (CO) and Program Outcome (PO) attainment.
class CopoPdfService {
  CopoPdfService._();

  static void generateAndOpenReportPdf({
    required CopoAttainmentReport report,
    required AttainmentConfig config,
    required KitCourseInfo course,
  }) {
    final htmlContent = _buildHtmlReport(report, config, course);

    // Create a Blob containing the styled HTML document
    final blob = html.Blob([htmlContent], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);

    // Open in a new window/tab for preview and printing
    final printWindow = html.window.open(url, '_blank');

    // Trigger cleanup
    Future.delayed(const Duration(seconds: 15), () {
      html.Url.revokeObjectUrl(url);
    });

    if (printWindow == null) {
      // Fallback: trigger file download if popup blocked
      downloadReportHtml(report: report, config: config, course: course);
    }
  }

  static void downloadReportHtml({
    required CopoAttainmentReport report,
    required AttainmentConfig config,
    required KitCourseInfo course,
  }) {
    final htmlContent = _buildHtmlReport(report, config, course);
    final bytes = utf8.encode(htmlContent);
    final blob = html.Blob([bytes], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'COPO_Attainment_Report_${course.code}.html')
      ..style.display = 'none';

    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  static String _buildHtmlReport(
    CopoAttainmentReport report,
    AttainmentConfig config,
    KitCourseInfo course,
  ) {
    final directPct = config.directWeightPercent.toStringAsFixed(0);
    final indirectPct = config.indirectWeightPercent.toStringAsFixed(0);
    final passingCutoff = config.passingThresholdPercent.toStringAsFixed(0);
    final target = config.targetBenchmark.toStringAsFixed(2);

    // CO Descriptions rows
    final coDescHtml = StringBuffer();
    for (int i = 0; i < course.cos.length; i++) {
      coDescHtml.write('<tr><td style="font-weight:600; width:60px;">CO${i + 1}</td><td>${course.cos[i]}</td></tr>');
    }

    // Correlation matrix headers
    final poHeaders = StringBuffer();
    for (final po in poColumnNames) {
      poHeaders.write('<th>$po</th>');
    }

    // Matrix rows
    final matrixRows = StringBuffer();
    for (int r = 0; r < 5; r++) {
      matrixRows.write('<tr><td style="font-weight:600;">CO${r + 1}</td>');
      for (int c = 0; c < poColumnNames.length; c++) {
        final val = (r < report.matrix.length && c < report.matrix[r].length) ? report.matrix[r][c] : 0;
        final display = val > 0 ? '$val' : '-';
        final bg = val == 3 ? '#e0f2fe' : (val == 2 ? '#f0fdf4' : (val == 1 ? '#fefce8' : '#ffffff'));
        matrixRows.write('<td style="background-color:$bg;">$display</td>');
      }
      matrixRows.write('</tr>');
    }

    // Average Correlation row
    final avgCorrCells = StringBuffer();
    for (final po in report.poAttainments) {
      avgCorrCells.write('<td style="font-weight:700; background:#f1f5f9;">${po.averageCorrelation.toStringAsFixed(2)}</td>');
    }

    // PO Attainment cells
    final poAttCells = StringBuffer();
    for (final po in report.poAttainments) {
      final valStr = po.poAttainment != null ? po.poAttainment!.toStringAsFixed(2) : '-';
      poAttCells.write('<td style="font-weight:bold; background:#e2e8f0; color:#0f172a;">$valStr</td>');
    }

    final ise1Title = report.master.ise1Name.isNotEmpty ? report.master.ise1Name : 'Assignment 1';
    final ise1Co = report.master.ise1MappedCo.isNotEmpty ? report.master.ise1MappedCo : 'CO1';
    final ise2Title = report.master.ise2Name.isNotEmpty ? report.master.ise2Name : 'Unit Test 1';
    final ise2Co = report.master.ise2MappedCo.isNotEmpty ? report.master.ise2MappedCo : 'CO2';
    final faculty = report.master.facultyInCharge.isNotEmpty ? report.master.facultyInCharge : 'Course Faculty In-Charge';

    // Direct Attainment ISE Rows
    final iseRows = '''
      <tr>
        <td style="font-weight:600;">ISE 1 ($ise1Title)</td>
        <td>$ise1Co</td>
        <td>10.0</td>
        <td>${report.ise1Stats.attemptedPercentage}%</td>
        <td>${report.ise1Stats.scoring50Percentage}%</td>
        <td><span class="badge badge-blue">Level ${report.ise1Stats.attainmentLevel}</span></td>
      </tr>
      <tr>
        <td style="font-weight:600;">ISE 2 ($ise2Title)</td>
        <td>$ise2Co</td>
        <td>10.0</td>
        <td>${report.ise2Stats.attemptedPercentage}%</td>
        <td>${report.ise2Stats.scoring50Percentage}%</td>
        <td><span class="badge badge-blue">Level ${report.ise2Stats.attainmentLevel}</span></td>
      </tr>
    ''';

    // MSE Question rows
    final mseRows = StringBuffer();
    for (final q in report.mseQuestionStats) {
      mseRows.write('''
        <tr>
          <td>MSE ${q.questionId}</td>
          <td>${q.coTag}</td>
          <td>${q.maxMarks}</td>
          <td>${q.stats.attemptedPercentage}%</td>
          <td>${q.stats.scoring50Percentage}%</td>
          <td><span class="badge badge-blue">Level ${q.stats.attainmentLevel}</span></td>
        </tr>
      ''');
    }

    // ESE Question rows
    final eseRows = StringBuffer();
    for (final q in report.eseQuestionStats) {
      eseRows.write('''
        <tr>
          <td>ESE ${q.questionId}</td>
          <td>${q.coTag}</td>
          <td>${q.maxMarks}</td>
          <td>${q.stats.attemptedPercentage}%</td>
          <td>${q.stats.scoring50Percentage}%</td>
          <td><span class="badge badge-blue">Level ${q.stats.attainmentLevel}</span></td>
        </tr>
      ''');
    }

    // Final CO Attainment rows
    final finalCoRows = StringBuffer();
    for (final co in report.coAttainments) {
      final isAtt = co.finalAttainment >= config.targetBenchmark;
      final statusBadge = isAtt
          ? '<span class="badge badge-green">Attained</span>'
          : '<span class="badge badge-amber">Not Attained</span>';

      finalCoRows.write('''
        <tr>
          <td style="font-weight:700;">${co.coId}</td>
          <td>${co.ise1Level != null ? "L${co.ise1Level}" : "-"}</td>
          <td>${co.ise2Level != null ? "L${co.ise2Level}" : "-"}</td>
          <td>${co.mseLevel != null ? co.mseLevel!.toStringAsFixed(2) : "-"}</td>
          <td>${co.eseLevel != null ? co.eseLevel!.toStringAsFixed(2) : "-"}</td>
          <td style="font-weight:600; color:#0369a1;">${co.directAttainment.toStringAsFixed(2)}</td>
          <td style="font-weight:600; color:#475569;">${co.indirectAttainment.toStringAsFixed(2)}</td>
          <td style="font-weight:800; font-size:14px; color:#0f172a;">${co.finalAttainment.toStringAsFixed(2)}</td>
          <td>$target</td>
          <td>$statusBadge</td>
        </tr>
      ''');
    }

    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>CO-PO Attainment Report — ${course.code}</title>
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap');
    
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      color: #1e293b;
      background: #f8fafc;
      padding: 24px;
      font-size: 11px;
      line-height: 1.4;
    }

    .toolbar {
      position: sticky;
      top: 12px;
      background: #0f172a;
      color: white;
      padding: 12px 20px;
      border-radius: 10px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 24px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.15);
      z-index: 1000;
    }
    .toolbar h2 { font-size: 14px; font-weight: 600; }
    .toolbar-buttons { display: flex; gap: 10px; }
    .btn {
      background: #f97316;
      color: white;
      border: none;
      padding: 8px 16px;
      border-radius: 6px;
      font-weight: 600;
      font-size: 12px;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 6px;
    }
    .btn:hover { background: #ea580c; }
    .btn-secondary { background: #334155; }
    .btn-secondary:hover { background: #475569; }

    .page {
      background: white;
      max-width: 1080px;
      margin: 0 auto;
      padding: 36px 40px;
      border-radius: 8px;
      box-shadow: 0 1px 3px rgba(0,0,0,0.08);
      border: 1px solid #e2e8f0;
    }

    .header-table { width: 100%; border-collapse: collapse; margin-bottom: 16px; }
    .header-logo { width: 64px; text-align: center; vertical-align: middle; }
    .college-header { text-align: center; }
    .college-header h1 { font-size: 16px; font-weight: 800; color: #0f172a; text-transform: uppercase; letter-spacing: 0.5px; }
    .college-header h2 { font-size: 13px; font-weight: 700; color: #f97316; margin-top: 2px; }
    .college-header p { font-size: 10.5px; color: #64748b; margin-top: 2px; }

    .meta-box {
      background: #f1f5f9;
      border: 1px solid #cbd5e1;
      border-radius: 6px;
      padding: 10px 14px;
      margin-bottom: 18px;
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 8px 16px;
    }
    .meta-item { display: flex; flex-direction: column; }
    .meta-label { font-size: 9.5px; text-transform: uppercase; font-weight: 700; color: #64748b; letter-spacing: 0.3px; }
    .meta-value { font-size: 11.5px; font-weight: 600; color: #0f172a; margin-top: 1px; }

    .rules-callout {
      background: #eff6ff;
      border-left: 4px solid #0284c7;
      padding: 8px 12px;
      border-radius: 0 6px 6px 0;
      margin-bottom: 20px;
      font-size: 10.5px;
      color: #0369a1;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }

    h3.section-title {
      font-size: 12.5px;
      font-weight: 700;
      color: #0f172a;
      border-bottom: 2px solid #e2e8f0;
      padding-bottom: 4px;
      margin-top: 20px;
      margin-bottom: 10px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }

    table.data-table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 14px;
      font-size: 10.5px;
    }
    table.data-table th, table.data-table td {
      border: 1px solid #cbd5e1;
      padding: 6px 8px;
      text-align: center;
    }
    table.data-table th {
      background: #f8fafc;
      font-weight: 700;
      color: #334155;
    }
    table.data-table td.text-left { text-align: left; }

    .badge {
      display: inline-block;
      padding: 2px 6px;
      border-radius: 4px;
      font-weight: 700;
      font-size: 9.5px;
      text-transform: uppercase;
    }
    .badge-blue { background: #e0f2fe; color: #0369a1; }
    .badge-green { background: #dcfce7; color: #15803d; }
    .badge-amber { background: #fef3c7; color: #b45309; }

    .two-col { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }

    .sign-table {
      width: 100%;
      margin-top: 40px;
      border-collapse: collapse;
    }
    .sign-table td {
      width: 33.3%;
      text-align: center;
      padding-top: 40px;
      font-weight: 600;
      font-size: 11px;
      border-top: 1px dashed #cbd5e1;
    }

    @media print {
      body { background: white; padding: 0; font-size: 10px; }
      .toolbar { display: none !important; }
      .page { box-shadow: none; border: none; padding: 0; max-width: 100%; }
      @page { size: A4 landscape; margin: 10mm 12mm; }
      table.data-table th, table.data-table td { padding: 4px 6px; }
    }
  </style>
</head>
<body>

  <div class="toolbar">
    <div>
      <h2>KIT CO-PO Attainment Report: ${course.code} — ${course.name}</h2>
      <p style="font-size: 11px; color:#cbd5e1;">Review the formatted NBA audit report below and print or save directly as PDF.</p>
    </div>
    <div class="toolbar-buttons">
      <button class="btn" onclick="window.print()">🖨️ Print / Save as PDF</button>
      <button class="btn btn-secondary" onclick="window.close()">✕ Close</button>
    </div>
  </div>

  <div class="page">
    <table class="header-table">
      <tr>
        <td class="header-logo">
          <div style="font-size:32px; color:#f97316; font-weight:900;">KIT</div>
        </td>
        <td class="college-header">
          <h1>KIT's College of Engineering (Autonomous), Kolhapur</h1>
          <h2>Department of Computer Science & Engineering (Artificial Intelligence and Machine Learning)</h2>
          <p>Approved by AICTE New Delhi & Affiliated to Shivaji University, Kolhapur | Accredited by NBA</p>
        </td>
      </tr>
    </table>

    <div class="meta-box">
      <div class="meta-item">
        <span class="meta-label">Course Code & Name</span>
        <span class="meta-value">${course.code} · ${course.name}</span>
      </div>
      <div class="meta-item">
        <span class="meta-label">Academic Year & Term</span>
        <span class="meta-value">${report.master.academicYear} (${course.year}, ${course.semester})</span>
      </div>
      <div class="meta-item">
        <span class="meta-label">Total Student Strength</span>
        <span class="meta-value">${report.totalStrength} Enrolled Students</span>
      </div>
      <div class="meta-item">
        <span class="meta-label">Course Coordinator</span>
        <span class="meta-value">$faculty</span>
      </div>
      <div class="meta-item">
        <span class="meta-label">Target Attainment</span>
        <span class="meta-value" style="color:#f97316;">$target / 3.00 (Benchmark)</span>
      </div>
      <div class="meta-item">
        <span class="meta-label">Overall Course Attainment</span>
        <span class="meta-value" style="color:#0284c7; font-weight:800;">${report.overallCourseAttainment.toStringAsFixed(2)} / 3.00</span>
      </div>
    </div>

    <div class="rules-callout">
      <span><strong>Active NBA Attainment Rules:</strong> Passing Cutoff = <strong>$passingCutoff%</strong> of Max Marks | Direct Weight = <strong>$directPct%</strong> | Indirect Survey Weight = <strong>$indirectPct%</strong> | NBA Rubric Levels: L3 (≥${config.level3CutoffPercent.toInt()}%), L2 (${config.level2CutoffPercent.toInt()}-${config.level3CutoffPercent.toInt()}%), L1 (${config.level1CutoffPercent.toInt()}-${config.level2CutoffPercent.toInt()}%)</span>
      <span style="font-weight:700;">Formula: Final CO = ($directPct% × Direct) + ($indirectPct% × Indirect)</span>
    </div>

    <!-- 1. COURSE OUTCOMES & MASTER MATRIX -->
    <h3 class="section-title">
      <span>1. Course Outcomes (COs) & CO-PO/PSO Correlation Matrix</span>
      <span style="font-size:10px; color:#64748b; font-weight:normal;">1: Slight, 2: Moderate, 3: Substantial</span>
    </h3>
    
    <table class="data-table">
      <thead>
        <tr>
          <th>Course Outcome</th>
          ${poHeaders.toString()}
        </tr>
      </thead>
      <tbody>
        ${matrixRows.toString()}
        <tr>
          <td style="font-weight:800; background:#f8fafc;">Average Correlation</td>
          ${avgCorrCells.toString()}
        </tr>
      </tbody>
    </table>

    <!-- 2. DIRECT EXAM BREAKDOWN -->
    <h3 class="section-title">2. Direct Assessment: In-Sem (ISE) & Question-Wise (MSE/ESE) Attainments</h3>
    <table class="data-table">
      <thead>
        <tr>
          <th>Assessment Component</th>
          <th>Mapped CO</th>
          <th>Max Marks</th>
          <th>Attempted %</th>
          <th>% Scoring ≥ $passingCutoff%</th>
          <th>Attainment Level</th>
        </tr>
      </thead>
      <tbody>
        $iseRows
        ${mseRows.toString()}
        ${eseRows.toString()}
      </tbody>
    </table>

    <!-- 3. FINAL CO ATTAINMENT & GAP ANALYSIS -->
    <h3 class="section-title">3. Final Course Outcome (CO) Attainment & Target Gap Analysis</h3>
    <table class="data-table">
      <thead>
        <tr>
          <th>CO ID</th>
          <th>ISE 1</th>
          <th>ISE 2</th>
          <th>MSE Level</th>
          <th>ESE Level</th>
          <th>Direct Attainment ($directPct%)</th>
          <th>Indirect Survey ($indirectPct%)</th>
          <th>Final Attainment</th>
          <th>Target</th>
          <th>Status</th>
        </tr>
      </thead>
      <tbody>
        ${finalCoRows.toString()}
      </tbody>
    </table>

    <!-- 4. PO & PSO ATTAINMENT -->
    <h3 class="section-title">4. Program Outcome (PO & PSO) Weighted Attainment Matrix</h3>
    <table class="data-table">
      <thead>
        <tr>
          <th>Metric</th>
          ${poHeaders.toString()}
        </tr>
      </thead>
      <tbody>
        <tr>
          <td style="font-weight:600;">Average Correlation</td>
          ${avgCorrCells.toString()}
        </tr>
        <tr>
          <td style="font-weight:800; color:#0284c7;">Attainment Score</td>
          ${poAttCells.toString()}
        </tr>
      </tbody>
    </table>

    <!-- 5. SIGNATURES -->
    <table class="sign-table">
      <tr>
        <td>
          Course Coordinator<br>
          <strong>$faculty</strong>
        </td>
        <td>
          Module / Academic Coordinator<br>
          <strong>NBA DAC Committee</strong>
        </td>
        <td>
          Head of Department (HOD)<br>
          <strong>Dept. of CSE (AI & ML)</strong>
        </td>
      </tr>
    </table>
  </div>

  <script>
    // Auto trigger print after short delay
    setTimeout(() => {
      window.print();
    }, 500);
  </script>
</body>
</html>''';
  }
}
