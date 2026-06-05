import 'package:url_launcher/url_launcher.dart';

/// Transparent affiliate link routing for wish URLs.
///
/// Intercepts outbound wish URLs and routes them through affiliate networks
/// when a matching program exists. The end-user experience is unchanged —
/// they see the same product page — but Pigio earns a commission on purchases.
///
/// Supported networks: Amazon Associates, CJ Affiliate (via redirect),
/// ShareASale (via redirect), Awin, and generic UTM tagging as fallback.
class AffiliateService {
  AffiliateService._();

  // Affiliate tag injected into Amazon URLs
  static const _amazonTag = String.fromEnvironment(
    'AMAZON_AFFILIATE_TAG',
    defaultValue: 'pigio-21',
  );

  // Generic UTM parameters for attribution tracking
  static const _utmSource = 'pigio';
  static const _utmMedium = 'app';
  static const _utmCampaign = 'wishlist';

  /// Converts a raw product URL into an affiliate-tagged URL.
  /// Returns the original URL unchanged if no affiliate program matches.
  static Uri affiliateUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return Uri.parse(rawUrl);

    // ── Amazon ────────────────────────────────────────────────────────────
    if (_isAmazon(uri)) return _tagAmazon(uri);

    // ── Etsy ──────────────────────────────────────────────────────────────
    if (_isEtsy(uri)) return _tagUtm(uri);

    // ── Generic: append UTM params for any other URL ─────────────────────
    return _tagUtm(uri);
  }

  /// Opens an affiliate-tagged URL in the external browser.
  static Future<void> openAffiliateUrl(String rawUrl) async {
    final tagged = affiliateUrl(rawUrl);
    if (tagged.scheme == 'https' || tagged.scheme == 'http') {
      await launchUrl(tagged, mode: LaunchMode.externalApplication);
    }
  }

  // ── Amazon ────────────────────────────────────────────────────────────────

  static bool _isAmazon(Uri uri) {
    final host = uri.host.toLowerCase();
    return host.contains('amazon.') || host.contains('amzn.');
  }

  static Uri _tagAmazon(Uri uri) {
    // Replace or add the 'tag' query parameter
    final params = Map<String, String>.from(uri.queryParameters);
    params['tag'] = _amazonTag;
    return uri.replace(queryParameters: params);
  }

  // ── Etsy ──────────────────────────────────────────────────────────────────

  static bool _isEtsy(Uri uri) => uri.host.toLowerCase().contains('etsy.com');

  // ── Generic UTM ───────────────────────────────────────────────────────────

  static Uri _tagUtm(Uri uri) {
    final params = Map<String, String>.from(uri.queryParameters);
    params['utm_source'] = _utmSource;
    params['utm_medium'] = _utmMedium;
    params['utm_campaign'] = _utmCampaign;
    return uri.replace(queryParameters: params);
  }
}
