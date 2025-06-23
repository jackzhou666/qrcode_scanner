import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'webview_page.dart';
import 'scan_history_page.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'api_keys.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox<String>('scan_history');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: '聚合扫码 V1.0'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? qrText;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  String? _location;
  String? _weather;
  bool _loadingWeather = false;

  @override
  void initState() {
    super.initState();
    _getLocationAndWeather();
  }

  Future<void> _getLocationAndWeather() async {
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
      // 权限处理增强
      LocationPermission permission = await Geolocator.checkPermission();
      print('初始定位权限: ' + permission.toString());
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        print('请求后定位权限: ' + permission.toString());
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
      print('准备获取经纬度...');
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 2),
        );
        print('高精度定位成功');
      } on TimeoutException catch (e) {
        print('高精度定位超时: ' + e.toString());
      } catch (e) {
        print('高精度定位失败: ' + e.toString());
      }
      if (position == null) {
        try {
          print('尝试低精度定位...');
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 2),
          );
          print('低精度定位成功');
          setState(() {
            _location = '（低精度）';
          });
        } on TimeoutException catch (e) {
          print('低精度定位超时: ' + e.toString());
        } catch (e) {
          print('低精度定位失败: ' + e.toString());
        }
      }
      if (position == null) {
        setState(() {
          _location = '无法获取定位信息';
          _weather = null;
        });
        return;
      }
      double lat = position.latitude;
      double lon = position.longitude;
      print('获取到经纬度: ' + lat.toString() + ', ' + lon.toString());
      // 逆地理编码获取城市名
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
      String city = placemarks.isNotEmpty ? placemarks.first.locality ?? '' : '';
      setState(() {
        _location = (city.isNotEmpty ? city : '纬度: $lat, 经度: $lon') + (_location == '（低精度）' ? '（低精度）' : '');
      });
      // 获取天气（OpenWeatherMap，需替换为你的API key）
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
    } on TimeoutException catch (e) {
      print('定位超时: ' + e.toString());
      setState(() {
        _location = '定位超时，请检查定位服务或尝试重启App';
        _weather = null;
      });
    } catch (e) {
      print('定位/天气获取异常: ' + e.toString());
      setState(() {
        _location = '定位/天气获取失败: ' + e.toString();
        _weather = null;
      });
    } finally {
      setState(() {
        _loadingWeather = false;
      });
    }
  }

  Future<void> _saveScanHistory(String content) async {
    final box = Hive.box<String>('scan_history');
    await box.add(content);
  }

  void _onQRViewCreated(QRViewController controller) {
    controller.scannedDataStream.listen((scanData) async {
      controller.pauseCamera();
      print('扫码结果: ${scanData.code}');
      setState(() {
        qrText = scanData.code;
      });
      await _saveScanHistory(scanData.code ?? '');
      Navigator.of(context).pop();

      final url = scanData.code;
      if (url != null && (url.startsWith('http://') || url.startsWith('https://'))) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (context.mounted) {
          final uri = Uri.parse(url);
          // 智能判断：支付类链接直接外部浏览器打开
          if (url.contains('pay.wps.cn')) {
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          } else {
            // 其他网页用 WebView 打开
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => WebViewPage(url: url)),
            );
          }
        }
      }
    });
  }

  void _scanQRCode() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: SizedBox(
          width: 300,
          height: 300,
          child: QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '扫码历史',
            onPressed: () async {
              // 显示炫酷加载动画对话框，页面不置灰
              showDialog(
                context: context,
                barrierDismissible: false,
                barrierColor: Colors.transparent,
                builder: (context) => Center(
                  child: Container(
                    constraints: BoxConstraints(minWidth: 120),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SpinKitFadingCircle(color: Colors.blue, size: 40),
                        SizedBox(height: 16),
                        Center(
                          child: Text(
                            '加载中...',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black,
                              decoration: TextDecoration.none,
                            ),
                            textAlign: TextAlign.center,
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
              // 延迟2秒
              await Future.delayed(const Duration(seconds: 2));
              // 关闭对话框
              Navigator.of(context).pop();
              // 跳转到扫码历史页面
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ScanHistoryPage()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_loadingWeather)
                Padding(
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
                )
              else if (_location != null && _weather != null)
                Padding(
                  padding: const EdgeInsets.only(top: 32.0, bottom: 16.0),
                  child: Column(
                    children: [
                      Text('当前位置：$_location', style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('天气：$_weather', style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                )
              else if (_location != null)
                Padding(
                  padding: const EdgeInsets.only(top: 32.0, bottom: 16.0),
                  child: Text('$_location', style: const TextStyle(fontSize: 16)),
                ),
              // 原有二维码信息显示
              Expanded(
                child: Center(
                  child: Text(
                    qrText == null ? '请扫描二维码' : '扫描结果: \n$qrText',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: Center(
              child: ElevatedButton(
                onPressed: _scanQRCode,
                child: const Text('扫描二维码'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
