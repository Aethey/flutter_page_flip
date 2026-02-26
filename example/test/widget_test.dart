import 'package:flutter_test/flutter_test.dart';

import 'package:page_example/main.dart';

void main() {
  testWidgets('Example app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pump();
    expect(find.text('Page 1/5'), findsOneWidget);
  });
}
