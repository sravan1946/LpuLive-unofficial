// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

// Project imports:
import '../services/file_saver_service.dart';
import '../services/storage_permission_service.dart';
import '../widgets/app_toast.dart';

class PowerPointViewer extends StatefulWidget {
  final String pptUrl;
  final String? fileName;

  const PowerPointViewer({super.key, required this.pptUrl, this.fileName});

  @override
  State<PowerPointViewer> createState() => _PowerPointViewerState();
}

class _PowerPointViewerState extends State<PowerPointViewer> {
  late final WebViewController _controller;
  bool isLoading = true;
  bool hasError = false;
  String? errorMessage;
  String? localPath;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading progress if needed
          },
          onPageStarted: (String url) {
            setState(() {
              isLoading = true;
              hasError = false;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            // Only show errors for actual failures, not CSP warnings
            if (error.errorCode != -3) {
              // -3 is often CSP warnings
              setState(() {
                hasError = true;
                errorMessage =
                    'Error loading presentation: ${error.description}';
                isLoading = false;
              });
            }
          },
        ),
      );

    _loadPresentation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set background color after the widget is fully initialized
    _controller.setBackgroundColor(Theme.of(context).colorScheme.surface);
  }

  Future<void> _loadPresentation() async {
    try {
      setState(() {
        isLoading = true;
        hasError = false;
        errorMessage = null;
      });

      // Try multiple approaches for PowerPoint viewing
      await _tryOffice365Viewer();
    } catch (e) {
      setState(() {
        hasError = true;
        errorMessage = 'Error loading presentation: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _tryOffice365Viewer() async {
    // Method 1: Try Microsoft Office 365 Online Viewer with optimized parameters
    final office365Url =
        'https://view.officeapps.live.com/op/embed.aspx?src=${Uri.encodeComponent(widget.pptUrl)}&wdAr=1.7777777777777777&wdEmbedCode=0&wdPrint=0&wdInConfigurator=true&wdInConfigurator=true&wdEmbedCode=0';

    try {
      await _controller.loadRequest(Uri.parse(office365Url));
    } catch (e) {
      // If Office 365 fails, try Google Slides viewer
      await _tryGoogleSlidesViewer();
    }
  }

  Future<void> _tryGoogleSlidesViewer() async {
    // Method 2: Try Google Slides viewer (requires file to be accessible via URL)
    final googleSlidesUrl =
        'https://docs.google.com/gview?url=${Uri.encodeComponent(widget.pptUrl)}&embedded=true&chrome=false';

    try {
      await _controller.loadRequest(Uri.parse(googleSlidesUrl));
    } catch (e) {
      // If Google Slides fails, try alternative Office viewer
      await _tryAlternativeOfficeViewer();
    }
  }

  Future<void> _tryAlternativeOfficeViewer() async {
    // Method 3: Try alternative Office viewer with different parameters
    final alternativeUrl =
        'https://view.officeapps.live.com/op/view.aspx?src=${Uri.encodeComponent(widget.pptUrl)}&wdAr=1.7777777777777777';

    try {
      await _controller.loadRequest(Uri.parse(alternativeUrl));
    } catch (e) {
      // If all methods fail, show simple error message
      setState(() {
        hasError = true;
        errorMessage =
            'Unable to view this presentation. Please try downloading the file.';
        isLoading = false;
      });
    }
  }

  Future<void> _downloadPresentation() async {
    try {
      // Download the file
      final response = await http.get(Uri.parse(widget.pptUrl));

      if (response.statusCode == 200) {
        final fileName =
            widget.fileName ?? widget.pptUrl.split('/').last.split('?').first;

        // Ensure filename has proper extension
        final pptFileName =
            fileName.endsWith('.ppt') || fileName.endsWith('.pptx')
            ? fileName
            : '$fileName.pptx';

        final saveResult = await FileSaverService.saveBytesToBestLocation(
          bytes: response.bodyBytes,
          fileName: pptFileName,
          requestPermission: () => StoragePermissionService.ensureStoragePermission(
            context: context,
            deniedMessage:
                'Storage permission is required to download files.',
            permanentlyDeniedMessage:
                'Storage permission permanently denied. Please enable it in app settings.',
            errorPrefix: 'Storage permission error',
          ),
        );

        if (mounted) {
          showAppToast(
            context,
            'Presentation saved to ${saveResult.locationLabel}\nPath: ${saveResult.filePath}',
            type: ToastType.success,
          );
        }
      } else {
        if (mounted) {
          showAppToast(
            context,
            'Failed to download presentation',
            type: ToastType.error,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          'Error downloading presentation: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _openInExternalApp() async {
    try {
      // Try to open with external apps
      final uri = Uri.parse(widget.pptUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          showAppToast(
            context,
            'No compatible app found to open this presentation',
            type: ToastType.warning,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          'Error opening presentation: $e',
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          widget.fileName ?? 'PowerPoint Presentation',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.download, color: colorScheme.onSurface),
            onPressed: _downloadPresentation,
            tooltip: 'Download presentation',
          ),
          IconButton(
            icon: Icon(Icons.open_in_new, color: colorScheme.onSurface),
            onPressed: _openInExternalApp,
            tooltip: 'Open in external app',
          ),
        ],
      ),
      body: Stack(
        children: [
          if (hasError)
            _buildErrorWidget()
          else
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: WebViewWidget(controller: _controller),
            ),

          if (isLoading)
            Container(
              color: colorScheme.surface,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading presentation...',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      color: colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Error Loading Presentation',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage ??
                    'Something went wrong. Please try downloading the file.',
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _downloadPresentation,
                icon: const Icon(Icons.download),
                label: const Text('Download File'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
