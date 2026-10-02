import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

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
  bool sold;
  String buyerName;
  String soldTime;

  Voucher({
    required this.id,
    required this.username,
    required this.password,
    required this.profile,
    required this.timeLimit,
    required this.dataLimit,
    required this.comment,
    this.sold = false,
    this.buyerName = '',
    this.soldTime = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'profile': profile,
      'timeLimit': timeLimit,
      'dataLimit': dataLimit,
      'comment': comment,
      'sold': sold,
      'buyerName': buyerName,
      'soldTime': soldTime,
    };
  }

  factory Voucher.fromJson(Map<String, dynamic> json) {
    return Voucher(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      profile: json['profile'] ?? '',
      timeLimit: json['timeLimit'] ?? '',
      dataLimit: json['dataLimit'] ?? '',
      comment: json['comment'] ?? '',
      sold: json['sold'] ?? false,
      buyerName: json['buyerName'] ?? '',
      soldTime: json['soldTime'] ?? '',
    );
  }
}

enum VoucherFilter {
  all,
  available,
  sold,
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String storageKey = 'hotspot_vouchers';

  List<Voucher> vouchers = [];
  VoucherFilter filter = VoucherFilter.all;

  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadVouchers();
    searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadVouchers() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(storageKey);

    if (saved == null || saved.isEmpty) {
      return;
    }

    try {
      final List<dynamic> data = jsonDecode(saved);

      setState(() {
        vouchers = data
            .map(
              (item) => Voucher.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList();
      });
    } catch (_) {
      // تجاهل البيانات غير الصالحة
    }
  }

  Future<void> saveVouchers() async {
    final prefs = await SharedPreferences.getInstance();

    final data = vouchers.map((voucher) => voucher.toJson()).toList();

    await prefs.setString(
      storageKey,
      jsonEncode(data),
    );
  }

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
      final content = utf8.decode(
        bytes,
        allowMalformed: true,
      );

      final rows = const CsvToListConverter(
        shouldParseNumbers: false,
        eol: '\n',
      ).convert(content);

      if (rows.isEmpty) {
        showMessage('ملف CSV فارغ');
        return;
      }

