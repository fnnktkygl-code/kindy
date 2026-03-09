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

  WeatherData copyWith({
    double? temperature,
    String? condition,
    bool? isDay,
    DateTime? fetchedAt,
  }) {
    return WeatherData(
      temperature: temperature ?? this.temperature,
      condition: condition ?? this.condition,
      isDay: isDay ?? this.isDay,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WeatherData &&
        other.temperature == temperature &&
        other.condition == condition &&
        other.isDay == isDay;
  }

  @override
  int get hashCode => Object.hash(temperature, condition, isDay);
}

class WeatherService {
  static WeatherData? _cache;
  
  static Future<WeatherData?> fetchCurrent() async {
    // Return cache if less than 15 mins old
    if (_cache != null && DateTime.now().difference(_cache!.fetchedAt).inMinutes < 15) {
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
          // getLastKnownPosition can return null on first launch — fall back to live fix
          position ??= await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(timeLimit: Duration(seconds: 8)),
          );
        }
      }

      // Default to Paris if no location
      double lat = position?.latitude ?? 48.8566;
      double lon = position?.longitude ?? 2.3522;

      // If no GPS position, try IP-based geolocation as fallback
      if (position == null) {
        try {
          final geoResp = await http.get(Uri.parse('https://ipapi.co/json/')).timeout(const Duration(seconds: 5));
          if (geoResp.statusCode == 200) {
            final geo = jsonDecode(geoResp.body);
            if (geo['latitude'] is num && geo['longitude'] is num) {
              lat = (geo['latitude'] as num).toDouble();
              lon = (geo['longitude'] as num).toDouble();
            }
          }
        } catch (_) {
          // Fallback stays at Paris
        }
      }

      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon'
        '&current=weather_code,temperature_2m,is_day'
        '&current_weather=true',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Prefer new "current" block; fall back to legacy "current_weather".
        final current = data['current'] ?? data['current_weather'];
        final temp = ((current['temperature_2m'] ?? current['temperature']) as num).toDouble();

        // Open-Meteo WMO weather interpretation codes
        // https://open-meteo.com/en/docs#weathervariables
        final wmoCode = (current['weather_code'] ?? current['weathercode']) as int;
        final cond = _wmoToCondition(wmoCode);
        final isDay = (current['is_day'] is int)
            ? current['is_day'] == 1
            : current['is_day'] == true;

        _cache = WeatherData(
          temperature: temp, 
          condition: cond, 
          isDay: isDay,
          fetchedAt: DateTime.now(),
        );
        return _cache;
      }
    } catch (_) {
      // Fallback: offline return null
    }
    return null;
  }

  /// Maps WMO weather code to app condition string.
  static String _wmoToCondition(int code) {
    // 0       = Clear sky
    // 1-3     = Mainly clear, partly cloudy, overcast
    // 45, 48  = Fog, depositing rime fog
    // 51-57   = Drizzle (light → freezing)
    // 61-67   = Rain (slight → freezing)
    // 71-77   = Snow fall / snow grains
    // 80-82   = Rain showers (slight → violent)
    // 85-86   = Snow showers
    // 95      = Thunderstorm
    // 96, 99  = Thunderstorm with hail
    if (code >= 95) return 'storm';
    if (code >= 85 && code <= 86) return 'snow';
    if (code >= 80 && code <= 82) return 'rain';    // rain showers
    if (code >= 71 && code <= 77) return 'snow';     // snow fall + grains
    if (code >= 51 && code <= 67) return 'rain';     // drizzle + rain
    if (code >= 45 && code <= 48) return 'cloudy';   // fog
    if (code >= 1 && code <= 3) return 'cloudy';
    return 'sunny'; // code 0 = clear sky
  }
}
