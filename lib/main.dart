import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  String selectedProfile = 'الكل';

  final TextEditingController searchController =
      TextEditingController();

  bool _showHeader = true;

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

  // ============================================================
  // ألوان Profiles
  // ============================================================

  static const List<Color> _profileColors = [
    Color(0xFFE3F2FD),
    Color(0xFFE8F5E9),
    Color(0xFFFFF3E0),
    Color(0xFFF3E5F5),
    Color(0xFFFFEBEE),
    Color(0xFFE0F7FA),
    Color(0xFFFFFDE7),
    Color(0xFFEDE7F6),
    Color(0xFFFCE4EC),
    Color(0xFFE0F2F1),
    Color(0xFFF1F8E9),
    Color(0xFFFFF8E1),
  ];

  static const List<Color> _profileAccentColors = [
    Color(0xFF1976D2),
    Color(0xFF388E3C),
    Color(0xFFF57C00),
    Color(0xFF7B1FA2),
    Color(0xFFD32F2F),
    Color(0xFF00838F),
    Color(0xFFF9A825),
    Color(0xFF512DA8),
    Color(0xFFC2185B),
    Color(0xFF00796B),
    Color(0xFF689F38),
    Color(0xFFFF8F00),
  ];

  int _profileColorIndex(String profile) {
    final normalized = profile.trim().toLowerCase();

    if (normalized.isEmpty) {
      return 0;
    }

    int hash = 0;

    for (final codeUnit in normalized.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }

    return hash % _profileColors.length;
  }

  Color _profileBackgroundColor(String profile) {
    return _profileColors[_profileColorIndex(profile)];
  }

  Color _profileAccentColor(String profile) {
    return _profileAccentColors[_profileColorIndex(profile)];
  }

  // ============================================================
  // تحميل وحفظ
  // ============================================================

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

  // ============================================================
  // رمز الاستيراد
  // ============================================================

  Future<bool> verifyImportCode() async {
    final now = DateTime.now();

    final expectedCode =
        now.day * 999 * now.month;

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
              onPressed: () =>
                  Navigator.of(context).pop(null),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(
                  controller.text.trim(),
                );
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

  // ============================================================
  // استيراد CSV
  // ============================================================

  Future<void> importCsv() async {
    final authorized = await verifyImportCode();

    if (!authorized) {
      return;
    }

    final result =
        await FilePicker.platform.pickFiles(
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
      if (file.bytes == null ||
          file.bytes!.isEmpty) {
        continue;
      }

      final importResult =
          await importCsvBytes(file.bytes!);

      totalAdded += importResult.added;
      totalDuplicates += importResult.duplicates;
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

    if (totalAdded == 0 &&
        totalDuplicates == 0) {
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
      final usernameIndex =
          indexOf('username');
      final passwordIndex =
          indexOf('password');
      final profileIndex =
          indexOf('profile');
      final timeIndex =
          indexOf('time limit');
      final dataIndex =
          indexOf('data limit');
      final commentIndex =
          indexOf('comment');

      final soldIndex = indexOf('sold');
      final buyerNameIndex =
          indexOf('buyer name');
      final soldTimeIndex =
          indexOf('sold time');

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

      final existingKeys = <String>{
        for (final voucher in vouchers)
          _voucherKey(
            voucher.username,
            voucher.profile,
          ),
      };

      final usedIds = <int>{
        for (final voucher in vouchers)
          voucher.id,
      };

      int nextId = 1;

      if (usedIds.isNotEmpty) {
        nextId =
            usedIds.reduce(
              (a, b) => a > b ? a : b,
            ) +
            1;
      }

      for (int i = 1;
          i < rows.length;
          i++) {
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

        int id =
            int.tryParse(
              value(row, idIndex),
            ) ??
            0;

        if (id <= 0 ||
            usedIds.contains(id)) {
          while (usedIds.contains(nextId)) {
            nextId++;
          }

          id = nextId;
          nextId++;
        }

        usedIds.add(id);

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

  // ============================================================
  // البيع
  // ============================================================

  Future<void> sellVoucher(
    Voucher voucher,
  ) async {
    if (voucher.sold) {
      return;
    }

    final controller =
        TextEditingController();

    final buyerName =
        await showDialog<String>(
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
                textDirection:
                    TextDirection.rtl,
                decoration:
                    const InputDecoration(
                  labelText: 'اسم المشتري',
                  hintText:
                      'مثلاً Mohammed',
                  border:
                      OutlineInputBorder(),
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
              icon: const Icon(
                Icons.check,
              ),
              label:
                  const Text('تأكيد البيع'),
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
        buyerName.isEmpty
            ? '—'
            : buyerName;

    voucher.soldTime =
        formatDateTime(DateTime.now());

    setState(() {});

    await saveVouchers();

    showMessage(
      'تم تسجيل بيع الكرت ${voucher.username}',
    );
  }

  Future<void> undoSale(
    Voucher voucher,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:
              const Text('إلغاء البيع'),
          content: Text(
            'هل تريد إعادة الكرت '
            '${voucher.username} '
            'إلى الكروت المتاحة؟',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text('لا'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
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

  String formatDateTime(
    DateTime dateTime,
  ) {
    final day = dateTime.day
        .toString()
        .padLeft(2, '0');

    final month = dateTime.month
        .toString()
        .padLeft(2, '0');

    final year = (dateTime.year % 100)
        .toString()
        .padLeft(2, '0');

    final hour = dateTime.hour
        .toString()
        .padLeft(2, '0');

    final minute = dateTime.minute
        .toString()
        .padLeft(2, '0');

    return '$day-$month-$year '
        '$hour:$minute';
  }

  // ============================================================
  // الفلاتر
  // ============================================================

  List<Voucher> get filteredVouchers {
    final query = searchController.text
        .trim()
        .toLowerCase();

    return vouchers.where((voucher) {
      if (selectedProfile != 'الكل' &&
          voucher.profile !=
              selectedProfile) {
        return false;
      }

      if (filter ==
              VoucherFilter.available &&
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
        .where(
          (v) =>
              v.profile ==
              selectedProfile,
        )
        .toList();
  }

  int get totalCount =>
      statsVouchers.length;

  int get soldCount =>
      statsVouchers
          .where((v) => v.sold)
          .length;

  int get availableCount =>
      statsVouchers
          .where((v) => !v.sold)
          .length;

  // ============================================================
  // CSV
  // ============================================================

  Future<String> createCsv({
    required bool remainingOnly,
  }) async {
    final list = remainingOnly
        ? vouchers
            .where((v) => !v.sold)
            .toList()
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

    return const ListToCsvConverter()
        .convert(rows);
  }

  Future<void> exportRemaining() async {
    if (availableCount == 0) {
      showMessage(
        'لا توجد كروت متبقية للتصدير',
      );
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
      showMessage(
        'لا توجد كروت للتصدير',
      );
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

    final m = now.month
        .toString()
        .padLeft(2, '0');

    final d = now.day
        .toString()
        .padLeft(2, '0');

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
            textDirection:
                TextDirection.rtl,
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                const ListTile(
                  title: Text(
                    'تصدير الكروت',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons
                        .inventory_2_outlined,
                  ),
                  title: const Text(
                    'تصدير المتبقي فقط',
                  ),
                  subtitle: Text(
                    'المتاح حالياً: '
                    '$availableCount كرت',
                  ),
                  onTap: () {
                    Navigator.pop(
                      context,
                    );
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
                  subtitle: const Text(
                    'يشمل حالة البيع واسم '
                    'المشتري ووقت البيع',
                  ),
                  onTap: () {
                    Navigator.pop(
                      context,
                    );
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
      mode:
          LaunchMode.externalApplication,
    )) {
      showMessage(
        'تعذر فتح واتساب',
      );
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> deleteAllVouchers() async {
    if (vouchers.isEmpty) {
      showMessage(
        'لا توجد كروت لحذفها',
      );
      return;
    }

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'حذف جميع الكروت؟',
          ),
          content: Text(
            'سيتم حذف جميع الكروت الموجودة '
            'وعددها ${vouchers.length} كرت.\n\n'
            'يشمل ذلك الكروت المتاحة والمباعة '
            'وبيانات المبيعات.\n'
            'لا يمكن التراجع عن هذه العملية.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context)
                      .pop(false),
              child: const Text(
                'إلغاء',
              ),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context)
                      .pop(true),
              child: const Text(
                'حذف الكل',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      vouchers.clear();
      filter = VoucherFilter.all;
      selectedProfile = 'الكل';
      searchController.clear();
    });

    await saveVouchers();

    showMessage(
      'تم حذف جميع الكروت بنجاح',
    );
  }

  // ============================================================
  // الواجهة الرئيسية
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: _showHeader
            ? AppBar(
                toolbarHeight: 48,
                title: const Text(
                  'بائع الكروت',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                centerTitle: true,
                actions: [
                  IconButton(
                    tooltip: 'استيراد CSV',
                    onPressed:
                        showImportOptions,
                    icon: const Icon(
                      Icons.upload_file,
                      size: 21,
                    ),
                  ),
                  IconButton(
                    tooltip: 'تصدير',
                    onPressed: showExportMenu,
                    icon: const Icon(
                      Icons.ios_share,
                      size: 21,
                    ),
                  ),
                  IconButton(
                    tooltip: 'حذف الكل',
                    onPressed: vouchers.isEmpty
                        ? null
                        : deleteAllVouchers,
                    icon: const Icon(
                      Icons.delete_sweep,
                      size: 21,
                    ),
                  ),
                ],
              )
            : null,
        body: Column(
          children: [
            _buildStats(),
            _buildSearch(),
            _buildFilters(),
            Expanded(
              child: vouchers.isEmpty
                  ? _emptyState()
                  : NotificationListener<
                      UserScrollNotification>(
                      onNotification:
                          (notification) {
                        if (notification
                                .direction ==
                            ScrollDirection
                                .reverse) {
                          if (_showHeader) {
                            setState(() {
                              _showHeader =
                                  false;
                            });
                          }
                        } else if (notification
                                .direction ==
                            ScrollDirection
                                .forward) {
                          if (!_showHeader) {
                            setState(() {
                              _showHeader =
                                  true;
                            });
                          }
                        }

                        return false;
                      },
                      child:
                          _buildVoucherList(),
                    ),
            ),

            // ==================================================
            // الحقوق + واتساب في الجهة المقابلة لزر الاستيراد
            // ==================================================
            _buildBottomBar(),
          ],
        ),

        // زر الاستيراد يبقى في الأسفل.
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
        floatingActionButtonLocation:
            FloatingActionButtonLocation
                .startFloat,
      ),
    );
  }

  // ============================================================
  // الشريط السفلي
  // ============================================================

  Widget _buildBottomBar() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        8,
        2,
        8,
        5,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.end,
        children: [
          InkWell(
            onTap: openWhatsApp,
            child: const Row(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Icon(
                  Icons.chat,
                  size: 15,
                ),
                SizedBox(width: 4),
                Text(
                  'واتساب: 0914111214',
                  style: TextStyle(
                    fontSize: 11,
                    decoration:
                        TextDecoration
                            .underline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 1,
            height: 14,
            color: Colors.grey,
          ),
          const SizedBox(width: 10),
          const Text(
            '© ودبرير',
            style: TextStyle(
              fontSize: 11,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // الإحصائيات
  // ============================================================

  Widget _buildStats() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        8,
        5,
        8,
        2,
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
        margin: const EdgeInsets.symmetric(
          horizontal: 2,
        ),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(
            vertical: 5,
            horizontal: 3,
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
              ),
              const SizedBox(width: 4),
              Text(
                '$value',
                style:
                    const TextStyle(
                  fontSize: 17,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                title,
                style:
                    const TextStyle(
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // البحث
  // ============================================================

  Widget _buildSearch() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        8,
        3,
        8,
        3,
      ),
      child: SizedBox(
        height: 46,
        child: TextField(
          controller:
              searchController,
          decoration:
              InputDecoration(
            hintText:
                'ابحث برقم الكرت أو الاسم...',
            prefixIcon: const Icon(
              Icons.search,
              size: 21,
            ),
            suffixIcon:
                searchController
                        .text
                        .isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          searchController
                              .clear();
                        },
                        icon: const Icon(
                          Icons.clear,
                          size: 20,
                        ),
                      ),
            border:
                const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // الفلاتر
  // ============================================================

  Widget _buildFilters() {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
      ),
      child:
          SingleChildScrollView(
        scrollDirection:
            Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              label:
                  const Text('الكل'),
              selected:
                  filter ==
                      VoucherFilter.all,
              onSelected: (_) {
                setState(() {
                  filter =
                      VoucherFilter.all;
                });
              },
            ),
            const SizedBox(width: 5),
            ChoiceChip(
              label:
                  const Text('المتاح'),
              selected:
                  filter ==
                      VoucherFilter
                          .available,
              onSelected: (_) {
                setState(() {
                  filter =
                      VoucherFilter
                          .available;
                });
              },
            ),
            const SizedBox(width: 5),
            ChoiceChip(
              label:
                  const Text('المباع'),
              selected:
                  filter ==
                      VoucherFilter.sold,
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

  // ============================================================
  // الحالة الفارغة
  // ============================================================

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons
                  .confirmation_number_outlined,
              size: 70,
            ),
            const SizedBox(height: 15),
            const Text(
              'لا توجد كروت',
              style: TextStyle(
                fontSize: 22,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'استورد ملف CSV الذي تم '
              'تصديره من Mikhmon',
              textAlign:
                  TextAlign.center,
            ),
            const SizedBox(height: 20),
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

  // ============================================================
  // قائمة الكروت
  // ============================================================

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
      padding:
          const EdgeInsets.fromLTRB(
        6,
        4,
        6,
        75,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final voucher = list[index];

        final profileBackground =
            _profileBackgroundColor(
          voucher.profile,
        );

        final profileAccent =
            _profileAccentColor(
          voucher.profile,
        );

        return Card(
          color: profileBackground,
          margin:
              const EdgeInsets.symmetric(
            vertical: 2,
          ),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(10),
            side: BorderSide(
              color: profileAccent
                  .withOpacity(0.28),
              width: 1,
            ),
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 7,
              vertical: 5,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          profileAccent,
                      foregroundColor:
                          Colors.white,
                      child: Text(
                        '${voucher.id}',
                        style:
                            const TextStyle(
                          fontSize: 12,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 7,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                voucher.sold
                                    ? Icons
                                        .check_circle
                                    : Icons
                                        .cancel,
                                size: 18,
                                color: voucher
                                        .sold
                                    ? Colors
                                        .green
                                    : Colors
                                        .red,
                              ),
                              const SizedBox(
                                width: 5,
                              ),
                              Flexible(
                                child: Text(
                                  voucher
                                      .username,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      const TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 2,
                          ),

                          // اسم Profile بلون خاص به
                          Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  profileAccent
                                      .withOpacity(
                                0.12,
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                5,
                              ),
                            ),
                            child: Text(
                              'Profile: ${voucher.profile}'
                              '${voucher.timeLimit.isEmpty ? '' : ' • ${voucher.timeLimit}'}',
                              style:
                                  TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    FontWeight
                                        .w600,
                                color:
                                    profileAccent,
                              ),
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      width: 3,
                    ),
                    Row(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip:
                              'إرسال رقم الكرت',
                          visualDensity:
                              VisualDensity
                                  .compact,
                          padding:
                              const EdgeInsets
                                  .all(4),
                          constraints:
                              const BoxConstraints(
                            minWidth: 34,
                            minHeight: 34,
                          ),
                          onPressed: () {
                            shareVoucher(
                              voucher,
                            );
                          },
                          icon: const Icon(
                            Icons.share,
                            size: 20,
                          ),
                        ),
                        if (!voucher.sold)
                          FilledButton(
                            style:
                                FilledButton
                                    .styleFrom(
                              minimumSize:
                                  const Size(
                                48,
                                34,
                              ),
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal: 8,
                              ),
                              visualDensity:
                                  VisualDensity
                                      .compact,
                            ),
                            onPressed: () {
                              sellVoucher(
                                voucher,
                              );
                            },
                            child:
                                const Text(
                              '✓ بيع',
                              style:
                                  TextStyle(
                                fontSize: 12,
                              ),
                            ),
                          )
                        else
                          IconButton(
                            tooltip:
                                'إلغاء البيع',
                            visualDensity:
                                VisualDensity
                                    .compact,
                            padding:
                                const EdgeInsets
                                    .all(4),
                            constraints:
                                const BoxConstraints(
                              minWidth: 34,
                              minHeight: 34,
                            ),
                            onPressed: () {
                              undoSale(
                                voucher,
                              );
                            },
                            icon: const Icon(
                              Icons.undo,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // بيانات البيع
                if (voucher.sold) ...[
                  const Divider(
                    height: 8,
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons
                            .person_outline,
                        size: 17,
                      ),
                      const SizedBox(
                        width: 5,
                      ),
                      Expanded(
                        child: Text(
                          'المشتري: ${voucher.buyerName}',
                          style:
                              const TextStyle(
                            fontSize: 12,
                          ),
                          overflow:
                              TextOverflow
                                  .ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 3,
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 17,
                      ),
                      const SizedBox(
                        width: 5,
                      ),
                      Text(
                        'وقت البيع: ${voucher.soldTime}',
                        style:
                            const TextStyle(
                          fontSize: 12,
                        ),
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

  // ============================================================
  // مشاركة الكرت
  // ============================================================

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