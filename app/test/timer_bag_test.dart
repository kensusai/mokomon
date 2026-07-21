import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/screens/timer_bag.dart';

class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with TimerBagMixin<_Host> {
  var fired = 0;

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  testWidgets('fired timers are removed from the bag', (tester) async {
    // docs/review-findings.md #29: 発火済み Timer が _timers に残り続けると、
    // 常駐する HomeScreen で参照が無制限に溜まる。
    await tester.pumpWidget(const _Host());
    final state = tester.state<_HostState>(find.byType(_Host));

    state.later(const Duration(milliseconds: 100), () => state.fired++);
    state.later(const Duration(milliseconds: 200), () => state.fired++);
    expect(state.pendingTimers, 2);

    await tester.pump(const Duration(milliseconds: 300));
    expect(state.fired, 2);
    expect(state.pendingTimers, 0);
  });

  testWidgets('pending timers are cancelled on dispose', (tester) async {
    await tester.pumpWidget(const _Host());
    final state = tester.state<_HostState>(find.byType(_Host));
    state.later(const Duration(seconds: 10), () => state.fired++);

    await tester.pumpWidget(const SizedBox()); // 画面破棄 → dispose()
    await tester.pump(const Duration(seconds: 11));
    expect(state.fired, 0); // キャンセル済みで発火しない
  });
}
