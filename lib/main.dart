import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const HotspotCardsApp());
}

class HotspotCardsApp extends StatelessWidget {
  const HotspotCardsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'إدارة كروت الإنترنت',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
      ),
      home: const HomeScreen(),
    );
  }
}

class Voucher {
  final int id;
  final String username;
  final String password;
  final String profile;
  final String timeLimit;
  final String dataLimit;
  final String comment;

  const Voucher({
    required this.id,
    required this.username,
    required this.password,
    required this.profile,
    required this.timeLimit,
    required this.dataLimit,
    required this.comment,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Voucher> vouchers = [];

  Future<void> importCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) {
      return;
    }

    try {
      final bytes = result.files.single.bytes!;
      final content = utf8.decode(bytes, allowMalformed: true);

      final rows = const CsvToListConverter(
        shouldParseNumbers: false,
        eol: '\n',
      ).convert(content);

      if (rows.isEmpty) {
        return;
      }

      final headers = rows.first
          .map((e) => e.toString().trim().toLowerCase())
          .toList();

      int indexOf(String name) {
        return headers.indexOf(name.toLowerCase());
      }

      final usernameIndex = indexOf('username');
      final passwordIndex = indexOf('password');
      final profileIndex = indexOf('profile');
      final timeIndex = indexOf('time limit');
      final dataIndex = indexOf('data limit');
      final commentIndex = indexOf('comment');

      if (usernameIndex == -1 || profileIndex == -1) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'ملف CSV غير متوافق. يجب أن يحتوي على Username و Profile',
            ),
          ),
        );
        return;
      }

      final imported = <Voucher>[];

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];

        String value(int index) {
          if (index < 0 || index >= row.length) return '';
          return row[index].toString().trim();
        }

        final username = value(usernameIndex);

        if (username.isEmpty) {
          continue;
        }

        imported.add(
          Voucher(
            id: imported.length + 1,
            username: username,
            password: value(passwordIndex),
            profile: value(profileIndex),
            timeLimit: value(timeIndex),
            dataLimit: value(dataIndex),
            comment: value(commentIndex),
          ),
        );
      }

      setState(() {
        vouchers = imported;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم استيراد ${imported.length} كرت بنجاح',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء قراءة الملف: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة كروت الإنترنت'),
        centerTitle: true,
      ),
      body: vouchers.isEmpty
          ? _emptyState()
          : _voucherList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: importCsv,
        icon: const Icon(Icons.upload_file),
        label: const Text('استيراد CSV'),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.confirmation_number_outlined,
              size: 80,
            ),
            const SizedBox(height: 20),
            const Text(
              'لا توجد كروت',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'استورد ملف CSV الذي تم تصديره من Mikhmon',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 25),
            FilledButton.icon(
              onPressed: importCsv,
              icon: const Icon(Icons.upload_file),
              label: const Text('استيراد ملف الكروت'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _voucherList() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Text(
            'عدد الكروت: ${vouchers.length}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: vouchers.length,
            itemBuilder: (context, index) {
              final voucher = vouchers[index];

              return ListTile(
                leading: CircleAvatar(
                  child: Text('${voucher.id}'),
                ),
                title: Text(
                  voucher.username,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '${voucher.profile} • ${voucher.timeLimit}',
                ),
                trailing: const Icon(
                  Icons.close,
                  color: Colors.red,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
