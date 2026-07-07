import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../services/api_service.dart';

// Content-type icon + colour
const _typeData = {
  'article': (Icons.article_outlined,          Color(0xFF818CF8)),
  'podcast': (Icons.headphones_outlined,        Color(0xFF34D399)),
  'video':   (Icons.play_circle_outline_rounded,Color(0xFFF87171)),
  'other':   (Icons.link_rounded,              Color(0xFF9B9AAE)),
};

const _dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const _dayLabels = {
  'mon': 'Monday',
  'tue': 'Tuesday',
  'wed': 'Wednesday',
  'thu': 'Thursday',
  'fri': 'Friday',
  'sat': 'Saturday',
  'sun': 'Sunday',
};
const _weekdayIndex = {
  'mon': DateTime.monday,
  'tue': DateTime.tuesday,
  'wed': DateTime.wednesday,
  'thu': DateTime.thursday,
  'fri': DateTime.friday,
  'sat': DateTime.saturday,
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
  bool    _loading     = true;
  bool    _generating  = false;
  String? _error;

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

  Future<void> _loadPlan() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.fetchCurrentPlan();
      setState(() => _plan = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generatePlan() async {
    setState(() => _generating = true);
    try {
      final data = await ApiService.generatePlan();
      setState(() => _plan = data);
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
          if (!_generating)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: kText2, size: 20),
              onPressed: _loadPlan,
              tooltip: "Refresh plan",
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
              : _plan == null || _plan!.containsKey('message')
                  ? _EmptyState(
                      generating: _generating,
                      onGenerate: _generatePlan,
                    )
                  : _PlanBody(plan: _plan!),
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
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: kAccentMuted,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.calendar_today_rounded,
                  color: kAccent, size: 32),
            ),
            const SizedBox(height: 20),
            Text("No plan yet",
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: kText1)),
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

// ── Plan body ─────────────────────────────────────────────────────────────────
class _PlanBody extends StatelessWidget {
  final Map<String, dynamic> plan;
  const _PlanBody({required this.plan});

  @override
  Widget build(BuildContext context) {
    final planJson = plan['plan_json'] ?? plan;
    final days     = (planJson['days'] as Map<String, dynamic>?) ?? {};
    final theme    = (planJson['week_theme'] as String?) ?? '';

    return RefreshIndicator(
      color: kAccent,
      backgroundColor: kSurface2,
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Week theme banner
          if (theme.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: kAccentMuted,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kAccent.withOpacity(0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome_outlined,
                      color: kAccent, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(theme,
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: kText1,
                            height: 1.4)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Day cards
          ..._dayKeys.map((key) => _DayCard(
                dayKey: key,
                label:  _dayLabels[key]!,
                content: days[key],
              )),
        ],
      ),
    );
  }
}

// ── Day card ──────────────────────────────────────────────────────────────────
class _DayCard extends StatefulWidget {
  final String  dayKey;
  final String  label;
  final dynamic content;
  const _DayCard(
      {required this.dayKey, required this.label, required this.content});

  @override
  State<_DayCard> createState() => _DayCardState();
}

class _DayCardState extends State<_DayCard> {
  late bool _expanded;

  bool get _isToday =>
      DateTime.now().weekday == _weekdayIndex[widget.dayKey];

  @override
  void initState() {
    super.initState();
    _expanded = _isToday; // today auto-expanded
  }

  @override
  Widget build(BuildContext context) {
    final items = _itemsForDay(widget.content);
    final isEmpty = items.isEmpty &&
        !(widget.dayKey == 'sun' && widget.content is Map);

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: kSurface2,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(
              color: _isToday ? kAccent : kBorder, width: _isToday ? 3 : 1),
          top:    const BorderSide(color: kBorderSoft),
          right:  const BorderSide(color: kBorderSoft),
          bottom: const BorderSide(color: kBorderSoft),
        ),
      ),
      child: Column(
        children: [
          // Header row
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Text(widget.label,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _isToday ? kAccent : kText1,
                      )),
                  if (_isToday) ...[
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
                  const Spacer(),
                  if (!isEmpty)
                    Text("${items.length} item${items.length != 1 ? 's' : ''}",
                        style: GoogleFonts.inter(
                            fontSize: 11, color: kText3)),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: kText3,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (_expanded) ...[
            Container(height: 1, color: kBorderSoft),
            _buildContent(),
          ],
        ],
      ),
    );
  }

  List<dynamic> _itemsForDay(dynamic content) {
    if (content is List) return content;
    if (content is Map && content.containsKey('items')) {
      final v = content['items'];
      if (v is List) return v;
    }
    return [];
  }

  Widget _buildContent() {
    // Sunday reflection
    if (widget.dayKey == 'sun' && widget.content is Map) {
      final reflection =
          (widget.content as Map)['reflection'] as String? ?? '';
      if (reflection.isNotEmpty) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x14A78BFA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x25A78BFA)),
            ),
            child: Text(reflection,
                style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: kText1,
                    height: 1.6,
                    fontStyle: FontStyle.italic)),
          ),
        );
      }
    }

    final items = _itemsForDay(widget.content);

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Text("Rest day — nothing scheduled",
            style: GoogleFonts.inter(fontSize: 12, color: kText3)),
      );
    }

    return Column(
      children: items.asMap().entries.map((e) {
        final i    = e.key;
        final item = e.value as Map<String, dynamic>;
        return _PlanItem(item: item, isLast: i == items.length - 1);
      }).toList(),
    );
  }
}

// ── Single plan item row ───────────────────────────────────────────────────────
class _PlanItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isLast;
  const _PlanItem({required this.item, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final title = item['title'] as String? ?? 'Untitled';
    final why   = item['why']   as String? ?? '';
    final url   = item['url']   as String? ?? '';
    final type  = item['content_type'] as String? ?? 'article';

    final (icon, color) =
        _typeData[type] ?? _typeData['other']!;

    return InkWell(
      onTap: () async {
        if (url.isNotEmpty) {
          final uri = Uri.tryParse(url);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: kBorderSoft)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type icon bubble
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 14),
            ),
            const SizedBox(width: 11),

            // Title + why
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: kText1,
                          height: 1.35)),
                  if (why.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(why,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 11, color: kText2, height: 1.4)),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),
            const Icon(Icons.open_in_new, color: kText3, size: 14),
          ],
        ),
      ),
    );
  }
}
