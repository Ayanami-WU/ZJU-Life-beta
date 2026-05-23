import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zjulife/config/theme.dart';
import 'package:zjulife/widgets/cupertino_grouped.dart';

void main() {
  testWidgets('CupertinoGroupRow keeps trailing actions independent', (
    tester,
  ) async {
    var rowTaps = 0;
    var trailingTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: CupertinoGroupRow(
              title: '打开详情',
              onTap: () => rowTaps += 1,
              trailing: CupertinoButton(
                key: const ValueKey('trailing-action'),
                padding: EdgeInsets.zero,
                onPressed: () => trailingTaps += 1,
                child: const Text('收藏'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('trailing-action')));
    await tester.pump();

    expect(trailingTaps, 1);
    expect(rowTaps, 0);

    await tester.tap(find.text('打开详情'));
    await tester.pump();

    expect(rowTaps, 1);
  });
}
