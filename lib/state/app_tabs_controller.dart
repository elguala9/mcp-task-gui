import 'package:flutter/foundation.dart';

import '../services/settings_store.dart';
import '../services/task_repository.dart';
import 'task_board_controller.dart';

/// One browser-like tab: an independently loaded project with its own
/// filters and selection.
class ProjectTab {
  ProjectTab(this.controller);

  final TaskBoardController controller;

  String get label {
    final root = controller.projectRoot;
    if (root == null) return 'New tab';
    final parts = root.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty);
    return parts.isEmpty ? root : parts.last;
  }
}

/// Owns the set of open project tabs and the app-wide settings (which
/// projects were open, preferred external editor), persisting both between
/// sessions via [SettingsStore].
///
/// Always starts with one empty tab already in [tabs] so the UI has
/// something to render immediately; [restore] then asynchronously replaces
/// it with whatever was open in the previous session, if anything.
class AppTabsController extends ChangeNotifier {
  AppTabsController(this._repository, this._settingsStore) {
    tabs.add(ProjectTab(TaskBoardController(_repository)));
  }

  final TaskRepository _repository;
  final SettingsStore _settingsStore;

  final List<ProjectTab> tabs = [];
  int activeIndex = 0;
  String? externalEditorPath;

  ProjectTab? get activeTab => tabs.isEmpty ? null : tabs[activeIndex];

  Future<void> restore() async {
    final settings = await _settingsStore.load();
    externalEditorPath = settings.externalEditorPath;

    if (settings.openProjects.isNotEmpty) {
      tabs.clear();
      for (final root in settings.openProjects) {
        final controller = TaskBoardController(_repository);
        await controller.loadProject(root);
        tabs.add(ProjectTab(controller));
      }
      if (tabs.isEmpty) tabs.add(ProjectTab(TaskBoardController(_repository)));
      activeIndex = settings.activeTabIndex.clamp(0, tabs.length - 1);
    }
    notifyListeners();
  }

  Future<void> openProjectInNewTab(String root) async {
    final controller = TaskBoardController(_repository);
    await controller.loadProject(root);
    tabs.add(ProjectTab(controller));
    activeIndex = tabs.length - 1;
    notifyListeners();
    await _persist();
  }

  Future<void> openProjectInActiveTab(String root) async {
    if (tabs.isEmpty) {
      tabs.add(ProjectTab(TaskBoardController(_repository)));
      activeIndex = 0;
    }
    await tabs[activeIndex].controller.loadProject(root);
    notifyListeners();
    await _persist();
  }

  void selectTab(int index) {
    activeIndex = index;
    notifyListeners();
    _persist();
  }

  Future<void> closeTab(int index) async {
    if (tabs.length <= 1) {
      // Never end up with zero tabs: reset the last one to an empty tab.
      tabs[0] = ProjectTab(TaskBoardController(_repository));
      activeIndex = 0;
    } else {
      tabs.removeAt(index);
      if (activeIndex >= tabs.length) {
        activeIndex = tabs.length - 1;
      } else if (activeIndex > index) {
        activeIndex--;
      }
    }
    notifyListeners();
    await _persist();
  }

  Future<void> addEmptyTab() async {
    tabs.add(ProjectTab(TaskBoardController(_repository)));
    activeIndex = tabs.length - 1;
    notifyListeners();
    await _persist();
  }

  Future<void> setExternalEditorPath(String? path) async {
    externalEditorPath = (path == null || path.trim().isEmpty) ? null : path.trim();
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final openProjects = tabs
        .map((t) => t.controller.projectRoot)
        .whereType<String>()
        .toList(growable: false);
    await _settingsStore.save(AppSettings(
      openProjects: openProjects,
      activeTabIndex: activeIndex,
      externalEditorPath: externalEditorPath,
    ));
  }
}
