import 'package:flutter_test/flutter_test.dart';
import 'package:tts_core/tts_core.dart';

void main() {
  test('import preserves Cyrillic and spoken colons and reports source rows', () {
    final result = const DialogModeParser().parseWithDiagnostics(
      '\r\nАнна: Ещё: привет, Алёша!\r\ninvalid row\r\n: Привет\r\nСергей: \r\nСергей: Угу.\r\n',
    );
    expect(result.lines.map((line) => line.speakerName), ['Анна', 'Сергей']);
    expect(result.lines.first.text, 'Ещё: привет, Алёша!');
    expect(result.issues.map((issue) => issue.sourceLineNumber), [3, 4, 5]);
    expect(result.issues.map((issue) => issue.sourceText), [
      'invalid row',
      ': Привет',
      'Сергей: ',
    ]);
    expect(result.issues.map((issue) => issue.message), [
      'Expected Speaker: text.',
      'Speaker name is missing.',
      'Spoken text is missing.',
    ]);
    expect(() => result.lines.clear(), throwsUnsupportedError);
    expect(() => result.issues.clear(), throwsUnsupportedError);
  });
}
