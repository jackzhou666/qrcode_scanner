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
import 'weather_info_widget.dart';

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
              WeatherInfoWidget(),
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
