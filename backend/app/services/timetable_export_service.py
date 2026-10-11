"""
Timetable Export Service — Generates official PDF and Excel documents for Timetables.
Supports exporting by Division/Class, Faculty, and Room/Lab.
"""

import io
from typing import Dict, List, Any
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
try:
    from reportlab.lib.pagesizes import letter, landscape
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib import colors
    REPORTLAB_AVAILABLE = True
except ImportError:
    REPORTLAB_AVAILABLE = False



def generate_timetable_excel(
    college_name: str,
    department_name: str,
    academic_year: str,
    semester: str,
    view_title: str,
    days: List[str],
    time_slots: List[Dict[str, Any]],
    grid_data: Dict[str, List[str]], # key: f"{day}_{slot}", val: [subject, faculty, room/batch]
    multi_grid_data: Dict[str, Dict[str, List[str]]] | None = None
) -> bytes:
    """
    Generates a professionally styled Excel spreadsheet (.xlsx) for a single or all timetable views.
    """
    wb = openpyxl.Workbook()
    # Remove default sheet
    default_sheet = wb.active

    # Determine sheets to build
    sheets_to_build: Dict[str, Dict[str, List[str]]] = {}
    if multi_grid_data and len(multi_grid_data) > 0:
        sheets_to_build = multi_grid_data
    else:
        sheets_to_build = {view_title or "Timetable": grid_data}

    header_fill = PatternFill(start_color="1E3A8A", end_color="1E3A8A", fill_type="solid")
    header_font = Font(name="Arial", size=11, bold=True, color="FFFFFF")
    thin_border = Border(
        left=Side(style='thin', color='CBD5E1'),
        right=Side(style='thin', color='CBD5E1'),
        top=Side(style='thin', color='CBD5E1'),
        bottom=Side(style='thin', color='CBD5E1')
    )
    break_fill = PatternFill(start_color="F1F5F9", end_color="F1F5F9", fill_type="solid")
    lecture_fill = PatternFill(start_color="EFF6FF", end_color="EFF6FF", fill_type="solid")
    lab_fill = PatternFill(start_color="F3E8FF", end_color="F3E8FF", fill_type="solid")

    for title, class_grid in sheets_to_build.items():
        # Excel sheet name cannot exceed 31 chars and cannot contain: \ / ? * : [ ]
        safe_sheet_name = "".join(c for c in title if c not in r"\/?*:[]")[:30] or "Schedule"
        ws = wb.create_sheet(title=safe_sheet_name)

        # Title Block
        num_cols = len(days) + 1
        last_col_letter = openpyxl.utils.get_column_letter(num_cols)
        
        ws.merge_cells(f"A1:{last_col_letter}1")
        ws["A1"] = college_name or "ENOSIS Engineering Institute"
        ws["A1"].font = Font(name="Arial", size=15, bold=True, color="1E293B")
        ws["A1"].alignment = Alignment(horizontal="center", vertical="center")

        ws.merge_cells(f"A2:{last_col_letter}2")
        ws["A2"] = f"Department of {department_name or 'Computer Science'} | {academic_year or '2026-2027'} ({semester or 'Odd'} Semester)"
        ws["A2"].font = Font(name="Arial", size=11, italic=True, color="475569")
        ws["A2"].alignment = Alignment(horizontal="center", vertical="center")

        ws.merge_cells(f"A3:{last_col_letter}3")
        ws["A3"] = f"Class / Timetable View: {title}"
        ws["A3"].font = Font(name="Arial", size=12, bold=True, color="2563EB")
        ws["A3"].alignment = Alignment(horizontal="center", vertical="center")

        ws.append([]) # Empty row 4

        # Header Row (Row 5)
        headers = ["Time / Slot"] + [d[:3].upper() for d in days]
        ws.append(headers)

        for col_num in range(1, len(headers) + 1):
            cell = ws.cell(row=5, column=col_num)
            cell.fill = header_fill
            cell.font = header_font
            cell.alignment = Alignment(horizontal="center", vertical="center")
            cell.border = thin_border

        # Data Rows
        for slot in time_slots:
            slot_num = slot.get("slot_number", 1)
            start_t = slot.get("start_time", "")
            end_t = slot.get("end_time", "")
            time_label = f"Slot {slot_num}\n({start_t} - {end_t})" if start_t else f"Slot {slot_num}"
            
            row = [time_label]
            is_break_slot = slot.get("is_break", False)

            for day in days:
                key = f"{day}_{slot_num}"
                cell_info = class_grid.get(key, ["Free", "", ""])
                subj = cell_info[0] if len(cell_info) > 0 else "Free"
                fac = cell_info[1] if len(cell_info) > 1 else ""
                extra = cell_info[2] if len(cell_info) > 2 else ""

                if is_break_slot or subj == "Break":
                    row.append("BREAK")
                elif subj in ("Free", "-", ""):
                    row.append("-")
                else:
                    text = f"{subj}\n{fac}"
                    if extra:
                        text += f"\n[{extra}]"
                    row.append(text)

            ws.append(row)
            current_row = ws.max_row
            ws.row_dimensions[current_row].height = 45

            # Format cells
            for col_num in range(1, len(headers) + 1):
                cell = ws.cell(row=current_row, column=col_num)
                cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
                cell.border = thin_border
                cell.font = Font(name="Arial", size=9)

                if col_num == 1:
                    cell.font = Font(name="Arial", size=9, bold=True)
                    cell.fill = PatternFill(start_color="F8FAFC", end_color="F8FAFC", fill_type="solid")
                else:
                    val = str(cell.value)
                    if val == "BREAK":
                        cell.fill = break_fill
                        cell.font = Font(name="Arial", size=9, italic=True, color="64748B")
                    elif "LAB" in val.upper() or "Batch" in val:
                        cell.fill = lab_fill
                    elif val != "-":
                        cell.fill = lecture_fill

        # Set Column Widths
        ws.column_dimensions['A'].width = 18
        for col_idx in range(2, len(headers) + 1):
            col_letter = openpyxl.utils.get_column_letter(col_idx)
            ws.column_dimensions[col_letter].width = 22

    # Remove initial empty default sheet
    if default_sheet in wb.worksheets and len(wb.worksheets) > 1:
        wb.remove(default_sheet)

    output = io.BytesIO()
    wb.save(output)
    return output.getvalue()


