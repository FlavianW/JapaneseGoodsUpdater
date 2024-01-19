import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Accueil.dart';
import 'TaskManager.dart';
import 'login.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  String? userId = prefs.getString('userId');
  await TaskManager.init();
  if (isLoggedIn && userId != null) {
    runApp(MaterialApp(
      home: Accueil(uid: userId),
      debugShowCheckedModeBanner: false,  // Ajouté ici
    ));
  } else {
    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: LoginPage(),  // Assurez-vous que c'est le bon écran de démarrage
      debugShowCheckedModeBanner: false,  // Ajouté ici
    );
  }
}


