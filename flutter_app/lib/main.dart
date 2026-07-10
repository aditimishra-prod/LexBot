import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/chat_screen.dart';
import 'screens/plan_screen.dart';
import 'screens/library_screen.dart';
import 'screens/reminders_screen.dart';
import 'services/api_service.dart';
import 'firebase_options.dart';

// ── VAPID key for web push notifications ──────────────────────────────────────
const _vapidKey =
    'BMlHw_n7fxPEC3rEGrAog7-qVphovRms1sdT7UeYpjK849CQ3pvIDFwmvXEsHE-OuU7o1G0jTs7cBZPjGpy7taE';

// ── Design palette ────────────────────────────────────────────────────────────
const kBg          = Color(0xFF0F0E17);
const kSurface2    = Color(0xFF1E1D2C);
const kSurface3    = Color(0xFF262537);
const kSurface4    = Color(0xFF2E2D40);
const kBorder      = Color(0xFF2C2B3D);
const kBorderSoft  = Color(0xFF232232);
const kText1       = Color(0xFFEDECF4);
const kText2       = Color(0xFF9B9AAE);
const kText3       = Color(0xFF5C5B72);
const kAccent      = Color(0xFFA78BFA);
const kAccentDim   = Color(0xFF7C6DB5);
const kAccentMuted = Color(0x1AA78BFA);
const kRed         = Color(0xFFF87171);
const kRedBg       = Color(0x1AF87171);

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:                    Colors.transparent,
      statusBarBrightness:               Brightness.dark,
      statusBarIconBrightness:           Brightness.light,
      systemNavigationBarColor:          kSurface2,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  // Always launch the app — never let Firebase crash block the UI
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);

    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);
      await _localNotifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
    }

    FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (n == null) return;
      if (!kIsWeb) {
        _localNotifications.show(
          msg.hashCode,
          n.title,
          n.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'lexbot_reminders',
              'LexBot Reminders',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      }
    });

    // Init FCM token in background — don't block app launch
    _initFcm();
  } catch (_) {
    // Firebase failed — app still loads, just no push notifications
  }

  runApp(const LexBotApp());
}

Future<void> _initFcm() async {
  try {
    await FirebaseMessaging.instance.requestPermission(
      alert: true, badge: true, sound: true,
    );
    final token = await FirebaseMessaging.instance.getToken(
      vapidKey: kIsWeb ? _vapidKey : null,
    );
    if (token != null) {
      ApiService.registerDevice(token).catchError((_) {});
    }
    FirebaseMessaging.instance.onTokenRefresh.listen((t) {
      ApiService.registerDevice(t).catchError((_) {});
    });
  } catch (_) {
    // Notification setup failed silently — app works without it
  }
}

class LexBotApp extends StatelessWidget {
  const LexBotApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base      = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme);

    return MaterialApp(
      title: 'LexBot',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        colorScheme: const ColorScheme.dark(
          surface:            kSurface2,
          primary:            kAccent,
          onPrimary:          Colors.white,
          primaryContainer:   kAccentDim,
          onPrimaryContainer: kText1,
          secondary:          kAccentDim,
          onSecondary:        Colors.white,
          onSurface:          kText1,
          outline:            kText3,
          outlineVariant:     kBorder,
          error:              kRed,
          onError:            Colors.white,
        ),
        scaffoldBackgroundColor: kBg,
        textTheme: textTheme,
        appBarTheme: AppBarTheme(
          backgroundColor:  kBg,
          foregroundColor:  kText1,
          elevation:        0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle:   GoogleFonts.inter(
            fontSize: 21, fontWeight: FontWeight.w700,
            color: kText1, letterSpacing: -0.3,
          ),
          iconTheme: const IconThemeData(color: kText2),
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor:          Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
        ),
        cardTheme: CardThemeData(
          color: kSurface2,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: kBorderSoft),
          ),
          elevation: 0,
        ),
        dividerColor: kBorderSoft,
        dividerTheme:
            const DividerThemeData(color: kBorderSoft, thickness: 1),
        chipTheme: ChipThemeData(
          backgroundColor: kSurface3,
          selectedColor:   kAccentMuted,
          labelStyle:      GoogleFonts.inter(
              color: kText2, fontSize: 11.5, fontWeight: FontWeight.w500),
          side:    const BorderSide(color: kBorder),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          shape:   const StadiumBorder(),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor:  kSurface4,
          contentTextStyle: TextStyle(color: kText1),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: kSurface2,
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled:    true,
          fillColor: kSurface3,
          hintStyle: GoogleFonts.inter(color: kText3, fontSize: 12.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: kAccent),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor:      kSurface2,
          surfaceTintColor:     Colors.transparent,
          modalBackgroundColor: kSurface2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
        ),
      ),
      home: const MainShell(),
    );
  }
}

// ── Main shell ─────────────────────────────────────────────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex     = 0;
  int _libraryRefresh   = 0;
  int _remindersRefresh = 0;
  int _planRefresh      = 0;

  void _onItemSaved() {
    setState(() {
      _libraryRefresh++;
      _remindersRefresh++;
    });
  }

  void _onTabTap(int i) {
    setState(() {
      _currentIndex = i;
      if (i == 1) _planRefresh++;
      if (i == 2) _libraryRefresh++;
      if (i == 3) _remindersRefresh++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ChatScreen(onItemSaved: _onItemSaved),
          PlanScreen(refreshTrigger: _planRefresh),
          LibraryScreen(refreshTrigger: _libraryRefresh),
          RemindersScreen(refreshTrigger: _remindersRefresh),
        ],
      ),
      bottomNavigationBar: _LexBotBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabTap,
      ),
    );
  }
}

// ── Custom pill-style bottom nav ──────────────────────────────────────────────
class _LexBotBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _LexBotBottomNav(
      {required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68 + MediaQuery.of(context).padding.bottom,
      decoration: const BoxDecoration(
        color: kSurface2,
        border: Border(top: BorderSide(color: kBorderSoft, width: 1)),
      ),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Row(
        children: [
          _NavItem(
            icon:       Icons.chat_bubble_outline_rounded,
            activeIcon: Icons.chat_bubble_rounded,
            label:      'Chat',
            active:     currentIndex == 0,
            onTap:      () => onTap(0),
          ),
          _NavItem(
            icon:       Icons.calendar_today_outlined,
            activeIcon: Icons.calendar_today_rounded,
            label:      'Plan',
            active:     currentIndex == 1,
            onTap:      () => onTap(1),
          ),
          _NavItem(
            icon:       Icons.library_books_outlined,
            activeIcon: Icons.library_books,
            label:      'Library',
            active:     currentIndex == 2,
            onTap:      () => onTap(2),
          ),
          _NavItem(
            icon:       Icons.notifications_outlined,
            activeIcon: Icons.notifications_rounded,
            label:      'Reminders',
            active:     currentIndex == 3,
            onTap:      () => onTap(3),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData     icon;
  final IconData     activeIcon;
  final String       label;
  final bool         active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? kAccent : kText3;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 28,
              decoration: BoxDecoration(
                color: active ? kAccentMuted : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(active ? activeIcon : icon,
                  size: 20, color: color),
            ),
            const SizedBox(height: 3),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}
