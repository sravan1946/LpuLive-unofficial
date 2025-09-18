// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:animations/animations.dart';

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

// Custom physics to disable swiping past edges in a specific direction
class EdgeLockedPageScrollPhysics extends PageScrollPhysics {
  final int currentPage;
  final int pageCount;

  const EdgeLockedPageScrollPhysics({
    required this.currentPage,
    required this.pageCount,
    ScrollPhysics? parent,
  }) : super(parent: parent);

  @override
  EdgeLockedPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return EdgeLockedPageScrollPhysics(
      currentPage: currentPage,
      pageCount: pageCount,
      parent: buildParent(ancestor),
    );
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final double current = position.pixels;
    // Disallow swiping right from first tab (attempting to go to -1)
    if (currentPage == 0 && value < current) {
      return current - value; // block movement
    }
    // Disallow swiping left from last tab (attempting to go beyond last)
    if (currentPage == pageCount - 1 && value > current) {
      return value - current; // block movement
    }
    return super.applyBoundaryConditions(position, value);
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
  double _panDx = 0;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
    void openDrawer() {
      // Prefer using the ScaffoldState directly for reliability
      final scaffoldState = _scaffoldKey.currentState;
      if (scaffoldState != null) {
        debugPrint('📖 Opening drawer via ScaffoldState');
        scaffoldState.openDrawer();
        return;
      }
      // Fallback to context-based lookup if state isn't yet available
      final ctx = _scaffoldKey.currentContext;
      if (ctx != null) {
        debugPrint('📖 Opening drawer via context');
        Scaffold.of(ctx).openDrawer();
        return;
      }
      // Schedule after the current frame as a last resort
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
        body: ConnectivityBanner(
          child: Stack(
            children: [
              // Content with transitions
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) {
                    _panDx = 0;
                  },
                  onHorizontalDragUpdate: (details) {
                    _panDx += details.delta.dx;
                  },
                  onHorizontalDragEnd: (details) {
                    final vx = details.primaryVelocity ?? 0;
                    const double vxThreshold = 200; // small fling ok
                    const double dxThreshold = 12;  // small swipe ok
                    final bool isLeft = _panDx < 0;
                    final bool isRight = _panDx > 0;

                    if ((vx.abs() > vxThreshold) || (_panDx.abs() > dxThreshold)) {
                      if (isLeft) {
                        // Move to next tab unless at last (DMs)
                        final last = _pages.length - 1;
                        if (_selectedIndex < last) {
                          _pageController.animateToPage(
                            _selectedIndex + 1,
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                          );
                        }
                      } else if (isRight) {
                        // Move to previous tab unless at first (University)
                        if (_selectedIndex > 0) {
                          _pageController.animateToPage(
                            _selectedIndex - 1,
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                          );
                        }
                      }
                    }
                    _panDx = 0;
                  },
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
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
