import 'package:flutter/material.dart';
import '../models/user_models.dart';
import '../services/chat_services.dart';
import '../services/message_status_service.dart';
import '../widgets/app_toast.dart';

class ChatData {
  static void stabilizeScrollPosition(ScrollController scrollController, int attemptsRemaining, double targetPosition) {
    if (attemptsRemaining <= 0) return;
    if (!scrollController.hasClients) return;
    try {
      scrollController.jumpTo(
        targetPosition.clamp(
          scrollController.position.minScrollExtent,
          scrollController.position.maxScrollExtent,
        ),
      );
      Future.delayed(const Duration(milliseconds: 50), () {
        stabilizeScrollPosition(scrollController, attemptsRemaining - 1, targetPosition);
      });
    } catch (_) {
      // ignore failures from jumpTo when controller is not ready
    }
  }

  static Future<void> loadMessages(
    BuildContext context,
    String groupId,
    ChatApiService apiService,
    Function(bool) setIsLoading,
    Function(List<ChatMessage>) setMessages,
    Function(int) setCurrentPage,
    MessageStatusService statusService,
    Function(DateTime?) setLastReadAt,
  ) async {
    if (currentUser == null) return;
    setIsLoading(true);
    
    try {
      final page = 1;
      final loaded = await apiService.fetchChatMessages(
        groupId,
        currentUser!.chatToken,
        page: page,
      );
      
      setMessages(loaded);
      setIsLoading(false);
      // Initialize status for loaded messages
      statusService.initializeStatuses(loaded);

      // If there are messages and no last-read marker, set it to the last message
      if (loaded.isNotEmpty) {
        try {
          final lastReadAt = DateTime.parse(loaded.last.timestamp);
          setLastReadAt(lastReadAt);
        } catch (_) {}
      }

      if (loaded.isNotEmpty) {
        final lastMsg = loaded.last;
        for (int i = 0; i < (currentUser?.groups.length ?? 0); i++) {
          if (currentUser!.groups[i].name == groupId) {
            currentUser!.groups[i] = currentUser!.groups[i].copyWith(
              groupLastMessage: lastMsg.message,
              lastMessageTime: lastMsg.timestamp,
            );
          }
        }
        TokenStorage.saveCurrentUser();
      }
    } catch (e) {
      setIsLoading(false);
      if (context.mounted) {
        showAppToast(
          context,
          'Failed to load messages: $e',
          type: ToastType.error,
        );
      }
    }
  }

  static Future<void> loadOlderMessages(
    BuildContext context,
    String groupId,
    ChatApiService apiService,
    ScrollController scrollController,
    int currentPage,
    Function(int) setCurrentPage,
    List<ChatMessage> messages,
    Function(List<ChatMessage>) setMessages,
    Function(bool) setIsLoadingMore,
    Function(bool) setHasReachedTop,
    MessageStatusService statusService,
  ) async {
    if (currentUser == null) return;
    setIsLoadingMore(true);
    
    try {
      // For reversed list, record current scroll position to maintain it
      final double currentScrollPosition = scrollController.hasClients
          ? scrollController.position.pixels
          : 0.0;

      final nextPage = currentPage + 1;
      final older = await apiService.fetchChatMessages(
        groupId,
        currentUser!.chatToken,
        page: nextPage,
      );
      
      if (older.isNotEmpty) {
        // older list is ascending; ensure combined stays ascending
        setMessages([...older, ...messages]);
        setCurrentPage(nextPage);
        statusService.initializeStatuses([...older, ...messages]);
        
        // For reversed list, maintain the same scroll position after prepending
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!scrollController.hasClients) return;
          scrollController.jumpTo(currentScrollPosition);
          // Additional stabilization passes to account for late image layout
          stabilizeScrollPosition(scrollController, 3, currentScrollPosition);
        });
      } else {
        // No more messages available - reached the top
        setHasReachedTop(true);
      }
    } catch (e) {
      // Check if this is the "No data found" response indicating we've reached the top
      if (e.toString().contains('No data found')) {
        // Reached the top - no more messages to load
        setHasReachedTop(true);
      } else if (context.mounted) {
        showAppToast(
          context,
          'Failed to load older messages: $e',
          type: ToastType.error,
        );
      }
    } finally {
      setIsLoadingMore(false);
    }
  }
}
