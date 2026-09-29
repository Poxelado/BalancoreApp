import 'package:flutter_test/flutter_test.dart';
import 'package:balancore/main.dart';

void main() {
  testWidgets('Carga la app Balancore sin errores', (WidgetTester tester) async {
    await tester.pumpWidget(const BalancoreApp());
    expect(find.text('Balancore'), findsOneWidget);
  });
}