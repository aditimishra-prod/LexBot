import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const _baseUrlKey = 'api_base_url';
  static const _defaultUrl = 'https://lexbot-zhsl.onrender.com';

  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_baseUrlKey) ?? _defaultUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _baseUrlKey, url.trimRight().replaceAll(RegExp(r'/$'), ''));
  }

  // ── Chat ──────────────────────────────────────────────────────────────────

  static Future<MessageResult> sendMessage(
    String message, {
    List<Map<String, dynamic>> history = const [],
  }) async {
    final base     = await getBaseUrl();
    final response = await http.post(
      Uri.parse('$base/message'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'message': message, 'history': history}),
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      final detail =
          jsonDecode(response.body)['detail'] ?? 'Unknown error';
      throw Exception(detail);
    }
    return MessageResult.fromJson(jsonDecode(response.body));
  }

  static Future<StatusResult> status() async {
    final base     = await getBaseUrl();
    final response = await http
        .get(Uri.parse('$base/status'))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) throw Exception('Status fetch failed');
    return StatusResult.fromJson(jsonDecode(response.body));
  }

  static Future<DigestResult?> fetchDigest() async {
    final base     = await getBaseUrl();
    final response = await http
        .get(Uri.parse('$base/digest'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body);
    if (data['available'] != true) return null;
    return DigestResult.fromJson(data);
  }

  // ── Library ───────────────────────────────────────────────────────────────

  static Future<LibraryResult> fetchItems({
    int limit        = 20,
    int offset       = 0,
    String? contentType,
    String? difficulty,
  }) async {
    final base = await getBaseUrl();
    final uri  = Uri.parse('$base/items').replace(queryParameters: {
      'limit':  '$limit',
      'offset': '$offset',
      if (contentType != null) 'content_type': contentType,
      if (difficulty  != null) 'difficulty':   difficulty,
    });
    final response =
        await http.get(uri).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) throw Exception('Failed to load library');
    return LibraryResult.fromJson(jsonDecode(response.body));
  }

  static Future<SavedItem> fetchItem(String id) async {
    final base     = await getBaseUrl();
    final response = await http
        .get(Uri.parse('$base/items/$id'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Item not found');
    return SavedItem.fromJson(jsonDecode(response.body));
  }

  static Future<SavedItem> updateItem(
    String id, {
    String? userNote,
    String? remindAt,
    bool? isRead,
  }) async {
    final base = await getBaseUrl();
    final body = <String, dynamic>{};
    if (userNote != null) body['user_note'] = userNote;
    if (remindAt != null) body['remind_at'] = remindAt;
    if (isRead   != null) body['is_read']   = isRead;

    final response = await http.patch(
      Uri.parse('$base/items/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Update failed');
    return SavedItem.fromJson(jsonDecode(response.body));
  }

  // ── Plan ──────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> fetchCurrentPlan() async {
    final base     = await getBaseUrl();
    final response = await http
        .get(Uri.parse('$base/plan/current'))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) throw Exception('Failed to load plan');
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> generatePlan() async {
    final base     = await getBaseUrl();
    final response = await http
        .post(Uri.parse('$base/plan/generate'))
        .timeout(const Duration(seconds: 120));
    if (response.statusCode != 200) throw Exception('Plan generation failed');
    return jsonDecode(response.body);
  }

  static Future<void> updatePlan(Map<String, dynamic> planJson) async {
    final base     = await getBaseUrl();
    final response = await http.patch(
      Uri.parse('$base/plan/current'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'plan_json': planJson}),
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw Exception('Plan save failed');
  }

  // ── Reminders ─────────────────────────────────────────────────────────────

  static Future<List<SavedItem>> fetchReminders() async {
    final base     = await getBaseUrl();
    final response = await http
        .get(Uri.parse('$base/reminders'))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) throw Exception('Failed to load reminders');
    final data = jsonDecode(response.body);
    return (data['reminders'] as List)
        .map((j) => SavedItem.fromJson(j))
        .toList();
  }

  // ── Device registration ───────────────────────────────────────────────────

  static Future<void> registerDevice(String fcmToken) async {
    final base = await getBaseUrl();
    await http.post(
      Uri.parse('$base/register-device'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'fcm_token': fcmToken}),
    ).timeout(const Duration(seconds: 10));
  }
}

// ── Models ────────────────────────────────────────────────────────────────────

class MessageResult {
  final String response;
  final String mode;

  MessageResult({required this.response, required this.mode});

  factory MessageResult.fromJson(Map<String, dynamic> json) => MessageResult(
        response: json['response'] ?? '',
        mode:     json['mode']     ?? 'browse',
      );
}

class StatusResult {
  final int total;
  final Map<String, int> byType;

  StatusResult({required this.total, required this.byType});

  factory StatusResult.fromJson(Map<String, dynamic> json) => StatusResult(
        total:  json['total'] ?? 0,
        byType: Map<String, int>.from(json['by_type'] ?? {}),
      );
}

class DigestResult {
  final String message;
  final List<dynamic> items;

  DigestResult({required this.message, required this.items});

  factory DigestResult.fromJson(Map<String, dynamic> json) => DigestResult(
        message: json['message'] ?? '',
        items:   json['items']   ?? [],
      );
}

class SavedItem {
  final String  id;
  final String  url;
  final String? title;
  final String? summary;
  final String  contentType;
  final String  difficulty;
  final List<String> tags;
  final String? source;
  final String  createdAt;
  final String? remindAt;
  final String? userNote;
  final bool    reminderSent;
  final bool    isRead;

  SavedItem({
    required this.id,
    required this.url,
    this.title,
    this.summary,
    required this.contentType,
    required this.difficulty,
    required this.tags,
    this.source,
    required this.createdAt,
    this.remindAt,
    this.userNote,
    required this.reminderSent,
    required this.isRead,
  });

  factory SavedItem.fromJson(Map<String, dynamic> j) => SavedItem(
        id:           j['id']           ?? '',
        url:          j['url']          ?? '',
        title:        j['title'],
        summary:      j['summary'],
        contentType:  j['content_type'] ?? 'article',
        difficulty:   j['difficulty']   ?? 'beginner',
        tags:         List<String>.from(j['tags'] ?? []),
        source:       j['source'],
        createdAt:    j['created_at']   ?? '',
        remindAt:     j['remind_at'],
        userNote:     j['user_note'],
        reminderSent: j['reminder_sent'] ?? false,
        isRead:       j['is_read']       ?? false,
      );

  String get displayTitle {
    if (title != null && title!.isNotEmpty) return title!;
    try {
      final host = Uri.parse(url).host;
      return host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }
}

class LibraryResult {
  final List<SavedItem> items;
  final int offset;
  final int count;

  LibraryResult(
      {required this.items, required this.offset, required this.count});

  factory LibraryResult.fromJson(Map<String, dynamic> json) => LibraryResult(
        items:  (json['items'] as List)
            .map((j) => SavedItem.fromJson(j))
            .toList(),
        offset: json['offset'] ?? 0,
        count:  json['count']  ?? 0,
      );
}
