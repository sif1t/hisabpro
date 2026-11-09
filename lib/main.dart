import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  runApp(const HisabProApp());
}

// ============================================================================
// BANGLADESHI CURRENCY (৳ BDT) & INTEGER PAISA ARITHMETIC FORMATTER
// ============================================================================
class BdFormat {
  static const String symbol = '৳';

  static int parseTakaToPaisa(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^0-9.]'), '').trim();
    if (cleaned.isEmpty) return 0;
    final parts = cleaned.split('.');
    final taka = int.tryParse(parts[0].isEmpty ? '0' : parts[0]) ?? 0;
    int paisa = 0;
    if (parts.length > 1) {
      final dec = parts[1].padRight(2, '0').substring(0, 2);
      paisa = int.tryParse(dec) ?? 0;
    }
    return (taka * 100) + paisa;
  }

  static String paisa(int paisaValue, {bool showSymbol = true}) {
    final isNeg = paisaValue < 0;
    final absVal = paisaValue.abs();
    final taka = absVal ~/ 100;
    final rem = absVal % 100;

    final intStr = _formatBdInt(taka);
    final decStr = rem > 0 ? '.${rem.toString().padLeft(2, '0')}' : '';
    final sign = isNeg ? '-' : '';
    final sym = showSymbol ? symbol : '';
    return '$sign$sym$intStr$decStr';
  }

  static String _formatBdInt(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
    final rest = s.substring(0, s.length - 3);
    final formattedRest = rest.replaceAll(RegExp(r'\B(?=(\d{2})+(?!\d))'), ',');
    return '$formattedRest,$last3';
  }

  static String date(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final mon = d.month.toString().padLeft(2, '0');
    return '$day/$mon/${d.year}';
  }
}

// ============================================================================
// DATA MODELS & OFFLINE FILE STORAGE ENGINE
// ============================================================================
class WalletItem {
  int id;
  String name;
  String type;
  int openingPaisa;
  int currentPaisa;

  WalletItem({
    required this.id,
    required this.name,
    required this.type,
    required this.openingPaisa,
    required this.currentPaisa,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'openingPaisa': openingPaisa,
        'currentPaisa': currentPaisa,
      };

  factory WalletItem.fromJson(Map<String, dynamic> j) => WalletItem(
        id: j['id'] as int,
        name: j['name'] as String,
        type: j['type'] as String,
        openingPaisa: j['openingPaisa'] as int,
        currentPaisa: j['currentPaisa'] as int,
      );
}

class TxnItem {
  int id;
  String type; // income | expense | transfer | savings | loan
  int amountPaisa;
  String category;
  int walletId;
  String walletName;
  int? toWalletId;
  String? toWalletName;
  String paymentMethod;
  DateTime date;
  String time;
  String description;
  String notes;

  TxnItem({
    required this.id,
    required this.type,
    required this.amountPaisa,
    required this.category,
    required this.walletId,
    required this.walletName,
    this.toWalletId,
    this.toWalletName,
    required this.paymentMethod,
    required this.date,
    required this.time,
    required this.description,
    required this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'amountPaisa': amountPaisa,
        'category': category,
        'walletId': walletId,
        'walletName': walletName,
        'toWalletId': toWalletId,
        'toWalletName': toWalletName,
        'paymentMethod': paymentMethod,
        'date': date.millisecondsSinceEpoch,
        'time': time,
        'description': description,
        'notes': notes,
      };

  factory TxnItem.fromJson(Map<String, dynamic> j) => TxnItem(
        id: j['id'] as int,
        type: j['type'] as String,
        amountPaisa: j['amountPaisa'] as int,
        category: j['category'] as String,
        walletId: j['walletId'] as int,
        walletName: j['walletName'] as String,
        toWalletId: j['toWalletId'] as int?,
        toWalletName: j['toWalletName'] as String?,
        paymentMethod: (j['paymentMethod'] ?? 'Cash') as String,
        date: DateTime.fromMillisecondsSinceEpoch(j['date'] as int),
        time: (j['time'] ?? '12:00') as String,
        description: (j['description'] ?? '') as String,
        notes: (j['notes'] ?? '') as String,
      );
}

class SavingsGoalItem {
  int id;
  String name;
  int targetPaisa;
  int currentPaisa;
  DateTime targetDate;

  SavingsGoalItem({
    required this.id,
    required this.name,
    required this.targetPaisa,
    required this.currentPaisa,
    required this.targetDate,
  });

  int get remainingPaisa => math.max(0, targetPaisa - currentPaisa);
  double get progressPct =>
      targetPaisa <= 0 ? 0 : ((currentPaisa / targetPaisa) * 100).clamp(0.0, 100.0);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'targetPaisa': targetPaisa,
        'currentPaisa': currentPaisa,
        'targetDate': targetDate.millisecondsSinceEpoch,
      };

  factory SavingsGoalItem.fromJson(Map<String, dynamic> j) => SavingsGoalItem(
        id: j['id'] as int,
        name: j['name'] as String,
        targetPaisa: j['targetPaisa'] as int,
        currentPaisa: j['currentPaisa'] as int,
        targetDate: DateTime.fromMillisecondsSinceEpoch(j['targetDate'] as int),
      );
}

class LoanItem {
  int id;
  String personName;
  String loanType; // borrowed | lent
  int principalPaisa;
  int paidPaisa;
  DateTime dueDate;
  String notes;

  LoanItem({
    required this.id,
    required this.personName,
    required this.loanType,
    required this.principalPaisa,
    required this.paidPaisa,
    required this.dueDate,
    required this.notes,
  });

  int get remainingPaisa => math.max(0, principalPaisa - paidPaisa);

  Map<String, dynamic> toJson() => {
        'id': id,
        'personName': personName,
        'loanType': loanType,
        'principalPaisa': principalPaisa,
        'paidPaisa': paidPaisa,
        'dueDate': dueDate.millisecondsSinceEpoch,
        'notes': notes,
      };

  factory LoanItem.fromJson(Map<String, dynamic> j) => LoanItem(
        id: j['id'] as int,
        personName: j['personName'] as String,
        loanType: j['loanType'] as String,
        principalPaisa: j['principalPaisa'] as int,
        paidPaisa: j['paidPaisa'] as int,
        dueDate: DateTime.fromMillisecondsSinceEpoch(j['dueDate'] as int),
        notes: (j['notes'] ?? '') as String,
      );
}

class RecurringItem {
  int id;
  String title;
  String type; // income | expense
  int amountPaisa;
  String category;
  int walletId;
  String frequency; // Daily | Weekly | Monthly | Yearly
  bool isPaused;

