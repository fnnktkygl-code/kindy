// ignore_for_file: avoid_print, unused_local_variable, prefer_interpolation_to_compose_strings
import 'package:pigio_app/services/ai_service.dart';

void main() async {
  print('--- Testing AI Service with New API Key and Usage Logging ---');
  
  final input = 'Un livre de science-fiction';
  print('Requesting Magic Wish for: "$input"');
  
  final result = await AiService.generateMagicWish(input);
  
  if (result != null) {
    print('Result: ${result['title']}');
  } else {
    print('Failed to get result.');
  }
}
