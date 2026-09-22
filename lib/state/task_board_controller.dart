import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/task.dart';
import '../services/task_repository.dart';

/// Whether the selected statuses narrow the list down to matches
/// ([FilterMode.include]) or hide matches ([FilterMode.exclude]).
enum FilterMode { include, exclude }

/// Holds the loaded project, its tasks, and the current filters/selection.
/// Filtering is computed on demand (small in-memory lists, no need to
/// persist filtered results).
class TaskBoardController extends ChangeNotifier {
  TaskBoardController(this._repository);

  final TaskRepository _repository;

  String? projectRoot;
  List<Task> _tasks = [];
  List<String> _knownStatuses = [];
  List<String> _knownTypes = [];
  bool isLoading = false;
  String? loadError;

  final Set<String> selectedStatuses = {'finished'};
  FilterMode statusFilterMode = FilterMode.exclude;
  final Set<String> selectedTypes = {};
  FilterMode typeFilterMode = FilterMode.include;
  String pathFilter = '';
  String? selectedTaskPath;

  List<Task> get tasks => _tasks;
  List<String> get knownStatuses => _knownStatuses;
  List<String> get knownTypes => _knownTypes;

  List<Task> get filteredTasks {
    return _tasks.where((task) {
      final matchesStatus = selectedStatuses.isEmpty ||
          (statusFilterMode == FilterMode.include
              ? selectedStatuses.contains(task.status)
              : !selectedStatuses.contains(task.status));
      final matchesType = selectedTypes.isEmpty ||
          (typeFilterMode == FilterMode.include
              ? selectedTypes.contains(task.type)
              : !selectedTypes.contains(task.type));
      final matchesPath = pathFilter.isEmpty ||
          task.path.toLowerCase().contains(pathFilter.toLowerCase());
      return matchesStatus && matchesType && matchesPath;
    }).toList(growable: false);
  }

  Task? get selectedTask {
    if (selectedTaskPath == null) return null;
    for (final task in _tasks) {
      if (task.path == selectedTaskPath) return task;
    }
    return null;
  }

  /// Tasks that declare [task] as a dependency.
  List<Task> dependentsOf(Task task) {
    return _tasks.where((t) => t.dependencies.contains(task.path)).toList(growable: false);
  }

  Task? findByPath(String path) {
    for (final task in _tasks) {
      if (task.path == path) return task;
    }
    return null;
  }

  Future<void> loadProject(String root) async {
    projectRoot = root;
    isLoading = true;
    loadError = null;
    notifyListeners();

    try {
      final tasks = await _repository.loadTasks(root);
      final configuredStatuses = await _repository.loadConfiguredStatuses(root);
      final configuredTypes = await _repository.loadConfiguredTypes(root);
      _tasks = tasks;
      _knownStatuses = configuredStatuses ?? _deriveStatuses(tasks);
      _knownTypes = configuredTypes ?? _deriveTypes(tasks);
      selectedStatuses.removeWhere((s) => !_knownStatuses.contains(s));
      selectedTypes.removeWhere((t) => !_knownTypes.contains(t));
    } on TaskRepositoryException catch (e) {
      loadError = e.message;
      _tasks = [];
      _knownStatuses = [];
      _knownTypes = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (projectRoot != null) await loadProject(projectRoot!);
  }

  void toggleStatus(String status) {
    if (!selectedStatuses.remove(status)) {
      selectedStatuses.add(status);
    }
    notifyListeners();
  }

  void clearStatusFilter() {
    selectedStatuses.clear();
    notifyListeners();
  }

  void setStatusFilterMode(FilterMode mode) {
    statusFilterMode = mode;
    notifyListeners();
  }

  void toggleType(String type) {
    if (!selectedTypes.remove(type)) {
      selectedTypes.add(type);
    }
    notifyListeners();
  }

  void clearTypeFilter() {
    selectedTypes.clear();
    notifyListeners();
  }

  void setTypeFilterMode(FilterMode mode) {
    typeFilterMode = mode;
    notifyListeners();
  }

  void setPathFilter(String value) {
    pathFilter = value;
    notifyListeners();
  }

  void selectTask(String? path) {
    selectedTaskPath = path;
    notifyListeners();
  }

  /// Reads a task's raw Markdown file for read-only viewing in-app — this
  /// is the only way to guarantee "view only", since the OS's default
  /// handler for `.md` (commonly Notepad) opens it as editable.
  Future<String> readTaskFileRaw(Task task) async {
    final root = projectRoot;
    if (root == null) return '';
    final file = File(p.join(root, 'tasks', task.path));
    return file.readAsString();
  }

  /// Opens a task's raw Markdown file in [externalEditorPath] (e.g. a path
  /// to Notepad++) for editing.
  Future<void> openTaskFileInEditor(Task task, String externalEditorPath) async {
    final root = projectRoot;
    if (root == null) return;
    final filePath = p.join(root, 'tasks', task.path);
    await Process.start(externalEditorPath.trim(), [filePath], mode: ProcessStartMode.detached);
  }

  List<String> _deriveStatuses(List<Task> tasks) {
    final seen = <String>{};
    final ordered = <String>[];
    for (final task in tasks) {
      if (seen.add(task.status)) ordered.add(task.status);
    }
    ordered.sort();
    return ordered;
  }

  List<String> _deriveTypes(List<Task> tasks) {
    final seen = <String>{};
    final ordered = <String>[];
    for (final task in tasks) {
      if (seen.add(task.type)) ordered.add(task.type);
    }
    ordered.sort();
    return ordered;
  }
}
