// ignore_for_file: avoid_print, unused_local_variable, prefer_interpolation_to_compose_strings
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

void main() async {
  final url = 'https://www.lacentrale.fr/auto-occasion-annonce-69117007559.html';
  try {
    final client = http.Client();
    final request = http.Request('GET', Uri.parse(url));
    request.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    
    final response = await client.send(request);
    final responseBody = await response.stream.bytesToString();
    
    print('Final URL: ' + response.request!.url.toString());
    print('Status Code: ' + response.statusCode.toString());
    
    final document = parse(responseBody);
    final title = document.querySelector('title')?.text ?? '';
    print('Title: ' + title);
    
    // check for specific car name in h1 or meta description
    final h1 = document.querySelector('h1')?.text ?? '';
    print('H1: ' + h1);
    
    final metaDesc = document.querySelector('meta[name="description"]')?.attributes['content'] ?? '';
    print('Meta Desc: ' + metaDesc);
    
    // Try to find a better image than og-lc.jpg
    final imgs = document.querySelectorAll('img');
    for (var img in imgs.take(10)) {
       final src = img.attributes['src'];
       final alt = img.attributes['alt'];
       if (src != null && src.contains('annonce')) {
         print('Possible Image: ' + src + ' (alt: ' + (alt ?? '') + ')');
       }
    }
  } catch (e) {
    print('Error: ' + e.toString());
  }
}
