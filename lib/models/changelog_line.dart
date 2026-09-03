/// How a single line of a changelog should be rendered.
enum ChangelogLineKind { header, bullet, paragraph }

/// One parsed, display-ready line of a changelog, stripped of its raw
/// markdown marker (if any) so the renderer never has to re-parse [text].
class ChangelogLine {
  final ChangelogLineKind kind;
  final String text;

  /// Whether a blank line in the source separated this line from the
  /// previous one — used to add extra spacing between paragraph blocks
  /// instead of the uniform gap markdown-as-plain-text would otherwise get.
  final bool startsNewBlock;

  const ChangelogLine({
    required this.kind,
    required this.text,
    required this.startsNewBlock,
  });
}

final _headerPattern = RegExp(r'^#{1,6}\s+');
final _bulletPattern = RegExp(r'^[-*•]\s+');

/// Parses raw changelog text (a GitHub/GitLab/Codeberg release body) into
/// display-ready lines: markdown headers and already-authored bullet points
/// keep their own styling instead of being flattened into a plain
/// bullet-per-line dump, which used to turn "## v2.0" into "•  ## v2.0" and
/// double-bullet lines that already started with "-".
///
/// Blank lines in [raw] aren't returned as lines of their own — they only
/// mark the following line as [ChangelogLine.startsNewBlock], so the
/// renderer can add paragraph spacing without rendering an empty bullet.
List<ChangelogLine> parseChangelog(String? raw) {
  final rawLines = (raw ?? '').split('\n');
  final result = <ChangelogLine>[];
  var pendingBlockBreak = false;

  for (final rawLine in rawLines) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      if (result.isNotEmpty) pendingBlockBreak = true;
      continue;
    }

    final ChangelogLineKind kind;
    final String text;
    if (_headerPattern.hasMatch(line)) {
      kind = ChangelogLineKind.header;
      text = line.replaceFirst(_headerPattern, '');
    } else if (_bulletPattern.hasMatch(line)) {
      kind = ChangelogLineKind.bullet;
      text = line.replaceFirst(_bulletPattern, '');
    } else {
      kind = ChangelogLineKind.paragraph;
      text = line;
    }

    result.add(
      ChangelogLine(kind: kind, text: text, startsNewBlock: pendingBlockBreak),
    );
    pendingBlockBreak = false;
  }

  return result;
}
