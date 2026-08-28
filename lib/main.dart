import 'package:flutter/material.dart';
import 'screens/auth_screen.dart';
import 'screens/node_canvas_screen.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bool hasSession = await ApiService.initSession();

  runApp(FeelingApp(initialHasSession: hasSession));
}

class FeelingApp extends StatelessWidget {
  final bool initialHasSession;

  const FeelingApp({super.key, required this.initialHasSession});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Feeling Canvas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: initialHasSession ? const NodeCanvasScreen() : const AuthScreen(),
    );
  }
}