  RecurringItem({
    required this.id,
    required this.title,
    required this.type,
    required this.amountPaisa,
    required this.category,
    required this.walletId,
    required this.frequency,
    this.isPaused = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type,
        'amountPaisa': amountPaisa,
        'category': category,
        'walletId': walletId,
        'frequency': frequency,
        'isPaused': isPaused,
      };

  factory RecurringItem.fromJson(Map<String, dynamic> j) => RecurringItem(
        id: j['id'] as int,
        title: j['title'] as String,
        type: j['type'] as String,
        amountPaisa: j['amountPaisa'] as int,
        category: j['category'] as String,
        walletId: j['walletId'] as int,
        frequency: j['frequency'] as String,
        isPaused: (j['isPaused'] ?? false) as bool,
      );
}

class WarningBannerItem {
  final String title;
  final String message;
  final Color color;
  const WarningBannerItem(this.title, this.message, this.color);
}

// ============================================================================
// CENTRAL APPLICATION STORE WITH AUTOMATIC ANDROID LOCAL FILE PERSISTENCE
// ============================================================================
class HisabStore extends ChangeNotifier {
  bool onboardingDone = false;
  String userName = 'User';
  String language = 'en'; // 'en' | 'bn'
  String themeMode = 'system'; // 'system' | 'light' | 'dark'
  String? pinCode;
  bool sessionUnlocked = true;

  int monthlyIncomeTargetPaisa = 30000 * 100;
  int monthlyBudgetLimitPaisa = 25000 * 100;
  int dailySpendingLimitPaisa = 1000 * 100;
  Map<String, int> categoryBudgetsPaisa = {};

  List<String> incomeCategories = [
    'Salary', 'Freelancing', 'Business', 'Online Income',
    'Part-time Job', 'Investment', 'Gift', 'Bonus', 'Other Income'
  ];

  List<String> expenseCategories = [
    'Food', 'Transportation', 'Shopping', 'House Rent', 'Electricity',
    'Internet', 'Mobile Recharge', 'Medical', 'Education', 'Entertainment',
    'Family', 'Travel', 'Clothing', 'Groceries', 'Personal Expenses', 'Other Expenses'
  ];

  List<WalletItem> wallets = [
    WalletItem(id: 1, name: 'Cash', type: 'cash', openingPaisa: 500000, currentPaisa: 500000),
    WalletItem(id: 2, name: 'bKash', type: 'mfs', openingPaisa: 300000, currentPaisa: 300000),
    WalletItem(id: 3, name: 'Nagad', type: 'mfs', openingPaisa: 200000, currentPaisa: 200000),
    WalletItem(id: 4, name: 'Rocket', type: 'mfs', openingPaisa: 0, currentPaisa: 0),
    WalletItem(id: 5, name: 'Bank Account', type: 'bank', openingPaisa: 1000000, currentPaisa: 1000000),
    WalletItem(id: 6, name: 'Debit Card', type: 'card', openingPaisa: 0, currentPaisa: 0),
    WalletItem(id: 7, name: 'Credit Card', type: 'credit', openingPaisa: 0, currentPaisa: 0),
  ];

  List<TxnItem> transactions = [];
  List<SavingsGoalItem> savingsGoals = [];
  List<LoanItem> loans = [];
  List<RecurringItem> recurringList = [];

  HisabStore() {
    _loadFromDisk();
  }

  bool get isBn => language == 'bn';
  String tr(String en, String bn) => isBn ? bn : en;

  File _getDbFile() {
    final candidates = [
      '/data/data/com.hisabpro.moneymanager/files',
      '/data/user/0/com.hisabpro.moneymanager/files',
      Directory.systemTemp.path,
    ];
    for (final path in candidates) {
      final dir = Directory(path);
      if (dir.existsSync()) {
        return File('${dir.path}/hisabpro_offline_db.json');
      }
    }
    return File('${Directory.systemTemp.path}/hisabpro_offline_db.json');
  }

  Future<void> _saveToDisk() async {
    try {
      final file = _getDbFile();
      final payload = jsonEncode(exportFullBackupMap());
      await file.writeAsString(payload);
    } catch (_) {}
  }

  Future<void> _loadFromDisk() async {
    try {
      final file = _getDbFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final map = jsonDecode(content) as Map<String, dynamic>;
        restoreFromBackupMap(map, notify: true);
      }
    } catch (_) {}
  }

  Map<String, dynamic> exportFullBackupMap() => {
        'onboardingDone': onboardingDone,
        'userName': userName,
        'language': language,
        'themeMode': themeMode,
        'pinCode': pinCode,
        'monthlyIncomeTargetPaisa': monthlyIncomeTargetPaisa,
        'monthlyBudgetLimitPaisa': monthlyBudgetLimitPaisa,
        'dailySpendingLimitPaisa': dailySpendingLimitPaisa,
        'categoryBudgetsPaisa': categoryBudgetsPaisa,
        'incomeCategories': incomeCategories,
        'expenseCategories': expenseCategories,
        'wallets': wallets.map((w) => w.toJson()).toList(),
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'savingsGoals': savingsGoals.map((g) => g.toJson()).toList(),
        'loans': loans.map((l) => l.toJson()).toList(),
        'recurringList': recurringList.map((r) => r.toJson()).toList(),
      };

  void restoreFromBackupMap(Map<String, dynamic> map, {bool notify = true}) {
    onboardingDone = (map['onboardingDone'] ?? false) as bool;
    userName = (map['userName'] ?? 'User') as String;
    language = (map['language'] ?? 'en') as String;
    themeMode = (map['themeMode'] ?? 'system') as String;
    pinCode = map['pinCode'] as String?;
    sessionUnlocked = (pinCode == null || pinCode!.isEmpty);
    monthlyIncomeTargetPaisa = (map['monthlyIncomeTargetPaisa'] ?? 3000000) as int;
    monthlyBudgetLimitPaisa = (map['monthlyBudgetLimitPaisa'] ?? 2500000) as int;
    dailySpendingLimitPaisa = (map['dailySpendingLimitPaisa'] ?? 100000) as int;

    if (map['categoryBudgetsPaisa'] != null) {
      final raw = map['categoryBudgetsPaisa'] as Map<String, dynamic>;
      categoryBudgetsPaisa = raw.map((k, v) => MapEntry(k, v as int));
    }
    if (map['wallets'] != null) {
      wallets = (map['wallets'] as List).map((e) => WalletItem.fromJson(e)).toList();
    }
    if (map['transactions'] != null) {
      transactions = (map['transactions'] as List).map((e) => TxnItem.fromJson(e)).toList();
    }
    if (map['savingsGoals'] != null) {
      savingsGoals = (map['savingsGoals'] as List).map((e) => SavingsGoalItem.fromJson(e)).toList();
    }
    if (map['loans'] != null) {
      loans = (map['loans'] as List).map((e) => LoanItem.fromJson(e)).toList();
    }
    if (map['recurringList'] != null) {
      recurringList = (map['recurringList'] as List).map((e) => RecurringItem.fromJson(e)).toList();
    }
    if (notify) notifyListeners();
  }

