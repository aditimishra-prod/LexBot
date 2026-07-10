import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../services/api_service.dart';

// Content-type metadata
const _typeData = {
  'article': (Icons.article_outlined,           Color(0xFF818CF8)),
  'podcast': (Icons.headphones_outlined,         Color(0xFF34D399)),
  'video':   (Icons.play_circle_outline_rounded, Color(0xFFF87171)),
  'other':   (Icons.link_rounded,               Color(0xFF9B9AAE)),
};
const _typeBgs = {
  'article': Color(0x1A818CF8),
  'podcast': Color(0x1A34D399),
  'video':   Color(0x1AF87171),
  'other':   Color(0x1A9B9AAE),
};

const _dayKeys   = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const _dayLabels = {
  'mon': 'Mon', 'tue': 'Tue', 'wed': 'Wed', 'thu': 'Thu',
  'fri': 'Fri', 'sat': 'Sat', 'sun': 'Sun',
};
const _dayFull = {
  'mon': 'Monday', 'tue': 'Tuesday', 'wed': 'Wednesday', 'thu': 'Thursday',
  'fri': 'Friday',  'sat': 'Saturday', 'sun': 'Sunday',
};
const _weekdayIndex = {
  'mon': DateTime.monday, 'tue': DateTime.tuesday,   'wed': DateTime.wednesday,
  'thu': DateTime.thursday,'fri': DateTime.friday,   'sat': DateTime.saturday,
  'sun': DateTime.sunday,
};

class PlanScreen extends StatefulWidget {
  final int refreshTrigger;
  const PlanScreen({super.key, this.refreshTrigger = 0});
  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  Map<String, dynamic>? _plan;
  bool    _loading    = true;
  bool    _generating = false;
  bool    _editMode   = false;
  bool    _saving     = false;
  String? _error;
  String  _selectedDay = _todayKey();

  // Local mutable copy of plan_json['days'] for editing
  Map<String, dynamic> _editDays = {};

  static String _todayKey() {
    const map = {
      DateTime.monday: 'mon', DateTime.tuesday: 'tue', DateTime.wednesday: 'wed',
      DateTime.thursday: 'thu', DateTime.friday: 'fri', DateTime.saturday: 'sat',
      DateTime.sunday: 'sun',
    };
    return map[DateTime.now().weekday] ?? 'mon';
  }

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  @override
  void didUpdateWidget(PlanScreen old) {
    super.didUpdateWidget(old);
    if (widget.refreshTrigger != old.refreshTrigger) _loadPlan();
  }

  bool get _hasValidPlan {
    if (_plan == null) return false;
    if (_plan!.containsKey('message')) return false;
    final pj = _plan!['plan_json'];
    if (pj is! Map) return false;
    if (pj.containsKey('error')) return false;
    return true;
  }

  Future<void> _loadPlan() async {
    setState(() { _loading = true; _error = null; _editMode = false; });
    try {
      final data = await ApiService.fetchCurrentPlan();
      setState(() {
        _plan = data;
        _syncEditDays();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _syncEditDays() {
    if (!_hasValidPlan) { _editDays = {}; return; }
    final pj = _plan!['plan_json'] as Map;
    _editDays = Map<String, dynamic>.from(
        (pj['days'] as Map? ?? {}).map((k, v) => MapEntry(k, v)));
  }

  Future<void> _generatePlan() async {
    setState(() => _generating = true);
    try {
      final data = await ApiService.generatePlan();
      setState(() { _plan = data; _syncEditDays(); });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not generate plan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _savePlan() async {
    setState(() => _saving = true);
    try {
      // Build updated plan_json
      final pj = Map<String, dynamic>.from(_plan!['plan_json'] as Map);
      pj['days'] = _editDays;
      await ApiService.updatePlan(pj);
      // Update local state
      final updatedPlan = Map<String, dynamic>.from(_plan!);
      updatedPlan['plan_json'] = pj;
      setState(() { _plan = updatedPlan; _editMode = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plan saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _deleteItem(String dayKey, int index) {
    setState(() {
      final dayContent = _editDays[dayKey];
      List<dynamic> items = [];
      if (dayContent is List) {
        items = List.from(dayContent);
      } else if (dayContent is Map && dayContent['items'] is List) {
        items = List.from(dayContent['items'] as List);
      }
      if (index < items.length) {
        items.removeAt(index);
        if (dayContent is Map) {
          final updated = Map<String, dynamic>.from(dayContent);
          updated['items'] = items;
          _editDays[dayKey] = updated;
        } else {
          _editDays[dayKey] = items;
        }
      }
    });
  }

  List<dynamic> _itemsForDay(String dayKey) {
    dynamic content = _editDays[dayKey];
    if (content == null && _hasValidPlan) {
      final daysMap = (_plan!['plan_json'] as Map)['days'];
      if (daysMap is Map) content = daysMap[dayKey];
    }
    if (content is List) return content;
    if (content is Map && content['items'] is List) {
      return content['items'] as List;
    }
    return [];
  }

  String? _reflectionForDay(String dayKey) {
    final content = _editDays[dayKey];
    if (content is Map) return content['reflection'] as String?;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        title: Text("This Week",
            style: GoogleFonts.inter(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: kText1,
                letterSpacing: -0.3)),
        actions: [
          if (_hasValidPlan && !_loading) ...[
            if (_editMode)
              _saving
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                          child: SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  color: kAccent, strokeWidth: 2))))
                  : IconButton(
                      icon: const Icon(Icons.check_rounded,
                          color: kAccent, size: 22),
                      onPressed: _savePlan,
                      tooltip: "Save changes",
                    )
            else
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: kText2, size: 20),
                onPressed: () {
                  _syncEditDays();
                  setState(() => _editMode = true);
                },
                tooltip: "Edit plan",
              ),
            if (!_editMode)
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: kText2, size: 20),
                onPressed: _loadPlan,
                tooltip: "Refresh",
              ),
            if (_editMode)
              IconButton(
                icon: const Icon(Icons.close, color: kText3, size: 20),
                onPressed: () {
                  _syncEditDays();
                  setState(() => _editMode = false);
                },
                tooltip: "Cancel",
              ),
          ] else if (!_loading)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: kText2, size: 20),
              onPressed: _loadPlan,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: kBorderSoft),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kAccent))
          : _error != null
              ? _ErrorState(error: _error!, onRetry: _loadPlan)
              : !_hasValidPlan
                  ? _EmptyState(
                      generating: _generating, onGenerate: _generatePlan)
                  : _PlannerBody(
                      plan:         _plan!,
                      editDays:     _editDays,
                      editMode:     _editMode,
                      selectedDay:  _selectedDay,
                      onDaySelect:  (d) => setState(() => _selectedDay = d),
                      onDelete:     _deleteItem,
                      itemsForDay:  _itemsForDay,
                      reflectionForDay: _reflectionForDay,
                    ),
    );
  }
}

