import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../services/api_service.dart';

class RemindersScreen extends StatefulWidget {
  final int refreshTrigger;
  const RemindersScreen({super.key, this.refreshTrigger = 0});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<SavedItem> _reminders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(RemindersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshTrigger != oldWidget.refreshTrigger) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await ApiService.fetchReminders();
      setState(() => _reminders = items);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, List<SavedItem>> get _grouped {
    final now    = DateTime.now();
    final groups = <String, List<SavedItem>>{
      'Overdue':   [],
      'Today':     [],
      'This Week': [],
      'Later':     [],
    };
    for (final item in _reminders) {
      if (item.remindAt == null) continue;
      final dt = DateTime.tryParse(item.remindAt!)?.toLocal();
      if (dt == null) continue;
      final diff = dt.difference(now);
      if (dt.isBefore(now)) {
        groups['Overdue']!.add(item);
      } else if (diff.inDays == 0) {
        groups['Today']!.add(item);
      } else if (diff.inDays < 7) {
        groups['This Week']!.add(item);
      } else {
        groups['Later']!.add(item);
      }
    }
    return groups;
  }

  Color _groupColor(String group) {
    switch (group) {
      case 'Overdue':   return const Color(0xFFF87171);
      case 'Today':     return kAccent;
      case 'This Week': return const Color(0xFFFBBF24);
      default:          return kText2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;
    final hasAny  = grouped.values.any((l) => l.isNotEmpty);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        title: Text("Reminders",
            style: GoogleFonts.inter(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: kText1,
                letterSpacing: -0.3)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: kBorderSoft),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kAccent))
          : !hasAny
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.notifications_off_outlined,
                          size: 64, color: kText3),
                      const SizedBox(height: 16),
                      Text("No reminders yet",
                          style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: kText2)),
                      const SizedBox(height: 8),
                      Text('Say "remind me in 2 hours" when saving a URL',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: kText3)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: kAccent,
                  backgroundColor: kSurface2,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      for (final group
                          in ['Overdue', 'Today', 'This Week', 'Later'])
                        if (grouped[group]!.isNotEmpty) ...[
                          _GroupHeader(
                              label: group, color: _groupColor(group)),
                          const SizedBox(height: 6),
                          ...grouped[group]!.map((item) => _ReminderCard(
                                item: item,
                                accentColor: _groupColor(group),
                              )),
                          const SizedBox(height: 14),
                        ],
                    ],
                  ),
                ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String label;
  final Color  color;
  const _GroupHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 3,
            height: 14,
            color: color,
            margin: const EdgeInsets.only(right: 8)),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.6)),
      ],
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final SavedItem item;
  final Color     accentColor;
  const _ReminderCard({required this.item, required this.accentColor});

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return "${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: kSurface2,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: accentColor, width: 3)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Text(item.displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kText1)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.summary != null) ...[
              const SizedBox(height: 2),
              Text(item.summary!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 11, color: kText2)),
            ],
            if (item.userNote != null) ...[
              const SizedBox(height: 4),
              Text('"${item.userNote!}"',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFFFBBF24))),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time_rounded,
                    size: 11, color: accentColor),
                const SizedBox(width: 4),
                Text(_formatTime(item.remindAt!),
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: accentColor)),
                if (item.reminderSent) ...[
                  const SizedBox(width: 8),
                  Text("sent",
                      style:
                          GoogleFonts.inter(fontSize: 11, color: kText3)),
                ],
              ],
            ),
          ],
        ),
        trailing: GestureDetector(
          onTap: () async {
            final uri = Uri.tryParse(item.url);
            if (uri != null) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: const Icon(Icons.open_in_new, size: 16, color: kText3),
        ),
      ),
    );
  }
}
