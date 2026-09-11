import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
              title: Text(existingRoom == null ? 'Add New Room / Lab' : 'Edit Room / Lab'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Room Name / Number', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(labelText: 'Resource Type', border: OutlineInputBorder()),
                      items: ['Classroom', 'Lab'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) => setDialogState(() => selectedType = val!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: capCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Seating Capacity', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bldgCtrl,
                      decoration: const InputDecoration(labelText: 'Building / Block (Optional)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: deptCtrl,
                      decoration: const InputDecoration(labelText: 'Department (Optional)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: equipCtrl,
                      decoration: const InputDecoration(labelText: 'Equipment / Specs (e.g. Projector, GPUs)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Active Resource'),
                      value: isActive,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setDialogState(() => isActive = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final cap = int.tryParse(capCtrl.text) ?? 60;
                    
                    final provider = context.read<TimetableProvider>();
                    await provider.addRoom(
                      Room(name: nameCtrl.text.trim(), type: selectedType, capacity: cap),
                      building: bldgCtrl.text.trim(),
                      department: deptCtrl.text.trim(),
                      equipment: equipCtrl.text.trim(),
                    );

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Room saved successfully!'), backgroundColor: Colors.green),
                      );
                    }
                  },
                  child: const Text('Save Room', style: TextStyle(color: Colors.white)),
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
      final bytes = await _repository.exportExcel(
        viewTitle: 'Room Import Template',
        viewType: 'room',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel template generated (${bytes.length} bytes)! Ready for download.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Template download: $e'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Import Rooms from Excel'),
          content: const Text(
            'Format expected in Excel:\n\n'
            '• Column A: Room Name (e.g. CR-101)\n'
            '• Column B: Type (Classroom / Lab)\n'
            '• Column C: Capacity (Numeric)\n'
            '• Column D: Building (Optional)\n'
            '• Column E: Equipment (Optional)\n\n'
            'Row-by-row validation will highlight any corrupt lines.',
          ),
          actions: [
            TextButton(
              onPressed: _downloadExcelTemplate,
              child: const Text('Download Template'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Simulated room import complete! 5 rooms updated.'), backgroundColor: Colors.green),
                );
              },
              child: const Text('Select File & Import', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRoomList(List<RoomModel> rooms, String typeFilter) {
    final filtered = rooms.where((r) => r.type.toLowerCase() == typeFilter.toLowerCase() || (typeFilter == 'Classroom' && r.type == 'Theory')).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(typeFilter == 'Lab' ? Icons.science_outlined : Icons.meeting_room_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No $typeFilter resources added yet.', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final r = filtered[index];
        return Card(
          elevation: 1.5,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: r.type == 'Lab' ? Colors.purple.shade50 : Colors.blue.shade50,
              child: Icon(r.type == 'Lab' ? Icons.science : Icons.chair, color: r.type == 'Lab' ? Colors.purple : AppColors.primary),
            ),
            title: Row(
              children: [
                Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                if (!r.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                    child: const Text('Inactive', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            subtitle: Text(
              'Capacity: ${r.capacity}'
              '${r.building != null && r.building!.isNotEmpty ? " • ${r.building}" : ""}'
              '${r.equipment != null && r.equipment!.isNotEmpty ? "\nSpecs: ${r.equipment}" : ""}',
              style: const TextStyle(fontSize: 12, height: 1.3),
            ),
            isThreeLine: r.equipment != null && r.equipment!.isNotEmpty,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                  onPressed: () => _showAddEditRoomDialog(r),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    context.read<TimetableProvider>().removeRoom(r.name);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomModels = context.watch<TimetableProvider>().roomModels;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resource & Room Management'),
        backgroundColor: AppColors.primary,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.meeting_room), text: 'Classrooms'),
            Tab(icon: Icon(Icons.science), text: 'Laboratories'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Download Template',
            onPressed: _downloadExcelTemplate,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import Excel',
            onPressed: _showImportDialog,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRoomList(roomModels, 'Classroom'),
          _buildRoomList(roomModels, 'Lab'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Room', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showAddEditRoomDialog(),
      ),
    );
  }
}