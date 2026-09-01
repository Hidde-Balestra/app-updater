import 'package:app_updater/models/changelog_line.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns an empty list for null or blank input', () {
    expect(parseChangelog(null), isEmpty);
    expect(parseChangelog(''), isEmpty);
    expect(parseChangelog('   \n  \n'), isEmpty);
  });

  test('plain lines with no markdown markers are all paragraphs', () {
    final lines = parseChangelog('Fixed a crash on startup.\nMinor UI tweaks.');

    expect(lines, hasLength(2));
    expect(lines[0].kind, ChangelogLineKind.paragraph);
    expect(lines[0].text, 'Fixed a crash on startup.');
    expect(lines[1].kind, ChangelogLineKind.paragraph);
    expect(lines[1].text, 'Minor UI tweaks.');
  });

  test('strips a markdown header marker and tags it as a header', () {
    final lines = parseChangelog('## v2.0.0\nSome notes');

    expect(lines[0].kind, ChangelogLineKind.header);
    expect(lines[0].text, 'v2.0.0');
    expect(lines[1].kind, ChangelogLineKind.paragraph);
  });

  test('strips an existing bullet marker instead of doubling it', () {
    final lines = parseChangelog('- Fixed a bug\n* Added a feature\n• Done');

    expect(lines.map((l) => l.kind), everyElement(ChangelogLineKind.bullet));
    expect(lines.map((l) => l.text), [
      'Fixed a bug',
      'Added a feature',
      'Done',
    ]);
  });

  test('marks the first line after a blank line as starting a new block', () {
    final lines = parseChangelog('First paragraph.\n\nSecond paragraph.');

    expect(lines, hasLength(2));
    expect(lines[0].startsNewBlock, isFalse);
    expect(lines[1].startsNewBlock, isTrue);
  });

  test('does not mark the very first line as starting a new block, even '
      'with leading blank lines', () {
    final lines = parseChangelog('\n\nFirst real line.');

    expect(lines, hasLength(1));
    expect(lines.single.startsNewBlock, isFalse);
  });

  test('multiple consecutive blank lines only count as one block break', () {
    final lines = parseChangelog('One.\n\n\n\nTwo.');

    expect(lines, hasLength(2));
    expect(lines[1].startsNewBlock, isTrue);
  });
}
