// ignore_for_file: avoid_print, unused_local_variable, prefer_interpolation_to_compose_strings
import 'package:pigio_app/services/ai_service.dart';

void main() async {
  // Test multiple images for a car (LaCentrale often has many)
  final url = 'https://www.lacentrale.fr/auto-occasion-annonce-69117007559.html';
  final result = await AiService.generateMagicWish(url);
  
  print('--- Multi-Image Result ---');
  if (result != null) {
    print('Title: ${result['title']}');
    print('Suggested Images: ${result['suggestedImages']}');
    print('Price: ${result['priceRange']}');
  } else {
    print('Failed to get result.');
  }
}
