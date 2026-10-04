import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/categories_screen.dart';

Future<void> main() async {
  // Needed before we talk to the phone (orientation, plugins) in main().
  WidgetsFlutterBinding.ensureInitialized();

  // Lock the whole app to PORTRAIT, so every video is recorded the same way.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const PslDatasetCollectorApp());
}

class PslDatasetCollectorApp extends StatelessWidget {
  const PslDatasetCollectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PSL Dataset Collector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      // Home screen = list of categories.
      home: const CategoriesScreen(),
    );
  }
}
