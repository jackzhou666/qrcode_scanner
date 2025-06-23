import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/services.dart';

class ScanHistoryPage extends StatefulWidget {
  const ScanHistoryPage({super.key});

  @override
  State<ScanHistoryPage> createState() => _ScanHistoryPageState();
}

class _ScanHistoryPageState extends State<ScanHistoryPage> {
  late Box<String> _box;

  @override
  void initState() {
    super.initState();
    _box = Hive.box<String>('scan_history');
  }

  void _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('内容已复制到剪贴板')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扫码历史')),
      body: ValueListenableBuilder(
        valueListenable: _box.listenable(),
        builder: (context, Box<String> box, _) {
          final items = box.values.toList().reversed.toList(); // 最新的在最上面
          if (items.isEmpty) {
            return const Center(child: Text('暂无扫码记录'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                title: Text(item),
                onLongPress: () => _copyToClipboard(item),
              );
            },
          );
        },
      ),
    );
  }
} 