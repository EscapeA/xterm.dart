import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/src/ui/custom_text_edit.dart';

void main() {
  testWidgets('IME delete command emits a single backspace', (tester) async {
    final focusNode = FocusNode();
    var deleteCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: CustomTextEdit(
            focusNode: focusNode,
            onInsert: (_) {},
            onDelete: () => deleteCount++,
            onComposing: (_) {},
            onAction: (_) {},
            onKeyEvent: (_, _) => KeyEventResult.ignored,
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();

    final state = tester.state<CustomTextEditState>(
      find.byType(CustomTextEdit),
    );

    state.performPrivateCommand('deleteSurroundingText', {'beforeLength': 128});
    await tester.pump();

    expect(deleteCount, 1);

    focusNode.dispose();
  });

  testWidgets('deleteDetection placeholder ignores follow-up IME updates', (
    tester,
  ) async {
    final focusNode = FocusNode();
    var deleteCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: CustomTextEdit(
            focusNode: focusNode,
            deleteDetection: true,
            onInsert: (_) {},
            onDelete: () => deleteCount++,
            onComposing: (_) {},
            onAction: (_) {},
            onKeyEvent: (_, _) => KeyEventResult.ignored,
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();

    final state = tester.state<CustomTextEditState>(
      find.byType(CustomTextEdit),
    );

    state.performPrivateCommand('deleteSurroundingText', {'beforeLength': 1});
    await tester.pump();

    // Simulate the IME reporting that one of the placeholder characters was removed.
    state.updateEditingValue(
      const TextEditingValue(
        text: ' ',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );

    expect(deleteCount, 1);

    focusNode.dispose();
  });

  testWidgets('IME commit inserts text when composition length changes', (
    tester,
  ) async {
    final focusNode = FocusNode();
    final insertedText = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: CustomTextEdit(
            focusNode: focusNode,
            onInsert: insertedText.add,
            onDelete: () {},
            onComposing: (_) {},
            onAction: (_) {},
            onKeyEvent: (_, _) => KeyEventResult.ignored,
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();

    final state = tester.state<CustomTextEditState>(
      find.byType(CustomTextEdit),
    );

    state.updateEditingValue(
      const TextEditingValue(
        text: 'nihongo',
        selection: TextSelection.collapsed(offset: 7),
        composing: TextRange(start: 0, end: 7),
      ),
    );
    state.updateEditingValue(
      const TextEditingValue(
        text: '日本語',
        selection: TextSelection.collapsed(offset: 3),
      ),
    );

    state.updateEditingValue(
      const TextEditingValue(
        text: 'ka',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ),
    );
    state.updateEditingValue(
      const TextEditingValue(
        text: 'かきく',
        selection: TextSelection.collapsed(offset: 3),
      ),
    );

    expect(insertedText, ['日本語', 'かきく']);

    focusNode.dispose();
  });

  testWidgets(
    'deleteDetection: composing commit with bare text inserts full candidate',
    (tester) async {
      final focusNode = FocusNode();
      final inserted = <String>[];
      var deleteCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: CustomTextEdit(
              focusNode: focusNode,
              deleteDetection: true,
              onInsert: inserted.add,
              onDelete: () => deleteCount++,
              onComposing: (_) {},
              onAction: (_) {},
              onKeyEvent: (_, _) => KeyEventResult.ignored,
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      final state = tester.state<CustomTextEditState>(
        find.byType(CustomTextEdit),
      );

      // Chinese IME: pinyin composing (no placeholder prefix), then commit
      // an English candidate with a *bare* text (no '  ' prefix).
      state.updateEditingValue(
        const TextEditingValue(
          text: 'tail',
          selection: TextSelection.collapsed(offset: 4),
          composing: TextRange(start: 0, end: 4),
        ),
      );
      state.updateEditingValue(
        const TextEditingValue(
          text: 'tailscale',
          selection: TextSelection.collapsed(offset: 9),
        ),
      );

      // The composing text was only a preview; the full candidate must be
      // inserted, not stripped by the placeholder offset.
      expect(inserted.join(), 'tailscale');
      expect(deleteCount, 0);

      focusNode.dispose();
    },
  );

  testWidgets(
    'deleteDetection: composing commit with placeholder prefix strips it',
    (tester) async {
      final focusNode = FocusNode();
      final inserted = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: CustomTextEdit(
              focusNode: focusNode,
              deleteDetection: true,
              onInsert: inserted.add,
              onDelete: () {},
              onComposing: (_) {},
              onAction: (_) {},
              onKeyEvent: (_, _) => KeyEventResult.ignored,
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      final state = tester.state<CustomTextEditState>(
        find.byType(CustomTextEdit),
      );

      // Windows-style IME: composing on top of the placeholder, commit keeps
      // the '  ' prefix -> strip it to get the real candidate.
      state.updateEditingValue(
        const TextEditingValue(
          text: '  tail',
          selection: TextSelection.collapsed(offset: 6),
          composing: TextRange(start: 2, end: 6),
        ),
      );
      state.updateEditingValue(
        const TextEditingValue(
          text: '  tailscale',
          selection: TextSelection.collapsed(offset: 11),
        ),
      );

      expect(inserted.join(), 'tailscale');

      focusNode.dispose();
    },
  );

  testWidgets(
    'no-deleteDetection: composing commit with bare text inserts full candidate',
    (tester) async {
      final focusNode = FocusNode();
      final inserted = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: CustomTextEdit(
              focusNode: focusNode,
              // deleteDetection defaults to false -> _processStandardInput.
              onInsert: inserted.add,
              onDelete: () {},
              onComposing: (_) {},
              onAction: (_) {},
              onKeyEvent: (_, _) => KeyEventResult.ignored,
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      final state = tester.state<CustomTextEditState>(
        find.byType(CustomTextEdit),
      );

      // ServerBox real-device scenario: pinyin composing then committing an
      // English candidate with bare text (no placeholder).
      state.updateEditingValue(
        const TextEditingValue(
          text: 'tail',
          selection: TextSelection.collapsed(offset: 4),
          composing: TextRange(start: 0, end: 4),
        ),
      );
      state.updateEditingValue(
        const TextEditingValue(
          text: 'tailscale',
          selection: TextSelection.collapsed(offset: 9),
        ),
      );

      expect(inserted.join(), 'tailscale');

      focusNode.dispose();
    },
  );

  testWidgets(
    'deleteDetection: IME clears buffer then candidate commit replaces word',
    (tester) async {
      final focusNode = FocusNode();
      final inserted = <String>[];
      var deleteCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: CustomTextEdit(
              focusNode: focusNode,
              deleteDetection: true,
              onInsert: inserted.add,
              onDelete: () => deleteCount++,
              onComposing: (_) {},
              onAction: (_) {},
              onKeyEvent: (_, _) => KeyEventResult.ignored,
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      final state = tester.state<CustomTextEditState>(
        find.byType(CustomTextEdit),
      );

      // Real Android IME sequence (from device log): pinyin letters are sent
      // one at a time on top of the placeholder...
      for (final ch in ['t', 'a', 'i', 'l']) {
        state.updateEditingValue(
          TextEditingValue(
            text: '  $ch',
            selection: TextSelection.collapsed(offset: 3),
          ),
        );
        await tester.pump();
      }
      expect(inserted.join(), 'tail');
      expect(deleteCount, 0);

      // ...then the IME CLEARS the editing buffer ('' — the replacement
      // signal) right before committing the full candidate.
      state.updateEditingValue(
        const TextEditingValue.empty(),
      );
      await tester.pump();

      // The tracked committed length (4: 'tail') is erased as backspaces so
      // the candidate replaces instead of appending.
      expect(deleteCount, 4);
      expect(inserted.join(), 'tail');

      // Candidate commit with placeholder prefix.
      state.updateEditingValue(
        const TextEditingValue(
          text: '  tailscale',
          selection: TextSelection.collapsed(offset: 11),
        ),
      );
      await tester.pump();

      // Net effect: tail -> 4 backspaces -> tailscale = tailscale.
      expect(inserted.join(), 'tailtailscale');
      expect(deleteCount, 4);

      focusNode.dispose();
    },
  );

  testWidgets(
    'deleteDetection: bare-text candidate commit after buffer clear',
    (tester) async {
      final focusNode = FocusNode();
      final inserted = <String>[];
      var deleteCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: CustomTextEdit(
              focusNode: focusNode,
              deleteDetection: true,
              onInsert: inserted.add,
              onDelete: () => deleteCount++,
              onComposing: (_) {},
              onAction: (_) {},
              onKeyEvent: (_, _) => KeyEventResult.ignored,
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      final state = tester.state<CustomTextEditState>(
        find.byType(CustomTextEdit),
      );

      for (final ch in ['t', 'a', 'i', 'l']) {
        state.updateEditingValue(
          TextEditingValue(
            text: '  $ch',
            selection: TextSelection.collapsed(offset: 3),
          ),
        );
        await tester.pump();
      }

      state.updateEditingValue(const TextEditingValue.empty());
      await tester.pump();
      expect(deleteCount, 4);

      // Some IMEs commit the candidate WITHOUT the placeholder prefix
      // (observed: 'tailscale' not '  tailscale'). It must be inserted in
      // full, not stripped by the placeholder offset.
      state.updateEditingValue(
        const TextEditingValue(
          text: 'tailscale',
          selection: TextSelection.collapsed(offset: 9),
        ),
      );
      await tester.pump();

      expect(inserted.last, 'tailscale');
      expect(deleteCount, 4);

      focusNode.dispose();
    },
  );

  testWidgets(
    'candidate replacement deletes the unfinished word then inserts the candidate',
    (tester) async {
      final focusNode = FocusNode();
      final inserted = <String>[];
      var deleteCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: CustomTextEdit(
              focusNode: focusNode,
              deleteDetection: true,
              onInsert: inserted.add,
              onDelete: () => deleteCount++,
              onComposing: (_) {},
              onAction: (_) {},
              onKeyEvent: (_, _) => KeyEventResult.ignored,
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      final state = tester.state<CustomTextEditState>(
        find.byType(CustomTextEdit),
      );

      // Soft-keyboard path: each letter is appended on top of the two-space
      // deleteDetection placeholder and then reset.
      for (final ch in ['t', 'a', 'i', 'l']) {
        state.updateEditingValue(
          TextEditingValue(
            text: '  $ch',
            selection: TextSelection.collapsed(offset: 3),
          ),
        );
        await tester.pump();
      }

      expect(inserted.join(), 'tail');
      expect(deleteCount, 0);

      // IME candidate selection: erase "tail", then commit "tailscale".
      state.performPrivateCommand('deleteSurroundingText', {
        'beforeLength': 4,
      });
      await tester.pump();
      state.updateEditingValue(
        const TextEditingValue(
          text: '  tailscale',
          selection: TextSelection.collapsed(offset: 11),
        ),
      );
      await tester.pump();

      expect(deleteCount, 4);
      expect(inserted.join(), 'tailtailscale');

      focusNode.dispose();
    },
  );

  testWidgets(
    'candidate-sized deletes stay multi-char even without tracked commits',
    (tester) async {
      final focusNode = FocusNode();
      var deleteCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: CustomTextEdit(
              focusNode: focusNode,
              onInsert: (_) {},
              onDelete: () => deleteCount++,
              onComposing: (_) {},
              onAction: (_) {},
              onKeyEvent: (_, _) => KeyEventResult.ignored,
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      final state = tester.state<CustomTextEditState>(
        find.byType(CustomTextEdit),
      );

      state.performPrivateCommand('deleteSurroundingText', {
        'beforeLength': 4,
      });
      await tester.pump();

      expect(deleteCount, 4);

      focusNode.dispose();
    },
  );

  testWidgets('enter clears tracked commit length for later IME deletes', (
    tester,
  ) async {
    final focusNode = FocusNode();
    var deleteCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: CustomTextEdit(
            focusNode: focusNode,
            deleteDetection: true,
            onInsert: (_) {},
            onDelete: () => deleteCount++,
            onComposing: (_) {},
            onAction: (_) {},
            onKeyEvent: (_, _) => KeyEventResult.ignored,
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();

    final state = tester.state<CustomTextEditState>(
      find.byType(CustomTextEdit),
    );

    state.updateEditingValue(
      const TextEditingValue(
        text: '  tail',
        selection: TextSelection.collapsed(offset: 6),
      ),
    );
    await tester.pump();

    state.performAction(TextInputAction.done);
    await tester.pump();

    // After enter, a modest delete should still work for candidate replace of
    // a new unfinished word, but a runaway 128 delete remains single BS.
    state.performPrivateCommand('deleteSurroundingText', {
      'beforeLength': 128,
    });
    await tester.pump();
    expect(deleteCount, 1);

    focusNode.dispose();
  });
}
