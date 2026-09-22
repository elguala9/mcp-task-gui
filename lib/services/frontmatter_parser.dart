import 'package:yaml/yaml.dart';

/// Extracts and parses the YAML frontmatter block of a task Markdown file.
///
/// Mirrors ../../McpTask/src/frontmatter.ts: the file must start with
/// `---`, followed by a YAML block, closed by a line starting with `---`.
/// Returns null if the file has no valid frontmatter block.
Map<dynamic, dynamic>? parseFrontmatter(String raw) {
  final normalized = raw.replaceAll('\r\n', '\n');
  if (!normalized.startsWith('---\n') && normalized != '---') {
    return null;
  }
  final rest = normalized.substring(4);
  final endIdx = rest.indexOf('\n---');
  if (endIdx == -1) return null;

  final yamlBlock = rest.substring(0, endIdx);
  try {
    final data = loadYaml(yamlBlock);
    if (data is Map) return data;
    return null;
  } on YamlException {
    return null;
  }
}