def generate_timetable_pdf(
    college_name: str,
    department_name: str,
    academic_year: str,
    semester: str,
    view_title: str,
    days: List[str],
    time_slots: List[Dict[str, Any]],
    grid_data: Dict[str, List[str]],
    multi_grid_data: Dict[str, Dict[str, List[str]]] | None = None
) -> bytes:
    """
    Generates a clean, multi-page PDF document for single or all timetable views using ReportLab.
    """
    if not REPORTLAB_AVAILABLE:
        # Fallback minimal valid PDF generation when reportlab is not in environment
        title_text = f"{college_name} - {department_name} ({view_title})"
        pdf_lines = [
            "%PDF-1.4",
            "1 0 obj <</Type /Catalog /Pages 2 0 R>> endobj",
            "2 0 obj <</Type /Pages /Kids [3 0 R] /Count 1>> endobj",
            "3 0 obj <</Type /Page /Parent 2 0 R /MediaBox [0 0 792 612] /Contents 4 0 R /Resources <</Font <</F1 5 0 R>>>>>> endobj",
            "4 0 obj <</Length 200>> stream",
            f"BT /F1 14 Tf 50 550 Td ({title_text}) Tj ET",
            "endstream endobj",
            "5 0 obj <</Type /Font /Subtype /Type1 /BaseFont /Helvetica>> endobj",
            "xref",
            "0 6",
            "0000000000 65535 f ",
            "0000000010 00000 n ",
            "0000000060 00000 n ",
            "0000000117 00000 n ",
            "0000000234 00000 n ",
            "0000000300 00000 n ",
            "trailer <</Size 6 /Root 1 0 R>>",
            "startxref",
            "370",
            "%%EOF"
        ]
        return "\n".join(pdf_lines).encode("latin-1")

    from reportlab.platypus import PageBreak

    buffer = io.BytesIO()

    doc = SimpleDocTemplate(
        buffer,
        pagesize=landscape(letter),
        rightMargin=20,
        leftMargin=20,
        topMargin=20,
        bottomMargin=20
    )

    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Heading1'],
        fontSize=15,
        leading=18,
        alignment=1, # Center
        textColor=colors.HexColor('#1E293B')
    )
    subtitle_style = ParagraphStyle(
        'DocSubTitle',
        parent=styles['Normal'],
        fontSize=10,
        leading=13,
        alignment=1,
        textColor=colors.HexColor('#475569')
    )
    view_style = ParagraphStyle(
        'ViewTitle',
        parent=styles['Heading2'],
        fontSize=12,
        leading=15,
        alignment=1,
        textColor=colors.HexColor('#2563EB')
    )

    cell_title_style = ParagraphStyle(
        'CellTitle',
        parent=styles['Normal'],
        fontSize=8,
        leading=10,
        alignment=1,
        fontName='Helvetica-Bold'
    )
    cell_sub_style = ParagraphStyle(
        'CellSub',
        parent=styles['Normal'],
        fontSize=7,
        leading=8,
        alignment=1,
        textColor=colors.HexColor('#334155')
    )

    sheets_to_build: Dict[str, Dict[str, List[str]]] = {}
    if multi_grid_data and len(multi_grid_data) > 0:
        sheets_to_build = multi_grid_data
    else:
        sheets_to_build = {view_title or "Timetable": grid_data}

    elements = []
    first_page = True

    for title, class_grid in sheets_to_build.items():
        if not first_page:
            elements.append(PageBreak())
        first_page = False

        elements.extend([
            Paragraph(college_name or "ENOSIS Engineering Institute", title_style),
            Paragraph(f"Department of {department_name or 'Computer Science'} | {academic_year or '2026-2027'} ({semester or 'Odd'})", subtitle_style),
            Paragraph(f"Timetable View: {title}", view_style),
            Spacer(1, 8)
        ])

        # Build Table
        table_data = []
        header_row = ["Time / Slot"] + [d[:3].upper() for d in days]
        table_data.append(header_row)

        for slot in time_slots:
            slot_num = slot.get("slot_number", 1)
            start_t = slot.get("start_time", "")
            end_t = slot.get("end_time", "")
            time_text = f"Slot {slot_num}<br/>{start_t} - {end_t}" if start_t else f"Slot {slot_num}"
            
            row = [Paragraph(time_text, cell_title_style)]
            is_break_slot = slot.get("is_break", False)

            for day in days:
                key = f"{day}_{slot_num}"
                cell_info = class_grid.get(key, ["Free", "", ""])
                subj = cell_info[0] if len(cell_info) > 0 else "Free"
                fac = cell_info[1] if len(cell_info) > 1 else ""
                extra = cell_info[2] if len(cell_info) > 2 else ""

                if is_break_slot or subj == "Break":
                    row.append(Paragraph("<b>BREAK</b>", cell_sub_style))
                elif subj in ("Free", "-", ""):
                    row.append(Paragraph("-", cell_sub_style))
                else:
                    html = f"<b>{subj}</b>"
                    if fac:
                        html += f"<br/>{fac}"
                    if extra:
                        html += f"<br/>[{extra}]"
                    row.append(Paragraph(html, cell_sub_style))

            table_data.append(row)

        col_widths = [80] + [110] * len(days)
        t = Table(table_data, colWidths=col_widths, repeatRows=1)
        
        t_style = [
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#1E3A8A')),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#CBD5E1')),
            ('BACKGROUND', (0, 1), (0, -1), colors.HexColor('#F8FAFC')),
        ]
        t.setStyle(TableStyle(t_style))
        elements.append(t)

    doc.build(elements)
    return buffer.getvalue()
