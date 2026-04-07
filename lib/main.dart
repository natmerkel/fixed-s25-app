import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'models/trade_models.dart';
import 'services/export_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'widgets/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notifications = NotificationService();
  await notifications.init();
  runApp(MondayRangeApp(notifications: notifications));
}

class MondayRangeApp extends StatelessWidget {
  final NotificationService notifications;
  const MondayRangeApp({super.key, required this.notifications});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Monday Range Journal',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0E14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4ADE80),
          secondary: Color(0xFF60A5FA),
          surface: Color(0xFF141821),
          error: Color(0xFFEF4444),
        ),
        useMaterial3: true,
      ),
      home: HomeScreen(notifications: notifications),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final NotificationService notifications;
  const HomeScreen({super.key, required this.notifications});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final storage = StorageService();
  final exportService = ExportService();
  LevelsData levels = LevelsData();
  List<TradeEntry> trades = [];
  Timer? timer;
  DateTime now = DateTime.now().toUtc().add(const Duration(hours: 10));

  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        now = DateTime.now().toUtc().add(const Duration(hours: 10));
      });
    });
  }

  Future<void> load() async {
    final loadedLevels = await storage.loadLevels();
    final loadedTrades = await storage.loadTrades();
    setState(() {
      levels = loadedLevels;
      trades = loadedTrades;
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  bool get sessionOpen {
    final start = DateTime(now.year, now.month, now.day, 23, 0);
    final end = start.add(const Duration(hours: 4));
    final adjustedNow = now.hour < 3 ? now.add(const Duration(days: -1)) : now;
    final sessionStart = DateTime(adjustedNow.year, adjustedNow.month, adjustedNow.day, 23, 0);
    final sessionEnd = sessionStart.add(const Duration(hours: 4));
    return now.isAfter(sessionStart) && now.isBefore(sessionEnd);
  }

  Duration timeToNextSession() {
    var next = DateTime(now.year, now.month, now.day, 23, 0);
    if (now.isAfter(next)) next = next.add(const Duration(days: 1));
    return next.difference(now);
  }

  String countdownLabel() {
    final d = timeToNextSession();
    return '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  int tradesThisSession() {
    final adjustedNow = now.hour < 3 ? now.add(const Duration(days: -1)) : now;
    final sessionStart = DateTime(adjustedNow.year, adjustedNow.month, adjustedNow.day, 23, 0);
    final sessionEnd = sessionStart.add(const Duration(hours: 4));
    return trades.where((t) => t.createdAt.isAfter(sessionStart) && t.createdAt.isBefore(sessionEnd)).length;
  }

  Future<void> openLevelsEditor() async {
    final result = await Navigator.push<LevelsData>(
      context,
      MaterialPageRoute(builder: (_) => LevelsEditorScreen(levels: levels)),
    );
    if (result != null) {
      await storage.saveLevels(result);
      setState(() => levels = result);
    }
  }

  Future<void> openTradeForm() async {
    final result = await Navigator.push<TradeEntry>(
      context,
      MaterialPageRoute(
        builder: (_) => TradeFormScreen(
          tradesThisSession: tradesThisSession(),
          levels: levels,
        ),
      ),
    );
    if (result != null) {
      final updated = [result, ...trades];
      await storage.saveTrades(updated);
      setState(() => trades = updated);
      await widget.notifications.instantAlert(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        title: 'New trade logged – remember to grade execution',
        body: '${result.symbol} | ${result.setupTag} | Score ${result.totalScore}/40',
      );
    }
  }

  Future<void> exportCsv() async {
    final file = await exportService.exportTrades(trades);
    await exportService.shareFile(file);
  }

  @override
  Widget build(BuildContext context) {
    final location = levels.locationLabel;
    final warning = location == 'Mid-range';
    final weeklyTrades = trades.where((t) => now.difference(t.createdAt).inDays < 7).toList();
    final avgScore = weeklyTrades.isEmpty
        ? 0.0
        : weeklyTrades.map((e) => e.totalScore).reduce((a, b) => a + b) / weeklyTrades.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monday Range Journal'),
        actions: [
          IconButton(onPressed: openLevelsEditor, icon: const Icon(Icons.tune)),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TraderCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('Session Status', subtitle: 'AEST / Brisbane handling built in'),
                  const SizedBox(height: 12),
                  Text(DateFormat('EEE d MMM • hh:mm:ss a').format(now), style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                    sessionOpen ? 'Session Open' : 'Countdown to 11:00 PM AEST',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: sessionOpen ? const Color(0xFF4ADE80) : Colors.white),
                  ),
                  if (!sessionOpen) ...[
                    const SizedBox(height: 8),
                    Text(countdownLabel(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            TraderCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('Current Price Location'),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: warning ? const Color(0xFF3A1015) : const Color(0xFF10221A),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(location, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text(
                          warning ? 'Mid-range = NO TRADE (instant rejection).' : 'Only proceed if all remaining rules are satisfied.',
                          style: TextStyle(color: warning ? const Color(0xFFFCA5A5) : const Color(0xFF9AE6B4)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TraderCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('Structure'),
                  const SizedBox(height: 12),
                  infoRow('Monday High', levels.mondayHigh),
                  infoRow('Monday Low', levels.mondayLow),
                  infoRow('4H Support', levels.h4Support),
                  infoRow('4H Resistance', levels.h4Resistance),
                  infoRow('Current Price', levels.currentPrice),
                  const SizedBox(height: 8),
                  Text(levels.rangeStatus, style: const TextStyle(color: Color(0xFF9AA4B2))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RulesScreen())), child: const Text('View Full Rules'))),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(onPressed: openTradeForm, child: const Text('Start New Trade'))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JournalScreen(trades: trades))), child: const Text('View Journal'))),
                const SizedBox(width: 12),
                Expanded(child: OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AlertsScreen(notifications: widget.notifications))), child: const Text('Alerts Settings'))),
              ],
            ),
            const SizedBox(height: 16),
            TraderCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('Weekly Summary'),
                  const SizedBox(height: 10),
                  Text('Trades: ${weeklyTrades.length}'),
                  Text('Average score: ${avgScore.toStringAsFixed(1)}/40'),
                  Text('Trades this session: ${tradesThisSession()}/2'),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(onPressed: trades.isEmpty ? null : exportCsv, icon: const Icon(Icons.download), label: const Text('Export CSV')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget infoRow(String label, double? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF9AA4B2))),
          Text(value == null ? '--' : value.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class LevelsEditorScreen extends StatefulWidget {
  final LevelsData levels;
  const LevelsEditorScreen({super.key, required this.levels});

  @override
  State<LevelsEditorScreen> createState() => _LevelsEditorScreenState();
}

class _LevelsEditorScreenState extends State<LevelsEditorScreen> {
  late final TextEditingController mondayHigh;
  late final TextEditingController mondayLow;
  late final TextEditingController h4Support;
  late final TextEditingController h4Resistance;
  late final TextEditingController currentPrice;

  @override
  void initState() {
    super.initState();
    mondayHigh = TextEditingController(text: widget.levels.mondayHigh?.toString() ?? '');
    mondayLow = TextEditingController(text: widget.levels.mondayLow?.toString() ?? '');
    h4Support = TextEditingController(text: widget.levels.h4Support?.toString() ?? '');
    h4Resistance = TextEditingController(text: widget.levels.h4Resistance?.toString() ?? '');
    currentPrice = TextEditingController(text: widget.levels.currentPrice?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Structure Levels')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          field('Monday High', mondayHigh),
          field('Monday Low', mondayLow),
          field('Active 4H Support', h4Support),
          field('Active 4H Resistance', h4Resistance),
          field('Current Price', currentPrice),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              Navigator.pop(
                context,
                LevelsData(
                  mondayHigh: double.tryParse(mondayHigh.text),
                  mondayLow: double.tryParse(mondayLow.text),
                  h4Support: double.tryParse(h4Support.text),
                  h4Resistance: double.tryParse(h4Resistance.text),
                  currentPrice: double.tryParse(currentPrice.text),
                  lastUpdated: DateTime.now().toUtc().add(const Duration(hours: 10)),
                ),
              );
            },
            child: const Text('Save Levels'),
          )
        ],
      ),
    );
  }

  Widget field(String label, TextEditingController controller) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
        ),
      );
}

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const rules = r'''
Trade only between 11:00 PM and 3:00 AM AEST. No entries outside this window. Asian session is strictly for marking structure only.

Before every session, mark: Monday High, Monday Low, Active 4H resistance, Active 4H support.

The active 4H range (support/resistance) is the key daily trading zone inside or aligned with Monday’s levels.

Classify current price location before any trade: At support, At resistance, or Mid-range. Mid-range = NO TRADE (instant rejection).

Level priority:
1. Monday High / Monday Low (primary)
2. 4H support / resistance (secondary)
3. 5m confirmation
4. 1m only for fine execution timing — never for creating the setup.

Use Whale Killer V2 (21/34/200 close) for confirmation on 5m.

5m confirmation is mandatory: clear rejection wick + close back inside the level/zone + volume higher than average of previous 5 candles + Whale Killer 21/34 crossover aligned with the 200-line filter.

Four setups only:

Range Long: Price taps Monday Low or 4H support → 5m bullish rejection + close back above + Whale Killer long confirmation. Entry on confirmation. Stop beyond rejection low. Targets: TP1 mid-range or nearest internal resistance, TP2 opposite side. Min 2:1 RR.

Range Short: Price taps Monday High or 4H resistance → 5m bearish rejection + close back below + Whale Killer short confirmation.

Bullish Breakout: Completed 4H candle closes above Monday High or 4H resistance during window → 5m confirmation or clean retest hold.

Bearish Breakdown: Completed 4H candle closes below Monday Low or 4H support during window → 5m confirmation or retest failure.

Hard rules: Only trade a clean range (at least 2 clear reactions from both boundaries on 4H, visually obvious, wide enough for 2:1 RR). Volume must be supportive on confirmation candle. Skip if too extended (>25–30% toward TP1 or abnormally large candle). Max 2 trades per session.

Risk: Exactly 0.5% of account per trade ($0.50 on $100 account). Leverage 5x–10x maximum. Stop always beyond invalidation zone. Never widen stop. Minimum 2:1 RR to TP1.''';
    return Scaffold(
      appBar: AppBar(title: const Text('Full Rules & Execution Card')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          TraderCard(child: Text(rules, style: TextStyle(height: 1.55))),
        ],
      ),
    );
  }
}

