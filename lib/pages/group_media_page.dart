// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:url_launcher/url_launcher.dart';

// Project imports:
import '../models/user_models.dart';
import '../services/chat_handlers.dart';
import '../services/chat_services.dart';
import '../widgets/app_toast.dart';

class GroupMediaPage extends StatefulWidget {
  final String groupName;
  final String groupId;

  const GroupMediaPage({
    super.key,
    required this.groupName,
    required this.groupId,
  });

  @override
  State<GroupMediaPage> createState() => _GroupMediaPageState();
}

class _GroupMediaPageState extends State<GroupMediaPage> {
  final ChatApiService _apiService = ChatApiService();
  List<GroupMediaItem> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    if (currentUser == null) {
      setState(() {
        _error = 'User not authenticated';
        _loading = false;
      });
      return;
    }
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      final items = await _apiService.fetchGroupMedia(
        currentUser!.chatToken,
        widget.groupName,
      );
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      if (mounted) {
        showAppToast(context, 'Failed to load media: $e', type: ToastType.error);
      }
    }
  }

  IconData _iconForMime(String mime) {
    final m = mime.toLowerCase();
    if (m.contains('pdf')) return Icons.picture_as_pdf;
    if (m.contains('presentation') || m.contains('powerpoint') || m.endsWith('/vnd.ms-powerpoint')) {
      return Icons.slideshow;
    }
    if (m.startsWith('image/')) return Icons.image;
    if (m.startsWith('video/')) return Icons.videocam;
    if (m.startsWith('audio/')) return Icons.audiotrack;
    return Icons.insert_drive_file;
    }

  String _mediaUrl(String mediaId) {
    return 'https://lpulive.lpu.in/backend/media/$mediaId/';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Media'),
        actions: [
          IconButton(
            onPressed: _loadMedia,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: scheme.error),
                        const SizedBox(height: 12),
                        Text(
                          'Failed to load media',
                          style: TextStyle(
                            color: scheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadMedia,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_off, size: 56, color: scheme.onSurfaceVariant),
                          const SizedBox(height: 12),
                          Text(
                            'No media found',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final url = _mediaUrl(item.mediaId);
                        return ListTile(
                          leading: Icon(_iconForMime(item.mediaType), color: scheme.primary),
                          title: Text(item.mediaName, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${item.sentBy} • ${item.entryDate}'),
                          trailing: IconButton(
                            tooltip: 'Download',
                            icon: const Icon(Icons.download),
                            onPressed: () {
                              ChatHandlers.downloadMedia(context, url);
                            },
                          ),
                          onTap: () async {
                            final mime = item.mediaType.toLowerCase();
                            if (mime.contains('pdf') || item.mediaName.toLowerCase().endsWith('.pdf')) {
                              ChatHandlers.showPDFViewer(context, url, item.mediaName);
                              return;
                            }
                            if (mime.contains('presentation') ||
                                mime.contains('powerpoint') ||
                                item.mediaName.toLowerCase().endsWith('.ppt') ||
                                item.mediaName.toLowerCase().endsWith('.pptx')) {
                              ChatHandlers.showPowerPointViewer(context, url, item.mediaName);
                              return;
                            }
                            if (mime.startsWith('image/') ||
                                item.mediaName.toLowerCase().endsWith('.png') ||
                                item.mediaName.toLowerCase().endsWith('.jpg') ||
                                item.mediaName.toLowerCase().endsWith('.jpeg') ||
                                item.mediaName.toLowerCase().endsWith('.gif') ||
                                item.mediaName.toLowerCase().endsWith('.webp')) {
                              ChatHandlers.showFullScreenImage(context, url);
                              return;
                            }
                            // Fallback: open in external app
                            final uri = Uri.parse(url);
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          },
                        );
                      },
                    ),
    );
  }
}