      final headers = rows.first
          .map(
            (e) => e.toString().trim().toLowerCase(),
          )
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
        showMessage(
          'ملف غير متوافق. يجب أن يحتوي على Username و Profile',
        );
        return;
      }

      final imported = <Voucher>[];

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];

        String value(int index) {
          if (index < 0 || index >= row.length) {
            return '';
          }
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

      if (imported.isEmpty) {
        showMessage('لم يتم العثور على كروت داخل الملف');
        return;
      }

      setState(() {
        vouchers = imported;
        filter = VoucherFilter.all;
        searchController.clear();
      });

      await saveVouchers();

      showMessage(
        'تم استيراد ${imported.length} كرت بنجاح',
      );
    } catch (e) {
      showMessage(
        'حدث خطأ أثناء قراءة الملف',
      );
    }
  }

  Future<void> sellVoucher(Voucher voucher) async {
    if (voucher.sold) {
      return;
    }

    final controller = TextEditingController();

    final buyerName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('بيع الكرت'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'رقم الكرت: ${voucher.username}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'الباقة: ${voucher.profile}',
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                autofocus: true,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  labelText: 'اسم المشتري',
                  hintText: 'مثلاً Mohammed',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(
                  context,
                  controller.text.trim(),
                );
              },
              icon: const Icon(Icons.check),
              label: const Text('تأكيد البيع'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (buyerName == null) {
      return;
    }

    voucher.sold = true;
    voucher.buyerName =
        buyerName.isEmpty ? '—' : buyerName;
    voucher.soldTime = formatDateTime(DateTime.now());

    setState(() {});

    await saveVouchers();

    showMessage(
      'تم تسجيل بيع الكرت ${voucher.username}',
    );
  }

  Future<void> shareVoucher(Voucher voucher) async {
    final text = voucher.timeLimit.isEmpty
        ? 'كرت الإنترنت: ${voucher.username}'
        : 'كرت الإنترنت: ${voucher.username}\nالباقة: ${voucher.profile}\nالمدة: ${voucher.timeLimit}';

    await Share.share(text);
  }

  Future<void> undoSale(Voucher voucher) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إلغاء البيع'),
          content: Text(
            'هل تريد إعادة الكرت ${voucher.username} إلى الكروت المتاحة؟',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('لا'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('نعم'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    voucher.sold = false;
    voucher.buyerName = '';
    voucher.soldTime = '';

    setState(() {});

    await saveVouchers();

    showMessage(
      'تم إلغاء بيع الكرت ${voucher.username}',
    );
  }

  String formatDateTime(DateTime dateTime) {
    final day =
        dateTime.day.toString().padLeft(2, '0');
    final month =
        dateTime.month.toString().padLeft(2, '0');
    final year =
        (dateTime.year % 100).toString().padLeft(2, '0');
    final hour =
        dateTime.hour.toString().padLeft(2, '0');
    final minute =
        dateTime.minute.toString().padLeft(2, '0');

    return '$day-$month-$year $hour:$minute';
  }

  List<Voucher> get filteredVouchers {
    final query =
        searchController.text.trim().toLowerCase();

    return vouchers.where((voucher) {
      if (filter == VoucherFilter.available &&
          voucher.sold) {
        return false;
      }

      if (filter == VoucherFilter.sold &&
          !voucher.sold) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      return voucher.username
              .toLowerCase()
              .contains(query) ||
          voucher.profile
              .toLowerCase()
              .contains(query) ||
          voucher.buyerName
              .toLowerCase()
              .contains(query);
    }).toList();
  }

  int get soldCount {
    return vouchers.where((v) => v.sold).length;
  }

  int get availableCount {
    return vouchers.where((v) => !v.sold).length;
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'إدارة كروت الإنترنت',
          ),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'استيراد CSV',
              onPressed: importCsv,
              icon: const Icon(
                Icons.upload_file,
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            _buildStats(),
            _buildSearch(),
            _buildFilters(),
            Expanded(
              child: vouchers.isEmpty
                  ? _emptyState()
                  : _buildVoucherList(),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: importCsv,
          icon: const Icon(Icons.upload_file),
          label: const Text('استيراد CSV'),
        ),
      ),
    );
  }

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        12,
        12,
        12,
        4,
      ),
      child: Row(
        children: [
          _statCard(
            'الإجمالي',
            vouchers.length,
            Icons.confirmation_number,
          ),
          _statCard(
            'المتاح',
            availableCount,
            Icons.check_circle_outline,
          ),
          _statCard(
            'المباع',
            soldCount,
            Icons.shopping_cart_outlined,
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    String title,
    int value,
    IconData icon,
  ) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 4,
          ),
          child: Column(
            children: [
              Icon(icon),
              const SizedBox(height: 4),
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: searchController,
        keyboardType: TextInputType.text,
        decoration: InputDecoration(
          hintText: 'ابحث برقم الكرت أو الاسم...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: searchController.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    searchController.clear();
                  },
                  icon: const Icon(Icons.clear),
                ),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              label: const Text('الكل'),
              selected: filter == VoucherFilter.all,
              onSelected: (_) {
                setState(() {
                  filter = VoucherFilter.all;
                });
              },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('المتاح'),
              selected:
                  filter == VoucherFilter.available,
              onSelected: (_) {
                setState(() {
                  filter = VoucherFilter.available;
                });
              },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('المباع'),
              selected:
                  filter == VoucherFilter.sold,
              onSelected: (_) {
                setState(() {
                  filter = VoucherFilter.sold;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
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
              label: const Text(
                'استيراد ملف الكروت',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoucherList() {
    final list = filteredVouchers;

    if (list.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد نتائج',
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        8,
        8,
        8,
        90,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final voucher = list[index];

        return Card(
          margin: const EdgeInsets.symmetric(
            vertical: 4,
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      child: Text(
                        '${voucher.id}',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                voucher.sold
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                size: 20,
                                color: voucher.sold
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                voucher.username,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Profile: ${voucher.profile}'
                            '${voucher.timeLimit.isEmpty ? '' : ' • ${voucher.timeLimit}'}',
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'إرسال رقم الكرت',
                          onPressed: () {
                            shareVoucher(voucher);
                          },
                          icon: const Icon(
                            Icons.share,
                          ),
                        ),
                        if (!voucher.sold)
                          FilledButton(
                            onPressed: () {
                              sellVoucher(voucher);
                            },
                            child: const Text('✓ بيع'),
                          )
                        else
                          IconButton(
                            tooltip: 'إلغاء البيع',
                            onPressed: () {
                              undoSale(voucher);
                            },
                            icon: const Icon(
                              Icons.undo,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (voucher.sold) ...[
                  const Divider(),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 19,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'المشتري: ${voucher.buyerName}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 19,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'وقت البيع: ${voucher.soldTime}',
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
