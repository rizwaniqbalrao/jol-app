import 'dart:async';

import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  InterstitialAd? _interstitialAd;

  /// Load the Interstitial Ad
  void loadInterstitial() {
    final adUnitId = kDebugMode
        ? 'ca-app-pub-3940256099942544/1033173712' // Test ID for debug builds
        : 'ca-app-pub-8560615341997714/1775210155'; // Real ID for release builds

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          // You can add more logging here if needed, but avoid console prints in production
        },
      ),
    );
  }

  bool isInterstitialReady() {
    return _interstitialAd != null;
  }

  /// Show Interstitial Ad if loaded, returns true if shown and dismissed successfully
  Future<bool> showInterstitial() async {
    if (_interstitialAd == null) {
      loadInterstitial(); // Preload for next time
      return false;
    }

    final completer = Completer<bool>();

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadInterstitial(); // Preload next ad
        completer.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        loadInterstitial(); // Preload next ad
        completer.complete(false);
      },
    );

    _interstitialAd!.show();
    _interstitialAd = null; // Prevent double show

    return completer.future;
  }
}