// Dart imports:
import 'dart:io';

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// Project imports:
import '../widgets/app_toast.dart';

class PDFViewer extends StatefulWidget {
  final String pdfUrl;
  final String? fileName;

  const PDFViewer({super.key, required this.pdfUrl, this.fileName});

  @override
  State<PDFViewer> createState() => _PDFViewerState();
}

class _PDFViewerState extends State<PDFViewer> {
  String? localPath;
  bool isLoading = true;
  bool hasError = false;
  String? errorMessage;
  int currentPage = 0;
  int totalPages = 0;
  bool isReady = false;
  String errorMessagePDF = '';

  @override
  void initState() {
    super.initState();
    _loadPDF();
  }

  Future<void> _loadPDF() async {
    try {
      setState(() {
        isLoading = true;
        hasError = false;
        errorMessage = null;
      });

      // Download PDF to local storage
      final response = await http.get(Uri.parse(widget.pdfUrl));

      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final fileName =
            widget.fileName ?? widget.pdfUrl.split('/').last.split('?').first;

        // Ensure filename has .pdf extension
        final pdfFileName = fileName.endsWith('.pdf')
            ? fileName
            : '$fileName.pdf';
        final file = File('${directory.path}/$pdfFileName');

        await file.writeAsBytes(response.bodyBytes);

        setState(() {
          localPath = file.path;
          isLoading = false;
        });
      } else {
        setState(() {
          hasError = true;
          errorMessage = 'Failed to download PDF (${response.statusCode})';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        hasError = true;
        errorMessage = 'Error loading PDF: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _downloadPDF() async {
    if (localPath == null) return;

    try {
      final sourceFile = File(localPath!);
      if (await sourceFile.exists()) {
        final fileName =
            widget.fileName ?? widget.pdfUrl.split('/').last.split('?').first;
        final pdfFileName = fileName.endsWith('.pdf')
            ? fileName
            : '$fileName.pdf';

        // Try Downloads folder first (works on most devices without permission)
        List<String> possiblePaths = [
          '/storage/emulated/0/Download',
          '/storage/emulated/0/Downloads',
          '/sdcard/Download',
          '/sdcard/Downloads',
        ];

        String? successPath;

        for (String path in possiblePaths) {
          try {
            final downloadsDir = Directory(path);
            if (await downloadsDir.exists() ||
                await _canCreateDirectory(downloadsDir)) {
              if (!await downloadsDir.exists()) {
                await downloadsDir.create(recursive: true);
              }

              final targetFile = File('${downloadsDir.path}/$pdfFileName');
              await sourceFile.copy(targetFile.path);
              successPath = path;
              break;
            }
          } catch (e) {
            // Try next path
            continue;
          }
        }

        // If Downloads folder failed, try with permission
        if (successPath == null) {
          final permission = await _requestStoragePermission();
          if (permission) {
            // Try again with permission
            for (String path in possiblePaths) {
              try {
                final downloadsDir = Directory(path);
                if (await downloadsDir.exists() ||
                    await _canCreateDirectory(downloadsDir)) {
                  if (!await downloadsDir.exists()) {
                    await downloadsDir.create(recursive: true);
                  }

                  final targetFile = File('${downloadsDir.path}/$pdfFileName');
                  await sourceFile.copy(targetFile.path);
                  successPath = path;
                  break;
                }
              } catch (e) {
                // Try next path
                continue;
              }
            }
          }
        }

        // If all download paths failed, use external storage
        if (successPath == null) {
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            final fallbackDir = Directory('${externalDir.path}/Download');
            if (!await fallbackDir.exists()) {
              await fallbackDir.create(recursive: true);
            }
            final targetFile = File('${fallbackDir.path}/$pdfFileName');
            await sourceFile.copy(targetFile.path);
            successPath = fallbackDir.path;
          } else {
            // Final fallback to app documents
            final appDir = await getApplicationDocumentsDirectory();
            final targetFile = File('${appDir.path}/$pdfFileName');
            await sourceFile.copy(targetFile.path);
            successPath = appDir.path;
          }
        }

        if (mounted) {
          final folderName = successPath.contains('Download')
              ? 'Downloads folder'
              : 'Documents folder';
          showAppToast(
            context,
            'PDF saved to $folderName\nPath: $successPath',
            type: ToastType.success,
          );
        }
      } else {
        if (mounted) {
          showAppToast(context, 'PDF file not found', type: ToastType.error);
        }
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'Failed to save PDF: $e', type: ToastType.error);
      }
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      try {
        // Check if permission is already granted
        if (await Permission.storage.isGranted) {
          return true;
        }

        // Check if permission is permanently denied
        if (await Permission.storage.isPermanentlyDenied) {
          if (mounted) {
            showAppToast(
              context,
              'Storage permission permanently denied. Please enable it in app settings.',
              type: ToastType.error,
            );
          }
          return false;
        }

        // Request storage permission
        final status = await Permission.storage.request();

        if (status.isGranted) {
          return true;
        } else if (status.isDenied) {
          if (mounted) {
            showAppToast(
              context,
              'Storage permission denied. Cannot download files.',
              type: ToastType.error,
            );
          }
          return false;
        } else if (status.isPermanentlyDenied) {
          if (mounted) {
            showAppToast(
              context,
              'Storage permission permanently denied. Please enable it in app settings.',
              type: ToastType.error,
            );
          }
          return false;
        }

        return false;
      } catch (e) {
        if (mounted) {
          showAppToast(
            context,
            'Error requesting storage permission: $e',
            type: ToastType.error,
          );
        }
        return false;
      }
    }
    return true; // iOS doesn't need this permission
  }

  Future<bool> _canCreateDirectory(Directory dir) async {
    try {
      await dir.create(recursive: true);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.fileName ?? 'PDF Viewer',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          if (isReady && totalPages > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                '${currentPage + 1} / $totalPages',
                style: TextStyle(
                  color: scheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (localPath != null)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _downloadPDF,
              tooltip: 'Download PDF',
            ),
        ],
      ),
      body: _buildBody(scheme),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('Loading PDF...', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    if (hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: scheme.error, size: 64),
            const SizedBox(height: 16),
            Text(
              'Failed to load PDF',
              style: TextStyle(
                color: scheme.onError,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? 'Unknown error',
              style: TextStyle(
                color: scheme.onError.withValues(alpha: 0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadPDF,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
              ),
            ),
          ],
        ),
      );
    }

    if (localPath == null) {
      return Center(
        child: Text(
          'PDF not available',
          style: TextStyle(color: scheme.onError),
        ),
      );
    }

    return PDFView(
      filePath: localPath!,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: false,
      pageFling: false,
      pageSnap: false,
      defaultPage: 0,
      fitPolicy: FitPolicy.BOTH,
      onRender: (pages) {
        setState(() {
          totalPages = pages ?? 0;
          isReady = true;
        });
      },
      onViewCreated: (PDFViewController pdfViewController) {
        // Controller is available if needed for future features
      },
      onPageChanged: (int? page, int? total) {
        setState(() {
          currentPage = page ?? 0;
        });
      },
      onError: (error) {
        setState(() {
          hasError = true;
          errorMessage = 'PDF rendering error: $error';
        });
      },
      onPageError: (page, error) {
        setState(() {
          hasError = true;
          errorMessage = 'Error on page $page: $error';
        });
      },
    );
  }
}
