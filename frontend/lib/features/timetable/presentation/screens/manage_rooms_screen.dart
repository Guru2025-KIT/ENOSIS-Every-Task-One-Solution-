import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/room.dart';
import '../../providers/timetable_provider.dart';

class ManageRoomsScreen extends StatefulWidget {
  const ManageRoomsScreen({super.key});

  @override
  State<ManageRoomsScreen> createState() => _ManageRoomsScreenState();
}

class _ManageRoomsScreenState extends State<ManageRoomsScreen> {
  final _nameController = TextEditingController();
  final _capacityController = TextEditingController();
  String _selectedType = 'Theory';

  void _addRoom() {
    if (_nameController.text.isEmpty || _capacityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Room Name and Capacity.')),
      );
      return;
    }

    context.read<TimetableProvider>().addRoom(Room(
      name: _nameController.text,
      type: _selectedType,
      capacity: int.tryParse(_capacityController.text) ?? 0,
    ));

    setState(() {
      _nameController.clear();
      _capacityController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final rooms = context.watch<TimetableProvider>().rooms;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Classrooms & Labs'),
        backgroundColor: AppColors.primary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add New Room', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Room / Lab Name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedType,
                            decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                            items: ['Theory', 'Lab'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (val) => setState(() => _selectedType = val!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _capacityController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Capacity', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // ✅ Manual Add Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Room Manually'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                        onPressed: _addRoom,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // ✅ Excel Upload Button (UI Only for now)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload Rooms from Excel'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        side: const BorderSide(color: AppColors.primary),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Excel upload feature will be connected in Phase 2!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: rooms.isEmpty
                ? const Center(child: Text('No rooms added yet.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: rooms.length,
                    itemBuilder: (context, index) {
                      final r = rooms[index];
                      return ListTile(
                        leading: Icon(r.type == 'Lab' ? Icons.science_outlined : Icons.meeting_room_outlined, color: AppColors.primary),
                        title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${r.type} • Capacity: ${r.capacity}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => context.read<TimetableProvider>().removeRoom(r.name),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}