import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_keys.dart';

class WeatherInfoWidget extends StatefulWidget {
  const WeatherInfoWidget({Key? key}) : super(key: key);

  @override
  State<WeatherInfoWidget> createState() => _WeatherInfoWidgetState();
}

class _WeatherInfoWidgetState extends State<WeatherInfoWidget> {
  String? _location;
  String? _weather;
  bool _loadingWeather = false;

  @override
  void initState() {
    super.initState();
    _getCityInfo();
  }

  Future<void> _getCityInfo() async {
    setState(() {
      _loadingWeather = true;
    });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _location = '定位未开启';
          _weather = null;
          _loadingWeather = false;
        });
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        setState(() {
          _location = '定位权限被拒绝，请在系统设置中开启定位权限';
          _weather = null;
          _loadingWeather = false;
        });
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _location = '定位权限永久被拒绝，请在系统设置中开启定位权限';
          _weather = null;
          _loadingWeather = false;
        });
        return;
      }
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        );
      } catch (_) {}
      if (position == null) {
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 10),
          );
        } catch (_) {}
      }
      if (position == null) {
        setState(() {
          _location = '无法获取定位信息';
          _weather = null;
          _loadingWeather = false;
        });
        return;
      }
      double lat = position.latitude;
      double lon = position.longitude;
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
      String city = placemarks.isNotEmpty ? placemarks.first.locality ?? '' : '';
      setState(() {
        _location = city.isNotEmpty ? city : '纬度: $lat, 经度: $lon';
      });
      final url = 'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$openWeatherMapApiKey&units=metric&lang=zh_cn';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final desc = data['weather'][0]['description'];
        final temp = data['main']['temp'];
        setState(() {
          _weather = '$desc, $temp°C';
        });
      } else {
        setState(() {
          _weather = '天气获取失败';
        });
      }
    } catch (e) {
      setState(() {
        _location = '定位/天气获取失败: $e';
        _weather = null;
      });
    } finally {
      setState(() {
        _loadingWeather = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingWeather) {
      return Padding(
        padding: const EdgeInsets.only(top: 32.0, bottom: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('获取位置和天气...'),
          ],
        ),
      );
    } else if (_location != null && _weather != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 32.0, bottom: 16.0),
        child: Column(
          children: [
            Text('当前位置：$_location', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text('天气：$_weather', style: const TextStyle(fontSize: 16)),
          ],
        ),
      );
    } else if (_location != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 32.0, bottom: 16.0),
        child: Text('$_location', style: const TextStyle(fontSize: 16)),
      );
    } else {
      return const SizedBox.shrink();
    }
  }
} 