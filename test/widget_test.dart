import 'package:flutter_test/flutter_test.dart';
import 'package:customer_mobile_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BookingManagementApp());
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.byType(BookingManagementApp), findsOneWidget);
  });
}
