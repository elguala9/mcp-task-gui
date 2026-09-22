import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:path/path.dart' as p;

import 'models/task.dart';
import 'services/settings_store.dart';
import 'services/task_repository.dart';
import 'state/app_tabs_controller.dart';
import 'state/task_board_controller.dart';

void main() {
  runApp(const McpTaskGuiApp());
}

class McpTaskGuiApp extends StatelessWidget {
  const McpTaskGuiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MCP Task GUI',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const RootPage(),
    );
  }
}

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  late final AppTabsController tabsController;

  @override
  void initState() {
    super.initState();
    tabsController = AppTabsController(TaskRepository(), SettingsStore());
    tabsController.restore();
  }

  @override
  void dispose() {
    tabsController.dispose();
    super.dispose();
  }

  Future<void> _pickProjectFolder() async {
    return FilePicker.platform
        .getDirectoryPath(dialogTitle: 'Select project root (must contain a tasks/ folder)')
        .then((dir) async {
      if (dir != null) await tabsController.openProjectInActiveTab(dir);
    });
  }

  Future<void> _pickProjectFolderInNewTab() async {
    final dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select project root (must contain a tasks/ folder)',
    );
    if (dir != null) await tabsController.openProjectInNewTab(dir);
  }

  Future<void> _openSettingsDialog() async {
    final controller = TextEditingController(text: tabsController.externalEditorPath ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('External editor (used by "Open with editor"):'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: r'e.g. C:\Program Files\Notepad++\notepad++.exe',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Browse…',
                    icon: const Icon(Icons.folder_open),
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        dialogTitle: 'Select external editor executable',
                        type: FileType.custom,
                        allowedExtensions: ['exe'],
                      );
                      final path = result?.files.single.path;
                      if (path != null) controller.text = path;
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) await tabsController.setExternalEditorPath(result);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tabsController,
      builder: (context, _) {
        final activeTab = tabsController.activeTab;
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: _ProjectTabBar(
              tabsController: tabsController,
              onNewTab: _pickProjectFolderInNewTab,
            ),
            actions: [
              IconButton(
                tooltip: 'Open project folder',
                icon: const Icon(Icons.folder_open),
                onPressed: _pickProjectFolder,
              ),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: activeTab?.controller.projectRoot == null
                    ? null
                    : activeTab!.controller.refresh,
              ),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: _openSettingsDialog,
              ),
            ],
          ),
          body: activeTab == null
              ? const SizedBox.shrink()
              : _TaskBoardBody(
                  controller: activeTab.controller,
                  externalEditorPath: tabsController.externalEditorPath,
                  onPickProject: _pickProjectFolder,
                ),
        );
      },
    );
  }
}

class _ProjectTabBar extends StatelessWidget {
  const _ProjectTabBar({required this.tabsController, required this.onNewTab});

  final AppTabsController tabsController;
  final VoidCallback onNewTab;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kToolbarHeight,
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tabsController.tabs.length,
              itemBuilder: (context, index) {
                final tab = tabsController.tabs[index];
                final isActive = index == tabsController.activeIndex;
                return Material(
                  color: isActive
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : Colors.transparent,
                  child: InkWell(
                    onTap: () => tabsController.selectTab(index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(tab.label, overflow: TextOverflow.ellipsis),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => tabsController.closeTab(index),
                            child: const Icon(Icons.close, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            tooltip: 'New tab',
            icon: const Icon(Icons.add),
            onPressed: onNewTab,
          ),
        ],
      ),
    );
  }
}

class _TaskBoardBody extends StatelessWidget {
  const _TaskBoardBody({
    required this.controller,
    required this.externalEditorPath,
    required this.onPickProject,
  });

  final TaskBoardController controller;
  final String? externalEditorPath;
  final VoidCallback onPickProject;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.projectRoot == null) {
          return Center(
            child: FilledButton.icon(
              onPressed: onPickProject,
              icon: const Icon(Icons.folder_open),
              label: const Text('Open a project'),
            ),
          );
        }
        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.loadError != null) {
          return Center(child: Text(controller.loadError!, style: const TextStyle(color: Colors.red)));
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 260, child: _FiltersPanel(controller: controller)),
            const VerticalDivider(width: 1),
            Expanded(flex: 2, child: _TaskTable(controller: controller)),
            const VerticalDivider(width: 1),
            SizedBox(
              width: 340,
              child: _DependencyPanel(controller: controller, externalEditorPath: externalEditorPath),
            ),
          ],
        );
      },
    );
  }
}

class _FiltersPanel extends StatelessWidget {
  const _FiltersPanel({required this.controller});

  final TaskBoardController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Status', style: Theme.of(context).textTheme.titleMedium),
              TextButton(
                onPressed: controller.selectedStatuses.isEmpty ? null : controller.clearStatusFilter,
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SegmentedButton<FilterMode>(
            segments: const [
              ButtonSegment(value: FilterMode.exclude, label: Text('Exclude'), icon: Icon(Icons.block)),
              ButtonSegment(value: FilterMode.include, label: Text('Include'), icon: Icon(Icons.check)),
            ],
            selected: {controller.statusFilterMode},
            onSelectionChanged: (selection) => controller.setStatusFilterMode(selection.first),
          ),
          Expanded(
            child: ListView(
              children: controller.knownStatuses.map((status) {
                return CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(status),
                  value: controller.selectedStatuses.contains(status),
                  onChanged: (_) => controller.toggleStatus(status),
                );
              }).toList(),
            ),
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Type', style: Theme.of(context).textTheme.titleMedium),
              TextButton(
                onPressed: controller.selectedTypes.isEmpty ? null : controller.clearTypeFilter,
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SegmentedButton<FilterMode>(
            segments: const [
              ButtonSegment(value: FilterMode.exclude, label: Text('Exclude'), icon: Icon(Icons.block)),
              ButtonSegment(value: FilterMode.include, label: Text('Include'), icon: Icon(Icons.check)),
            ],
            selected: {controller.typeFilterMode},
            onSelectionChanged: (selection) => controller.setTypeFilterMode(selection.first),
          ),
          Expanded(
            child: ListView(
              children: controller.knownTypes.map((type) {
                return CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(type),
                  value: controller.selectedTypes.contains(type),
                  onChanged: (_) => controller.toggleType(type),
                );
              }).toList(),
            ),
          ),
          const Divider(),
          Text('Path', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              hintText: 'e.g. feature/',
              prefixIcon: Icon(Icons.filter_alt_outlined),
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: controller.setPathFilter,
          ),
        ],
      ),
    );
  }
}

