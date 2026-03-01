import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class WeatherData {
  final double temperature;
  final String condition;
  final bool isDay;
  final DateTime fetchedAt;

  WeatherData({
    required this.temperature,
    required this.condition,
    required this.isDay,
    required this.fetchedAt,
  });
}

class WeatherService {
  static WeatherData? _cache;
  
  static Future<WeatherData?> fetchCurrent() async {
    // Return cache if less than 30 mins old
    if (_cache != null && DateTime.now().difference(_cache!.fetchedAt).inMinutes < 30) {
      return _cache;
    }

    try {
      Position? position;
      
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        
        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          position = await Geolocator.getLastKnownPosition();
        }
      }

      // Default to Paris if no location
      double lat = position?.latitude ?? 48.8566;
      double lon = position?.longitude ?? 2.3522;

      final url = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true');
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final current = data['current_weather'];
        final temp = (current['temperature'] as num).toDouble();
        
        // Open-Meteo WMO codes
        final wmoCode = current['weathercode'] as int;
        String cond = 'sunny';
        if (wmoCode >= 51 && wmoCode <= 67) { cond = 'rain'; }
        else if (wmoCode >= 71 && wmoCode <= 82) { cond = 'snow'; }
        else if (wmoCode >= 95) { cond = 'storm'; }
        else if (wmoCode == 1 || wmoCode == 2 || wmoCode == 3) { cond = 'cloudy'; }

        _cache = WeatherData(
          temperature: temp, 
          condition: cond, 
          isDay: current['is_day'] == 1,
          fetchedAt: DateTime.now(),
        );
        return _cache;
      }
    } catch (_) {
      // Fallback: offline return null
    }
    return null;
  }
}