  void completeOnboarding({
    required String name,
    required String lang,
    required String theme,
    required int cashPaisa,
    required int bkashPaisa,
    required int nagadPaisa,
    required int bankPaisa,
    required int incomePaisa,
    required int budgetPaisa,
  }) {
    userName = name.isEmpty ? 'User' : name;
    language = lang;
    themeMode = theme;
    monthlyIncomeTargetPaisa = incomePaisa;
    monthlyBudgetLimitPaisa = budgetPaisa;
    onboardingDone = true;

    for (final w in wallets) {
      if (w.name == 'Cash') {
        w.openingPaisa = cashPaisa;
        w.currentPaisa = cashPaisa;
      } else if (w.name == 'bKash') {
        w.openingPaisa = bkashPaisa;
        w.currentPaisa = bkashPaisa;
      } else if (w.name == 'Nagad') {
        w.openingPaisa = nagadPaisa;
        w.currentPaisa = nagadPaisa;
      } else if (w.name == 'Bank Account') {
        w.openingPaisa = bankPaisa;
        w.currentPaisa = bankPaisa;
      }
    }
    _saveToDisk();
    notifyListeners();
  }

  int get totalAvailableBalancePaisa =>
      wallets.fold(0, (sum, w) => sum + w.currentPaisa);

  int get totalSavingsPaisa =>
      savingsGoals.fold(0, (sum, g) => sum + g.currentPaisa);

  int get totalBorrowedDebtPaisa =>
      loans.where((l) => l.loanType == 'borrowed').fold(0, (s, l) => s + l.remainingPaisa);

  int get totalLentReceivablePaisa =>
      loans.where((l) => l.loanType == 'lent').fold(0, (s, l) => s + l.remainingPaisa);

  int get totalNetWorthPaisa =>
      totalAvailableBalancePaisa + totalSavingsPaisa + totalLentReceivablePaisa - totalBorrowedDebtPaisa;

  int get todayIncomePaisa {
    final now = DateTime.now();
    return transactions
        .where((t) =>
            t.type == 'income' &&
            t.date.year == now.year &&
            t.date.month == now.month &&
            t.date.day == now.day)
        .fold(0, (s, t) => s + t.amountPaisa);
  }

  int get todayExpensePaisa {
    final now = DateTime.now();
    return transactions
        .where((t) =>
            t.type == 'expense' &&
            t.date.year == now.year &&
            t.date.month == now.month &&
            t.date.day == now.day)
        .fold(0, (s, t) => s + t.amountPaisa);
  }

  int get monthlyIncomePaisa {
    final now = DateTime.now();
    return transactions
        .where((t) => t.type == 'income' && t.date.year == now.year && t.date.month == now.month)
        .fold(0, (s, t) => s + t.amountPaisa);
  }

  int get monthlyExpensePaisa {
    final now = DateTime.now();
    return transactions
        .where((t) => t.type == 'expense' && t.date.year == now.year && t.date.month == now.month)
        .fold(0, (s, t) => s + t.amountPaisa);
  }

  int get effectiveMonthlyIncomePaisa =>
      monthlyIncomePaisa > 0 ? monthlyIncomePaisa : monthlyIncomeTargetPaisa;

  int get remainingBudgetPaisa =>
      (monthlyBudgetLimitPaisa > 0 ? monthlyBudgetLimitPaisa : effectiveMonthlyIncomePaisa) -
      monthlyExpensePaisa;

  Map<String, int> get currentMonthCategoryExpenseMap {
    final now = DateTime.now();
    final map = <String, int>{};
    for (final t in transactions) {
      if (t.type == 'expense' && t.date.year == now.year && t.date.month == now.month) {
        map[t.category] = (map[t.category] ?? 0) + t.amountPaisa;
      }
    }
    return map;
  }

  int get financialHealthScore {
    int score = 0;
    final inc = effectiveMonthlyIncomePaisa;
    final exp = monthlyExpensePaisa;
    if (inc > 0) {
      final ratio = exp / inc;
      if (ratio <= 0.5) {
        score += 35;
      } else if (ratio <= 0.8) {
        score += 25;
      } else if (ratio <= 1.0) {
        score += 15;
      }
    } else if (exp == 0) {
      score += 25;
    }

    final netSaved = inc - exp;
    if (inc > 0 && (netSaved / inc) >= 0.2) {
      score += 25;
    } else if (netSaved > 0) {
      score += 15;
    }

    if (monthlyBudgetLimitPaisa > 0 && exp <= monthlyBudgetLimitPaisa) {
      score += 25;
    } else if (monthlyBudgetLimitPaisa == 0) {
      score += 15;
    }

    if (totalAvailableBalancePaisa > 0) score += 15;
    return score.clamp(0, 100);
  }

  List<WarningBannerItem> get activeWarnings {
    final list = <WarningBannerItem>[];
    final inc = effectiveMonthlyIncomePaisa;
    final exp = monthlyExpensePaisa;

    if (totalAvailableBalancePaisa < 0) {
      list.add(WarningBannerItem(
        tr('Negative Available Balance!', 'নেগেটিভ ব্যালেন্স সতর্কতা!'),
        'Critical! Available balance is ${BdFormat.paisa(totalAvailableBalancePaisa)}.',
        const Color(0xFFDC2626),
      ));
    }

    if (inc > 0 && exp > inc) {
      final diff = exp - inc;
      list.add(WarningBannerItem(
        tr('Overspending Alert (>100% Income)', 'অতিরিক্ত ব্যয় সতর্কতা (>১০০% আয়)'),
        'Warning! Your expenses have exceeded your income by ${BdFormat.paisa(diff)}.',
        const Color(0xFFDC2626),
      ));
    } else if (inc > 0 && exp > 0) {
      final pct = (exp / inc) * 100;
      if (pct >= 100) {
        list.add(WarningBannerItem(
          'Critical Warning (100% Income Used)',
          'Your monthly expenses have reached 100% of your monthly income.',
          const Color(0xFFDC2626),
        ));
      } else if (pct >= 90) {
        list.add(WarningBannerItem(
          'High Spending Alert (90%+)',
          'Your monthly expenses have reached ${pct.toStringAsFixed(0)}% of your income. Please review your spending.',
          const Color(0xFFF59E0B),
        ));
      } else if (pct >= 70) {
        list.add(WarningBannerItem(
          'Spending Warning (70%+)',
          'You have spent ${pct.toStringAsFixed(0)}% of your monthly income.',
          const Color(0xFFF59E0B),
        ));
      } else if (pct >= 50) {
        list.add(WarningBannerItem(
          'Informational Update (50%+)',
          'You have used ${pct.toStringAsFixed(0)}% of your monthly income.',
          const Color(0xFF2563EB),
        ));
      }
    }

    if (dailySpendingLimitPaisa > 0 && todayExpensePaisa > dailySpendingLimitPaisa) {
      final over = todayExpensePaisa - dailySpendingLimitPaisa;
      list.add(WarningBannerItem(
        'Daily Spending Limit Exceeded!',
        'Today\'s spending exceeded your daily limit by ${BdFormat.paisa(over)}.',
        const Color(0xFFF59E0B),
      ));
    }

    final catMap = currentMonthCategoryExpenseMap;
    categoryBudgetsPaisa.forEach((cat, limit) {
      if (limit > 0) {
        final spent = catMap[cat] ?? 0;
        if (spent > limit) {
          list.add(WarningBannerItem(
            '$cat Budget Exceeded!',
            '$cat spending (${BdFormat.paisa(spent)}) exceeded limit of ${BdFormat.paisa(limit)}.',
            const Color(0xFFDC2626),
          ));
        } else if (spent >= (limit * 0.8)) {
          list.add(WarningBannerItem(
            '$cat Budget at ${((spent / limit) * 100).toStringAsFixed(0)}%',
            'Approaching category budget limit for $cat.',
            const Color(0xFFF59E0B),
          ));
        }
      }
    });

    return list;
  }

