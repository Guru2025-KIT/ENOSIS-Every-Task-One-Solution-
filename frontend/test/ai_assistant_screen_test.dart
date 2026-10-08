import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enosis/features/ai_assistant/presentation/screens/ai_assistant_screen.dart';

void main() {
  group('AI Assistant Screen UI & Voice Tests', () {
    testWidgets('Renders title, suggestions, mic button, and input field', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: AiAssistantScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check header
      expect(find.text('ENOSIS Assistant'), findsOneWidget);

      // Check initial message
      expect(find.textContaining('Hello! I am your ENOSIS Assistant'), findsOneWidget);

      // Check suggestion chips
      expect(find.text("Show me Rajesh Kumar's certificates"), findsOneWidget);
      expect(find.text("What certificates does Rajesh Kumar have?"), findsOneWidget);
      expect(find.text("Does Rajesh Kumar have a Python certificate?"), findsOneWidget);

      // Check microphone button and send button
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(find.byIcon(Icons.send), findsOneWidget);

      // Check input text field
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Tapping microphone button handles voice interaction gracefully', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: AiAssistantScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap microphone
      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pump();

      // In unit test environment without real microphone hardware,
      // it handles permission/availability gracefully without throwing unhandled exceptions.
      expect(find.byType(AiAssistantScreen), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
