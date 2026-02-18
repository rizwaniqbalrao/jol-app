import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:jol_app/utils/app_routes.dart';

class DeepLinkService extends GetxService {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  Future<DeepLinkService> init() async {
    _appLinks = AppLinks();
    _initDeepLinks();
    return this;
  }

  void _initDeepLinks() async {
    // Check initial link
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleDeepLink(initialLink);
      }
    } catch (e) {
      debugPrint('Error getting initial link: $e');
    }

    // Listen for changes
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      debugPrint('Deep link error: $err');
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('Received deep link: $uri');

    // Email Verification Logic
    // Tries to handle both query param key and path segment key
    // e.g. /verify-email/?key=XYZ or /verify-email/XYZ/
    if (uri.path.contains('verify-email')) {
      String? key = uri.queryParameters['key'];

      // If not in query, check path segments
      if (key == null) {
        final segments = uri.pathSegments;
        final verifyIndex = segments.indexOf('verify-email');
        if (verifyIndex != -1 && verifyIndex + 1 < segments.length) {
          key = segments[verifyIndex + 1];
        }
      }

      if (key != null) {
        _handleEmailVerification(key);
      }
    }

    // Password Reset Logic
    if (uri.path.contains('password/reset/confirm') ||
        uri.path.contains('password-reset-confirm')) {
      final segments = uri.pathSegments;
      String? uid;
      String? token;

      // Try path segments first (standard django auth format)
      // /auth/password/reset/confirm/<uid>/<token>/
      int confirmIndex = -1;
      if (segments.contains('confirm')) {
        confirmIndex = segments.indexOf('confirm');
      }

      if (confirmIndex != -1 && confirmIndex + 2 < segments.length) {
        uid = segments[confirmIndex + 1];
        token = segments[confirmIndex + 2];
      }

      // Fallback to query params
      uid ??= uri.queryParameters['uid'];
      token ??= uri.queryParameters['token'];

      if (uid != null && token != null) {
        _handlePasswordReset(uid, token);
      }
    }
  }

  void _handleEmailVerification(String key) {
    // Navigate to verification screen with key so it can auto-verify
    // Alternatively, verify directly here if user is logged in

    // For now, let's navigate to a screen that shows "Verifying..."
    Get.toNamed(AppRoutes.verifyEmail, arguments: {'key': key});
  }

  void _handlePasswordReset(String uid, String token) {
    Get.toNamed(AppRoutes.resetPasswordConfirm,
        arguments: {'uid': uid, 'token': token});
  }

  @override
  void onClose() {
    _linkSubscription?.cancel();
    super.onClose();
  }
}