  void addIncomeOrExpense({
    required String type,
    required int amountPaisa,
    required String category,
    required int walletId,
    required String paymentMethod,
    required DateTime date,
    required String description,
    required String notes,
  }) {
    final w = wallets.firstWhere((e) => e.id == walletId, orElse: () => wallets.first);
    final now = TimeOfDay.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final nextId = transactions.isEmpty ? 1 : (transactions.map((e) => e.id).reduce(math.max) + 1);
    transactions.insert(
      0,
      TxnItem(
        id: nextId,
        type: type,
        amountPaisa: amountPaisa,
        category: category,
        walletId: w.id,
        walletName: w.name,
        paymentMethod: paymentMethod,
        date: date,
        time: timeStr,
        description: description,
        notes: notes,
      ),
    );

    w.currentPaisa += (type == 'income' ? amountPaisa : -amountPaisa);
    _saveToDisk();
    notifyListeners();
  }

  void deleteTransaction(int id) {
    final idx = transactions.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final t = transactions[idx];
    final w = wallets.where((e) => e.id == t.walletId).firstOrNull;

    if (t.type == 'income' && w != null) {
      w.currentPaisa -= t.amountPaisa;
    } else if (t.type == 'expense' && w != null) {
      w.currentPaisa += t.amountPaisa;
    } else if (t.type == 'transfer' && w != null && t.toWalletId != null) {
      final toW = wallets.where((e) => e.id == t.toWalletId).firstOrNull;
      w.currentPaisa += t.amountPaisa;
      if (toW != null) toW.currentPaisa -= t.amountPaisa;
    }
    transactions.removeAt(idx);
    _saveToDisk();
    notifyListeners();
  }

  void transferBetweenWallets({
    required int fromWalletId,
    required int toWalletId,
    required int amountPaisa,
    required String notes,
  }) {
    if (fromWalletId == toWalletId || amountPaisa <= 0) return;
    final fromW = wallets.firstWhere((e) => e.id == fromWalletId);
    final toW = wallets.firstWhere((e) => e.id == toWalletId);
    fromW.currentPaisa -= amountPaisa;
    toW.currentPaisa += amountPaisa;

    final nextId = transactions.isEmpty ? 1 : (transactions.map((e) => e.id).reduce(math.max) + 1);
    transactions.insert(
      0,
      TxnItem(
        id: nextId,
        type: 'transfer',
        amountPaisa: amountPaisa,
        category: 'Wallet Transfer',
        walletId: fromW.id,
        walletName: fromW.name,
        toWalletId: toW.id,
        toWalletName: toW.name,
        paymentMethod: 'Transfer',
        date: DateTime.now(),
        time: '12:00',
        description: '${fromW.name} → ${toW.name}',
        notes: notes,
      ),
    );
    _saveToDisk();
    notifyListeners();
  }

  void addSavingsGoal(String name, int targetPaisa, DateTime targetDate) {
    final nextId = savingsGoals.isEmpty ? 1 : (savingsGoals.map((e) => e.id).reduce(math.max) + 1);
    savingsGoals.add(SavingsGoalItem(
      id: nextId,
      name: name,
      targetPaisa: targetPaisa,
      currentPaisa: 0,
      targetDate: targetDate,
    ));
    _saveToDisk();
    notifyListeners();
  }

  void moveSavings({
    required int goalId,
    required int walletId,
    required int amountPaisa,
    required bool isDeposit,
  }) {
    final g = savingsGoals.firstWhere((e) => e.id == goalId);
    final w = wallets.firstWhere((e) => e.id == walletId);
    if (isDeposit) {
      w.currentPaisa -= amountPaisa;
      g.currentPaisa += amountPaisa;
    } else {
      w.currentPaisa += amountPaisa;
      g.currentPaisa = math.max(0, g.currentPaisa - amountPaisa);
    }

    final nextId = transactions.isEmpty ? 1 : (transactions.map((e) => e.id).reduce(math.max) + 1);
    transactions.insert(
      0,
      TxnItem(
        id: nextId,
        type: 'savings',
        amountPaisa: amountPaisa,
        category: isDeposit ? 'Savings Deposit' : 'Savings Withdraw',
        walletId: w.id,
        walletName: w.name,
        paymentMethod: 'Savings Transfer',
        date: DateTime.now(),
        time: '12:00',
        description: '${g.name} (${isDeposit ? "Deposit" : "Withdraw"})',
        notes: '',
      ),
    );
    _saveToDisk();
    notifyListeners();
  }

  void addLoan({
    required String personName,
    required String loanType,
    required int principalPaisa,
    required int walletId,
    required DateTime dueDate,
    required String notes,
  }) {
    final w = wallets.firstWhere((e) => e.id == walletId);
    final nextId = loans.isEmpty ? 1 : (loans.map((e) => e.id).reduce(math.max) + 1);
    loans.add(LoanItem(
      id: nextId,
      personName: personName,
      loanType: loanType,
      principalPaisa: principalPaisa,
      paidPaisa: 0,
      dueDate: dueDate,
      notes: notes,
    ));

    w.currentPaisa += (loanType == 'borrowed' ? principalPaisa : -principalPaisa);
    final txnId = transactions.isEmpty ? 1 : (transactions.map((e) => e.id).reduce(math.max) + 1);
    transactions.insert(
      0,
      TxnItem(
        id: txnId,
        type: 'loan',
        amountPaisa: principalPaisa,
        category: loanType == 'borrowed' ? 'Loan Taken' : 'Loan Given',
        walletId: w.id,
        walletName: w.name,
        paymentMethod: w.name,
        date: DateTime.now(),
        time: '12:00',
        description: '${loanType == 'borrowed' ? "Borrowed from" : "Lent to"} $personName',
        notes: notes,
      ),
    );
    _saveToDisk();
    notifyListeners();
  }

  void payLoanInstallment(int loanId, int walletId, int amountPaisa) {
    final l = loans.firstWhere((e) => e.id == loanId);
    final w = wallets.firstWhere((e) => e.id == walletId);
    l.paidPaisa = math.min(l.principalPaisa, l.paidPaisa + amountPaisa);
    w.currentPaisa += (l.loanType == 'borrowed' ? -amountPaisa : amountPaisa);

    final txnId = transactions.isEmpty ? 1 : (transactions.map((e) => e.id).reduce(math.max) + 1);
    transactions.insert(
      0,
      TxnItem(
        id: txnId,
        type: 'loan',
        amountPaisa: amountPaisa,
        category: l.loanType == 'borrowed' ? 'Loan Repayment' : 'Loan Recovery',
        walletId: w.id,
        walletName: w.name,
        paymentMethod: w.name,
        date: DateTime.now(),
        time: '12:00',
        description: 'Installment - ${l.personName}',
        notes: '',
      ),
    );
    _saveToDisk();
    notifyListeners();
  }

