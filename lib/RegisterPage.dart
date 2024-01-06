import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:japanesegoodstool/Accueil.dart';
import 'package:japanesegoodstool/login.dart';
import 'package:firebase_auth/firebase_auth.dart';


class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nicknameController = TextEditingController(); // Contrôleur pour le pseudonyme

  Future<void> register() async {
    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text,
        password: passwordController.text,
      );

      User? user = userCredential.user;
      if (user != null) {
        // Enregistrer les informations de l'utilisateur dans Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email,
          'nickname': nicknameController.text, // et autres informations utilisateur
        });

        // Redirection ou gestion après inscription
      }
    } on FirebaseAuthException catch (e) {
      // Gestion des erreurs
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inscription'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextFormField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextFormField(
              controller: passwordController,
              decoration: InputDecoration(labelText: 'Mot de passe'),
              obscureText: true,
            ),
            TextFormField(
              controller: nicknameController,
              decoration: InputDecoration(labelText: 'Pseudonyme'),
            ),
            ElevatedButton(
              onPressed: register,
              child: Text('S\'inscrire'),
            ),
          ],
        ),
      ),
    );
  }
}
