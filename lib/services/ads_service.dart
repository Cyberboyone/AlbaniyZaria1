import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdsService {
  AdsService._();
  static final AdsService instance = AdsService._();

  static const String appId = 'ca-app-pub-9529770421530115~7513693312';
  static const String bannerAdUnitId = 'ca-app-pub-9529770421530115/9055623669';
  static const String interstitialAdUnitId = 'ca-app-pub-9529770421530115/3574448306';

  InterstitialAd? _interstitialAd;
  int _interstitialLoadAttempts = 0;
  static const int maxFailedLoadAttempts = 3;

  Future<void> init() async {
    await MobileAds.instance.initialize();
    _loadInterstitialAd();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _interstitialLoadAttempts = 0;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          _interstitialLoadAttempts++;
          _interstitialAd = null;
          if (_interstitialLoadAttempts < maxFailedLoadAttempts) {
            _loadInterstitialAd();
          }
        },
      ),
    );
  }

  void showInterstitialAd({VoidCallback? onDismissed}) {
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadInterstitialAd();
          onDismissed?.call();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _loadInterstitialAd();
          onDismissed?.call();
        },
      );
      _interstitialAd!.show();
      _interstitialAd = null;
    } else {
      onDismissed?.call();
    }
  }

  BannerAd createBannerAd({VoidCallback? onLoaded}) {
    final ad = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('Banner ad loaded');
          onLoaded?.call();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Banner ad failed: $error');
        },
      ),
    );
    ad.load();
    return ad;
  }
}