  void addWallet(String name, String type, int openingPaisa) {
    final nextId = wallets.isEmpty ? 1 : (wallets.map((e) => e.id).reduce(math.max) + 1);
    wallets.add(WalletItem(
      id: nextId,
      name: name,
      type: type,
      openingPaisa: openingPaisa,
      currentPaisa: openingPaisa,
    ));
    _saveToDisk();
    notifyListeners();
  }

  void addCustomCategory(String name, bool isIncome) {
    if (isIncome && !incomeCategories.contains(name)) {
      incomeCategories.add(name);
    } else if (!isIncome && !expenseCategories.contains(name)) {
      expenseCategories.add(name);
    }
    _saveToDisk();
    notifyListeners();
  }

  void setBudgets({required int monthlyPaisa, required int dailyPaisa, String? cat, int? catLimitPaisa}) {
    monthlyBudgetLimitPaisa = monthlyPaisa;
    dailySpendingLimitPaisa = dailyPaisa;
    if (cat != null && catLimitPaisa != null && catLimitPaisa > 0) {
      categoryBudgetsPaisa[cat] = catLimitPaisa;
    }
    _saveToDisk();
    notifyListeners();
  }

  void updatePreferences({String? lang, String? theme, String? newPin}) {
    if (lang != null) language = lang;
    if (theme != null) themeMode = theme;
    if (newPin != null) {
      pinCode = newPin.isEmpty ? null : newPin;
    }
    _saveToDisk();
    notifyListeners();
  }

  void unlockSession() {
    sessionUnlocked = true;
    notifyListeners();
  }

  String generateCsvExport() {
    final sb = StringBuffer();
    sb.writeln('ID,Date,Time,Type,Category,Amount(BDT),Wallet,PaymentMethod,Description');
    for (final t in transactions) {
      sb.writeln(
        '${t.id},${BdFormat.date(t.date)},${t.time},${t.type.toUpperCase()},"${t.category}",${(t.amountPaisa / 100).toStringAsFixed(2)},"${t.walletName}","${t.paymentMethod}","${t.description}"',
      );
    }
    return sb.toString();
  }
}

final HisabStore appStore = HisabStore();

// ============================================================================
// ROOT APP & THEME CONFIGURATION
// ============================================================================
class HisabProApp extends StatelessWidget {
  const HisabProApp({super.key});

  static const Color primaryPurple = Color(0xFF4A148C);
  static const Color secondaryEmerald = Color(0xFF10B981);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appStore,
      builder: (context, _) {
        final mode = appStore.themeMode == 'light'
            ? ThemeMode.light
            : appStore.themeMode == 'dark'
                ? ThemeMode.dark
                : ThemeMode.system;

        return MaterialApp(
          title: 'HisabPro – Smart Money Manager',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: primaryPurple,
              primary: primaryPurple,
              secondary: secondaryEmerald,
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: primaryPurple,
              secondary: secondaryEmerald,
              brightness: Brightness.dark,
            ),
          ),
          home: !appStore.onboardingDone
              ? const OnboardingScreen()
              : (!appStore.sessionUnlocked && appStore.pinCode != null)
                  ? const PinLockScreen()
                  : const MainNavigationShell(),
        );
      },
    );
  }
}

