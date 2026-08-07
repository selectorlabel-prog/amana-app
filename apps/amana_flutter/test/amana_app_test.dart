import 'package:amana_flutter/src/amana_app.dart';
import 'package:amana_flutter/src/order_flow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows all role entry points in RTL', (tester) async {
    await tester.pumpWidget(const AmanaApp());

    expect(find.text('دخول واجهة عميل'), findsOneWidget);
    expect(find.text('دخول واجهة مقدم خدمة'), findsOneWidget);
    expect(find.text('دخول واجهة إدارة'), findsOneWidget);
  });

  testWidgets('opens the customer scaffold', (tester) async {
    await tester.pumpWidget(const AmanaApp());
    await tester.tap(find.text('دخول واجهة عميل'));
    await tester.pumpAndSettle();

    expect(find.text('طلباتي'), findsOneWidget);
    expect(find.text('اطلب خدمة'), findsOneWidget);
  });

  test('order, offer, acceptance, and commission form one flow', () {
    final flow = DemoOrderFlow();
    addTearDown(flow.dispose);

    flow.createOrder(
      description: 'إصلاح تسريب مياه',
      city: 'الخرطوم',
      district: 'الرياض',
    );
    flow.submitOffer(price: 5000, message: 'يمكنني الحضور اليوم');
    flow.acceptOffer();

    expect(flow.order?.status, AmanaOrderStatus.accepted);
    expect(flow.order?.offer?.price, 5000);
    expect(flow.providerWallet, 49250);
  });
}