class _TaskTable extends StatelessWidget {
  const _TaskTable({required this.controller});

  final TaskBoardController controller;

  @override
  Widget build(BuildContext context) {
    final tasks = controller.filteredTasks;
    if (tasks.isEmpty) {
      return const Center(child: Text('No tasks match the current filters.'));
    }
    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final isSelected = task.path == controller.selectedTaskPath;
        final colorScheme = Theme.of(context).colorScheme;
        return Container(
          decoration: isSelected
              ? BoxDecoration(
                  color: colorScheme.primaryContainer,
                  border: Border(left: BorderSide(color: colorScheme.primary, width: 4)),
                )
              : null,
          child: ListTile(
            selected: isSelected,
            selectedTileColor: colorScheme.primaryContainer,
            onTap: () => controller.selectTask(task.path),
            leading: _StatusDot(status: task.status),
            title: Text(
              task.title,
              style: isSelected ? const TextStyle(fontWeight: FontWeight.bold) : null,
            ),
            subtitle: Text(task.path),
            trailing: task.dependencies.isEmpty
                ? null
                : Chip(label: Text('${task.dependencies.length} deps')),
          ),
        );
      },
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final String status;

  static const _palette = {
    'created': Colors.blueGrey,
    'started': Colors.blue,
    'tested': Colors.orange,
    'deployed': Colors.purple,
    'finished': Colors.green,
  };

  @override
  Widget build(BuildContext context) {
    final color = _palette[status] ?? Colors.grey;
    return Tooltip(
      message: status,
      child: CircleAvatar(radius: 6, backgroundColor: color),
    );
  }
}

Future<void> _viewRawFile(BuildContext context, TaskBoardController controller, Task task) async {
  final content = await controller.readTaskFileRaw(task);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('${task.path} (read only)'),
      content: SizedBox(
        width: 700,
        height: 600,
        child: Markdown(data: content, selectable: true),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    ),
  );
}

class _DependencyPanel extends StatelessWidget {
  const _DependencyPanel({required this.controller, required this.externalEditorPath});

  final TaskBoardController controller;
  final String? externalEditorPath;

  @override
  Widget build(BuildContext context) {
    final task = controller.selectedTask;
    if (task == null) {
      return const Center(child: Text('Select a task to see its dependencies.'));
    }

    final dependents = controller.dependentsOf(task);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          Text(task.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(task.path, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            children: [
              _CopyButton(
                tooltip: 'Copy file name',
                icon: Icons.description_outlined,
                value: p.basename(task.path),
              ),
              _CopyButton(
                tooltip: 'Copy relative path',
                icon: Icons.folder_outlined,
                value: task.path,
              ),
              if (controller.projectRoot != null)
                _CopyButton(
                  tooltip: 'Copy absolute path',
                  icon: Icons.dns_outlined,
                  value: p.join(controller.projectRoot!, 'tasks', task.path),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text('status: ${task.status}')),
              Chip(label: Text('type: ${task.type}')),
              if (task.priority != null) Chip(label: Text('priority: ${task.priority}')),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _viewRawFile(context, controller, task),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Open file'),
              ),
              Builder(builder: (context) {
                final editorPath = externalEditorPath;
                return OutlinedButton.icon(
                  onPressed: editorPath == null
                      ? null
                      : () => controller.openTaskFileInEditor(task, editorPath),
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: const Text('Open with editor'),
                );
              }),
            ],
          ),
          const Divider(height: 24),
          Text('Depends on', style: Theme.of(context).textTheme.titleMedium),
          if (task.dependencies.isEmpty) const Text('None'),
          ..._dependencyTiles(context, task.dependencies),
          const Divider(height: 24),
          Text('Depended on by', style: Theme.of(context).textTheme.titleMedium),
          if (dependents.isEmpty) const Text('None'),
          ...dependents.map((t) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(t.title),
                subtitle: Text(t.path),
                onTap: () => controller.selectTask(t.path),
              )),
        ],
      ),
    );
  }

  List<Widget> _dependencyTiles(BuildContext context, List<String> deps) {
    return deps.map((depPath) {
      final resolved = controller.findByPath(depPath);
      return ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: resolved == null
            ? const Icon(Icons.error_outline, color: Colors.red, size: 18)
            : _StatusDot(status: resolved.status),
        title: Text(resolved?.title ?? depPath),
        subtitle: Text(depPath),
        onTap: resolved == null ? null : () => controller.selectTask(resolved.path),
      );
    }).toList();
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.tooltip, required this.icon, required this.value});

  final String tooltip;
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 18),
      visualDensity: VisualDensity.compact,
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: value));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Copied: $value'), duration: const Duration(seconds: 2)),
        );
      },
    );
  }
}
