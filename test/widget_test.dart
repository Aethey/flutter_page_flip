import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:page_demo/main.dart';

void main() {
  testWidgets('page curl demo boots and shows first page marker',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PageCurlDemoApp());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Page 1/5'), findsOneWidget);
  });
}
