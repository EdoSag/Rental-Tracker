import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// Local SQLite storage. Everything stays on the phone.
class AppDb {
  final Database db;
  AppDb._(this.db);

  static Future<AppDb> open() async {
    final path = p.join(await getDatabasesPath(), 'rental.db');
    final db = await openDatabase(path, version: 1, onCreate: (db, v) async {
      await db.execute('''CREATE TABLE tenant_month(
        month TEXT NOT NULL, tenant INTEGER NOT NULL, rent REAL NOT NULL DEFAULT 0,
        elec_prev REAL, elec_cur REAL, water_prev REAL, water_cur REAL,
        arnona REAL NOT NULL DEFAULT 0, paid INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY(month, tenant))''');
      await db.execute('''CREATE TABLE expense(
        month TEXT PRIMARY KEY, elec REAL NOT NULL DEFAULT 0, water REAL NOT NULL DEFAULT 0,
        arnona REAL NOT NULL DEFAULT 0, other REAL NOT NULL DEFAULT 0)''');
      await db.execute('''CREATE TABLE photo(
        id INTEGER PRIMARY KEY AUTOINCREMENT, month TEXT NOT NULL, tenant INTEGER NOT NULL,
        file TEXT NOT NULL)''');
      await db.execute('CREATE TABLE setting(key TEXT PRIMARY KEY, value REAL NOT NULL)');
    });
    return AppDb._(db);
  }

  Future<List<TenantMonth>> tenantMonths() async =>
      (await db.query('tenant_month')).map(TenantMonth.fromMap).toList();

  Future<List<MonthExpense>> expenses() async =>
      (await db.query('expense')).map(MonthExpense.fromMap).toList();

  Future<List<Photo>> photos() async =>
      (await db.query('photo', orderBy: 'id')).map(Photo.fromMap).toList();

  Future<Settings> settings() async {
    final rows = await db.query('setting');
    return Settings.fromKv({for (final r in rows) r['key'] as String: (r['value'] as num).toDouble()});
  }

  Future<void> saveTenantMonth(TenantMonth t) =>
      db.insert('tenant_month', t.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> saveExpense(MonthExpense e) =>
      db.insert('expense', e.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  Future<int> addPhoto(Photo ph) => db.insert('photo', ph.toMap());

  Future<void> deletePhoto(int id) => db.delete('photo', where: 'id = ?', whereArgs: [id]);

  Future<void> saveSettings(Settings s) async {
    final batch = db.batch();
    s.toKv().forEach((k, v) =>
        batch.insert('setting', {'key': k, 'value': v}, conflictAlgorithm: ConflictAlgorithm.replace));
    await batch.commit(noResult: true);
  }

  /// Replace all data (used by restore from backup).
  Future<void> replaceAll(
      List<TenantMonth> rows, List<MonthExpense> exps, List<Photo> photos, Settings s) async {
    await db.transaction((txn) async {
      await txn.delete('tenant_month');
      await txn.delete('expense');
      await txn.delete('photo');
      await txn.delete('setting');
      for (final r in rows) {
        await txn.insert('tenant_month', r.toMap());
      }
      for (final e in exps) {
        await txn.insert('expense', e.toMap());
      }
      for (final ph in photos) {
        await txn.insert('photo', ph.toMap());
      }
      for (final e in s.toKv().entries) {
        await txn.insert('setting', {'key': e.key, 'value': e.value});
      }
    });
  }
}
