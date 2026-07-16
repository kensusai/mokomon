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
  final controller = GameController(state, store)..startDecayTimer();
  controller.sfx.startBgm();
  runApp(MokomonApp(controller: controller));
}

class MokomonApp extends StatefulWidget {
  final GameController controller;
  const MokomonApp({super.key, required this.controller});

  @override
  State<MokomonApp> createState() => _MokomonAppState();
}

class _MokomonAppState extends State<MokomonApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// バックグラウンドではBGMを止める(復帰で再開)。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.controller.sfx.syncBgm(suspend: state != AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'もこもん',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'MPLUSRounded1c',
        colorSchemeSeed: const Color(0xFF34C98E),
      ),
      home: HomeScreen(controller: widget.controller),
    );
  }
}
