import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:universal_html/html.dart' as html;

import 'api_service.dart';

/// Service managing OAuth2 authentication flows with Spotify for both mobile and web clients.
/// Handles OAuth redirect schemes, cross-origin messaging, authorization code extraction,
/// and backend credential linking.
class SpotifyService {
  /// Initiates the Spotify OAuth authentication flow.
  /// Dynamically routes execution between native mobile deep-linking and web popup windows.
  static Future<ActionResult> connectSpotify() async {
    try {
      final authUrl = await ApiService.getSpotifyLoginUrl();
      if (authUrl == null || authUrl.isEmpty) {
        return ActionResult.failure('Unable to retrieve Spotify login URL.');
      }

      if (kIsWeb) {
        return await _authenticateWeb(authUrl);
      }

      // Execute native OAuth authentication using secure custom scheme 'feelingcanvas://'
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl,
        callbackUrlScheme: 'feelingcanvas',
        options: const FlutterWebAuth2Options(
          preferEphemeral: true,
        ),
      );

      final uri = Uri.parse(result);
      final code = uri.queryParameters['code'];

      if (code != null && code.isNotEmpty) {
        return await ApiService.linkSpotifyAccount(code);
      } else {
        return ActionResult.failure(
            'Authorization code not found in callback.');
      }
    } catch (_) {
      return ActionResult.failure(
          'Spotify authentication was cancelled or failed.');
    }
  }

  /// Handles Web-based OAuth authentication using a secure popup window and message listener.
  /// Enforces origin validation to mitigate Cross-Site Scripting (XSS) and message spoofing attacks.
  static Future<ActionResult> _authenticateWeb(String authUrl) async {
    final completer = Completer<ActionResult>();

    final popup = html.window.open(
      authUrl,
      'SpotifyAuth',
      'width=600,height=700,scrollbars=yes',
    );

    late StreamSubscription<html.MessageEvent> messageSubscription;
    Timer? timeoutTimer;

    // Safety timeout to automatically clean up resources if user abandons popup
    timeoutTimer = Timer(const Duration(minutes: 5), () {
      messageSubscription.cancel();
      popup.close();
      if (!completer.isCompleted) {
        completer.complete(
          ActionResult.failure('Spotify authentication timed out.'),
        );
      }
    });

    messageSubscription =
        html.window.onMessage.listen((html.MessageEvent event) async {
      try {
        // Validate event origin against trusted window host to prevent unauthorized cross-origin injections
        if (event.origin != html.window.location.origin) {
          return;
        }

        final String? urlData = event.data?.toString();
        if (urlData != null && urlData.contains('code=')) {
          final uri = Uri.parse(urlData);
          final code = uri.queryParameters['code'];

          timeoutTimer?.cancel();
          await messageSubscription.cancel();
          popup.close();

          if (code != null && code.isNotEmpty) {
            final actionResult = await ApiService.linkSpotifyAccount(code);
            if (!completer.isCompleted) completer.complete(actionResult);
          } else {
            if (!completer.isCompleted) {
              completer.complete(
                ActionResult.failure(
                    'Authorization code not found in callback.'),
              );
            }
          }
        }
      } catch (_) {
        timeoutTimer?.cancel();
        messageSubscription.cancel();
        popup.close();
        if (!completer.isCompleted) {
          completer.complete(
            ActionResult.failure(
                'An error occurred during web authentication.'),
          );
        }
      }
    });

    return completer.future;
  }
}
