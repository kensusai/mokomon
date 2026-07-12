import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/data/save_store.dart';
import 'package:mokomon/logic/game_controller.dart';
import 'package:mokomon/main.dart';
import 'package:mokomon/models/game_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app boots on the home screen with a fresh state',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
        MokomonApp(controller: GameController(GameState(), SaveStore())));

    // Fresh state: 10 coins, egg stage.
    expect(find.textContaining('10'), findsWidgets);
    expect(find.textContaining('たまご'), findsOneWidget);
  });
}
