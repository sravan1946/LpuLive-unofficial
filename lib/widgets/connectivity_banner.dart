// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:connectivity_plus/connectivity_plus.dart';

// Project imports:
import '../services/connectivity_service.dart';

class ConnectivityBanner extends StatefulWidget {
  final Widget child;
  final bool showBanner;

  const ConnectivityBanner({
    super.key,
    required this.child,
    this.showBanner = true,
  });

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  final ConnectivityService _connectivityService = ConnectivityService();
  bool _hasInternetConnection = true;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _listenToConnectivityChanges();
  }

  void _listenToConnectivityChanges() {
    _connectivityService.connectivityStream.listen((
      List<ConnectivityResult> results,
    ) {
      if (results.isNotEmpty && results.first != ConnectivityResult.none) {
        // Connectivity is back, check if we actually have internet
        _checkConnectivity();
      } else {
        // No connectivity at all
        if (mounted) {
          setState(() {
            _hasInternetConnection = false;
            _isChecking = false;
          });
        }
      }
    });
  }

  Future<void> _checkConnectivity() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
    });

    final hasInternet = await _connectivityService.hasInternetConnection();

    if (mounted) {
      setState(() {
        _hasInternetConnection = hasInternet;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showBanner) {
      return widget.child;
    }

    return Stack(
      children: [
        // Main content takes full space
        widget.child,
        // Floating connectivity banner
        if (!_hasInternetConnection)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade600,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No internet connection. Some features may not work properly.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_isChecking)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: _checkConnectivity,
                        child: Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
