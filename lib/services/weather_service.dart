import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// OpenWeatherMap API 서비스 (#44)
/// B6 Fix: API 키를 하드코딩 → SharedPreferences 저장/로드로 변경
class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  static const _baseUrl = 'https://api.openweathermap.org/data/2.5/weather';
  static const _prefsKey = 'openweathermap_api_key';

  // 서울 기본 좌표
  static const _defaultLat = 37.5665;
  static const _defaultLon = 126.9780;

  WeatherData? _cached;
  DateTime? _lastFetch;
  String? _apiKey;

  /// API 키 설정 (설정 화면에서 호출)
  Future<void> setApiKey(String key) async {
    _apiKey = key.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _apiKey!);
    // 캐시 무효화
    _cached = null;
    _lastFetch = null;
    debugPrint('[Weather] API key updated');
  }

  /// API 키 로드
  Future<String?> getApiKey() async {
    if (_apiKey != null && _apiKey!.isNotEmpty) return _apiKey;
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString(_prefsKey);
    return _apiKey;
  }

  /// API 키 설정 여부 확인
  Future<bool> hasValidApiKey() async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty && key != 'YOUR_OPENWEATHERMAP_API_KEY';
  }

  /// 현재 날씨 가져오기 (15분 캐시)
  Future<WeatherData?> getCurrentWeather({
    double? lat,
    double? lon,
  }) async {
    // 15분 이내 캐시 사용
    if (_cached != null && _lastFetch != null &&
        DateTime.now().difference(_lastFetch!).inMinutes < 15) {
      return _cached;
    }

    final key = await getApiKey();
    if (key == null || key.isEmpty || key == 'YOUR_OPENWEATHERMAP_API_KEY') {
      debugPrint('[Weather] API key not set — skipping fetch');
      return _cached;
    }

    final useLat = lat ?? _defaultLat;
    final useLon = lon ?? _defaultLon;

    try {
      final url = Uri.parse(
        '$_baseUrl?lat=$useLat&lon=$useLon&appid=$key'
        '&units=metric&lang=kr',
      );
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        _cached = WeatherData.fromJson(json);
        _lastFetch = DateTime.now();
        return _cached;
      } else if (response.statusCode == 401) {
        debugPrint('[Weather] 401 Unauthorized — API key invalid or expired');
        // 401이면 키가 잘못된 것이므로 null 반환 (이전 캐시도 무효)
        return null;
      } else {
        debugPrint('[Weather] API error: ${response.statusCode}');
        return _cached; // 다른 에러는 이전 캐시 반환
      }
    } catch (e) {
      debugPrint('[Weather] Fetch error: $e');
      return _cached;
    }
  }

  /// 브리핑용 날씨 텍스트
  Future<String> getWeatherBriefing() async {
    final hasKey = await hasValidApiKey();
    if (!hasKey) return '날씨 API 키가 설정되지 않았습니다. 설정에서 OpenWeatherMap API 키를 입력하세요.';

    final w = await getCurrentWeather();
    if (w == null) return '날씨 정보를 가져올 수 없습니다.';
    return w.briefingSummary;
  }

  /// 외출 시 옷차림 추천
  String getClothingAdvice(WeatherData w) {
    final t = w.temp;
    if (t >= 28) return '반팔, 반바지. 자외선 주의.';
    if (t >= 23) return '반팔 또는 얇은 긴팔.';
    if (t >= 17) return '긴팔, 가디건 준비.';
    if (t >= 12) return '자켓 또는 니트 필수.';
    if (t >= 5) return '코트, 두꺼운 외투.';
    return '패딩, 목도리. 방한 철저.';
  }

  /// 우산 필요 여부
  bool needsUmbrella(WeatherData w) {
    final m = w.main.toLowerCase();
    return m == 'rain' || m == 'drizzle' || m == 'thunderstorm';
  }
}