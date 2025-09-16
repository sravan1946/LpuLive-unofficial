import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/user_models.dart';
import '../models/message_status.dart';
import '../services/chat_services.dart';
import '../services/message_status_service.dart';
import '../services/read_tracker.dart';
import '../widgets/app_toast.dart';
import '../widgets/pdf_viewer.dart';
import '../widgets/powerpoint_viewer.dart';
import '../widgets/chat_widgets.dart';

class ChatHandlers {
  static void showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(imageUrl: imageUrl),
      ),
    );
  }

  static void replyToMessage(
    BuildContext context,
    ChatMessage message,
    Function(ChatMessage?) setReplyingTo,
    TextEditingController messageController,
  ) {
    setReplyingTo(message);
    messageController.clear();
    // Focus on the text field
    FocusScope.of(context).requestFocus(FocusNode());
  }

  static void cancelReply(Function(ChatMessage?) setReplyingTo) {
    setReplyingTo(null);
  }

  static void showPDFViewer(BuildContext context, String pdfUrl, String? fileName) {
    // Navigate to PDF viewer page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PDFViewer(
          pdfUrl: pdfUrl,
          fileName: fileName,
        ),
      ),
    );
  }

  static void downloadPDFDirectly(String pdfUrl, String? fileName, Function(String) downloadMedia) {
    // Use the same download logic as downloadMedia
    downloadMedia(pdfUrl);
  }

  static void showPowerPointViewer(BuildContext context, String pptUrl, String? fileName) {
    // Navigate to PowerPoint viewer page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PowerPointViewer(
          pptUrl: pptUrl,
          fileName: fileName,
        ),
      ),
    );
  }

  static void downloadPowerPointDirectly(String pptUrl, String? fileName, Function(String) downloadMedia) {
    // Use the same download logic as downloadMedia
    downloadMedia(pptUrl);
  }

  static void showMessageOptions(
    BuildContext context,
    ChatMessage message,
    bool isReadOnly,
    Function(ChatMessage) replyToMessage,
    Function(String, String?) showPDFViewer,
    Function(String, String?) downloadPDFDirectly,
    Function(String) downloadMedia,
    Function(ChatMessage) copyMessageText,
    {
      bool isAdmin = false,
      Future<void> Function(ChatMessage)? onDelete,
    }
  ) {
    final url = message.mediaUrl ?? '';
    final fileName = message.mediaName;
    final isPDF = url.toLowerCase().endsWith('.pdf') || 
                  (fileName?.toLowerCase().endsWith('.pdf') ?? false);
    final isPowerPoint = url.toLowerCase().endsWith('.ppt') || 
                        url.toLowerCase().endsWith('.pptx') ||
                        (fileName?.toLowerCase().endsWith('.ppt') ?? false) ||
                        (fileName?.toLowerCase().endsWith('.pptx') ?? false);
    
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Reply option (same as regular messages) - hide in read-only chats
              if (!isReadOnly)
                ListTile(
                  leading: const Icon(Icons.reply),
                  title: const Text('Reply'),
                  subtitle: const Text('Reply to this message'),
                  onTap: () {
                    Navigator.pop(context);
                    replyToMessage(message);
                  },
                ),
              if (isPDF) ...[
                ListTile(
                  leading: const Icon(Icons.visibility),
                  title: const Text('View PDF'),
                  subtitle: const Text('Open in PDF viewer'),
                  onTap: () {
                    Navigator.pop(context);
                    showPDFViewer(url, fileName);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Download PDF'),
                  subtitle: const Text('Save to Downloads folder'),
                  onTap: () {
                    Navigator.pop(context);
                    downloadPDFDirectly(url, fileName);
                  },
                ),
              ] else if (isPowerPoint) ...[
                ListTile(
                  leading: const Icon(Icons.slideshow),
                  title: const Text('View Presentation'),
                  subtitle: const Text('Open in PowerPoint viewer'),
                  onTap: () {
                    Navigator.pop(context);
                    showPowerPointViewer(context, url, fileName);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Download Presentation'),
                  subtitle: const Text('Save to Downloads folder'),
                  onTap: () {
                    Navigator.pop(context);
                    downloadPowerPointDirectly(url, fileName, downloadMedia);
                  },
                ),
              ] else if (url.isNotEmpty) ...[
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Download File'),
                  subtitle: const Text('Save to Downloads folder'),
                  onTap: () {
                    Navigator.pop(context);
                    downloadMedia(url);
                  },
                ),
              ],
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy text'),
                subtitle: const Text('Copy message content'),
                onTap: () {
                  Navigator.pop(context);
                  copyMessageText(message);
                },
              ),
              if (url.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.open_in_browser),
                  title: const Text('Open in Browser'),
                  subtitle: const Text('View in external app'),
                  onTap: () async {
                    Navigator.pop(context);
                    final uri = Uri.parse(url);
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                ),
              if (isAdmin && onDelete != null)
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Delete message'),
                  subtitle: const Text('Remove this message for everyone'),
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context);
                    await onDelete(message);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  static void downloadMedia(BuildContext context, String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      final directory = await getApplicationDocumentsDirectory();
      final filename = url.split('/').last.split('?').first;
      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(response.bodyBytes);

      if (context.mounted) {
        showAppToast(
          context,
          'Downloaded to ${file.path}',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        showAppToast(context, 'Failed to download: $e', type: ToastType.error);
      }
    }
  }

  static void copyMessageText(BuildContext context, ChatMessage message) {
    // Copy message text to clipboard
    Clipboard.setData(ClipboardData(text: message.message));
    showAppToast(context, 'Text copied to clipboard', type: ToastType.success);
  }

  static Future<void> sendMessage(
    BuildContext context,
    String message,
    bool isReadOnly,
    bool isSending,
    Function(bool) setIsSending,
    ChatMessage? replyingTo,
    Function(ChatMessage?) setReplyingTo,
    WebSocketChatService wsService,
    String groupId,
    List<ChatMessage> messages,
    Function(List<ChatMessage>) setMessages,
    MessageStatusService statusService,
    TextEditingController messageController,
    Function(DateTime?) setLastReadAt,
  ) async {
    if (message.isEmpty || isReadOnly || isSending) return;

    if (!wsService.isConnected) {
      if (context.mounted) {
        showAppToast(
          context,
          'Not connected to chat server',
          type: ToastType.warning,
        );
      }
      return;
    }

    setIsSending(true);

    // Capture reply target before clearing state
    final String? capturedReplyToId = replyingTo?.id;
    final String? capturedReplyMessage = replyingTo?.message;
    final String? capturedReplyUserId = replyingTo?.sender;

    // Create optimistic message with sending status
    final localMessageId = 'local-${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = ChatMessage(
      id: localMessageId,
      message: message,
      sender: currentUser?.id ?? '',
      senderName: currentUser?.displayName ?? currentUser?.name ?? 'You',
      timestamp: DateTime.now().toIso8601String(),
      isOwnMessage: true,
      userImage: currentUser?.userImageUrl,
      category: currentUser?.category,
      group: groupId,
      replyMessageId: capturedReplyToId,
      replyType: capturedReplyToId != null ? 'p' : null,
      replyMessage: capturedReplyMessage,
      replyUserId: capturedReplyUserId,
    );

    // Add optimistic message with sending status
    setMessages([...messages, optimistic]);
    statusService.setStatus(localMessageId, MessageStatus.sending);
    setReplyingTo(null);
    setIsSending(false);
    // Sending marks conversation as read; divider should disappear instantly
    setLastReadAt(DateTime.now());

    // Sending a message should clear unread divider going forward
    ConversationReadTracker.setLastReadToNow(groupId);

    try {
      await wsService.sendMessage(
        message: message,
        group: groupId,
        replyToMessageId: capturedReplyToId,
      );

      messageController.clear();

      // Update group last message info
      final timestamp = DateTime.now().toIso8601String();
      if (currentUser != null) {
        for (int i = 0; i < currentUser!.groups.length; i++) {
          if (currentUser!.groups[i].name == groupId) {
            currentUser!.groups[i] = currentUser!.groups[i].copyWith(
              groupLastMessage: message,
              lastMessageTime: timestamp,
            );
          }
        }
        await TokenStorage.saveCurrentUser();
      }
    } catch (e) {
      if (context.mounted) {
        setIsSending(false);
        // Remove the failed message from the UI
        final updatedMessages = messages.where((msg) => msg.id != localMessageId).toList();
        setMessages(updatedMessages);
        statusService.removeStatus(localMessageId);
        showAppToast(
          context,
          'Failed to send message: $e',
          type: ToastType.error,
        );
      }
    }
  }

  static Future<void> deleteMessage(
    BuildContext context,
    WebSocketChatService wsService,
    ChatMessage message,
  ) async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete message?'),
          content: const Text('This will delete the message for everyone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      await wsService.deleteMessage(messageId: message.id);
      // No toast here; show toast when server confirms deletion
    } catch (e) {
      if (context.mounted) {
        showAppToast(context, 'Failed to delete: $e', type: ToastType.error);
      }
    }
  }
}