// ============================================================================
// 1. FIRST-TIME ONBOARDING SCREEN
// ============================================================================
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameCtrl = TextEditingController();
  final _cashCtrl = TextEditingController(text: '5000');
  final _bkashCtrl = TextEditingController(text: '3000');
  final _nagadCtrl = TextEditingController(text: '2000');
  final _bankCtrl = TextEditingController(text: '10000');
  final _incomeCtrl = TextEditingController(text: '30000');
  final _budgetCtrl = TextEditingController(text: '25000');
  String _lang = 'en';
  String _theme = 'system';

  int get _openingTotalPaisa =>
      BdFormat.parseTakaToPaisa(_cashCtrl.text) +
      BdFormat.parseTakaToPaisa(_bkashCtrl.text) +
      BdFormat.parseTakaToPaisa(_nagadCtrl.text) +
      BdFormat.parseTakaToPaisa(_bankCtrl.text);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A148C).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.account_balance_wallet, color: Color(0xFF4A148C), size: 36),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('HisabPro', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        Text('Smart Money Manager • Bangladesh (৳)'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Your Name / আপনার নাম',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _lang,
                      decoration: const InputDecoration(labelText: 'Language', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'bn', child: Text('বাংলা')),
                      ],
                      onChanged: (v) => setState(() => _lang = v ?? 'en'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _theme,
                      decoration: const InputDecoration(labelText: 'Theme', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'system', child: Text('System')),
                        DropdownMenuItem(value: 'light', child: Text('Light')),
                        DropdownMenuItem(value: 'dark', child: Text('Dark')),
                      ],
                      onChanged: (v) => setState(() => _theme = v ?? 'system'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Starting Wallet Balances (৳)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _numField('Cash (৳)', _cashCtrl)),
                  const SizedBox(width: 10),
                  Expanded(child: _numField('bKash (৳)', _bkashCtrl)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _numField('Nagad (৳)', _nagadCtrl)),
                  const SizedBox(width: 10),
                  Expanded(child: _numField('Bank (৳)', _bankCtrl)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A148C),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Opening Total Balance:', style: TextStyle(color: Colors.white70)),
                    Text(
                      BdFormat.paisa(_openingTotalPaisa),
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Monthly Targets (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _numField('Monthly Income (৳)', _incomeCtrl)),
                  const SizedBox(width: 10),
                  Expanded(child: _numField('Monthly Budget (৳)', _budgetCtrl)),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () {
                    appStore.completeOnboarding(
                      name: _nameCtrl.text.trim(),
                      lang: _lang,
                      theme: _theme,
                      cashPaisa: BdFormat.parseTakaToPaisa(_cashCtrl.text),
                      bkashPaisa: BdFormat.parseTakaToPaisa(_bkashCtrl.text),
                      nagadPaisa: BdFormat.parseTakaToPaisa(_nagadCtrl.text),
                      bankPaisa: BdFormat.parseTakaToPaisa(_bankCtrl.text),
                      incomePaisa: BdFormat.parseTakaToPaisa(_incomeCtrl.text),
                      budgetPaisa: BdFormat.parseTakaToPaisa(_budgetCtrl.text),
                    );
                  },
                  icon: const Icon(Icons.Rocket_launch_outlined),
                  label: const Text('Start Using HisabPro'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numField(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      onChanged: (_) => setState(() {}),
    );
  }
}

// ============================================================================
// 2. PIN LOCK SCREEN
// ============================================================================
class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  final _pinCtrl = TextEditingController();
  String? _err;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Color(0xFF4A148C)),
            const SizedBox(height: 16),
            const Text('Unlock HisabPro', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: 'Enter Security PIN',
                errorText: _err,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () {
                  if (_pinCtrl.text.trim() == appStore.pinCode) {
                    appStore.unlockSession();
                  } else {
                    setState(() => _err = 'Incorrect PIN');
                  }
                },
                child: const Text('Unlock'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 3. MAIN NAVIGATION SHELL (5 TABS + FLOATING ACTION BUTTON)
// ============================================================================
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DashboardTab(),
      const TransactionsAndCalendarTab(),
      const ReportsAndInsightsTab(),
      const SavingsBudgetsLoansTab(),
      const SettingsAndWalletsTab(),
    ];

    return Scaffold(
      body: pages[_tabIndex],
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4A148C),
        foregroundColor: Colors.white,
        onPressed: () => _showQuickActionSheet(context),
        child: const Icon(Icons.add, size: 28),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.dashboard_outlined), label: appStore.tr('Home', 'হোম')),
          NavigationDestination(icon: const Icon(Icons.receipt_long_outlined), label: appStore.tr('Transactions', 'লেনদেন')),
          NavigationDestination(icon: const Icon(Icons.bar_chart_outlined), label: appStore.tr('Reports', 'রিপোর্ট')),
          NavigationDestination(icon: const Icon(Icons.savings_outlined), label: appStore.tr('Savings', 'সঞ্চয়')),
          NavigationDestination(icon: const Icon(Icons.settings_outlined), label: appStore.tr('Settings', 'সেটিংস')),
        ],
      ),
    );
  }

  void _showQuickActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFF16A34A), child: Icon(Icons.south_west, color: Colors.white)),
              title: Text(appStore.tr('Add Income', 'আয় যোগ করুন'), style: const TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                _showAddTxnDialog(context, 'income');
              },
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFDC2626), child: Icon(Icons.north_east, color: Colors.white)),
              title: Text(appStore.tr('Add Expense', 'ব্যয় যোগ করুন'), style: const TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                _showAddTxnDialog(context, 'expense');
              },
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFF4A148C), child: Icon(Icons.swap_horiz, color: Colors.white)),
              title: Text(appStore.tr('Transfer Money', 'ওয়ালেট ট্রান্সফার'), style: const TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                _showTransferDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

void _showAddTxnDialog(BuildContext context, String type) {
  final amountCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final cats = type == 'income' ? appStore.incomeCategories : appStore.expenseCategories;
  String selectedCat = cats.first;
  int selectedWalletId = appStore.wallets.first.id;
  String paymentMethod = 'Cash';

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialog) => AlertDialog(
        title: Text(type == 'income' ? 'Add Income (৳)' : 'Add Expense (৳)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (৳ BDT)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedCat,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: cats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setDialog(() => selectedCat = v ?? selectedCat),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: selectedWalletId,
                decoration: const InputDecoration(labelText: 'Wallet', border: OutlineInputBorder()),
                items: appStore.wallets.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                onChanged: (v) => setDialog(() => selectedWalletId = v ?? selectedWalletId),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: paymentMethod,
                decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder()),
                items: const ['Cash', 'bKash', 'Nagad', 'Rocket', 'Bank Transfer', 'Card']
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setDialog(() => paymentMethod = v ?? paymentMethod),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description / Notes', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final paisa = BdFormat.parseTakaToPaisa(amountCtrl.text);
              if (paisa > 0) {
                appStore.addIncomeOrExpense(
                  type: type,
                  amountPaisa: paisa,
                  category: selectedCat,
                  walletId: selectedWalletId,
                  paymentMethod: paymentMethod,
                  date: DateTime.now(),
                  description: descCtrl.text.trim(),
                  notes: '',
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

void _showTransferDialog(BuildContext context) {
  int fromId = appStore.wallets.first.id;
  int toId = appStore.wallets.length > 1 ? appStore.wallets[1].id : appStore.wallets.first.id;
  final amountCtrl = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialog) => AlertDialog(
        title: const Text('Transfer Between Wallets'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              value: fromId,
              decoration: const InputDecoration(labelText: 'From Wallet', border: OutlineInputBorder()),
              items: appStore.wallets.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
              onChanged: (v) => setDialog(() => fromId = v ?? fromId),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              value: toId,
              decoration: const InputDecoration(labelText: 'To Wallet', border: OutlineInputBorder()),
              items: appStore.wallets.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
              onChanged: (v) => setDialog(() => toId = v ?? toId),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (৳)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final paisa = BdFormat.parseTakaToPaisa(amountCtrl.text);
              appStore.transferBetweenWallets(
                fromWalletId: fromId,
                toWalletId: toId,
                amountPaisa: paisa,
                notes: '',
              );
              Navigator.pop(ctx);
            },
            child: const Text('Transfer'),
          ),
        ],
      ),
    ),
  );
}

