import 'package:flutter_test/flutter_test.dart';
import 'package:foaie_prestatii_mvp/main.dart';

void main() {
  testWidgets('app boots', (tester) async {
    await tester.pumpWidget(
      const MyApp(
        initialShowOnboarding: false,
        initialPrivacyPolicyAccepted: true,
      ),
    );
    // just ensure first frame renders
    expect(find.byType(MyApp), findsOneWidget);
  });
}
