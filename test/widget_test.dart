import 'package:flutter_test/flutter_test.dart';
import 'package:nadra_queue_app/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const NADRAApp());

    expect(find.text('NADRA Queue'), findsOneWidget);
  });
}