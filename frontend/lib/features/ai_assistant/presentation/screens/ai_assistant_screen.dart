import 'package:flutter/material.dart';
import '../../../../core/widgets/empty_state.dart';

/// Placeholder for the Conversational AI Assistant (Phase 17 onward).
/// This will eventually be an agentic assistant with tool-calling into
/// every other module (To-Do, Career, Attendance, Gmail, etc.) — not
/// implemented yet, on purpose. We build the mock-response chat UI first,
/// then wire real AI/backend calls much later.
class AiAssistantScreen extends StatelessWidget {
  const AiAssistantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ENOSIS Assistant')),
      body: const EmptyState(
        icon: Icons.smart_toy_outlined,
        title: 'AI Assistant coming soon',
        message: 'A mock-response chat UI arrives in Phase 17, before any real AI wiring.',
      ),
    );
  }
}
