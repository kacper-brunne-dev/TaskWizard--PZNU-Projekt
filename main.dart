import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:dart_openai/dart_openai.dart';

import 'firebase_options.dart';
import 'screens/firestore_data_screen.dart';
import 'screens/add_task_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  OpenAI.apiKey = 'api-key';

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskWizard',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: const FirestoreDataScreen(),
      routes: {
        '/add': (_) => const AddTaskScreen(),
      },
    );
  }
}
