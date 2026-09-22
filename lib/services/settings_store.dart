import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// App-wide settings: which project tabs were open, which one was active,
/// and the preferred external editor for viewing a task's raw Markdown.
class AppSettings {
  final List<String> openProjects;
  final int activeTabIndex;
  final String? externalEditorPath;

  const AppSettings({
    this.openProjects = const [],
    this.activeTabIndex = 0,
    this.externalEditorPath,
  });

  Map<String, dynamic> toJson() => {
        'openProjects': openProjects,
        'activeTabIndex': activeTabIndex,
        'externalEditorPath': externalEditorPath,
      };

  factory AppSettings.fromJson(Map<dynamic, dynamic> json) => AppSettings(
        openProjects: (json['openProjects'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        activeTabIndex: json['activeTabIndex'] as int? ?? 0,
        externalEditorPath: json['externalEditorPath'] as String?,
      );
}

/// Persists [AppSettings] to a JSON file under the user's app-data
/// directory, so open tabs and preferences survive between sessions.
class SettingsStore {
  SettingsStore({File? file}) : _fileOverride = file;

  final File? _fileOverride;

  File _resolveFile() {
    if (_fileOverride != null) return _fileOverride;
    final base = Platform.environment['APPDATA'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    return File(p.join(base, 'McpTaskGui', 'settings.json'));
  }

  Future<AppSettings> load() async {
    final file = _resolveFile();
    try {
      if (!await file.exists()) return const AppSettings();
      final raw = await file.readAsString();
      final data = jsonDecode(raw);
      if (data is Map) return AppSettings.fromJson(data);
    } catch (_) {
      // Corrupted or unreadable settings file: fall back to defaults.
    }
    return const AppSettings();
  }

  Future<void> save(AppSettings settings) async {
    final file = _resolveFile();
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(settings.toJson()));
    } catch (_) {
      // Best-effort persistence; a failure here shouldn't crash the app.
    }
  }
}
