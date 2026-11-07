part of 'build_site.dart';

/// The /docs page (HYA-402): the commons documentation pack rendered as
/// static semantic HTML. The page is regenerated from docs/*.md on every
/// build, so it can never drift from the repository files; crawlers and
/// AI agents find the data dictionary and methodology verbatim. Zero
/// client JavaScript - the entire page is pre-rendered.
String _docsPageHtml(String urlBase, String commitSha) {
  final shortSha = commitSha == 'local' ? 'local' : commitSha.substring(0, 7);
  final pack = <List<String>>[
    ['readme', 'Index', 'docs/README.md'],
    ['data-dictionary', 'Data dictionary', 'docs/data-dictionary.md'],
    ['methodology', 'Methodology', 'docs/methodology.md'],
    ['changelog', 'Changelog', 'docs/changelog.md'],
    ['errata', 'Errata', 'docs/errata.md'],
    ['provenance', 'Provenance manifest', 'docs/provenance-manifest.md'],
  ];
  final toc = [
    for (final p in pack) '<li><a href="#${p[0]}">${p[1]}</a></li>'
  ].join('\n');
  final articles = [
    for (final p in pack)
      '<article id="${p[0]}">\n${_mdToHtml(_readSourceFile(p[2]))}\n</article>'
  ].join('\n');
  final body = '''
<h1>Documentation <span lang="ne">· कागजात</span></h1>
<p>The commons documentation pack, rendered verbatim from <a href="https://github.com/namunaONE/nMiti/tree/main/docs">docs/</a> on every build - the repository files remain the single source of truth, so this page can never drift from them. Zero client JavaScript.</p>
<ol id="docs-toc">
$toc
</ol>
$articles
''';
  return _docShell(
      'Documentation',
      'The nMiti commons documentation pack rendered verbatim: data dictionary, methodology, changelog, public errata log and provenance manifest.',
      urlBase, 'docs.html', body, shortSha);
}

