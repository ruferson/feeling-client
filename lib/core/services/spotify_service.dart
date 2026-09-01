import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:universal_html/html.dart' as html;

import 'api_service.dart';

class SpotifyService {
  static Future<bool> connectSpotify() async {
    try {
      // 1. Fetch authorization URL from FastAPI (.env)
      final authUrl = await ApiService.getSpotifyLoginUrl();
      if (authUrl == null || authUrl.isEmpty) return false;

      if (kIsWeb) {
        return await _authenticateWeb(authUrl);
      } else {
        final result = await FlutterWebAuth2.authenticate(
          url: authUrl,
          callbackUrlScheme: 'feelingcanvas',
        );
        final code = Uri.parse(result).queryParameters['code'];
        if (code == null || code.isEmpty) return false;
        return await ApiService.linkSpotifyAccount(code);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Spotify Auth Exception: $e');
      }
      return false;
    }
  }

  static Future<bool> _authenticateWeb(String authUrl) async {
    final completer = Completer<bool>();

    final popup = html.window.open(
      authUrl,
      'SpotifyAuth',
      'width=600,height=700,scrollbars=yes',
    );

    late StreamSubscription messageSubscription;
    messageSubscription =
        html.window.onMessage.listen((html.MessageEvent event) async {
      try {
        final String? urlData = event.data?.toString();
        if (urlData != null && urlData.contains('code=')) {
          final uri = Uri.parse(urlData);
          final code = uri.queryParameters['code'];

          messageSubscription.cancel();
          popup.close();

          if (code != null && code.isNotEmpty) {
            final success = await ApiService.linkSpotifyAccount(code);
            completer.complete(success);
          } else {
            completer.complete(false);
          }
        }
      } catch (_) {
        messageSubscription.cancel();
        popup.close();
        if (!completer.isCompleted) completer.complete(false);
      }
    });

    return completer.future;
  }
}