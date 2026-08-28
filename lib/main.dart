import 'package:flutter/material.dart';
import 'screens/node_canvas_screen.dart';

void main() {
  runApp(const FeelingApp());
}

class FeelingApp extends StatelessWidget {
  const FeelingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Feeling App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const NodeCanvasScreen(),
    );
  }
}