/// Minimal markdown-to-HTML renderer for the docs pack. Handles exactly
/// the constructs the docs use - ATX headings, paragraphs, ordered and
/// unordered lists, pipe tables, indented code blocks, horizontal rules,
/// and inline code/bold/italic/links - and HTML-escapes everything else.
/// Text is preserved verbatim; anything unrecognized falls through to a
/// paragraph, never dropped. Headings are demoted one level so the page
/// keeps a single h1.
String _mdToHtml(String md) {
  final lines = md.split('\n');
  final out = <String>[];
  var i = 0;
  while (i < lines.length) {
    final line = lines[i];
    final t = line.trim();
    if (t.isEmpty) {
      i++;
      continue;
    }
    final indent = line.length - line.trimLeft().length;
    if (indent >= 4) {
      // Indented code block.
      final buf = <String>[];
      while (i < lines.length) {
        final l = lines[i];
        if (l.trim().isEmpty) {
          buf.add('');
          i++;
        } else if (l.length - l.trimLeft().length >= 4) {
          buf.add(l.substring(4));
          i++;
        } else {
          break;
        }
      }
      while (buf.isNotEmpty && buf.last.isEmpty) {
        buf.removeLast();
      }
      out.add('<pre><code>${_htmlEscape(buf.join('\n'))}</code></pre>');
      continue;
    }
    final h = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(t);
    if (h != null) {
      final level = h.group(1)!.length + 1;
      out.add('<h$level>${_mdInline(h.group(2)!)}</h$level>');
      i++;
      continue;
    }
    if (RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(t)) {
      out.add('<hr>');
      i++;
      continue;
    }
    if (t.startsWith('|') &&
        i + 1 < lines.length &&
        RegExp(r'^\|[\s:|-]+\|?$').hasMatch(lines[i + 1].trim())) {
      // Pipe table: header row, separator row, then body rows.
      String stripEdges(String row) {
        var c = row.trim();
        if (c.startsWith('|')) c = c.substring(1);
        if (c.endsWith('|')) c = c.substring(0, c.length - 1);
        return c;
      }
      final head = stripEdges(t)
          .split('|')
          .map((c) => '<th>${_mdInline(c.trim())}</th>')
          .join();
      i += 2;
      final rows = <String>[];
      while (i < lines.length && lines[i].trim().startsWith('|')) {
        rows.add('<tr>'
            '${stripEdges(lines[i]).split('|').map((c) => '<td>${_mdInline(c.trim())}</td>').join()}'
            '</tr>');
        i++;
      }
      out.add(
          '<table><thead><tr>$head</tr></thead><tbody>${rows.join()}</tbody></table>');
      continue;
    }
    final ul = RegExp(r'^[-*]\s+(.*)$').firstMatch(t);
    final ol = RegExp(r'^\d+[.)]\s+(.*)$').firstMatch(t);
    if (ul != null || ol != null) {
      final ordered = ol != null;
      final items = <String>[];
      while (i < lines.length) {
        final l = lines[i].trim();
        final m = ordered
            ? RegExp(r'^\d+[.)]\s+(.*)$').firstMatch(l)
            : RegExp(r'^[-*]\s+(.*)$').firstMatch(l);
        if (m == null) break;
        items.add('<li>${_mdInline(m.group(1)!)}</li>');
        i++;
      }
      out.add(ordered ? '<ol>${items.join()}</ol>' : '<ul>${items.join()}</ul>');
      continue;
    }
    // Paragraph: consecutive plain lines.
    final para = <String>[];
    final paraStart = i;
    while (i < lines.length) {
      final l = lines[i];
      final lt = l.trim();
      if (lt.isEmpty || l.length - l.trimLeft().length >= 4) break;
      if (RegExp(r'^#{1,6}\s').hasMatch(lt) ||
          RegExp(r'^[-*]\s').hasMatch(lt) ||
          RegExp(r'^\d+[.)]\s').hasMatch(lt) ||
          lt.startsWith('|') ||
          RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(lt)) {
        break;
      }
      para.add(lt);
      i++;
    }
    // A line that opens with the pipe character but has no separator
    // row after it is not a table: consume it as a one-line paragraph
    // so this loop always advances and never spins on one line.
    if (i == paraStart && i < lines.length) {
      para.add(lines[i].trim());
      i++;
    }
    out.add('<p>${_mdInline(para.join(' '))}</p>');
  }
  return out.join('\n');
}

/// Inline markdown: escape first, then code spans, links, bold, italic.
/// Relative links to sibling .md docs resolve on GitHub, not on the
/// served site, so they are pointed at the repository files.
String _mdInline(String s) {
  var out = _htmlEscape(s);
  out = out.replaceAllMapped(
      RegExp(r'`([^`]+)`'), (m) => '<code>${m.group(1)}</code>');
  out = out.replaceAllMapped(RegExp(r'\[([^\]]+)\]\(([^)]+)\)'), (m) {
    var href = m.group(2)!.trim();
    if (!href.startsWith('http')) {
      href = 'https://github.com/namunaONE/nMiti/blob/main/docs/$href';
    }
    return '<a href="$href">${m.group(1)}</a>';
  });
  out = out.replaceAllMapped(
      RegExp(r'\*\*([^*]+)\*\*'), (m) => '<strong>${m.group(1)}</strong>');
  out = out.replaceAllMapped(
      RegExp(r'\*([^*]+)\*'), (m) => '<em>${m.group(1)}</em>');
  return out;
}

String _htmlEscape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
String _notFoundHtml(String urlBase) => '''
<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><title>Not found | nMiti</title></head>
<body>
<main>
<h1>404 — not found</h1>
<p><a href="$urlBase">nMiti — today's date in Nepal</a> · <a href="${urlBase}api/v1/today.json">today.json</a></p>
</main>
</body>
</html>
''';

/// Reads a source data file from the repository (not the build output).
/// The build runs from the repo root; some runners use a package cwd.
String _readSourceFile(String rel) {
  for (final path in [rel, '../../' + rel]) {
    final f = File(path);
    if (f.existsSync()) return f.readAsStringSync();
  }
  throw StateError('Required source data file not found: ' + rel);
}