// ── Planner body ──────────────────────────────────────────────────────────────
class _PlannerBody extends StatelessWidget {
  final Map<String, dynamic> plan;
  final Map<String, dynamic> editDays;
  final bool         editMode;
  final String       selectedDay;
  final ValueChanged<String> onDaySelect;
  final void Function(String dayKey, int index) onDelete;
  final List<dynamic> Function(String dayKey) itemsForDay;
  final String? Function(String dayKey)       reflectionForDay;

  const _PlannerBody({
    required this.plan,
    required this.editDays,
    required this.editMode,
    required this.selectedDay,
    required this.onDaySelect,
    required this.onDelete,
    required this.itemsForDay,
    required this.reflectionForDay,
  });

  String get _theme {
    final pj = plan['plan_json'] ?? plan;
    return (pj['week_theme'] as String?) ?? '';
  }

  bool _isToday(String dayKey) =>
      DateTime.now().weekday == _weekdayIndex[dayKey];

  int _itemCount(String dayKey) => itemsForDay(dayKey).length;

  @override
  Widget build(BuildContext context) {
    final items = itemsForDay(selectedDay);
    final reflection = reflectionForDay(selectedDay);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Week theme banner ──
        if (_theme.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: kAccentMuted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kAccent.withOpacity(0.22)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome_outlined,
                    color: kAccent, size: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_theme,
                      style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: kText1,
                          height: 1.4)),
                ),
              ],
            ),
          ),

        const SizedBox(height: 12),

        // ── Day selector strip ──
        SizedBox(
          height: 58,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: _dayKeys.map((key) {
              final isSelected = key == selectedDay;
              final isToday    = _isToday(key);
              final count      = _itemCount(key);
              return GestureDetector(
                onTap: () => onDaySelect(key),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? kAccent
                        : isToday
                            ? kAccentMuted
                            : kSurface2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? kAccent
                          : isToday
                              ? kAccent.withOpacity(0.4)
                              : kBorderSoft,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_dayLabels[key]!,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : kText1)),
                      const SizedBox(height: 2),
                      Text(
                        count > 0 ? '$count item${count != 1 ? "s" : ""}' : 'Rest',
                        style: GoogleFonts.inter(
                            fontSize: 9.5,
                            color: isSelected
                                ? Colors.white.withOpacity(0.8)
                                : kText3),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // ── Day header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Row(
            children: [
              Text(_dayFull[selectedDay]!,
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: kText1)),
              if (_isToday(selectedDay)) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: kAccentMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text("TODAY",
                      style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: kAccent,
                          letterSpacing: 0.6)),
                ),
              ],
              if (editMode) ...[
                const Spacer(),
                Text("tap × to remove",
                    style: GoogleFonts.inter(
                        fontSize: 10.5, color: kText3,
                        fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),

        Container(height: 1, color: kBorderSoft),

        // ── Content list ──
        Expanded(
          child: items.isEmpty && reflection == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.self_improvement_outlined,
                          size: 42, color: kText3),
                      const SizedBox(height: 10),
                      Text("Rest day",
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: kText2)),
                      const SizedBox(height: 4),
                      Text("Nothing scheduled — take a break!",
                          style: GoogleFonts.inter(
                              fontSize: 12, color: kText3)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                  children: [
                    // Sunday reflection
                    if (selectedDay == 'sun' && reflection != null &&
                        reflection.isNotEmpty) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: kAccentMuted,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: kAccent.withOpacity(0.22)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.lightbulb_outline,
                                  color: kAccent, size: 14),
                              const SizedBox(width: 6),
                              Text("Weekly reflection",
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: kAccent)),
                            ]),
                            const SizedBox(height: 8),
                            Text(reflection,
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: kText1,
                                    height: 1.6,
                                    fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                    ],

                    // Content type summary pills
                    if (items.isNotEmpty) ...[
                      _TypeSummaryRow(items: items),
                      const SizedBox(height: 10),
                    ],

                    // Item cards
                    ...items.asMap().entries.map((e) {
                      final idx  = e.key;
                      final item = e.value as Map<String, dynamic>;
                      return _PlanItemCard(
                        item:     item,
                        editMode: editMode,
                        onDelete: () => onDelete(selectedDay, idx),
                      );
                    }),
                  ],
                ),
        ),
      ],
    );
  }
}

