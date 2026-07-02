import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() async {
  print('Initializing Supabase...');
  await Supabase.initialize(
    url: 'https://vcnelfgziucsyukahhey.supabase.co',
    anonKey: 'sb_publishable_wzRubrYmP5G_hJFlW8BScg_pNeHzSiQ',
  );

  print('Fetching latest release from app_releases table...');
  try {
    final response = await Supabase.instance.client
        .from('app_releases')
        .select()
        .order('build_number', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) {
      print('❌ No release found in the database.');
    } else {
      print('✅ Release found!');
      print('Version: ${response['version']}');
      print('Build Number: ${response['build_number']}');
      print('Download URL: ${response['download_url']}');
      print('Release Notes: ${response['release_notes']}');

      final currentBuildNumber = 3; // Simulating old version
      print('\nSimulating old app version (build number $currentBuildNumber)...');
      
      if (response['build_number'] > currentBuildNumber) {
        print('✅ UPDATE TRIGGERED: App will show the update dialog!');
      } else {
        print('❌ UPDATE NOT TRIGGERED: Build numbers do not match criteria.');
      }
    }
  } catch (e) {
    print('❌ Error fetching from Supabase: $e');
  }
}
