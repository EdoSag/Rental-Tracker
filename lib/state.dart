import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'calc.dart';
import 'db.dart';
import 'models.dart';

/// Holds all data in memory and writes every change straight to SQLite
/// (auto-save, no "save" button).
class AppState extends ChangeNotifier {
  final AppDb _db;
  final Directory photosDir;
  final Map<String, TenantMonth> _rows = {};
  final Map<String, MonthExpense> _expenses = {};
  final List<Photo> _photos = [];
  Settings settings;
  /// Bumped on restore so input fields re-read their values.
  int dataVersion = 0;
  Future<void> _writeQueue = Future.value();

  AppState._(this._db, this.photosDir, this.settings);

  static Future<AppState> load() async {
    final db = await AppDb.open();
    final docs = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(docs.path, 'photos'));
    await photosDir.create(recursive: true);
    final s = AppState._(db, photosDir, await db.settings());
    await s._reload();
    return s;
  }

  Future<void> _reload() async {
    _rows
      ..clear()
      ..addEntries((await _db.tenantMonths()).map((r) => MapEntry(Calculator.rowKey(r.month, r.tenant), r)));
    _expenses
      ..clear()
      ..addEntries((await _db.expenses()).map((e) => MapEntry(e.month, e)));
    _photos
      ..clear()
      ..addAll(await _db.photos());
    settings = await _db.settings();
  }

  void _write(Future<void> Function() op) {
    _writeQueue = _writeQueue.then((_) => op()).catchError((e) => debugPrint('DB write failed: $e'));
  }

  Future<void> flush() => _writeQueue;

  Calculator get calc => Calculator(_rows.values, _expenses.values, settings);

  List<TenantMonth> get rows => _rows.values.toList();
  List<MonthExpense> get expenses => _expenses.values.toList();
  List<Photo> get photos => List.unmodifiable(_photos);

  TenantMonth? row(String month, int tenant) => _rows[Calculator.rowKey(month, tenant)];
  MonthExpense? expense(String month) => _expenses[month];

  /// Creates the month's rows (all tenants + expenses) the first time it is edited.
  /// Rent is copied from settings at that moment, so later rent changes don't rewrite history.
  void _ensureMonth(String month) {
    for (var i = 0; i < kTenants.length; i++) {
      final key = Calculator.rowKey(month, i);
      if (!_rows.containsKey(key)) {
        final r = TenantMonth(month: month, tenant: i, rent: settings.rents[i]);
        _rows[key] = r;
        _write(() => _db.saveTenantMonth(r));
      }
    }
    if (!_expenses.containsKey(month)) {
      final e = MonthExpense(month: month);
      _expenses[month] = e;
      _write(() => _db.saveExpense(e));
    }
  }

  void updateTenant(String month, int tenant, void Function(TenantMonth r) change) {
    _ensureMonth(month);
    final r = _rows[Calculator.rowKey(month, tenant)]!;
    change(r);
    _write(() => _db.saveTenantMonth(r));
    notifyListeners();
  }

  void updateExpense(String month, void Function(MonthExpense e) change) {
    _ensureMonth(month);
    final e = _expenses[month]!;
    change(e);
    _write(() => _db.saveExpense(e));
    notifyListeners();
  }

  /// Changing a tenant's rent in settings also updates the current and future
  /// months already created; past months keep the rent they had.
  void updateSettings(void Function(Settings s) change, {String? currentMonth}) {
    final oldRents = List.of(settings.rents);
    change(settings);
    if (currentMonth != null) {
      for (var i = 0; i < kTenants.length; i++) {
        if (settings.rents[i] == oldRents[i]) continue;
        for (final r in _rows.values) {
          if (r.tenant == i && r.month.compareTo(currentMonth) >= 0) {
            r.rent = settings.rents[i];
            _write(() => _db.saveTenantMonth(r));
          }
        }
      }
    }
    final snapshot = settings;
    _write(() => _db.saveSettings(snapshot));
    notifyListeners();
  }

  List<Photo> photosFor(String month, int tenant) =>
      _photos.where((ph) => ph.month == month && ph.tenant == tenant).toList();

  File photoFile(Photo ph) => File(p.join(photosDir.path, ph.fileName));

  Future<void> addPhoto(String month, int tenant, String sourcePath) async {
    final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final name = '${month}_t${tenant}_${DateTime.now().microsecondsSinceEpoch}$ext';
    await File(sourcePath).copy(p.join(photosDir.path, name));
    _ensureMonth(month);
    await flush();
    final ph = Photo(month: month, tenant: tenant, fileName: name);
    final id = await _db.addPhoto(ph);
    _photos.add(Photo(id: id, month: month, tenant: tenant, fileName: name));
    notifyListeners();
  }

  Future<void> deletePhoto(Photo ph) async {
    _photos.removeWhere((x) => x.id == ph.id);
    notifyListeners();
    if (ph.id != null) await _db.deletePhoto(ph.id!);
    final f = photoFile(ph);
    if (await f.exists()) await f.delete();
  }

  /// Replace everything (restore). Photos must already be in [photosDir].
  Future<void> replaceAll(
      List<TenantMonth> rows, List<MonthExpense> exps, List<Photo> photos, Settings s) async {
    await flush();
    await _db.replaceAll(rows, exps, photos, s);
    await _reload();
    dataVersion++;
    notifyListeners();
  }
}
