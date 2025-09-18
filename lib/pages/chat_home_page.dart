// Flutter imports:
import 'package:flutter/material.dart';

// Project imports:
import '../models/user_models.dart';
import '../providers/theme_provider.dart';
import '../services/chat_services.dart';
import '../theme.dart';
import '../widgets/app_nav_drawer.dart';
import '../widgets/connectivity_banner.dart';
import '../widgets/glass_bottom_nav_bar.dart';
import 'direct_messages_page.dart';
import 'personal_groups_page.dart';
import 'university_groups_page.dart';

// Package imports:


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    print('🏠 MyApp built - main app launched!');
    return ThemeProvider(
      themeService: globalThemeService,
      child: AnimatedBuilder(
        animation: globalThemeService,
        builder: (context, child) {
          return MaterialApp(
            title: 'LPU Live Chat',
            theme: lpuTheme,
            darkTheme: lpuDarkTheme,
            themeMode: globalThemeService.themeMode,
            home: const ChatHomePage(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

// Custom physics that hard-locks edges: no movement when at first/last page
class EdgeLockedPagePhysics extends PageScrollPhysics {
  const EdgeLockedPagePhysics({super.parent});

  @override
  EdgeLockedPagePhysics applyTo(ScrollPhysics? ancestor) {
    return EdgeLockedPagePhysics(parent: buildParent(ancestor));
  }

  // Prevent any pixel movement beyond min/max extents to avoid jitter
  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // If we're at the min extent (first page) and user drags left (decreasing pixels)
    if (value < position.pixels && position.pixels <= position.minScrollExtent) {
      return value - position.pixels;
    }
    // If we're at the max extent (last page) and user drags right (increasing pixels)
    if (position.maxScrollExtent <= position.pixels && position.pixels < value) {
      return value - position.pixels;
    }
    return super.applyBoundaryConditions(position, value);
  }
}

// Remove overscroll glow/indicator to avoid visual jitter at edges
class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class ChatHomePage extends StatefulWidget {
  const ChatHomePage({super.key});

  @override
  State<ChatHomePage> createState() => _ChatHomePageState();
}

class _ChatHomePageState extends State<ChatHomePage> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;
  final WebSocketChatService _wsService = WebSocketChatService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final PageController _pageController = PageController(initialPage: 0);

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
    void openDrawer() {
      final scaffoldState = _scaffoldKey.currentState;
      if (scaffoldState != null) {
        debugPrint('📖 Opening drawer via ScaffoldState');
        scaffoldState.openDrawer();
        return;
      }
      final ctx = _scaffoldKey.currentContext;
      if (ctx != null) {
        debugPrint('📖 Opening drawer via context');
        Scaffold.of(ctx).openDrawer();
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint('📖 Opening drawer via post-frame callback');
        _scaffoldKey.currentState?.openDrawer();
      });
    }

    _pages = [
      UniversityGroupsPage(wsService: _wsService, onOpenDrawer: openDrawer),
      PersonalGroupsPage(wsService: _wsService, onOpenDrawer: openDrawer),
      DirectMessagesPage(wsService: _wsService, onOpenDrawer: openDrawer),
    ];
  }

  @override
  void dispose() {
    _wsService.disconnect();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _connectWebSocket() async {
    if (currentUser != null) {
      try {
        await _wsService.connect(currentUser!.chatToken);
        print('✅ [ChatHomePage] WebSocket connected successfully');
      } catch (e) {
        print('❌ [ChatHomePage] Failed to connect WebSocket: $e');
      }
    }
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<bool> _showExitConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit App'),
            content: const Text('Are you sure you want to exit the app?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Exit'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
          return;
        }
        final navigator = Navigator.of(context);
        final exit = await _showExitConfirmation(context);
        if (exit) {
          navigator.maybePop();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        resizeToAvoidBottomInset: false,
        drawer: const AppNavDrawer(),
        drawerEnableOpenDragGesture: false,
        endDrawerEnableOpenDragGesture: false,
        drawerEdgeDragWidth: 0.0,
        body: ConnectivityBanner(
          child: Stack(
            children: [
              // Content with native page scrolling for 1:1 swipe tracking
              Positioned.fill(
                child: ScrollConfiguration(
                  behavior: const _NoGlowScrollBehavior(),
                  child: PageView(
                    controller: _pageController,
                    pageSnapping: true,
                    physics: const EdgeLockedPagePhysics(parent: ClampingScrollPhysics()),
                    onPageChanged: (index) {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                    children: _pages,
                  ),
                ),
              ),
              // Floating glass bottom navigation
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: GlassBottomNavBar(
                    selectedIndex: _selectedIndex,
                    onItemSelected: _onItemTapped,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
