import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../state.dart';

const _dataFile = 'data.json';
const _photosPrefix = 'photos/';

/// Everything in one zip: data.json + photos/.
List<int> buildBackupZip({
  required List<TenantMonth> rows,
  required List<MonthExpense> expenses,
  required List<Photo> photos,
  required Settings settings,
  required List<int>? Function(Photo) readPhoto,
}) {
  final data = {
    'format': 'rental-tracker-backup',
    'version': 1,
    'created': DateTime.now().toIso8601String(),
    'settings': settings.toKv(),
    'tenant_months': [for (final r in rows) r.toMap()],
    'expenses': [for (final e in expenses) e.toMap()],
    'photos': [for (final ph in photos) ph.toMap()..remove('id')],
  };
  final archive = Archive();
  final json = utf8.encode(const JsonEncoder.withIndent(' ').convert(data));
  archive.addFile(ArchiveFile(_dataFile, json.length, json));
  for (final ph in photos) {
    final bytes = readPhoto(ph);
    if (bytes != null) archive.addFile(ArchiveFile('$_photosPrefix${ph.fileName}', bytes.length, bytes));
  }
  return ZipEncoder().encode(archive)!;
}

class BackupContent {
  final List<TenantMonth> rows;
  final List<MonthExpense> expenses;
  final List<Photo> photos;
  final Settings settings;
  final Map<String, List<int>> photoBytes;
  BackupContent(this.rows, this.expenses, this.photos, this.settings, this.photoBytes);
}

BackupContent parseBackupZip(List<int> zipBytes) {
  final archive = ZipDecoder().decodeBytes(zipBytes);
  final dataEntry = archive.findFile(_dataFile);
  if (dataEntry == null) throw const FormatException('הקובץ אינו גיבוי של האפליקציה');
  final data = jsonDecode(utf8.decode(dataEntry.content as List<int>)) as Map<String, dynamic>;
  if (data['format'] != 'rental-tracker-backup') throw const FormatException('הקובץ אינו גיבוי של האפליקציה');
  final settings = Settings.fromKv({
    for (final e in (data['settings'] as Map<String, dynamic>).entries) e.key: (e.value as num).toDouble()
  });
  final rows = [for (final m in data['tenant_months'] as List) TenantMonth.fromMap(Map<String, Object?>.from(m))];
  final exps = [for (final m in data['expenses'] as List) MonthExpense.fromMap(Map<String, Object?>.from(m))];
  final photos = [for (final m in data['photos'] as List) Photo.fromMap(Map<String, Object?>.from(m))];
  final bytes = <String, List<int>>{};
  for (final f in archive.files) {
    if (f.isFile && f.name.startsWith(_photosPrefix)) {
      bytes[p.basename(f.name)] = f.content as List<int>;
    }
  }
  return BackupContent(rows, exps, photos.where((ph) => bytes.containsKey(ph.fileName)).toList(), settings, bytes);
}

Future<void> shareBackup(AppState state) async {
  await state.flush();
  final zip = buildBackupZip(
    rows: state.rows,
    expenses: state.expenses,
    photos: state.photos,
    settings: state.settings,
    readPhoto: (ph) {
      final f = state.photoFile(ph);
      return f.existsSync() ? f.readAsBytesSync() : null;
    },
  );
  final dir = await getTemporaryDirectory();
  final now = DateTime.now();
  final stamp = '${monthKey(now.year, now.month)}-${now.day.toString().padLeft(2, '0')}';
  final file = File(p.join(dir.path, 'rental_backup_$stamp.zip'));
  await file.writeAsBytes(zip, flush: true);
  await SharePlus.instance.share(ShareParams(
    files: [XFile(file.path, mimeType: 'application/zip')],
    subject: 'גיבוי ניהול שכירות',
  ));
}

/// Lets the user pick a backup zip. Returns null if cancelled.
Future<BackupContent?> pickBackup() async {
  final files = await FilePicker.pickFiles(type: FileType.any);
  if (files.isEmpty) return null;
  final bytes = await files.first.xFile.readAsBytes();
  return parseBackupZip(bytes);
}

Future<void> restoreBackup(AppState state, BackupContent c) async {
  // Remove old photos, write the restored ones.
  if (await state.photosDir.exists()) {
    for (final f in state.photosDir.listSync()) {
      if (f is File) await f.delete();
    }
  }
  for (final e in c.photoBytes.entries) {
    await File(p.join(state.photosDir.path, e.key)).writeAsBytes(e.value, flush: true);
  }
  await state.replaceAll(c.rows, c.expenses, c.photos, c.settings);
}
