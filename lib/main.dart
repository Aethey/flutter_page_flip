import 'package:flutter/material.dart';

import 'page_viewer.dart';

void main() {
  runApp(const PageCurlDemoApp());
}

class PageCurlDemoApp extends StatelessWidget {
  const PageCurlDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Page Curl Demo',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9C7E54),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const PageViewer(),
    );
  }
}
