import 'dart:convert';

class LevelsData {
  double? mondayHigh;
  double? mondayLow;
  double? h4Support;
  double? h4Resistance;
  double? currentPrice;
  DateTime? lastUpdated;

  LevelsData({
    this.mondayHigh,
    this.mondayLow,
    this.h4Support,
    this.h4Resistance,
    this.currentPrice,
    this.lastUpdated,
  });

  String get locationLabel {
    if (currentPrice == null || h4Support == null || h4Resistance == null) return 'Unknown';
    final p = currentPrice!;
    final s = h4Support!;
    final r = h4Resistance!;
    final band = (r - s).abs() * 0.15;
    if (p <= s + band) return 'At support';
    if (p >= r - band) return 'At resistance';
    return 'Mid-range';
  }

  String get rangeStatus {
    if (h4Support == null || h4Resistance == null) return 'Not set';
    return 'Active 4H range: ${h4Support!.toStringAsFixed(2)} - ${h4Resistance!.toStringAsFixed(2)}';
  }

  Map<String, dynamic> toMap() => {
        'mondayHigh': mondayHigh,
        'mondayLow': mondayLow,
        'h4Support': h4Support,
        'h4Resistance': h4Resistance,
        'currentPrice': currentPrice,
        'lastUpdated': lastUpdated?.toIso8601String(),
      };

  factory LevelsData.fromMap(Map<String, dynamic> map) => LevelsData(
        mondayHigh: (map['mondayHigh'] as num?)?.toDouble(),
        mondayLow: (map['mondayLow'] as num?)?.toDouble(),
        h4Support: (map['h4Support'] as num?)?.toDouble(),
        h4Resistance: (map['h4Resistance'] as num?)?.toDouble(),
        currentPrice: (map['currentPrice'] as num?)?.toDouble(),
        lastUpdated: map['lastUpdated'] != null ? DateTime.tryParse(map['lastUpdated']) : null,
      );

  String encode() => jsonEncode(toMap());
  factory LevelsData.decode(String raw) => LevelsData.fromMap(jsonDecode(raw));
}

class TradeChecklist {
  bool sessionWindow;
  bool atKeyLevel;
  bool mondayRangeClean;
  bool h4LevelObvious;
  bool whaleKillerAligned;
  bool volumeSupportive;
  bool rrValid;
  bool riskValid;
  bool tradeCountValid;

  TradeChecklist({
    this.sessionWindow = false,
    this.atKeyLevel = false,
    this.mondayRangeClean = false,
    this.h4LevelObvious = false,
    this.whaleKillerAligned = false,
    this.volumeSupportive = false,
    this.rrValid = false,
    this.riskValid = false,
    this.tradeCountValid = false,
  });

  bool get complete =>
      sessionWindow &&
      atKeyLevel &&
      mondayRangeClean &&
      h4LevelObvious &&
      whaleKillerAligned &&
      volumeSupportive &&
      rrValid &&
      riskValid &&
      tradeCountValid;

  Map<String, dynamic> toMap() => {
        'sessionWindow': sessionWindow,
        'atKeyLevel': atKeyLevel,
        'mondayRangeClean': mondayRangeClean,
        'h4LevelObvious': h4LevelObvious,
        'whaleKillerAligned': whaleKillerAligned,
        'volumeSupportive': volumeSupportive,
        'rrValid': rrValid,
        'riskValid': riskValid,
        'tradeCountValid': tradeCountValid,
      };

  factory TradeChecklist.fromMap(Map<String, dynamic> map) => TradeChecklist(
        sessionWindow: map['sessionWindow'] ?? false,
        atKeyLevel: map['atKeyLevel'] ?? false,
        mondayRangeClean: map['mondayRangeClean'] ?? false,
        h4LevelObvious: map['h4LevelObvious'] ?? false,
        whaleKillerAligned: map['whaleKillerAligned'] ?? false,
        volumeSupportive: map['volumeSupportive'] ?? false,
        rrValid: map['rrValid'] ?? false,
        riskValid: map['riskValid'] ?? false,
        tradeCountValid: map['tradeCountValid'] ?? false,
      );
}

class TradeEntry {
  String id;
  DateTime createdAt;
  String symbol;
  String setupTag;
  String sourceLevel;
  double entry;
  double stop;
  double tp1;
  double tp2;
  double leverage;
  String management;
  String review;
  TradeChecklist checklist;
  int planQuality;
  int executionQuality;
  int discipline;
  int emotionalControl;

  TradeEntry({
    required this.id,
    required this.createdAt,
    required this.symbol,
    required this.setupTag,
    required this.sourceLevel,
    required this.entry,
    required this.stop,
    required this.tp1,
    required this.tp2,
    required this.leverage,
    required this.management,
    required this.review,
    required this.checklist,
    required this.planQuality,
    required this.executionQuality,
    required this.discipline,
    required this.emotionalControl,
  });

  double get riskDistance => (entry - stop).abs();
  double get rewardToTp1 => (tp1 - entry).abs();
  double get rrToTp1 => riskDistance == 0 ? 0 : rewardToTp1 / riskDistance;
  int get totalScore => planQuality + executionQuality + discipline + emotionalControl;

  Map<String, dynamic> toMap() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'symbol': symbol,
        'setupTag': setupTag,
        'sourceLevel': sourceLevel,
        'entry': entry,
        'stop': stop,
        'tp1': tp1,
        'tp2': tp2,
        'leverage': leverage,
        'management': management,
        'review': review,
        'checklist': checklist.toMap(),
        'planQuality': planQuality,
        'executionQuality': executionQuality,
        'discipline': discipline,
        'emotionalControl': emotionalControl,
      };

  factory TradeEntry.fromMap(Map<String, dynamic> map) => TradeEntry(
        id: map['id'],
        createdAt: DateTime.parse(map['createdAt']),
        symbol: map['symbol'],
        setupTag: map['setupTag'],
        sourceLevel: map['sourceLevel'],
        entry: (map['entry'] as num).toDouble(),
        stop: (map['stop'] as num).toDouble(),
        tp1: (map['tp1'] as num).toDouble(),
        tp2: (map['tp2'] as num).toDouble(),
        leverage: (map['leverage'] as num).toDouble(),
        management: map['management'] ?? '',
        review: map['review'] ?? '',
        checklist: TradeChecklist.fromMap(Map<String, dynamic>.from(map['checklist'])),
        planQuality: map['planQuality'] ?? 0,
        executionQuality: map['executionQuality'] ?? 0,
        discipline: map['discipline'] ?? 0,
        emotionalControl: map['emotionalControl'] ?? 0,
      );
}