class TradeFormScreen extends StatefulWidget {
  final int tradesThisSession;
  final LevelsData levels;
  const TradeFormScreen({super.key, required this.tradesThisSession, required this.levels});

  @override
  State<TradeFormScreen> createState() => _TradeFormScreenState();
}

class _TradeFormScreenState extends State<TradeFormScreen> {
  final formKey = GlobalKey<FormState>();
  final entry = TextEditingController();
  final stop = TextEditingController();
  final tp1 = TextEditingController();
  final tp2 = TextEditingController();
  final leverage = TextEditingController(text: '5');
  final management = TextEditingController();
  final review = TextEditingController();
  String symbol = 'ETHUSD';
  String setup = 'Range Long';
  String sourceLevel = 'Monday Low';
  final checklist = TradeChecklist();
  double riskPercent = 0.5;
  int planQuality = 0;
  int executionQuality = 0;
  int discipline = 0;
  int emotionalControl = 0;

  @override
  void initState() {
    super.initState();
    checklist.tradeCountValid = widget.tradesThisSession < 2;
    checklist.atKeyLevel = widget.levels.locationLabel != 'Mid-range';
  }

  @override
  Widget build(BuildContext context) {
    final rr = _rr();
    checklist.rrValid = rr >= 2.0;
    checklist.riskValid = riskPercent <= 0.5 && double.tryParse(leverage.text) != null && double.parse(leverage.text) <= 10;

    return Scaffold(
      appBar: AppBar(title: const Text('New Trade')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionTitle('Pre-Trade Checklist', subtitle: 'Must be complete before logging'),
            const SizedBox(height: 12),
            ...checkTile('Session window', checklist.sessionWindow, (v) => setState(() => checklist.sessionWindow = v ?? false)),
            ...checkTile('At key level (not mid-range)', checklist.atKeyLevel, null),
            ...checkTile('Monday range clean', checklist.mondayRangeClean, (v) => setState(() => checklist.mondayRangeClean = v ?? false)),
            ...checkTile('4H level obvious', checklist.h4LevelObvious, (v) => setState(() => checklist.h4LevelObvious = v ?? false)),
            ...checkTile('Whale Killer aligned on 5m', checklist.whaleKillerAligned, (v) => setState(() => checklist.whaleKillerAligned = v ?? false)),
            ...checkTile('Volume supportive', checklist.volumeSupportive, (v) => setState(() => checklist.volumeSupportive = v ?? false)),
            ...checkTile('RR ≥ 2:1', checklist.rrValid, null),
            ...checkTile('Risk 0.5% or less', checklist.riskValid, null),
            ...checkTile('<2 trades this session', checklist.tradeCountValid, null),
            const SizedBox(height: 16),
            DropdownButtonFormField(value: symbol, items: const ['ETHUSD', 'BTCUSD'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => symbol = v!)),
            const SizedBox(height: 12),
            DropdownButtonFormField(value: setup, items: const ['Range Long', 'Range Short', 'Bullish Breakout', 'Bearish Breakdown'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => setup = v!)),
            const SizedBox(height: 12),
            DropdownButtonFormField(value: sourceLevel, items: const ['Monday High', 'Monday Low', '4H Support', '4H Resistance'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => sourceLevel = v!)),
            const SizedBox(height: 12),
            numField('Entry', entry),
            numField('Stop', stop),
            numField('TP1', tp1),
            numField('TP2', tp2),
            numField('Leverage (5x–10x max)', leverage),
            const SizedBox(height: 12),
            Slider(
              value: riskPercent,
              min: 0.1,
              max: 1.0,
              divisions: 9,
              label: '${riskPercent.toStringAsFixed(1)}%',
              onChanged: (v) => setState(() => riskPercent = v),
            ),
            Text('Risk per trade: ${riskPercent.toStringAsFixed(1)}%'),
            const SizedBox(height: 8),
            Text('RR to TP1: ${rr.toStringAsFixed(2)}', style: TextStyle(color: rr >= 2 ? const Color(0xFF4ADE80) : const Color(0xFFEF4444))),
            const SizedBox(height: 12),
            textField('Management notes', management, maxLines: 3),
            textField('Review', review, maxLines: 4),
            const SizedBox(height: 12),
            scoreSlider('Plan Quality', planQuality, (v) => setState(() => planQuality = v)),
            scoreSlider('Execution Quality', executionQuality, (v) => setState(() => executionQuality = v)),
            scoreSlider('Discipline', discipline, (v) => setState(() => discipline = v)),
            scoreSlider('Emotional Control', emotionalControl, (v) => setState(() => emotionalControl = v)),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                if (!checklist.complete) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checklist is incomplete. Logging blocked.')));
                  return;
                }
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(
                  context,
                  TradeEntry(
                    id: const Uuid().v4(),
                    createdAt: DateTime.now().toUtc().add(const Duration(hours: 10)),
                    symbol: symbol,
                    setupTag: setup,
                    sourceLevel: sourceLevel,
                    entry: double.parse(entry.text),
                    stop: double.parse(stop.text),
                    tp1: double.parse(tp1.text),
                    tp2: double.parse(tp2.text),
                    leverage: double.parse(leverage.text),
                    management: management.text,
                    review: review.text,
                    checklist: checklist,
                    planQuality: planQuality,
                    executionQuality: executionQuality,
                    discipline: discipline,
                    emotionalControl: emotionalControl,
                  ),
                );
              },
              child: const Text('Save Trade'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> checkTile(String title, bool value, ValueChanged<bool?>? onChanged) => [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: value,
          title: Text(title),
          onChanged: onChanged,
        )
      ];

  Widget numField(String label, TextEditingController controller) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (v) => (v == null || double.tryParse(v) == null) ? 'Enter a valid number' : null,
          decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
        ),
      );

  Widget textField(String label, TextEditingController controller, {int maxLines = 2}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
        ),
      );

  Widget scoreSlider(String label, int value, ValueChanged<int> onChanged) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: $value/10'),
          Slider(value: value.toDouble(), min: 0, max: 10, divisions: 10, onChanged: (v) => onChanged(v.round())),
        ],
      );

  double _rr() {
    final e = double.tryParse(entry.text);
    final s = double.tryParse(stop.text);
    final t = double.tryParse(tp1.text);
    if (e == null || s == null || t == null || e == s) return 0;
    return (t - e).abs() / (e - s).abs();
  }
}

