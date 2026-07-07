import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

// Design palette
const _bg         = Color(0xFF0F0E17);
const _surface2   = Color(0xFF1E1D2C);
const _surface3   = Color(0xFF262537);
const _surface4   = Color(0xFF2E2D40);
const _border     = Color(0xFF2C2B3D);
const _borderSoft = Color(0xFF232232);
const _text1      = Color(0xFFEDECF4);
const _text2      = Color(0xFF9B9AAE);
const _text3      = Color(0xFF5C5B72);
const _accent     = Color(0xFFA78BFA);

// DPDP content type colours
const _typeColors = {
  'article': Color(0xFF818CF8),
  'video':   Color(0xFFF87171),
  'podcast': Color(0xFF34D399),
  'other':   Color(0xFF9B9AAE),
};
const _typeBgs = {
  'article': Color(0x1A818CF8),
  'video':   Color(0x1AF87171),
  'podcast': Color(0x1A34D399),
  'other':   Color(0x1A9B9AAE),
};
const _typeIcons = {
  'article': Icons.article_outlined,
  'video':   Icons.play_circle_outline_rounded,
  'podcast': Icons.headphones_outlined,
  'other':   Icons.link_rounded,
};
const _diffColors = {
  'beginner':     Color(0xFF34D399),
  'intermediate': Color(0xFFFBBF24),
  'advanced':     Color(0xFFF87171),
};

const _filterPills = ['all', 'article', 'video', 'podcast'];

