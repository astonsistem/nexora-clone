class AppUpdateInfo {
  const AppUpdateInfo({
    required this.updateAvailable,
    required this.forceUpdate,
    required this.currentVersion,
    this.latestVersion,
    this.releaseNotes,
    this.updateUrl,
    this.applicationName,
  });

  final bool updateAvailable;
  final bool forceUpdate;
  final String currentVersion;
  final String? latestVersion;
  final String? releaseNotes;
  final String? updateUrl;
  final String? applicationName;

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    final row = json['app_update'] is Map<String, dynamic>
        ? json['app_update'] as Map<String, dynamic>
        : json;

    return AppUpdateInfo(
      updateAvailable: row['update_available'] == true,
      forceUpdate: row['force_update'] == true,
      currentVersion: row['current_version']?.toString() ?? '',
      latestVersion: row['latest_version']?.toString(),
      releaseNotes: row['release_notes']?.toString(),
      updateUrl: row['update_url']?.toString(),
      applicationName: row['application_name']?.toString(),
    );
  }
}
