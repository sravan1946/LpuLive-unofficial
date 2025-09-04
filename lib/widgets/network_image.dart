import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import '../services/chat_services.dart';

// Safe Network Image Widget
class _InMemoryImageCache {
  static final Map<String, Uint8List> _bytesCache = {};
  static final Map<String, Future<Uint8List?>> _inflight = {};

  static Uint8List? get(String url) => _bytesCache[url];

  static Future<Uint8List?> getOrFetch(String url) {
    final cached = _bytesCache[url];
    if (cached != null) return Future.value(cached);

    final inflight = _inflight[url];
    if (inflight != null) return inflight;

    final future = _fetch(url);
    _inflight[url] = future;
    future.whenComplete(() => _inflight.remove(url));
    return future;
  }

  static Future<Uint8List?> _fetch(String url) async {
    try {
      final response = await CustomHttpClient.getWithCertificateHandling(url);
      if (response != null && response.statusCode == 200) {
        final data = response.bodyBytes;
        _bytesCache[url] = data;
        return data;
      }
    } catch (_) {}
    return null;
  }
}

class SafeNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const SafeNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final cached = _InMemoryImageCache.get(imageUrl);
    if (cached != null) {
      return Image.memory(
        cached,
        width: width,
        height: height,
        fit: fit ?? BoxFit.cover,
        gaplessPlayback: true,
      );
    }

    return FutureBuilder<Uint8List?>(
      future: _InMemoryImageCache.getOrFetch(imageUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return placeholder ?? const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        final bytes = snapshot.data;
        if (snapshot.hasError || bytes == null) {
          return errorWidget ?? Container(
            width: width ?? 32,
            height: height ?? 32,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.person,
              color: Colors.grey[600],
              size: (width ?? 32) * 0.6,
            ),
          );
        }

        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit ?? BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stack) {
            return errorWidget ?? Container(
              width: width ?? 32,
              height: height ?? 32,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.person,
                color: Colors.grey[600],
                size: (width ?? 32) * 0.6,
              ),
            );
          },
        );
      },
    );
  }
}