// ── Content-type summary pills ────────────────────────────────────────────────
class _TypeSummaryRow extends StatelessWidget {
  final List<dynamic> items;
  const _TypeSummaryRow({required this.items});

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final item in items) {
      if (item is Map) {
        final t = (item['content_type'] as String?) ?? 'other';
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }

    return Wrap(
      spacing: 6,
      children: counts.entries.map((e) {
        final (icon, color) = _typeData[e.key] ?? _typeData['other']!;
        final bg = _typeBgs[e.key] ?? const Color(0x1A9B9AAE);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 4),
              Text(
                '${e.value} ${e.key}${e.value > 1 ? "s" : ""}',
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Plan item card ────────────────────────────────────────────────────────────
class _PlanItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool         editMode;
  final VoidCallback onDelete;
  const _PlanItemCard(
      {required this.item, required this.editMode, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final title = item['title']        as String? ?? 'Untitled';
    final why   = item['why']          as String? ?? '';
    final url   = item['url']          as String? ?? '';
    final type  = item['content_type'] as String? ?? 'article';
    final est   = item['estimated_time'] as String?;

    final (icon, color) = _typeData[type] ?? _typeData['other']!;
    final bg            = _typeBgs[type]  ?? const Color(0x1A9B9AAE);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kSurface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderSoft),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: editMode
              ? null
              : () async {
                  if (url.isNotEmpty) {
                    final uri = Uri.tryParse(url);
                    if (uri != null) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  }
                },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type bubble
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: bg,
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 17),
                ),
                const SizedBox(width: 11),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type label + time estimate
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(5)),
                            child: Text(
                              type[0].toUpperCase() + type.substring(1),
                              style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: color),
                            ),
                          ),
                          if (est != null && est.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.timer_outlined,
                                size: 10, color: kText3),
                            const SizedBox(width: 2),
                            Text(est,
                                style: GoogleFonts.inter(
                                    fontSize: 10, color: kText3)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Title
                      Text(title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: kText1,
                              height: 1.35)),

                      // Why (curator reason)
                      if (why.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(why,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: kText2,
                                height: 1.4)),
                      ],

                      // Open link hint
                      if (!editMode && url.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.open_in_new,
                                size: 11, color: kText3),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                Uri.tryParse(url)?.host
                                        .replaceFirst('www.', '') ??
                                    url,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                    fontSize: 10.5, color: kText3),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Delete button (edit mode) or open icon
                if (editMode)
                  GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: kRedBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close, color: kRed, size: 14),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.chevron_right_rounded,
                        color: kText3, size: 18),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool _generating;
  final VoidCallback onGenerate;
  const _EmptyState({required bool generating, required this.onGenerate})
      : _generating = generating;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                  color: kAccentMuted,
                  borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.calendar_today_rounded,
                  color: kAccent, size: 32),
            ),
            const SizedBox(height: 20),
            Text("No plan yet",
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w700, color: kText1)),
            const SizedBox(height: 8),
            Text(
              "Your Mon–Sun learning plan is auto-generated every Sunday at 9 am IST.\n\nOr tap below to build one now from your saved DPDP resources.",
              style: GoogleFonts.inter(
                  fontSize: 12.5, color: kText2, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            _generating
                ? const CircularProgressIndicator(color: kAccent)
                : GestureDetector(
                    onTap: onGenerate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 12),
                      decoration: BoxDecoration(
                          color: kAccent,
                          borderRadius: BorderRadius.circular(14)),
                      child: Text("Generate Plan Now",
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: kRed, size: 48),
          const SizedBox(height: 12),
          Text(error,
              style: GoogleFonts.inter(fontSize: 12, color: kText2),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child: Text("Retry",
                style: GoogleFonts.inter(
                    color: kAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
