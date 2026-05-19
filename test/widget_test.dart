import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('shows Firebase setup screen when config is missing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MindFlowApp(firebaseReady: false));

    expect(find.text('MindFlow'), findsOneWidget);
    expect(
      find.text('Firebase is not configured on this build'),
      findsOneWidget,
    );
  });
}
