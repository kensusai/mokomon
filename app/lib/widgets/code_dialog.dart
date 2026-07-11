import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/game_controller.dart';
import 'toast.dart';

/// あいことばセーブ/ロード(プロトタイプ #saveModal)。docs/game-design.md §8。
Future<void> showCodeDialog(BuildContext context, GameController controller) {
  return showDialog(
    context: context,
    builder: (dialogContext) =>
        _CodeDialogBody(controller: controller, rootContext: context),
  );
}

class _CodeDialogBody extends StatefulWidget {
  final GameController controller;
  final BuildContext rootContext;
  const _CodeDialogBody({required this.controller, required this.rootContext});

  @override
  State<_CodeDialogBody> createState() => _CodeDialogBodyState();
}

class _CodeDialogBodyState extends State<_CodeDialogBody> {
  String? _code;
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _load() {
    final text = _input.text.trim();
    if (text.isEmpty) {
      showToast(widget.rootContext, 'あいことばを いれてね');
      return;
    }
    if (widget.controller.applyCode(text)) {
      Navigator.of(context).pop();
      showToast(widget.rootContext, 'おかえり! つづきから あそべるよ🎉');
    } else {
      showToast(widget.rootContext, 'あいことばが ちがうみたい…🤔');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('💾 セーブ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF3A3F52))),
              const SizedBox(height: 8),
              const Text(
                '「あいことば」を メモしておくと、べつの スマホや パソコンでも つづきから あそべるよ!\n(もようの おえかきは ひきつがれないよ)',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    height: 1.7,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8A90A8)),
              ),
              const SizedBox(height: 12),
              _bigButton(
                emoji: '🔑',
                label: 'あいことばを つくる',
                colors: const [Color(0xFF34C98E), Color(0xFF1FAE76)],
                onTap: () =>
                    setState(() => _code = widget.controller.state.makeCode()),
              ),
              if (_code != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: const Color(0xFFE3E6F0), width: 3),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SelectableText(_code!,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3A3F52))),
                ),
                const SizedBox(height: 8),
                Material(
                  color: const Color(0xFFEEF0F7),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: _code!));
                      if (context.mounted) {
                        showToast(widget.rootContext,
                            'コピーしたよ! メモちょうに はっておいてね📝');
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('📋 コピーする',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF8A90A8))),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Divider(color: Color(0xFFE3E6F0), thickness: 3),
              const SizedBox(height: 12),
              TextField(
                controller: _input,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3A3F52)),
                decoration: InputDecoration(
                  hintText: 'あいことばを ここに いれてね',
                  contentPadding: const EdgeInsets.all(10),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFFE3E6F0), width: 3),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFF34C98E), width: 3),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _bigButton(
                emoji: '📥',
                label: 'よみこむ',
                colors: const [Color(0xFFFFAB49), Color(0xFFFF8F1F)],
                onTap: _load,
              ),
              const SizedBox(height: 10),
              Material(
                color: const Color(0xFFEEF0F7),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('とじる',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF8A90A8))),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bigButton({
    required String emoji,
    required String label,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x24000000), offset: Offset(0, 5)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
