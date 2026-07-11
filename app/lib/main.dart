import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/game_state.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final state = await GameState.load();
  runApp(MokomonApp(state: state));
}

class MokomonApp extends StatelessWidget {
  final GameState state;
  const MokomonApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'もこもん',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // TODO: M PLUS Rounded 1c をassetsに追加して fontFamily を設定
        colorSchemeSeed: const Color(0xFF34C98E),
      ),
      home: HomeScreen(state: state),
    );
  }
}
