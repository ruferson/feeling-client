import 'package:flutter_test/flutter_test.dart';

import 'package:feeling_client/main.dart';

void main() {
  testWidgets('App shell loads the auth screen by default', (tester) async {
    await tester.pumpWidget(const FeelingApp(initialHasSession: false));

    expect(find.text('Feeling Canvas - Sign In'), findsOneWidget);
  });
}