class JournalScreen extends StatelessWidget {
  final List<TradeEntry> trades;
  const JournalScreen({super.key, required this.trades});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trade Journal')),
      body: trades.isEmpty
          ? const Center(child: Text('No trades logged yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: trades.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, index) {
                final t = trades[index];
                return TraderCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${t.symbol} • ${t.setupTag}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          Text('${t.totalScore}/40', style: const TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(DateFormat('EEE d MMM • hh:mm a').format(t.createdAt)),
                      const SizedBox(height: 10),
                      Text('Source level: ${t.sourceLevel}'),
                      Text('Entry ${t.entry} | Stop ${t.stop} | TP1 ${t.tp1} | TP2 ${t.tp2}'),
                      Text('RR to TP1: ${t.rrToTp1.toStringAsFixed(2)} | Leverage: ${t.leverage}x'),
                      const SizedBox(height: 10),
                      Text('Management: ${t.management.isEmpty ? '-' : t.management}'),
                      Text('Review: ${t.review.isEmpty ? '-' : t.review}'),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class AlertsScreen extends StatelessWidget {
  final NotificationService notifications;
  const AlertsScreen({super.key, required this.notifications});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alerts Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TraderCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Phone Alerts'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    await notifications.requestPermissions();
                    await notifications.scheduleDailySessionOpen();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Daily 11 PM session alert scheduled.')));
                    }
                  },
                  child: const Text('Enable 11 PM Session Alert'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () async {
                    await notifications.instantAlert(
                      id: 999,
                      title: 'Price near 4H Support / Monday Low – check for 5m confirmation',
                      body: 'Manual test alert fired.',
                    );
                  },
                  child: const Text('Send Test Alert'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'For live price-based alerts on ETHUSD and BTCUSD, connect Firebase Cloud Messaging plus a small backend or TradingView webhook bridge. This scaffold is ready for that extension.',
                  style: TextStyle(color: Color(0xFF9AA4B2), height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
