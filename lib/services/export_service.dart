import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/trade_models.dart';

class ExportService {
  Future<File> exportTrades(List<TradeEntry> trades) async {
    final rows = <List<dynamic>>[
      [
        'Created At',
        'Symbol',
        'Setup',
        'Source Level',
        'Entry',
        'Stop',
        'TP1',
        'TP2',
        'RR to TP1',
        'Leverage',
        'Checklist Complete',
        'Plan Quality',
        'Execution Quality',
        'Discipline',
        'Emotional Control',
        'Total Score',
        'Management',
        'Review',
      ]
    ];

    for (final t in trades) {
      rows.add([
        t.createdAt.toIso8601String(),
        t.symbol,
        t.setupTag,
        t.sourceLevel,
        t.entry,
        t.stop,
        t.tp1,
        t.tp2,
        t.rrToTp1.toStringAsFixed(2),
        t.leverage,
        t.checklist.complete ? 'YES' : 'NO',
        t.planQuality,
        t.executionQuality,
        t.discipline,
        t.emotionalControl,
        t.totalScore,
        t.management,
        t.review,
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/monday_range_journal.csv');
    await file.writeAsString(csv);
    return file;
  }

  Future<void> shareFile(File file) async {
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }
}
