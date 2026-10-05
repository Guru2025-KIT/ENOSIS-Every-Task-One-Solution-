import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel_pkg;
import '../../data/timetable_repository.dart';
import '../../models/room.dart';
import '../../providers/timetable_provider.dart';

class ManageRoomsScreen extends StatefulWidget {
  const ManageRoomsScreen({super.key});

  @override
  State<ManageRoomsScreen> createState() => _ManageRoomsScreenState();
}

class _ManageRoomsScreenState extends State<ManageRoomsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _repository = TimetableRepository();
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    // ✅ Changed length to 3 to accommodate the new Division Structure tab
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TimetableProvider>().loadRooms();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddEditRoomDialog([RoomModel? existingRoom]) {
    final nameCtrl = TextEditingController(text: existingRoom?.name ?? '');
    final capCtrl = TextEditingController(text: (existingRoom?.capacity ?? 60).toString());
    final bldgCtrl = TextEditingController(text: existingRoom?.building ?? '');
    final deptCtrl = TextEditingController(text: existingRoom?.department ?? '');
    final equipCtrl = TextEditingController(text: existingRoom?.equipment ?? '');

    String selectedType = existingRoom?.type ?? (_tabController.index == 1 ? 'Lab' : 'Classroom');
    bool isActive = existingRoom?.isActive ?? true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF334155)),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      existingRoom == null ? Icons.add_business : Icons.edit_location_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    existingRoom == null ? 'Add New Room / Lab' : 'Edit Room / Lab',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460, minWidth: 300),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          labelText: 'Room Name / Identifier (e.g. CR-101, LAB-2)',
                          labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                          floatingLabelStyle: const TextStyle(color: Color(0xFFFB923C), fontSize: 13, fontWeight: FontWeight.bold),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFF97316), width: 1.5),
                          ),
                          prefixIcon: const Icon(Icons.meeting_room, color: Color(0xFFF97316), size: 20),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedType.toLowerCase() == 'lab' ? 'Lab' : 'Classroom',
                        dropdownColor: const Color(0xFF1E293B),
                        style: const TextStyle(color: Colors.white, fontSize: 13.5),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          labelText: 'Resource Type',
                          labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                          floatingLabelStyle: const TextStyle(color: Color(0xFFFB923C), fontSize: 13, fontWeight: FontWeight.bold),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFF97316), width: 1.5),
                          ),
                          prefixIcon: const Icon(Icons.category, color: Color(0xFFF97316), size: 20),
                        ),
                        items: ['Classroom', 'Lab'].map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(color: Colors.white)))).toList(),
                        onChanged: (val) => setDialogState(() => selectedType = val!),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: capCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          labelText: 'Seating Capacity',
                          labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                          floatingLabelStyle: const TextStyle(color: Color(0xFFFB923C), fontSize: 13, fontWeight: FontWeight.bold),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFF97316), width: 1.5),
                          ),
                          prefixIcon: const Icon(Icons.people_outline, color: Color(0xFFF97316), size: 20),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: bldgCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          labelText: 'Building / Block (Optional)',
                          labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                          floatingLabelStyle: const TextStyle(color: Color(0xFFFB923C), fontSize: 13, fontWeight: FontWeight.bold),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFF97316), width: 1.5),
                          ),
                          prefixIcon: const Icon(Icons.business, color: Color(0xFFF97316), size: 20),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: deptCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          labelText: 'Department (Optional)',
                          labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                          floatingLabelStyle: const TextStyle(color: Color(0xFFFB923C), fontSize: 13, fontWeight: FontWeight.bold),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFF97316), width: 1.5),
                          ),
                          prefixIcon: const Icon(Icons.school_outlined, color: Color(0xFFF97316), size: 20),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: equipCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          labelText: 'Equipment / Specs (e.g. Projector, GPUs, LAN)',
                          labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                          floatingLabelStyle: const TextStyle(color: Color(0xFFFB923C), fontSize: 13, fontWeight: FontWeight.bold),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFF97316), width: 1.5),
                          ),
                          prefixIcon: const Icon(Icons.devices, color: Color(0xFFF97316), size: 20),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active for Scheduling', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                        value: isActive,
                        activeThumbColor: const Color(0xFFF97316),
                        onChanged: (val) => setDialogState(() => isActive = val),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final cap = int.tryParse(capCtrl.text) ?? 60;
                    
                    final provider = context.read<TimetableProvider>();
                    if (existingRoom?.id != null) {
                      await provider.updateRoom(
                        existingRoom!.id!,
                        Room(name: nameCtrl.text.trim(), type: selectedType, capacity: cap),
                        building: bldgCtrl.text.trim(),
                        department: deptCtrl.text.trim(),
                        equipment: equipCtrl.text.trim(),
                        isActive: isActive,
                      );
                    } else {
                      await provider.addRoom(
                        Room(name: nameCtrl.text.trim(), type: selectedType, capacity: cap),
                        building: bldgCtrl.text.trim(),
                        department: deptCtrl.text.trim(),
                        equipment: equipCtrl.text.trim(),
                        isActive: isActive,
                      );
                    }

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${nameCtrl.text.trim()} saved successfully!'),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    }
                  },
                  child: const Text('Save Room', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _downloadExcelTemplate() async {
    try {
      final bytes = await _repository.downloadRoomExcelTemplate();
      if (kIsWeb) {
        final blob = html.Blob([Uint8List.fromList(bytes)], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)..setAttribute('download', 'room_import_template.xlsx');
        html.document.body?.append(anchor);
        anchor.click();
        anchor.remove();
        html.Url.revokeObjectUrl(url);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Room Excel template downloaded! Check your Downloads folder.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Template download: $e'), backgroundColor: const Color(0xFFF97316)),
        );
      }
    }
  }

  Future<void> _pickAndImportExcel() async {
    try {
      setState(() => _isImporting = true);
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (file == null) {
        setState(() => _isImporting = false);
        return;
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        setState(() => _isImporting = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to read selected Excel file.'), backgroundColor: Color(0xFFF97316)),
          );
        }
        return;
      }

      int processed = 0;
      int classroomsCount = 0;
      int labsCount = 0;
      final List<RoomModel> parsedRooms = [];

      try {
        final excel = excel_pkg.Excel.decodeBytes(bytes);
        for (final table in excel.tables.keys) {
          final sheet = excel.tables[table];
          if (sheet == null) continue;

          bool isHeader = true;
          int nameCol = 0;
          int typeCol = 1;
          int capCol = 2;
          int bldgCol = 3;
          int equipCol = 4;

          for (int rowIdx = 0; rowIdx < sheet.rows.length; rowIdx++) {
            final row = sheet.rows[rowIdx];
            if (row.isEmpty) continue;

            final firstCell = row[0]?.value?.toString().trim().toLowerCase() ?? '';
            if (firstCell.isEmpty && row.every((c) => c?.value == null)) continue;

            if (isHeader) {
              if (firstCell.contains('room') || firstCell.contains('name') || firstCell.contains('classroom') ||
                  row.any((c) => c?.value?.toString().toLowerCase().contains('capacity') == true)) {
                for (int c = 0; c < row.length; c++) {
                  final headerVal = row[c]?.value?.toString().trim().toLowerCase() ?? '';
                  if (headerVal.contains('room') || headerVal.contains('name')) nameCol = c;
                  if (headerVal.contains('type') || headerVal.contains('category')) typeCol = c;
                  if (headerVal.contains('cap') || headerVal.contains('size') || headerVal.contains('seat')) capCol = c;
                  if (headerVal.contains('bldg') || headerVal.contains('build') || headerVal.contains('block') || headerVal.contains('dept')) bldgCol = c;
                  if (headerVal.contains('equip') || headerVal.contains('spec') || headerVal.contains('facil')) equipCol = c;
                }
                isHeader = false;
                continue;
              }
              isHeader = false;
            }

            final rawName = (nameCol < row.length ? row[nameCol]?.value?.toString() : null)?.trim() ?? '';
            if (rawName.isEmpty) continue;

            processed++;
            final rawType = (typeCol < row.length ? row[typeCol]?.value?.toString() : null)?.trim() ?? '';
            final rawCap = (capCol < row.length ? row[capCol]?.value?.toString() : null)?.trim() ?? '';
            final rawBldg = (bldgCol < row.length ? row[bldgCol]?.value?.toString() : null)?.trim();
            final rawEquip = (equipCol < row.length ? row[equipCol]?.value?.toString() : null)?.trim();

            int cap = 60;
            if (rawCap.isNotEmpty) {
              cap = int.tryParse(RegExp(r'\d+').firstMatch(rawCap)?.group(0) ?? '') ?? 60;
            }

            String roomType = 'Classroom';
            final tLower = rawType.toLowerCase();
            final nLower = rawName.toLowerCase();
            if (tLower.contains('lab') || tLower.contains('practical') || nLower.contains('lab')) {
              roomType = 'Lab';
              labsCount++;
            } else {
              roomType = 'Classroom';
              classroomsCount++;
            }

            parsedRooms.add(RoomModel(
              id: 'room_${DateTime.now().millisecondsSinceEpoch}_$processed',
              name: rawName,
              type: roomType,
              capacity: cap,
              building: rawBldg,
              equipment: rawEquip,
              isActive: true,
            ));
          }
        }
      } catch (excelError) {
        debugPrint('Client excel decode error: $excelError');
      }

      if (parsedRooms.isNotEmpty) {
        await context.read<TimetableProvider>().bulkAddRooms(parsedRooms);
      }

      try {
        await _repository.importRoomsExcel(bytes, file.name);
      } catch (_) {}

      setState(() => _isImporting = false);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF334155)),
            ),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF10B981)),
                SizedBox(width: 8),
                Text('Rooms Import Successful', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFFB923C))),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Processed: $processed infrastructure entries', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('• Classrooms / Lecture Halls:', style: TextStyle(color: Color(0xFFCBD5E1))),
                          Text('$classroomsCount', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFB923C))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('• Computer & Science Labs:', style: TextStyle(color: Color(0xFFCBD5E1))),
                          Text('$labsCount', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFB923C))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'All resources have been successfully stored and are active for timetable generation!',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _isImporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import status: $e'), backgroundColor: const Color(0xFFF97316)),
        );
      }
    }
  }

  Widget _buildRoomList(List<RoomModel> rooms, String typeFilter) {
    final filtered = rooms.where((r) {
      final t = r.type.toLowerCase();
      if (typeFilter == 'Classroom') {
        return t == 'classroom' || t == 'lecture' || t == 'theory';
      } else {
        return t == 'lab' || t == 'practical';
      }
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Icon(
                typeFilter == 'Classroom' ? Icons.meeting_room_outlined : Icons.science_outlined,
                size: 48,
                color: const Color(0xFFF97316),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No $typeFilter resources registered yet.',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap "+ Add Room" or "Import Excel" above to register infrastructure.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final r = filtered[index];
        final isLab = r.type.toLowerCase() == 'lab';

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF334155)),
          ),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isLab
                          ? [const Color(0xFFEA580C), const Color(0xFFC2410C)]
                          : [const Color(0xFFF97316), const Color(0xFFEA580C)], 
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isLab ? Icons.science : Icons.meeting_room,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            r.name,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFF97316),
                              ),
                            ),
                            child: Text(
                              'Cap: ${r.capacity}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFB923C),
                              ),
                            ),
                          ),
                          if (r.building != null && r.building!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              '• ${r.building}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFFFB923C)),
                            ),
                          ],
                        ],
                      ),
                      if (r.equipment != null && r.equipment!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Specs: ${r.equipment}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFFFED7AA)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 19, color: Color(0xFFFB923C)),
                  tooltip: 'Edit Room',
                  onPressed: () => _showAddEditRoomDialog(r),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 19, color: Color(0xFFF87171)),
                  tooltip: 'Delete Room',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFF334155)),
                        ),
                        title: const Text('Delete Resource', style: TextStyle(color: Color(0xFFFB923C), fontWeight: FontWeight.bold)),
                        content: Text('Are you sure you want to remove ${r.name}?', style: const TextStyle(color: Color(0xFFCBD5E1))),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8)))),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && mounted) {
                      await context.read<TimetableProvider>().removeRoom(r.name);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${r.name} deleted.'), backgroundColor: const Color(0xFFF97316)),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDivisionStructureTab() {
    final provider = context.watch<TimetableProvider>();
    final structure = provider.divisionStructure;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 2,
          color: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF334155))),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.groups_2_outlined, color: Color(0xFFF97316)),
                    const SizedBox(width: 8),
                    Text('Division & Lab Batch Structure', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Define how many lab batches each division has. You can also alias them (e.g., "Batch 1" = "A1, A2"). The solver will use this to split lab hours.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 24),
                ...structure.entries.map((entry) {
                  final year = entry.key;
                  final divisions = entry.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(year, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFF97316))),
                      ),
                      ...divisions.map((divInfo) {
                        final divName = divInfo['division'] as String;
                        final batches = divInfo['batches'] as int;
                        List<dynamic> aliases = divInfo['aliases'] as List<dynamic>;
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 80,
                                child: Text('Div $divName:', style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white, height: 2.5)),
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                DropdownButton<int>(
                                  dropdownColor: const Color(0xFF1E293B),
                                  value: batches,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  items: [1, 2, 3, 4].map((b) {
                                    return DropdownMenuItem(value: b, child: Text('$b Batch${b > 1 ? "es" : ""}'));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      provider.updateDivisionBatches(year, divName, val);
                                    }
                                  },
                                ),
                                const SizedBox(height: 8),
                                // Alias Text Fields
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 8,
                                  children: List.generate(batches, (i) {
                                    return SizedBox(
                                      width: 100,
                                      child: TextField(
                                        style: const TextStyle(color: Colors.white, fontSize: 12),
                                        decoration: InputDecoration(
                                          labelText: 'Batch ${i+1}',
                                          labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF334155))),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF334155))),
                                        ),
                                        controller: TextEditingController(text: aliases.length > i ? aliases[i] : ''),
                                        onChanged: (val) => provider.updateBatchAlias(year, divName, i, val),
                                      ),
                                    );
                                  }),
                                )
                              ],
                                ),
                              )
                            ],
                          ),
                        );
                      }).toList(),
                      const Divider(color: Color(0xFF334155), height: 32),
                    ],
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimetableProvider>();
    final rooms = provider.roomModels;

    final classRooms = rooms.where((r) => r.type.toLowerCase() != 'lab').toList();
    final labs = rooms.where((r) => r.type.toLowerCase() == 'lab').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Text(
          'Classrooms & Laboratories',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: Color(0xFFFB923C)),
            tooltip: 'Download Excel Template',
            onPressed: _downloadExcelTemplate,
          ),
          IconButton(
            icon: _isImporting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.file_upload_outlined, color: Color(0xFFFB923C)),
            tooltip: 'Import Rooms from Excel',
            onPressed: _isImporting ? null : _pickAndImportExcel,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFF97316),
          indicatorWeight: 3.5,
          labelColor: const Color(0xFFFB923C),
          unselectedLabelColor: const Color(0xFF94A3B8),
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          tabs: [
            Tab(
              icon: const Icon(Icons.meeting_room, size: 20),
              text: 'Classrooms (${classRooms.length})',
            ),
            Tab(
              icon: const Icon(Icons.science, size: 20),
              text: 'Laboratories (${labs.length})',
            ),
            // ✅ NEW TAB ADDED HERE
            const Tab(
              icon: Icon(Icons.groups_2_outlined, size: 20),
              text: 'Divisions & Batches',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── STEP 3 GUIDANCE BANNER (DARK CARD WITH ORANGE HIGHLIGHTS) ────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFEA580C), Color(0xFFF97316)]),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Step 3',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Register available lecture halls, lab rooms, and division structures. The solver allocates them based on capacity and course type.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFCBD5E1),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: const Text('Import Excel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _pickAndImportExcel,
                ),
              ],
            ),
          ),

          // ── TAB VIEWS ───────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRoomList(rooms, 'Classroom'),
                _buildRoomList(rooms, 'Lab'),
                _buildDivisionStructureTab(), // ✅ ADDED HERE
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFF97316),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Room / Lab', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showAddEditRoomDialog(),
      ),
    );
  }
}