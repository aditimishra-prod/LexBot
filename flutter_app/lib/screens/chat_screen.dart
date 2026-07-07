import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../widgets/chat_bubble.dart';

class ChatScreen extends StatefulWidget {
  final VoidCallback? onItemSaved;
  const ChatScreen({super.key, this.onItemSaved});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputController  = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  final List<Map<String, dynamic>> _history  = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _addSystemMessage(
        "👋 Welcome to **LexBot** — your DPDP Act 2023 learning assistant!\n\n"
        "Paste a URL to save it, or ask me anything about India's Digital Personal Data Protection Act.\n\n"
        "Try: _\"What is a Data Fiduciary?\"_ or _\"Show me my unread saves\"_");
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addSystemMessage(String text) {
    setState(() => _messages.add({'type': 'system', 'text': text}));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _loading) return;

    _inputController.clear();
    setState(() {
      _messages.add({'type': 'user', 'text': text});
      _loading = true;
    });
    _scrollToBottom();

    try {
      final result = await ApiService.sendMessage(text, history: _history);
      _history.add({'role': 'user', 'content': text});
      _history.add({'role': 'assistant', 'content': result.response});
      if (_history.length > 20) _history.removeRange(0, 2);

      setState(() {
        _messages.add({
          'type': 'assistant',
          'text': result.response,
          'label': result.mode,
        });
      });

      if (result.mode == 'ingest') {
        widget.onItemSaved?.call();
      }
    } catch (e) {
      setState(() => _messages.add({
            'type': 'assistant',
            'text': '⚠️ Something went wrong: $e',
            'label': null,
          }));
    } finally {
      setState(() => _loading = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        title: Row(
          children: [
            const LexBotAvatar(size: 28),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("LexBot",
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: kText1)),
                Text("DPDP Act 2023",
                    style: GoogleFonts.inter(fontSize: 11, color: kText3)),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: kBorderSoft),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: _messages.length + (_loading ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _messages.length) {
                  return const TypingIndicator();
                }
                final m    = _messages[i];
                final type = m['type'] == 'user'
                    ? BubbleType.user
                    : m['type'] == 'system'
                        ? BubbleType.system
                        : BubbleType.assistant;
                return ChatBubble(
                  text:  m['text'],
                  type:  type,
                  label: m['label'],
                );
              },
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: kSurface2,
              border: Border(top: BorderSide(color: kBorderSoft, width: 1)),
            ),
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 10,
              bottom: 10 + MediaQuery.of(context).padding.bottom,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: kSurface3,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: kBorder),
                    ),
                    child: TextField(
                      controller: _inputController,
                      maxLines: 4,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      style: GoogleFonts.inter(fontSize: 13, color: kText1),
                      decoration: InputDecoration(
                        hintText: "Ask about DPDP or paste a URL…",
                        hintStyle:
                            GoogleFonts.inter(fontSize: 13, color: kText3),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        filled: false,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: kAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_upward_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
