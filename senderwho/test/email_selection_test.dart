import 'package:flutter_test/flutter_test.dart';
import 'package:sender_who/utils/email_selection.dart';

void main() {
  test('selection supports toggle, select all, retain, replace, and clear', () {
    final selection = EmailSelection();

    selection.toggle('message-1');
    selection.selectAll(['message-2', '', 'message-3']);
    expect(selection.ids, {'message-1', 'message-2', 'message-3'});

    selection.toggle('message-2');
    selection.retain(['message-1', 'message-2']);
    expect(selection.ids, {'message-1'});

    selection.replaceWith(['failed-message']);
    expect(selection.ids, {'failed-message'});

    selection.clear();
    expect(selection.isEmpty, isTrue);
  });

  test('selectOnly replaces stale selection and ignores an empty id', () {
    final selection = EmailSelection()..selectAll(['old-1', 'old-2']);

    selection.selectOnly('current');
    expect(selection.ids, {'current'});

    selection.selectOnly('');
    expect(selection.isEmpty, isTrue);
  });
}
