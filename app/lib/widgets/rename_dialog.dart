import 'package:flutter/material.dart';

import 'ui_kit.dart';

/// なまえ変更ダイアログ。決定でニックネーム(空文字=もとの名前)を返す。
/// キャンセル(とじる)は null。
Future<String?> showRenameDialog(BuildContext context, {String? current}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _RenameDialogBody(current: current),
  );
}

/// code_dialog と同じ StatefulWidget 形式: TextEditingController を
/// State が所有して dispose する(docs/review-findings.md #25)。
class _RenameDialogBody extends StatefulWidget {
  final String? current;
  const _RenameDialogBody({this.current});

  @override
  State<_RenameDialogBody> createState() => _RenameDialogBodyState();
}

class _RenameDialogBodyState extends State<_RenameDialogBody> {
  late final _input = TextEditingController(text: widget.current ?? '');

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MokoModalShell(
      header: const [ModalTitle('✏️ なまえを つける')],
      body: [
        const Text(
          '10もじまで つけられるよ',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: ink2Color,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _input,
          autofocus: true,
          maxLength: 10,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: inkColor,
          ),
          decoration: InputDecoration(
            hintText: 'なまえを いれてね',
            counterText: '',
            contentPadding: const EdgeInsets.all(12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE3E6F0), width: 3),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: accentGreen, width: 3),
            ),
          ),
        ),
      ],
      footer: [
        PressableGradient(
          colors: greenGradient,
          onTap: () => Navigator.of(context).pop(_input.text),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'けってい!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ModalCloseButton(
          label: 'もとの なまえに もどす',
          onTap: () => Navigator.of(context).pop(''),
        ),
        const SizedBox(height: 8),
        ModalCloseButton(
          label: 'とじる',
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
