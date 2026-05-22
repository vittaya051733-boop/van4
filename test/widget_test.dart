import 'package:flutter_test/flutter_test.dart';

import 'package:van4/admin_app.dart';

void main() {
  testWidgets('renders admin home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const VanMarketAdminApp());

    expect(find.text('Van Market Admin'), findsOneWidget);
    expect(find.text('แอปแอดมินแว๊นตลาด'), findsOneWidget);
    expect(find.text('จัดการร้านค้า'), findsOneWidget);
  });
}
