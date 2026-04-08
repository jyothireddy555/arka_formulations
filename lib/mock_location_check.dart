// lib/mock_location_check.dart
import 'dart:io';
import 'package:flutter/services.dart';

class MockLocationDetector {
  static const _channel = MethodChannel('com.arkaformulations/mock_location');

  /// Returns true if mock/fake GPS is active.
  /// Falls back to false on any error (fail-open for non-Android).
  static Future<bool> isMockLocationActive() async {
    if (!Platform.isAndroid) return false;
    try {
      final bool result = await _channel.invokeMethod('isMockLocation');
      return result;
    } catch (_) {
      return false;
    }
  }
}