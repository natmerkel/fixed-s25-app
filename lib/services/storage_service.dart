import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/trade_models.dart';

class StorageService {
  static const _levelsKey = 'levels_data';
  static const _tradesKey = 'trade_entries';

  Future<LevelsData> loadLevels() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_levelsKey);
    if (raw == null || raw.isEmpty) return LevelsData();
    return LevelsData.decode(raw);
  }

  Future<void> saveLevels(LevelsData levels) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_levelsKey, levels.encode());
  }

  Future<List<TradeEntry>> loadTrades() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_tradesKey);
    if (raw == null || raw.isEmpty) return [];
    final List<dynamic> decoded = jsonDecode(raw);
    return decoded
        .map((e) => TradeEntry.fromMap(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> saveTrades(List<TradeEntry> trades) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(trades.map((e) => e.toMap()).toList());
    await prefs.setString(_tradesKey, raw);
  }
}
