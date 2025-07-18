import 'package:flutter/material.dart';
import 'package:maengelapp/screens/dashboard_screen.dart';
import 'package:maengelapp/screens/map_screen.dart';
import 'package:maengelapp/screens/report_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:maengelapp/screens/login_screen.dart';
import 'package:maengelapp/screens/register_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://qeqlmaxjmzbrvvbesiuh.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFlcWxtYXhqbXpicnZ2YmVzaXVoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk5MzY5MDQsImV4cCI6MjA2NTUxMjkwNH0.KqKw1WDYXgojmlIkH1OMGLArxAXwezifRlhv0SWK-gA',
  );

  runApp(MaengelApp());
}

class MaengelApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mängelmelder',
      theme: ThemeData(primarySwatch: Colors.green),
      initialRoute: '/',
      routes: {
        '/': (context) => DashboardScreen(),
        '/karte': (context) => MapScreen(),
        '/neuemeldung': (context) => ReportScreen(),
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(), // Neue Route hinzufügen
      },
    );
  }
}
