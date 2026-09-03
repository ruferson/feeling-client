import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/config/canvas_constants.dart';
import 'core/services/api_service.dart';
import 'features/auth/screens/auth_screen.dart';
import 'features/canvas/screens/node_canvas_screen.dart';

/// Entry point of the Feeling Canvas application.
/// Initializes bindings, configures system UI overlays, verifies persistent JWT session credentials,
/// and launches the primary widget tree.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool hasSession = false;

  // Restore encrypted JWT session token from local storage prior to UI mounting
  try {
    hasSession = await ApiService.initSession();
  } catch (_) {
    hasSession = false;
  }

  runApp(FeelingApp(initialHasSession: hasSession));
}

/// Root application widget establishing global Light and Dark Material Theme definitions,
/// system UI overlay listeners, and initial route switching based on session state.
class FeelingApp extends StatefulWidget {
  final bool initialHasSession;

  const FeelingApp({
    super.key,
    required this.initialHasSession,
  });

  /// Global inherited ValueNotifier enabling theme toggling from anywhere in the widget tree.
  static final ValueNotifier<ThemeMode> themeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  @override
  State<FeelingApp> createState() => _FeelingAppState();
}

class _FeelingAppState extends State<FeelingApp> {
  @override
  void initState() {
    super.initState();
    FeelingApp.themeNotifier.addListener(_updateSystemOverlay);
  }

  @override
  void dispose() {
    FeelingApp.themeNotifier.removeListener(_updateSystemOverlay);
    super.dispose();
  }

  /// Synchronizes Android/iOS status bars and navigation bars dynamically with the active theme.
  void _updateSystemOverlay() {
    final Brightness platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final ThemeMode mode = FeelingApp.themeNotifier.value;

    final bool isDark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system && platformBrightness == Brightness.dark);

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: isDark
            ? CanvasConstants.darkBackgroundColor
            : CanvasConstants.lightBackgroundColor,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: FeelingApp.themeNotifier,
      builder: (context, currentMode, child) {
        _updateSystemOverlay();

        return MaterialApp(
          title: 'Feeling Canvas',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,

          // ==================================================================
          // LIGHT THEME DEFINITION
          // ==================================================================
          theme: ThemeData.light().copyWith(
            scaffoldBackgroundColor: CanvasConstants.lightBackgroundColor,
            appBarTheme: const AppBarTheme(
              backgroundColor: CanvasConstants.lightAppBarColor,
              elevation: 0,
              centerTitle: false,
              iconTheme: IconThemeData(color: Colors.black87),
              titleTextStyle: TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            colorScheme: const ColorScheme.light(
              primary: CanvasConstants.localNodeColor,
              secondary: CanvasConstants.remoteNodeColor,
              surface: CanvasConstants.lightCardBackgroundColor,
            ),
          ),

          // ==================================================================
          // DARK THEME DEFINITION
          // ==================================================================
          darkTheme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: CanvasConstants.darkBackgroundColor,
            appBarTheme: const AppBarTheme(
              backgroundColor: CanvasConstants.darkAppBarColor,
              elevation: 0,
              centerTitle: false,
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            colorScheme: const ColorScheme.dark(
              primary: CanvasConstants.localNodeColor,
              secondary: CanvasConstants.remoteNodeColor,
              surface: CanvasConstants.darkCardBackgroundColor,
            ),
          ),

          // Route to NodeCanvasScreen if valid session exists, otherwise AuthScreen
          home: widget.initialHasSession
              ? const NodeCanvasScreen()
              : const AuthScreen(),
        );
      },
    );
  }
}
