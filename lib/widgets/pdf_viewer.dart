// Dart imports:
import 'dart:io';

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

// Project imports:
import '../services/file_saver_service.dart';
import '../services/storage_permission_service.dart';
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
        final saveResult = await FileSaverService.copyFileToBestLocation(
          sourceFile: sourceFile,
          fileName: pdfFileName,
          requestPermission: () => StoragePermissionService.ensureStoragePermission(
            context: context,
            deniedMessage:
                'Storage permission denied. Cannot download files.',
            permanentlyDeniedMessage:
                'Storage permission permanently denied. Please enable it in app settings.',
            errorPrefix: 'Error requesting storage permission',
          ),
        );

        if (mounted) {
          showAppToast(
            context,
            'PDF saved to ${saveResult.locationLabel}\nPath: ${saveResult.filePath}',
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
