import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const HotspotCardsApp());
}

class HotspotCardsApp extends StatelessWidget {
  const HotspotCardsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'بائع الكروت',
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
      id: _toInt(json['id']),
      username: '${json['username'] ?? ''}',
      password: '${json['password'] ?? ''}',
      profile: '${json['profile'] ?? ''}',
      timeLimit: '${json['timeLimit'] ?? ''}',
      dataLimit: '${json['dataLimit'] ?? ''}',
      comment: '${json['comment'] ?? ''}',
      sold: json['sold'] == true,
      buyerName: '${json['buyerName'] ?? ''}',
      soldTime: '${json['soldTime'] ?? ''}',
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse('$value') ?? 0;
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

  // فلتر حسب Profile
  String selectedProfile = 'الكل';

  final TextEditingController searchController =
      TextEditingController();

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

    final data =
        vouchers.map((voucher) => voucher.toJson()).toList();

    await prefs.setString(
      storageKey,
      jsonEncode(data),
    );
  }

  Future<bool> verifyImportCode() async {
    final now = DateTime.now();
    final expectedCode = now.day * 999 * now.month;

    final controller = TextEditingController();

    final enteredCode = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('رمز السماح بالاستيراد'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'أدخل رمز اليوم',
              hintText: 'رمز الاستيراد',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(controller.text.trim());
              },
              child: const Text('تحقق'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (enteredCode == null) {
      return false;
    }

    if (enteredCode == expectedCode.toString()) {
      return true;
    }

    if (mounted) {
      showMessage('رمز الاستيراد غير صحيح');
    }

    return false;
  }

  Future<void> importCsv() async {
    final authorized = await verifyImportCode();

    if (!authorized) {
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    int totalAdded = 0;
    int totalDuplicates = 0;

    for (final file in result.files) {
      if (file.bytes == null || file.bytes!.isEmpty) {
        continue;
      }

      final result = await importCsvBytes(
        file.bytes!,
      );

      totalAdded += result.added;
      totalDuplicates += result.duplicates;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      filter = VoucherFilter.all;
      selectedProfile = 'الكل';
      searchController.clear();
    });

    await saveVouchers();

    if (totalAdded == 0 && totalDuplicates == 0) {
      showMessage(
        'لم يتم العثور على كروت جديدة في الملفات المحددة',
      );
      return;
    }

    String message =
        'تمت إضافة $totalAdded كرت بنجاح';

    if (totalDuplicates > 0) {
      message +=
          '\nتم تجاهل $totalDuplicates كرت مكرر';
    }

    showMessage(message);
  }

  Future<({int added, int duplicates})> importCsvBytes(
    List<int> bytes,
  ) async {
    int addedCount = 0;
    int duplicateCount = 0;

    try {
      var content = utf8.decode(
        bytes,
        allowMalformed: true,
      );

      // إزالة BOM إن وجد.
      content = content.replaceFirst(
        '\uFEFF',
        '',
      );

      final rows = const CsvToListConverter(
        shouldParseNumbers: false,
        eol: '\n',
      ).convert(content);

      if (rows.isEmpty) {
        return (
          added: 0,
          duplicates: 0,
        );
      }

      final headers = rows.first
          .map(
            (e) => e
                .toString()
                .trim()
                .toLowerCase(),
          )
          .toList();

      int indexOf(String name) {
        return headers.indexOf(
          name.toLowerCase(),
        );
      }

      final idIndex = indexOf('id');
      final usernameIndex = indexOf('username');
      final passwordIndex = indexOf('password');
      final profileIndex = indexOf('profile');
      final timeIndex = indexOf('time limit');
      final dataIndex = indexOf('data limit');
      final commentIndex = indexOf('comment');

      final soldIndex = indexOf('sold');
      final buyerNameIndex = indexOf('buyer name');
      final soldTimeIndex = indexOf('sold time');

      if (usernameIndex == -1 ||
          profileIndex == -1) {
        return (
          added: 0,
          duplicates: 0,
        );
      }

      String value(
        List<dynamic> row,
        int index,
      ) {
        if (index < 0 ||
            index >= row.length) {
          return '';
        }

        return row[index]
            .toString()
            .trim();
      }

      // --------------------------------------------------------
      // مفاتيح الكروت الموجودة حالياً.
      //
      // Username + Profile
      // مثال:
      // 1234567 + 3H
      // 1234567 + 12H
      // يعتبران كرتين مختلفين.
      // --------------------------------------------------------
      final existingKeys = <String>{
        for (final voucher in vouchers)
          _voucherKey(
            voucher.username,
            voucher.profile,
          ),
      };

      // IDs الموجودة بالفعل.
      final usedIds = <int>{
        for (final voucher in vouchers)
          voucher.id,
      };

      int nextId = 1;

      if (usedIds.isNotEmpty) {
        nextId = usedIds.reduce(
              (a, b) => a > b ? a : b,
            ) +
            1;
      }

      // --------------------------------------------------------
      // معالجة كل صف من الملف.
      // --------------------------------------------------------
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];

        final username = value(
          row,
          usernameIndex,
        );

        if (username.isEmpty) {
          continue;
        }

        final profile = value(
          row,
          profileIndex,
        );

        final key = _voucherKey(
          username,
          profile,
        );

        // ------------------------------------------------------
        // منع التكرار.
        // ------------------------------------------------------
        if (existingKeys.contains(key)) {
          duplicateCount++;
          continue;
        }

        final soldText = value(
          row,
          soldIndex,
        ).toLowerCase();

        final isSold =
            soldText == 'yes' ||
            soldText == 'true' ||
            soldText == '1' ||
            soldText == 'نعم' ||
            soldText == 'مباع';

        // ------------------------------------------------------
        // ID:
        // إذا كان ID موجودًا وغير مستخدم نحتفظ به.
        // إذا لم يكن صالحًا، نعطي الكرت ID جديدًا.
        // ------------------------------------------------------
        int id = int.tryParse(
              value(row, idIndex),
            ) ??
            0;

        if (id <= 0 || usedIds.contains(id)) {
          while (usedIds.contains(nextId)) {
            nextId++;
          }

          id = nextId;
          nextId++;
        }

        usedIds.add(id);

        // ------------------------------------------------------
        // إضافة الكرت مباشرة إلى القائمة الحالية.
        // لا نستخدم:
        //
        // vouchers = imported;
        //
        // لأن ذلك كان سبب اختفاء الملفات السابقة.
        // ------------------------------------------------------
        vouchers.add(
          Voucher(
            id: id,
            username: username,
            password: value(
              row,
              passwordIndex,
            ),
            profile: profile,
            timeLimit: value(
              row,
              timeIndex,
            ),
            dataLimit: value(
              row,
              dataIndex,
            ),
            comment: value(
              row,
              commentIndex,
            ),
            sold: isSold,
            buyerName: value(
              row,
              buyerNameIndex,
            ),
            soldTime: value(
              row,
              soldTimeIndex,
            ),
          ),
        );

        existingKeys.add(key);
        addedCount++;
      }

      return (
        added: addedCount,
        duplicates: duplicateCount,
      );
    } catch (_) {
      return (
        added: addedCount,
        duplicates: duplicateCount,
      );
    }
  }

  String _voucherKey(
    String username,
    String profile,
  ) {
    return '${username.trim().toLowerCase()}|'
        '${profile.trim().toLowerCase()}';
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
            crossAxisAlignment:
                CrossAxisAlignment.start,
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
    voucher.soldTime =
        formatDateTime(DateTime.now());

    setState(() {});

    await saveVouchers();

    showMessage(
      'تم تسجيل بيع الكرت ${voucher.username}',
    );
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
        (dateTime.year % 100)
            .toString()
            .padLeft(2, '0');

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

  List<Voucher> get statsVouchers {
    if (selectedProfile == 'الكل') {
      return vouchers;
    }

    return vouchers
        .where((v) => v.profile == selectedProfile)
        .toList();
  }

  int get totalCount => statsVouchers.length;

  int get soldCount =>
      statsVouchers.where((v) => v.sold).length;

  int get availableCount =>
      statsVouchers.where((v) => !v.sold).length;

  Future<String> createCsv({
    required bool remainingOnly,
  }) async {
    final list = remainingOnly
        ? vouchers.where((v) => !v.sold).toList()
        : vouchers;

    final rows = <List<dynamic>>[];

    if (remainingOnly) {
      rows.add([
        'Username',
        'Password',
        'Profile',
        'Time Limit',
        'Data Limit',
        'Comment',
      ]);

      for (final voucher in list) {
        rows.add([
          voucher.username,
          voucher.password,
          voucher.profile,
          voucher.timeLimit,
          voucher.dataLimit,
          voucher.comment,
        ]);
      }
    } else {
      rows.add([
        'ID',
        'Username',
        'Password',
        'Profile',
        'Time Limit',
        'Data Limit',
        'Comment',
        'Sold',
        'Buyer Name',
        'Sold Time',
      ]);

      for (final voucher in list) {
        rows.add([
          voucher.id,
          voucher.username,
          voucher.password,
          voucher.profile,
          voucher.timeLimit,
          voucher.dataLimit,
          voucher.comment,
          voucher.sold ? 'YES' : 'NO',
          voucher.buyerName,
          voucher.soldTime,
        ]);
      }
    }

    return const ListToCsvConverter().convert(rows);
  }

  Future<void> exportRemaining() async {
    if (availableCount == 0) {
      showMessage('لا توجد كروت متبقية للتصدير');
      return;
    }

    final csv = await createCsv(
      remainingOnly: true,
    );

    await shareCsv(
      csv,
      'hotspot_remaining_${fileDate()}.csv',
      'الكروت المتبقية',
    );
  }

  Future<void> exportAll() async {
    if (vouchers.isEmpty) {
      showMessage('لا توجد كروت للتصدير');
      return;
    }

    final csv = await createCsv(
      remainingOnly: false,
    );

    await shareCsv(
      csv,
      'hotspot_backup_${fileDate()}.csv',
      'نسخة احتياطية لجميع الكروت',
    );
  }

  Future<void> shareCsv(
    String csv,
    String fileName,
    String message,
  ) async {
    try {
      final directory =
          await getTemporaryDirectory();

      final file = File(
        '${directory.path}/$fileName',
      );

      await file.writeAsString(
        csv,
        encoding: utf8,
      );

      await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType: 'text/csv',
          ),
        ],
        text: message,
      );
    } catch (e) {
      showMessage(
        'تعذر إنشاء ملف CSV',
      );
    }
  }

  String fileDate() {
    final now = DateTime.now();

    final y = now.year.toString();
    final m =
        now.month.toString().padLeft(2, '0');
    final d =
        now.day.toString().padLeft(2, '0');

    return '$y-$m-$d';
  }

  Future<void> showImportOptions() async {
    await importCsv();
  }

  void showExportMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  title: Text(
                    'تصدير الكروت',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.inventory_2_outlined,
                  ),
                  title: const Text(
                    'تصدير المتبقي فقط',
                  ),
                  subtitle: Text(
                    'المتاح حالياً: $availableCount كرت',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    exportRemaining();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.backup_outlined,
                  ),
                  title: const Text(
                    'تصدير جميع الكروت',
                  ),
                  subtitle: Text(
                    'يشمل حالة البيع واسم المشتري ووقت البيع',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    exportAll();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> openWhatsApp() async {
    final uri = Uri.parse(
      'https://wa.me/249914111214',
    );

    if (!await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    )) {
      showMessage('تعذر فتح واتساب');
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> deleteAllVouchers() async {
    if (vouchers.isEmpty) {
      showMessage('لا توجد كروت لحذفها');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('حذف جميع الكروت؟'),
          content: Text(
            'سيتم حذف جميع الكروت الموجودة وعددها ${vouchers.length} كرت.\n\n'
            'يشمل ذلك الكروت المتاحة والمباعة وبيانات المبيعات.\n'
            'لا يمكن التراجع عن هذه العملية.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('حذف الكل'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      vouchers.clear();
      filter = VoucherFilter.all;
      selectedProfile = 'الكل';
      searchController.clear();
    });

    await saveVouchers();

    showMessage('تم حذف جميع الكروت بنجاح');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'بائع الكروت',
          ),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'استيراد CSV',
              onPressed: showImportOptions,
              icon: const Icon(
                Icons.upload_file,
              ),
            ),
            IconButton(
              tooltip: 'تصدير',
              onPressed: showExportMenu,
              icon: const Icon(
                Icons.ios_share,
              ),
            ),
            IconButton(
              tooltip: 'حذف الكل',
              onPressed: vouchers.isEmpty ? null : deleteAllVouchers,
              icon: const Icon(
                Icons.delete_sweep,
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
            _buildAppFooter(),
            const SizedBox(height: 80),
          ],
        ),
        floatingActionButton:
            FloatingActionButton.extended(
          onPressed: importCsv,
          icon: const Icon(
            Icons.upload_file,
          ),
          label: const Text(
            'استيراد CSV',
          ),
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
            totalCount,
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
        decoration: InputDecoration(
          hintText:
              'ابحث برقم الكرت أو الاسم...',
          prefixIcon: const Icon(
            Icons.search,
          ),
          suffixIcon:
              searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        searchController.clear();
                      },
                      icon: const Icon(
                        Icons.clear,
                      ),
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
              selected:
                  filter == VoucherFilter.all,
              onSelected: (_) {
                setState(() {
                  filter =
                      VoucherFilter.all;
                });
              },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('المتاح'),
              selected: filter ==
                  VoucherFilter.available,
              onSelected: (_) {
                setState(() {
                  filter =
                      VoucherFilter.available;
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
                  filter =
                      VoucherFilter.sold;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'جميع الحقوق محفوظة © ودبرير',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          InkWell(
            onTap: openWhatsApp,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.chat,
                  size: 16,
                ),
                SizedBox(width: 5),
                Text(
                  'واتساب: 0914111214',
                  style: TextStyle(
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ],
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
              icon: const Icon(
                Icons.upload_file,
              ),
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
          style: TextStyle(
            fontSize: 18,
          ),
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
                                style:
                                    const TextStyle(
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
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip:
                              'إرسال رقم الكرت',
                          onPressed: () {
                            shareVoucher(
                              voucher,
                            );
                          },
                          icon: const Icon(
                            Icons.share,
                          ),
                        ),
                        if (!voucher.sold)
                          FilledButton(
                            onPressed: () {
                              sellVoucher(
                                voucher,
                              );
                            },
                            child:
                                const Text('✓ بيع'),
                          )
                        else
                          IconButton(
                            tooltip:
                                'إلغاء البيع',
                            onPressed: () {
                              undoSale(
                                voucher,
                              );
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

  Future<void> shareVoucher(
    Voucher voucher,
  ) async {
    final text = voucher.timeLimit.isEmpty
        ? 'كرت الإنترنت: ${voucher.username}'
        : 'كرت الإنترنت: ${voucher.username}\n'
            'الباقة: ${voucher.profile}\n'
            'المدة: ${voucher.timeLimit}';

    await Share.share(text);
  }
}