class LibraryScreen extends StatefulWidget {
  final int refreshTrigger;
  const LibraryScreen({super.key, this.refreshTrigger = 0});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _selectedType   = 'all';
  String _searchQuery    = '';
  List<SavedItem> _items = [];
  bool _loading = false;
  bool _hasMore = true;
  int  _offset  = 0;
  static const _pageSize = 20;

  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshTrigger != oldWidget.refreshTrigger) {
      _load(reset: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loading &&
        _hasMore) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    if (reset) {
      _offset  = 0;
      _hasMore = true;
    }
    try {
      final result = await ApiService.fetchItems(
        limit:       _pageSize,
        offset:      _offset,
        contentType: _selectedType == 'all' ? null : _selectedType,
      );
      setState(() {
        if (reset) _items = result.items;
        else _items.addAll(result.items);
        _offset += result.count;
        _hasMore = result.count == _pageSize;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't load library")),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<SavedItem> get _filtered {
    if (_searchQuery.isEmpty) return _items;
    final q = _searchQuery.toLowerCase();
    return _items.where((item) {
      return item.displayTitle.toLowerCase().contains(q) ||
          (item.summary?.toLowerCase().contains(q) ?? false) ||
          item.url.toLowerCase().contains(q) ||
          item.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        title: Row(
          children: [
            Text("Library",
                style: GoogleFonts.inter(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: _text1,
                    letterSpacing: -0.3)),
            if (_items.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                    color: _surface3,
                    borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: Text("${_items.length}",
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _text1)),
              ),
            ],
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _borderSoft),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: _bg,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Column(
              children: [
                // Search bar
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: _surface2,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      const Icon(Icons.search, size: 15, color: _text3),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _searchQuery = v),
                          style: GoogleFonts.inter(
                              fontSize: 12.5, color: _text2),
                          decoration: InputDecoration(
                            hintText: "Search DPDP resources…",
                            hintStyle: GoogleFonts.inter(
                                fontSize: 12.5, color: _text3),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            filled: false,
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: const Padding(
                            padding: EdgeInsets.only(right: 10),
                            child: Icon(Icons.close, size: 15, color: _text3),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Filter pills
                SizedBox(
                  height: 30,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _filterPills.map((pill) {
                      final active = _selectedType == pill;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedType = pill);
                          _load(reset: true);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 5),
                          decoration: BoxDecoration(
                            color: active
                                ? (pill == 'all'
                                    ? _accent
                                    : (_typeBgs[pill] ?? _surface3))
                                : _surface3,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: active && pill != 'all'
                                  ? (_typeColors[pill] ?? _accent)
                                      .withOpacity(0.2)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (pill != 'all') ...[
                                Icon(
                                  _typeIcons[pill] ?? Icons.label_outline,
                                  size: 11,
                                  color: active
                                      ? (_typeColors[pill] ?? _accent)
                                      : _text2,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                pill == 'all'
                                    ? 'All'
                                    : pill[0].toUpperCase() +
                                        pill.substring(1),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: active
                                      ? (pill == 'all'
                                          ? Colors.white
                                          : (_typeColors[pill] ?? _accent))
                                      : _text2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          Container(height: 1, color: _borderSoft),
          Expanded(
            child: filtered.isEmpty && !_loading
                ? _buildEmptyState()
                : RefreshIndicator(
                    color: _accent,
                    backgroundColor: _surface2,
                    onRefresh: () => _load(reset: true),
                    child: GridView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(10),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 9,
                        mainAxisSpacing: 9,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: filtered.length + (_hasMore ? 2 : 0),
                      itemBuilder: (_, i) {
                        if (i >= filtered.length) {
                          return _loading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                      color: _accent, strokeWidth: 2))
                              : const SizedBox.shrink();
                        }
                        return _LibraryCard(
                          item: filtered[i],
                          onTap: () => _showDetail(filtered[i]),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.library_books_outlined, size: 64, color: _text3),
          const SizedBox(height: 16),
          Text("Nothing saved yet",
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _text2)),
          const SizedBox(height: 8),
          Text("Paste a URL in Chat or wait for the daily scrape",
              style: GoogleFonts.inter(fontSize: 12, color: _text3)),
        ],
      ),
    );
  }

  void _showDetail(SavedItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _surface2,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _ItemDetailSheet(item: item),
    );
  }
}

// ── Library card ──────────────────────────────────────────────────────────────
class _LibraryCard extends StatelessWidget {
  final SavedItem item;
  final VoidCallback onTap;
  const _LibraryCard({required this.item, required this.onTap});

  String get _domain {
    try {
      return Uri.parse(item.url).host.replaceFirst('www.', '');
    } catch (_) {
      return '';
    }
  }

  String get _domainInitial {
    final d = _domain;
    return d.isEmpty ? '?' : d[0].toUpperCase();
  }

  Color get _faviconColor {
    const colors = [
      Color(0xFFFF6B35), Color(0xFF1A8CD8), Color(0xFF0A66C2),
      Color(0xFFA31515), Color(0xFF111111), Color(0xFFCC0000),
      Color(0xFF34D399), Color(0xFF818CF8), Color(0xFFFBBF24),
    ];
    return colors[_domain.hashCode.abs() % colors.length];
  }

  String _formatDate(String iso) {
    try {
      final dt   = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inDays == 0)  return 'today';
      if (diff.inDays == 1)  return '1d ago';
      if (diff.inDays < 7)   return '${diff.inDays}d ago';
      if (diff.inDays < 30)  return '${(diff.inDays / 7).floor()}w ago';
      return '${(diff.inDays / 30).floor()}mo ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeColor   = _typeColors[item.contentType]  ?? _accent;
    final typeBg      = _typeBgs[item.contentType]     ?? const Color(0x1AA78BFA);
    final typeIcon    = _typeIcons[item.contentType]   ?? Icons.label_outline;
    final diffColor   = _diffColors[item.difficulty]  ?? _text2;
    final hasReminder = item.remindAt != null && !item.reminderSent;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: _surface2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                          color: _faviconColor,
                          borderRadius: BorderRadius.circular(6)),
                      child: Center(
                        child: Text(_domainInitial,
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(_domain,
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: _text3),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: typeColor, shape: BoxShape.circle)),
                  ],
                ),
                const SizedBox(height: 7),
                Text(item.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _text1,
                        height: 1.4)),
                const SizedBox(height: 5),
                Expanded(
                  child: Text(item.summary ?? '',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 10.5, color: _text2, height: 1.4)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                          color: typeBg,
                          borderRadius: BorderRadius.circular(7)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(typeIcon, size: 9, color: typeColor),
                          const SizedBox(width: 3),
                          Text(
                            item.contentType[0].toUpperCase() +
                                item.contentType.substring(1),
                            style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: typeColor,
                                letterSpacing: 0.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: diffColor, shape: BoxShape.circle)),
                    const Spacer(),
                    Text(_formatDate(item.createdAt),
                        style: GoogleFonts.inter(
                            fontSize: 9.5, color: _text3)),
                  ],
                ),
              ],
            ),
          ),
          if (hasReminder)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.fromLTRB(7, 2, 7, 2),
                decoration: BoxDecoration(
                    color: const Color(0x1AFBBF24),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 9, color: Color(0xFFFBBF24)),
                    const SizedBox(width: 3),
                    Text("Reminder",
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFBBF24))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Item detail bottom sheet ──────────────────────────────────────────────────
class _ItemDetailSheet extends StatelessWidget {
  final SavedItem item;
  const _ItemDetailSheet({required this.item});

  String get _domain {
    try {
      return Uri.parse(item.url).host.replaceFirst('www.', '');
    } catch (_) {
      return item.url;
    }
  }

