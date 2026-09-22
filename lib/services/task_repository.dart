import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../models/task.dart';
import 'frontmatter_parser.dart';

const _doneSubdir = 'done';

/// Reads all tasks under `<projectRoot>/tasks/`, excluding the archived
/// `tasks/done/` subtree, mirroring McpTask/src/store.ts walkMarkdownFiles.
class TaskRepository {
  Future<List<Task>> loadTasks(String projectRoot) async {
    final tasksDir = Directory(p.join(projectRoot, 'tasks'));
    if (!await tasksDir.exists()) {
      throw TaskRepositoryException(
        'No "tasks" folder found under: $projectRoot',
      );
    }

    final tasks = <Task>[];
    await for (final entity in tasksDir.list(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.md')) continue;

      final relPath = p.relative(entity.path, from: tasksDir.path).replaceAll('\\', '/');
      if (relPath == _doneSubdir || relPath.startsWith('$_doneSubdir/')) continue;

      final raw = await entity.readAsString();
      final frontmatter = parseFrontmatter(raw);
      if (frontmatter == null) continue;

      tasks.add(Task.fromFrontmatter(relPath, frontmatter));
    }

    tasks.sort((a, b) => a.path.compareTo(b.path));
    return tasks;
  }

  /// Statuses declared in `<projectRoot>/task-config.yaml`, in file order.
  /// Returns null if the file is absent or has no `statuses` list.
  Future<List<String>?> loadConfiguredStatuses(String projectRoot) async {
    final configFile = File(p.join(projectRoot, 'task-config.yaml'));
    if (!await configFile.exists()) return null;

    final raw = await configFile.readAsString();
    dynamic data;
    try {
      data = loadYaml(raw);
    } on YamlException {
      return null;
    }
    if (data is! Map) return null;
    final statuses = data['statuses'];
    if (statuses is! List) return null;
    return statuses.map((e) => e.toString()).toList(growable: false);
  }

  /// Type names declared in `<projectRoot>/task-config.yaml` (the keys of
  /// the `types` map), in file order. Returns null if the file is absent or
  /// has no `types` map.
  Future<List<String>?> loadConfiguredTypes(String projectRoot) async {
    final configFile = File(p.join(projectRoot, 'task-config.yaml'));
    if (!await configFile.exists()) return null;

    final raw = await configFile.readAsString();
    dynamic data;
    try {
      data = loadYaml(raw);
    } on YamlException {
      return null;
    }
    if (data is! Map) return null;
    final types = data['types'];
    if (types is! Map) return null;
    return types.keys.map((e) => e.toString()).toList(growable: false);
  }
}

class TaskRepositoryException implements Exception {
  final String message;
  TaskRepositoryException(this.message);

  @override
  String toString() => message;
}
