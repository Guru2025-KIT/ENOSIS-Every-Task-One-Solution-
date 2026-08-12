import 'package:flutter_test/flutter_test.dart';
import 'package:enosis/app/app.dart';

void main() {
  testWidgets('EnosisApp initialization and splash screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const EnosisApp());

    // Verify that EnosisApp starts and shows the splash tagline
    expect(find.text('Every Task. One Solution.'), findsOneWidget);

    // Let the splash timer and network load run out (cancelling pending timers)
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
