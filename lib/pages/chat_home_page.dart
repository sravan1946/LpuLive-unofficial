import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import '../theme.dart';
import 'university_groups_page.dart';
import 'personal_groups_page.dart';
import 'direct_messages_page.dart';
import '../services/chat_services.dart';
import '../models/user_models.dart';
import '../services/theme_controller.dart';
import '../widgets/app_nav_drawer.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    print('🏠 MyApp built - main app launched!');
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.themeModeListenable,
      builder: (context, mode, _) {
        return MaterialApp(
      title: 'LPU Live Chat',
      theme: lpuTheme,
      darkTheme: lpuDarkTheme,
      themeMode: mode,
      home: const ChatHomePage(),
      debugShowCheckedModeBanner: false,
        );
      },
    );
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

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
    _pages = [
      UniversityGroupsPage(wsService: _wsService),
      PersonalGroupsPage(wsService: _wsService),
      DirectMessagesPage(wsService: _wsService),
    ];
  }

  @override
  void dispose() {
    _wsService.disconnect();
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
    setState(() {
      _selectedIndex = index;
    });
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
    final scheme = Theme.of(context).colorScheme;
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
        drawer: const AppNavDrawer(),
        body: PageTransitionSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation, secondaryAnimation) {
            return SharedAxisTransition(
              transitionType: SharedAxisTransitionType.horizontal,
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              child: child,
            );
          },
          child: KeyedSubtree(
            key: ValueKey(_selectedIndex),
            child: _pages[_selectedIndex],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          backgroundColor: scheme.surface,
          elevation: 3,
          indicatorColor: scheme.primary.withValues(alpha: 0.12),
          onDestinationSelected: _onItemTapped,
          selectedIndex: _selectedIndex,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.school_outlined),
              selectedIcon: Icon(Icons.school),
              label: 'University',
            ),
            NavigationDestination(
              icon: Icon(Icons.group_outlined),
              selectedIcon: Icon(Icons.group),
              label: 'Personal',
            ),
            NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum),
              label: 'DMs',
            ),
          ],
        ),
      ),
    );
  }
}
