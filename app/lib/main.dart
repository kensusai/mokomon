import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/save_store.dart';
import 'logic/game_controller.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final store = SaveStore();
  final state = await store.load();
  runApp(MokomonApp(controller: GameController(state, store)));
}

class MokomonApp extends StatelessWidget {
  final GameController controller;
  const MokomonApp({super.key, required this.controller});

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
      home: HomeScreen(controller: controller),
    );
  }
}