// ============================================================================
// TAB 1: HOME DASHBOARD
// ============================================================================
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final warnings = appStore.activeWarnings;
    final catMap = appStore.currentMonthCategoryExpenseMap;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Assalamu Alaikum, ${appStore.userName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              'Net Worth: ${BdFormat.paisa(appStore.totalNetWorthPaisa)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF10B981)),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              label: Text('Health: ${appStore.financialHealthScore}/100'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          for (final w in warnings)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: w.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: w.color),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: w.color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(w.title, style: TextStyle(fontWeight: FontWeight.bold, color: w.color)),
                        Text(w.message, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF4A148C), Color(0xFF673AB7)]),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(appStore.tr('Total Available Balance', 'মোট বর্তমান ব্যালেন্স'), style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 4),
                Text(
                  BdFormat.paisa(appStore.totalAvailableBalancePaisa),
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _metricCol(appStore.tr("Today's Income", 'আজকের আয়'), BdFormat.paisa(appStore.todayIncomePaisa)),
                    _metricCol(appStore.tr("Today's Expense", 'আজকের ব্যয়'), BdFormat.paisa(appStore.todayExpensePaisa)),
                  ],
                ),
                const Divider(color: Colors.white24, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _metricCol(appStore.tr('Monthly Income', 'মাসিক আয়'), BdFormat.paisa(appStore.monthlyIncomePaisa)),
                    _metricCol(appStore.tr('Monthly Expense', 'মাসিক ব্যয়'), BdFormat.paisa(appStore.monthlyExpensePaisa)),
                    _metricCol(appStore.tr('Remaining Budget', 'অবশিষ্ট বাজেট'), BdFormat.paisa(appStore.remainingBudgetPaisa)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: appStore.wallets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final w = appStore.wallets[i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(w.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text(BdFormat.paisa(w.currentPaisa), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Monthly Income vs Expense Comparison', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _BarComparisonWidget(
                    incomePaisa: appStore.monthlyIncomePaisa,
                    expensePaisa: appStore.monthlyExpensePaisa,
                    savingsPaisa: appStore.totalSavingsPaisa,
                  ),
                ],
              ),
            ),
          ),
          if (catMap.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Category-wise Expenses', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ...catMap.entries.map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(e.key),
                              Text(BdFormat.paisa(e.value), style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(appStore.tr('Recent Transactions', 'সাম্প্রতিক লেনদেন'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (appStore.transactions.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No transactions yet. Tap + to add.'))))
          else
            ...appStore.transactions.take(8).map((t) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: t.type == 'income'
                          ? const Color(0xFF16A34A).withValues(alpha: 0.15)
                          : t.type == 'expense'
                              ? const Color(0xFFDC2626).withValues(alpha: 0.15)
                              : const Color(0xFF2563EB).withValues(alpha: 0.15),
                      child: Icon(
                        t.type == 'income' ? Icons.south_west : t.type == 'expense' ? Icons.north_east : Icons.swap_horiz,
                        color: t.type == 'income' ? const Color(0xFF16A34A) : t.type == 'expense' ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                      ),
                    ),
                    title: Text(t.category, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${t.walletName} • ${BdFormat.date(t.date)} ${t.description.isNotEmpty ? "• ${t.description}" : ""}'),
                    trailing: Text(
                      BdFormat.paisa(t.amountPaisa),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: t.type == 'income' ? const Color(0xFF16A34A) : t.type == 'expense' ? const Color(0xFFDC2626) : null,
                      ),
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _metricCol(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}

class _BarComparisonWidget extends StatelessWidget {
  final int incomePaisa;
  final int expensePaisa;
  final int savingsPaisa;

  const _BarComparisonWidget({
    required this.incomePaisa,
    required this.expensePaisa,
    required this.savingsPaisa,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = math.max(1, math.max(incomePaisa, math.max(expensePaisa, savingsPaisa)));
    return Column(
      children: [
        _barRow('Income', incomePaisa, maxVal, const Color(0xFF16A34A)),
        const SizedBox(height: 8),
        _barRow('Expense', expensePaisa, maxVal, const Color(0xFFDC2626)),
        const SizedBox(height: 8),
        _barRow('Savings', savingsPaisa, maxVal, const Color(0xFF2563EB)),
      ],
    );
  }

  Widget _barRow(String label, int val, int maxVal, Color color) {
    final factor = (val / maxVal).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            Text(BdFormat.paisa(val), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: factor,
          minHeight: 10,
          borderRadius: BorderRadius.circular(6),
          color: color,
        ),
      ],
    );
  }
}

// ============================================================================
// TAB 2: TRANSACTIONS & FINANCIAL CALENDAR
// ============================================================================
class TransactionsAndCalendarTab extends StatefulWidget {
  const TransactionsAndCalendarTab({super.key});

  @override
  State<TransactionsAndCalendarTab> createState() => _TransactionsAndCalendarTabState();
}

class _TransactionsAndCalendarTabState extends State<TransactionsAndCalendarTab> {
  String _filter = 'all';
  String _search = '';
  DateTime _selectedDate = DateTime.now();
  bool _showCalendar = false;

  @override
  Widget build(BuildContext context) {
    final filtered = appStore.transactions.where((t) {
      if (_filter != 'all' && t.type != _filter) return false;
      if (_showCalendar) {
        if (t.date.year != _selectedDate.year || t.date.month != _selectedDate.month || t.date.day != _selectedDate.day) {
          return false;
        }
      }
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        return t.category.toLowerCase().contains(q) ||
            t.description.toLowerCase().contains(q) ||
            t.walletName.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(appStore.tr('Transactions & Calendar', 'লেনদেন ও ক্যালেন্ডার')),
        actions: [
          IconButton(
            icon: Icon(_showCalendar ? Icons.list : Icons.calendar_month),
            onPressed: () => setState(() => _showCalendar = !_showCalendar),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showCalendar)
            Card(
              margin: const EdgeInsets.all(12),
              child: CalendarDatePicker(
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
                onDateChanged: (d) => setState(() => _selectedDate = d),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search transactions...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final f in ['all', 'income', 'expense', 'transfer', 'savings', 'loan'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.toUpperCase()),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final t = filtered[i];
                return Card(
                  child: ListTile(
                    title: Text('${t.category} (${t.type.toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${t.walletName} • ${BdFormat.date(t.date)} • ${t.description}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(BdFormat.paisa(t.amountPaisa), style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                          onPressed: () => appStore.deleteTransaction(t.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TAB 3: MONTHLY & YEARLY REPORTS + EXPORT
// ============================================================================
class ReportsAndInsightsTab extends StatelessWidget {
  const ReportsAndInsightsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = now.day.clamp(1, 31);
    final avgDaily = appStore.monthlyExpensePaisa ~/ days;

    return Scaffold(
      appBar: AppBar(
        title: Text(appStore.tr('Financial Reports & Insights', 'আর্থিক রিপোর্ট ও বিশ্লেষণ')),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export CSV',
            onPressed: () {
              final csv = appStore.generateCsvExport();
              Clipboard.setData(ClipboardData(text: csv));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('CSV Report copied to clipboard & saved locally!')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Monthly Report (${now.month}/${now.year})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Divider(),
                  _row('Total Monthly Income', BdFormat.paisa(appStore.monthlyIncomePaisa)),
                  _row('Total Monthly Expenses', BdFormat.paisa(appStore.monthlyExpensePaisa)),
                  _row('Net Cash Flow', BdFormat.paisa(appStore.monthlyIncomePaisa - appStore.monthlyExpensePaisa)),
                  _row('Total Dedicated Savings', BdFormat.paisa(appStore.totalSavingsPaisa)),
                  _row('Average Daily Expense', BdFormat.paisa(avgDaily)),
                  _row('Remaining Monthly Budget', BdFormat.paisa(appStore.remainingBudgetPaisa)),
                  _row('Financial Health Score', '${appStore.financialHealthScore} / 100'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Net Worth & Balance Sheet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Divider(),
                  _row('Liquid Wallet Assets', BdFormat.paisa(appStore.totalAvailableBalancePaisa)),
                  _row('Savings Goal Assets', BdFormat.paisa(appStore.totalSavingsPaisa)),
                  _row('Loan Receivables (Lent)', BdFormat.paisa(appStore.totalLentReceivablePaisa)),
                  _row('Outstanding Debt (Borrowed)', BdFormat.paisa(appStore.totalBorrowedDebtPaisa)),
                  const Divider(),
                  _row('Total Net Worth', BdFormat.paisa(appStore.totalNetWorthPaisa)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k),
          Text(v, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ============================================================================
// TAB 4: SAVINGS GOALS, BUDGETS & LOANS
// ============================================================================
class SavingsBudgetsLoansTab extends StatelessWidget {
  const SavingsBudgetsLoansTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(appStore.tr('Savings, Budgets & Loans', 'সঞ্চয়, বাজেট ও ঋণ')),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Savings Goals'),
              Tab(text: 'Budgets'),
              Tab(text: 'Loans & Debt'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildSavingsView(context),
            _buildBudgetsView(context),
            _buildLoansView(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingsView(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        FilledButton.icon(
          onPressed: () {
            final nameCtrl = TextEditingController();
            final targetCtrl = TextEditingController();
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('New Savings Goal'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Goal Name (e.g. Laptop)')),
                    const SizedBox(height: 10),
                    TextField(controller: targetCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Target Amount (৳)')),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  FilledButton(
                    onPressed: () {
                      final t = BdFormat.parseTakaToPaisa(targetCtrl.text);
                      if (nameCtrl.text.isNotEmpty && t > 0) {
                        appStore.addSavingsGoal(nameCtrl.text.trim(), t, DateTime.now().add(const Duration(days: 180)));
                      }
                      Navigator.pop(ctx);
                    },
                    child: const Text('Create'),
                  ),
                ],
              ),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Create Savings Goal'),
        ),
        const SizedBox(height: 12),
        ...appStore.savingsGoals.map((g) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(g.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('${g.progressPct.toStringAsFixed(1)}%'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Saved: ${BdFormat.paisa(g.currentPaisa)} / ${BdFormat.paisa(g.targetPaisa)}'),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: g.progressPct / 100, minHeight: 8),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => _showSavingsMoveDialog(context, g, true),
                          child: const Text('+ Deposit'),
                        ),
                        TextButton(
                          onPressed: () => _showSavingsMoveDialog(context, g, false),
                          child: const Text('- Withdraw'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  void _showSavingsMoveDialog(BuildContext context, SavingsGoalItem g, bool isDeposit) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${isDeposit ? "Deposit to" : "Withdraw from"} ${g.name}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount (৳)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final p = BdFormat.parseTakaToPaisa(ctrl.text);
              if (p > 0) {
                appStore.moveSavings(goalId: g.id, walletId: appStore.wallets.first.id, amountPaisa: p, isDeposit: isDeposit);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetsView(BuildContext context) {
    final mCtrl = TextEditingController(text: (appStore.monthlyBudgetLimitPaisa ~/ 100).toString());
    final dCtrl = TextEditingController(text: (appStore.dailySpendingLimitPaisa ~/ 100).toString());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Budget Configuration (৳)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                TextField(controller: mCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Monthly Overall Budget (৳)', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: dCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Daily Spending Limit (৳)', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    appStore.setBudgets(
                      monthlyPaisa: BdFormat.parseTakaToPaisa(mCtrl.text),
                      dailyPaisa: BdFormat.parseTakaToPaisa(dCtrl.text),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Budgets Updated!')));
                  },
                  child: const Text('Save Budgets'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoansView(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        FilledButton.icon(
          onPressed: () {
            final pCtrl = TextEditingController();
            final aCtrl = TextEditingController();
            String type = 'borrowed';
            showDialog(
              context: context,
              builder: (ctx) => StatefulBuilder(
                builder: (ctx, setD) => AlertDialog(
                  title: const Text('Add Loan Record'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: pCtrl, decoration: const InputDecoration(labelText: 'Person Name')),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: type,
                        items: const [
                          DropdownMenuItem(value: 'borrowed', child: Text('Money Borrowed (Loan Taken)')),
                          DropdownMenuItem(value: 'lent', child: Text('Money Lent (Loan Given)')),
                        ],
                        onChanged: (v) => setD(() => type = v ?? 'borrowed'),
                      ),
                      const SizedBox(height: 10),
                      TextField(controller: aCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (৳)')),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    FilledButton(
                      onPressed: () {
                        final p = BdFormat.parseTakaToPaisa(aCtrl.text);
                        if (pCtrl.text.isNotEmpty && p > 0) {
                          appStore.addLoan(
                            personName: pCtrl.text.trim(),
                            loanType: type,
                            principalPaisa: p,
                            walletId: appStore.wallets.first.id,
                            dueDate: DateTime.now().add(const Duration(days: 30)),
                            notes: '',
                          );
                        }
                        Navigator.pop(ctx);
                      },
                      child: const Text('Save Loan'),
                    ),
                  ],
                ),
              ),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Borrowed / Lent Loan'),
        ),
        const SizedBox(height: 12),
        ...appStore.loans.map((l) => Card(
              child: ListTile(
                title: Text('${l.personName} (${l.loanType.toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Remaining: ${BdFormat.paisa(l.remainingPaisa)} / Principal: ${BdFormat.paisa(l.principalPaisa)}'),
                trailing: l.remainingPaisa == 0
                    ? const Chip(label: Text('Settled'))
                    : FilledButton.tonal(
                        onPressed: () => appStore.payLoanInstallment(l.id, appStore.wallets.first.id, l.remainingPaisa),
                        child: const Text('Settle'),
                      ),
              ),
            )),
      ],
    );
  }
}

// ============================================================================
// TAB 5: SETTINGS, WALLETS, PIN SECURITY & BACKUP
// ============================================================================
class SettingsAndWalletsTab extends StatelessWidget {
  const SettingsAndWalletsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(appStore.tr('Settings & Wallets', 'সেটিংস ও ওয়ালেট'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Wallets (৳ BDT)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: () {
                  final nCtrl = TextEditingController();
                  final bCtrl = TextEditingController();
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Add Wallet'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(controller: nCtrl, decoration: const InputDecoration(labelText: 'Wallet Name')),
                          const SizedBox(height: 10),
                          TextField(controller: bCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Opening Balance (৳)')),
                        ],
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        FilledButton(
                          onPressed: () {
                            if (nCtrl.text.isNotEmpty) {
                              appStore.addWallet(nCtrl.text.trim(), 'custom', BdFormat.parseTakaToPaisa(bCtrl.text));
                            }
                            Navigator.pop(ctx);
                          },
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('New Wallet'),
              ),
            ],
          ),
          ...appStore.wallets.map((w) => Card(
                child: ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF4A148C)),
                  title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Text(BdFormat.paisa(w.currentPaisa), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              )),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('Language / ভাষা'),
                  trailing: DropdownButton<String>(
                    value: appStore.language,
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'bn', child: Text('বাংলা')),
                    ],
                    onChanged: (v) => appStore.updatePreferences(lang: v),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Theme Mode'),
                  trailing: DropdownButton<String>(
                    value: appStore.themeMode,
                    items: const [
                      DropdownMenuItem(value: 'system', child: Text('System')),
                      DropdownMenuItem(value: 'light', child: Text('Light')),
                      DropdownMenuItem(value: 'dark', child: Text('Dark')),
                    ],
                    onChanged: (v) => appStore.updatePreferences(theme: v),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.pin_outlined),
                  title: Text(appStore.pinCode == null ? 'Set Security PIN Lock' : 'Update / Clear PIN Lock'),
                  onTap: () {
                    final ctrl = TextEditingController();
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Set 4-Digit PIN'),
                        content: TextField(
                          controller: ctrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'PIN (Leave blank to disable)'),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                          FilledButton(
                            onPressed: () {
                              appStore.updatePreferences(newPin: ctrl.text.trim());
                              Navigator.pop(ctx);
                            },
                            child: const Text('Save PIN'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
