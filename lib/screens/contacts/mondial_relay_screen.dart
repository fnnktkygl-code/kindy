import 'package:pigio_app/core/theme/pigio_theme.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:pigio_app/core/config/constants.dart';
import 'package:pigio_app/shared/widgets/ui_widgets.dart';
import 'package:pigio_app/core/i18n/i18n.dart';

class MondialRelayScreen extends StatefulWidget {
  const MondialRelayScreen({super.key});

  @override
  State<MondialRelayScreen> createState() => _MondialRelayScreenState();
}

class _MondialRelayScreenState extends State<MondialRelayScreen> {
  late final WebViewController _controller;
  late final String _htmlContent;
  bool _isLoading = true;
  bool _hasError = false;
  Timer? _timeoutTimer;

  void _startLoad() {
    _timeoutTimer?.cancel();
    setState(() { _isLoading = true; _hasError = false; });
    _controller.loadHtmlString(_htmlContent);
    _timeoutTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t(context, 'loading_slow'))));
        setState(() => _hasError = true);
      }
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    final String brandId = MondialRelayConfig.brandId;

    final String htmlContent = '''
<!DOCTYPE html>
<html>

<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>Mondial Relay Widget</title>

    <!-- jQuery 3.7.1 -->
    <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.7.1/jquery.min.js"></script>

    <!-- Leaflet 1.9.4 -->
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
    <link rel="stylesheet" type="text/css" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />

    <!-- Mondial Relay Widget Script -->
    <script src="https://widget.mondialrelay.com/parcelshop-picker/jquery.plugin.mondialrelay.parcelshoppicker.min.js"></script>

    <style>
        body,
        html {
            margin: 0;
            padding: 0;
            height: 100%;
            width: 100%;
            overflow: hidden;
        }

        #Zone_Widget {
            width: 100%;
            height: 100%;
        }
    </style>
</head>

<body>
    <!-- Widget Container -->
    <div id="Zone_Widget"></div>

    <!-- Hidden input to capture selection -->
    <input type="hidden" id="Target_Widget" />

    <script>
        \$(document).ready(function () {
            \$("#Zone_Widget").MR_ParcelShopPicker({
                Target: "#Target_Widget",
                Brand: "$brandId",
                Country: "FR",
                Theme: "mondialrelay",
                Responsive: true,
                ShowResultsOnMap: true,
                DisplayMapInfo: true,
                OnParcelShopSelected: function (data) {
                    // Send selected data to Flutter
                    if (window.ParcelShopPickerChannel) {
                        window.ParcelShopPickerChannel.postMessage(JSON.stringify(data));
                    }
                }
            });
        });
    </script>
</body>

</html>
''';

    _htmlContent = htmlContent;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) { _timeoutTimer?.cancel(); setState(() => _isLoading = false); }
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) setState(() { _isLoading = false; _hasError = true; });
          },
          onNavigationRequest: (NavigationRequest request) {
            // Only allow trusted hosts — block any redirect/exfiltration attempts
            const allowed = {
              'widget.mondialrelay.com',
              'ajax.googleapis.com',
              'unpkg.com',
              'tile.openstreetmap.org',
              'nominatim.openstreetmap.org',
            };
            final host = Uri.tryParse(request.url)?.host ?? '';
            if (request.isMainFrame && !allowed.any(host.endsWith)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel(
        'ParcelShopPickerChannel',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            final data = jsonDecode(message.message);
            // Validate expected Mondial Relay structure before passing to caller.
            if (data is Map<String, dynamic> &&
                data.containsKey('ID') &&
                data.containsKey('Nom')) {
              Navigator.of(context).pop(data);
            } else {
              if (kDebugMode) debugPrint('Mondial Relay: unexpected data structure');
            }
          } catch (e) {
            if (kDebugMode) debugPrint('Error parsing Mondial Relay data: \$e');
          }
        },
      );
    _startLoad();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    return Scaffold(
      backgroundColor: theme.scaffold,
      appBar: const PigioAppBar(title: "Mondial Relay", showBack: true),
      body: SafeArea(
        child: _hasError
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off, size: 48, color: theme.light),
                    const SizedBox(height: 16),
                    Text("Service temporairement indisponible", style: fw(size: 16, w: FontWeight.w700, color: theme.mid)),
                    const SizedBox(height: 20),
                    PigioButton(
                      label: "Réessayer",
                      icon: Icons.refresh,
                      color: theme.primary,
                      textColor: theme.onAccent,
                      height: 46,
                      fontSize: 15,
                      onTap: _startLoad,
                    ),
                  ],
                ),
              )
            : Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_isLoading)
                    Center(child: CircularProgressIndicator(color: theme.primary)),
                ],
              ),
      ),
    );
  }
}
