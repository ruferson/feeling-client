import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/config/canvas_constants.dart';
import 'core/services/api_service.dart';
import 'features/auth/screens/auth_screen.dart';
import 'features/canvas/screens/node_canvas_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: CanvasConstants.backgroundColor,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  bool hasSession = false;
  try {
    hasSession = await ApiService.initSession();
  } catch (_) {
    hasSession = false;
  }

  runApp(FeelingApp(initialHasSession: hasSession));
}

class FeelingApp extends StatelessWidget {
  final bool initialHasSession;

  const FeelingApp({
    super.key,
    required this.initialHasSession,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Feeling Canvas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: CanvasConstants.backgroundColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: CanvasConstants.appBarColor,
          elevation: 0,
          centerTitle: false,
        ),
        colorScheme: const ColorScheme.dark(
          primary: CanvasConstants.localNodeColor,
          secondary: CanvasConstants.remoteNodeColor,
          surface: CanvasConstants.cardBackgroundColor,
        ),
      ),
      home: initialHasSession ? const NodeCanvasScreen() : const AuthScreen(),
    );
  }
}
