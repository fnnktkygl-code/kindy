// ignore_for_file: avoid_print, unused_local_variable, prefer_interpolation_to_compose_strings
import 'dart:convert';
import 'dart:io';

void main() async {
  print("🔍 Checking Gemini 2.5 Flash deprecation status...");

  final apiKey = Platform.environment['GEMINI_API_KEY'] ?? '';
  if (apiKey.isEmpty) {
    print("⚠️ Set the GEMINI_API_KEY environment variable before running this tool.");
    exit(1);
  }
  final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=\$apiKey');

  try {
    final client = HttpClient();
    final request = await client.getUrl(uri);
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    
    if (response.statusCode == 200) {
      final json = jsonDecode(responseBody);
      final models = json['models'] as List;
      
      final names = models.map((m) => m['name'] as String).toList();
      
      const targetModel = 'models/gemini-2.5-flash';
      
      if (names.contains(targetModel)) {
        print("✅ SUCCESS: \$targetModel is active and supported.");
      } else {
        print("❌ DANGER: \$targetModel is NOT found in the API list!");
        print("⚠️ ACTION REQUIRED: The model alias has been deprecated. Update PiGio immediately.");
        exit(1);
      }
    } else {
      print("⚠️ Error fetching models: HTTP \${response.statusCode}");
      print(responseBody);
      exit(1);
    }
    client.close();
  } catch (e) {
    print("⚠️ Network error while checking Gemini deprecation: \$e");
    exit(1);
  }
}
