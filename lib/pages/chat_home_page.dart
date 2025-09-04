import 'package:flutter/material.dart';
import 'university_groups_page.dart';
import 'personal_groups_page.dart';
import 'direct_messages_page.dart';
import '../services/chat_services.dart';
import '../models/user_models.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    print('🏠 MyApp built - main app launched!');
    return MaterialApp(
      title: 'LPU Live Chat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const ChatHomePage(),
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
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
          return false;
        }
        return await _showExitConfirmation(context);
      },
      child: Scaffold(
        body: _pages[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.school),
              label: 'University',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.group),
              label: 'Personal',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.message),
              label: 'DMs',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Colors.grey,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 8,
        ),
      ),
    );
  }
}