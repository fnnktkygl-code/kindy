import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pigio_logger.dart';

class AppReleaseInfo {
  final String version;
  final int buildNumber;
  final String downloadUrl;
  final String? releaseNotes;
  final bool isMandatory;

  AppReleaseInfo({
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    this.releaseNotes,
    this.isMandatory = false,
  });

  factory AppReleaseInfo.fromJson(Map<String, dynamic> json) {
    return AppReleaseInfo(
      version: json['version'] as String,
      buildNumber: json['build_number'] as int,
      downloadUrl: json['download_url'] as String,
      releaseNotes: json['release_notes'] as String?,
      isMandatory: json['is_mandatory'] as bool? ?? false,
    );
  }
}

class UpdateService {
  UpdateService._();

  static Future<AppReleaseInfo?> checkForUpdate() async {
    try {
      // 1. Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      // 2. Fetch latest release from Supabase
      final response = await Supabase.instance.client
          .from('app_releases')
          .select()
          .order('build_number', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      final latestRelease = AppReleaseInfo.fromJson(response);

      // 3. Compare build numbers
      if (latestRelease.buildNumber > currentBuildNumber) {
        log.info('UpdateService', 'New version available: ${latestRelease.version} (${latestRelease.buildNumber})');
        return latestRelease;
      }
      
      log.info('UpdateService', 'App is up to date.');
      return null;
    } catch (e, stack) {
      log.error('UpdateService', 'Error checking for update', e, stack);
      return null;
    }
  }
}
