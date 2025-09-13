import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();

  /// Check if device has internet connectivity
  Future<bool> hasInternetConnection() async {
    try {
      // Check connectivity status
      final connectivityResults = await _connectivity.checkConnectivity();
      
      // If no connectivity at all, return false
      if (connectivityResults.isEmpty || connectivityResults.first == ConnectivityResult.none) {
        debugPrint('🌐 [ConnectivityService] No connectivity detected');
        return false;
      }

      // Even if we have connectivity, try to reach a reliable server
      // to ensure we actually have internet access
      try {
        final result = await InternetAddress.lookup('google.com');
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          debugPrint('🌐 [ConnectivityService] Internet connection confirmed');
          return true;
        }
      } catch (e) {
        debugPrint('🌐 [ConnectivityService] Internet lookup failed: $e');
        return false;
      }
      
      return false;
    } catch (e) {
      debugPrint('🌐 [ConnectivityService] Error checking connectivity: $e');
      return false;
    }
  }

  /// Stream of connectivity changes
  Stream<List<ConnectivityResult>> get connectivityStream => _connectivity.onConnectivityChanged;

  /// Check if we have any form of connectivity (WiFi, mobile, etc.)
  Future<bool> hasConnectivity() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      return connectivityResults.isNotEmpty && connectivityResults.first != ConnectivityResult.none;
    } catch (e) {
      debugPrint('🌐 [ConnectivityService] Error checking basic connectivity: $e');
      return false;
    }
  }
}
