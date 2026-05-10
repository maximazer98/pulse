import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/main.dart';

void main() {
  testWidgets('GameApp boots', (WidgetTester tester) async {
    await tester.pumpWidget(const GameApp());
    expect(find.byType(GameApp), findsOneWidget);
  });
}
