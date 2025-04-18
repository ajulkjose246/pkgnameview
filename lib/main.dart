import 'package:flutter/material.dart';
import 'package:pkgnameview/screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(
          background: Color(0xFF121212),
          surface: Color(0xFF1E1E1E),
          primary: Colors.blue,
          secondary: Colors.blueAccent,
          onBackground: Colors.white,
          onSurface: Colors.white,
        ),
      ),
      routes: {'/': (context) => const HomeScreen()},
      initialRoute: '/',
    );
  }
}
