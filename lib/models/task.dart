/// A single task read from a `<project>/tasks/**/*.md` Markdown file.
///
/// Mirrors the frontmatter schema defined by the mcp-task server
/// (see ../../McpTask/src/types.ts TaskFrontmatter).
class Task {
  /// Path relative to the `tasks/` folder, e.g. "feature/login.md".
  final String path;
  final String title;
  final String type;
  final String status;
  final String? priority;
  final String? createdAt;
  final String? updatedAt;
  final List<String> tags;

  /// Paths (relative to `tasks/`) of tasks this one depends on.
  final List<String> dependencies;

  const Task({
    required this.path,
    required this.title,
    required this.type,
    required this.status,
    this.priority,
    this.createdAt,
    this.updatedAt,
    this.tags = const [],
    this.dependencies = const [],
  });

  factory Task.fromFrontmatter(String path, Map<dynamic, dynamic> data) {
    return Task(
      path: path,
      title: (data['title'] as String?)?.trim() ?? path,
      type: (data['type'] as String?)?.trim() ?? 'unknown',
      status: (data['status'] as String?)?.trim() ?? 'unknown',
      priority: (data['priority'] as String?)?.trim(),
      createdAt: (data['created_at'] as String?)?.trim(),
      updatedAt: (data['updated_at'] as String?)?.trim(),
      tags: _stringList(data['tags']),
      dependencies: _stringList(data['dependencies']),
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => e.toString()).toList(growable: false);
  }
}
