import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/game_controller.dart';
import 'toast.dart';
import 'ui_kit.dart';

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
    return MokoModalShell(
      header: const [ModalTitle('💾 セーブ')],
      body: [
        const Text(
          '「あいことば」を メモしておくと、べつの スマホや パソコンでも つづきから あそべるよ!\n(もようの おえかきは ひきつがれないよ)',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            height: 1.7,
            fontWeight: FontWeight.w700,
            color: ink2Color,
          ),
        ),
        const SizedBox(height: 12),
        _bigButton(
          emoji: '🔑',
          label: 'あいことばを つくる',
          colors: greenGradient,
          onTap: () =>
              setState(() => _code = widget.controller.state.makeCode()),
        ),
        if (_code != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE3E6F0), width: 3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: SelectableText(
              _code!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: inkColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ModalCloseButton(
            label: '📋 コピーする',
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: _code!));
              if (context.mounted) {
                showToast(widget.rootContext, 'コピーしたよ! メモちょうに はっておいてね📝');
              }
            },
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
            color: inkColor,
          ),
          decoration: InputDecoration(
            hintText: 'あいことばを ここに いれてね',
            contentPadding: const EdgeInsets.all(10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE3E6F0), width: 3),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: accentGreen, width: 3),
            ),
          ),
        ),
      ],
      footer: [
        _bigButton(
          emoji: '📥',
          label: 'よみこむ',
          colors: orangeGradient,
          onTap: _load,
        ),
        const SizedBox(height: 10),
        ModalCloseButton(
          label: 'とじる',
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _bigButton({
    required String emoji,
    required String label,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return PressableGradient(
      colors: colors,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