  Color get _faviconColor {
    const colors = [
      Color(0xFFFF6B35), Color(0xFF1A8CD8), Color(0xFF0A66C2),
      Color(0xFFA31515), Color(0xFF111111), Color(0xFFCC0000),
      Color(0xFF34D399), Color(0xFF818CF8), Color(0xFFFBBF24),
    ];
    return colors[_domain.hashCode.abs() % colors.length];
  }

  Future<void> _openUrl() async {
    final uri = Uri.tryParse(item.url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _searchYouTube() async {
    final q   = Uri.encodeComponent('${item.displayTitle} DPDP');
    final uri = Uri.parse('https://www.youtube.com/results?search_query=$q');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _formatRemindAt(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return "${dt.day}/${dt.month}/${dt.year} at "
          "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _typeColors[item.contentType] ?? _accent;
    final typeBg    = _typeBgs[item.contentType]    ?? const Color(0x1AA78BFA);
    final typeIcon  = _typeIcons[item.contentType]  ?? Icons.label_outline;
    final diffColor = _diffColors[item.difficulty]  ?? _text2;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.95,
      builder: (_, sc) {
        return Container(
          decoration: const BoxDecoration(
            color: _surface2,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: sc,
            padding: EdgeInsets.zero,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.fromLTRB(0, 12, 0, 14),
                  decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                              color: _faviconColor,
                              borderRadius: BorderRadius.circular(10)),
                          child: Center(
                            child: Text(
                              _domain.isNotEmpty
                                  ? _domain[0].toUpperCase()
                                  : '?',
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_domain,
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: _text2)),
                        ),
                        GestureDetector(
                          onTap: _openUrl,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                                color: _surface4, shape: BoxShape.circle),
                            child: const Icon(Icons.open_in_new,
                                size: 15, color: _accent),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(item.displayTitle,
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _text1,
                            height: 1.4)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                              color: typeBg,
                              borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(typeIcon, size: 11, color: typeColor),
                              const SizedBox(width: 4),
                              Text(
                                item.contentType[0].toUpperCase() +
                                    item.contentType.substring(1),
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: typeColor),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: diffColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            item.difficulty[0].toUpperCase() +
                                item.difficulty.substring(1),
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: diffColor),
                          ),
                        ),
                        ...item.tags.map((t) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                  color: _surface4,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _border)),
                              child: Text(t,
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: _text2)),
                            )),
                      ],
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: _borderSoft),
              if (item.summary != null) ...[
                _SheetSection(
                  icon: Icons.menu_book_outlined,
                  title: "Summary",
                  child: MarkdownBody(
                    data: item.summary!,
                    styleSheet: MarkdownStyleSheet(
                      p: GoogleFonts.inter(
                          fontSize: 12.5, color: _text1, height: 1.6),
                      strong: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _accent),
                    ),
                  ),
                ),
                Container(height: 1, color: _borderSoft),
              ],
              if (item.userNote != null) ...[
                _SheetSection(
                  icon: Icons.edit_outlined,
                  title: "Your Note",
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0x14FBBF24),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x26FBBF24)),
                    ),
                    child: Text('"${item.userNote!}"',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: const Color(0xFFFBBF24))),
                  ),
                ),
                Container(height: 1, color: _borderSoft),
              ],
              if (item.remindAt != null) ...[
                _SheetSection(
                  icon: Icons.access_time_rounded,
                  title: "Reminder",
                  child: Text(
                    item.reminderSent
                        ? "Reminder sent ✓"
                        : _formatRemindAt(item.remindAt!),
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: item.reminderSent ? _text2 : _text1),
                  ),
                ),
                Container(height: 1, color: _borderSoft),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _openUrl,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                            color: _accent,
                            borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.open_in_new,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text("Open",
                                style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                    if (item.contentType == 'video' ||
                        item.contentType == 'podcast') ...[
                      const SizedBox(height: 9),
                      GestureDetector(
                        onTap: _searchYouTube,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                              color: _surface4,
                              borderRadius: BorderRadius.circular(14)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.play_circle_outline_rounded,
                                  size: 14, color: _text1),
                              const SizedBox(width: 6),
                              Text("Find on YouTube",
                                  style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: _text1)),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 9),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                            color: _surface4,
                            borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.chat_bubble_outline_rounded,
                                size: 14, color: _accent),
                            const SizedBox(width: 6),
                            Text("Ask LexBot",
                                style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: _accent)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Sheet section helper ───────────────────────────────────────────────────────
class _SheetSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _SheetSection(
      {required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: _text3),
              const SizedBox(width: 4),
              Text(title.toUpperCase(),
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _text3,
                      letterSpacing: 0.8)),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
