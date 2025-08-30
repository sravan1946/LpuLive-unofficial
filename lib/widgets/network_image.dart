import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/chat_services.dart';

// Safe Network Image Widget
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
    return FutureBuilder<http.Response?>(
      future: CustomHttpClient.getWithCertificateHandling(imageUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return placeholder ?? const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        if (snapshot.hasError || snapshot.data == null || snapshot.data!.statusCode != 200) {
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
          snapshot.data!.bodyBytes,
          width: width,
          height: height,
          fit: fit ?? BoxFit.cover,
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