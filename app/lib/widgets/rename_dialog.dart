import 'package:flutter/material.dart';

import 'ui_kit.dart';

/// なまえ変更ダイアログ。決定でニックネーム(空文字=もとの名前)を返す。
/// キャンセル(とじる)は null。
Future<String?> showRenameDialog(BuildContext context, {String? current}) {
  final input = TextEditingController(text: current ?? '');
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => MokoModalShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ModalTitle('✏️ なまえを つける'),
          const SizedBox(height: 8),
          const Text('10もじまで つけられるよ',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: ink2Color)),
          const SizedBox(height: 12),
          TextField(
            controller: input,
            autofocus: true,
            maxLength: 10,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: inkColor),
            decoration: InputDecoration(
              hintText: 'なまえを いれてね',
              counterText: '',
              contentPadding: const EdgeInsets.all(12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: Color(0xFFE3E6F0), width: 3),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: Color(0xFF34C98E), width: 3),
              ),
            ),
          ),
          const SizedBox(height: 12),
          PressableGradient(
            colors: greenGradient,
            onTap: () => Navigator.of(dialogContext).pop(input.text),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('けってい!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
          ),
          const SizedBox(height: 10),
          ModalCloseButton(
              label: 'もとの なまえに もどす',
              onTap: () => Navigator.of(dialogContext).pop('')),
          const SizedBox(height: 8),
          ModalCloseButton(
              label: 'とじる', onTap: () => Navigator.of(dialogContext).pop()),
        ],
      ),
    ),
  );
}
