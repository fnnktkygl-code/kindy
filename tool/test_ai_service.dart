// ignore_for_file: avoid_print, unused_local_variable, prefer_interpolation_to_compose_strings
import 'package:pigio_app/services/ai_service.dart';

void main() async {
  // 1. Test LaCentrale (Blocked URL, should return generic title, null price, null image, or deduced title)
  final url1 = 'https://www.lacentrale.fr/auto-occasion-annonce-69117007559.html';
  final result1 = await AiService.generateMagicWish(url1);
  print('--- Lacentrale test ---');
  print(result1);

  // 2. Test generic word (Text-only)
  final text2 = 'Une chaussette rouge';
  final result2 = await AiService.generateMagicWish(text2);
  print('--- Text test ---');
  print(result2);
}
