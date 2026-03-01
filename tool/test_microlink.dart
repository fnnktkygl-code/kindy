// ignore_for_file: avoid_print, unused_local_variable, prefer_interpolation_to_compose_strings
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = 'https://www.lacentrale.fr/auto-occasion-annonce-69117007559.html';
  final encodedUrl = Uri.encodeComponent(url);
  final res = await http.get(Uri.parse('https://api.microlink.io?url=$encodedUrl'));
  
  print('Status: ${res.statusCode}');
  print('Body: ${res.body}');
  if (res.statusCode == 200) {
    final data = jsonDecode(res.body);
    print('Data: ' + JsonEncoder.withIndent('  ').convert(data['data']));
  }
}
