import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'Accueil.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Controllers
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nicknameController = TextEditingController();

  Future<void> register() async {
    if (passwordController.text.length < 6) {
      showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Error'),
              content: const Text('The password must be at least 6 characters long.'),
              actions: <Widget>[
                TextButton(
                  child: const Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop(); // Ferme le popup
                  },
                ),
              ],
            );
          });
      return; // Arrête l'exécution de la méthode ici si le mot de passe est trop court
    }

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text,
        password: passwordController.text,
      );

      User? user = userCredential.user;
      if (user != null) {
        // Envoyer à Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email,
          'nickname': nicknameController.text,
        });

        // Si tout réussit, navigue vers la page d'accueil
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => Accueil(uid: user.uid), // Assurez-vous que la classe Accueil est bien définie et accepte un uid en paramètre
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      // Gestion des erreurs de FirebaseAuth
      String errorMessage = 'An error occurred. Please try again.';
      if (e.code == 'email-already-in-use') {
        errorMessage = 'The email address is already in use by another account.';
      } else if (e.code == 'weak-password') {
        errorMessage = 'The password is too weak.';
      }

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Registration Error'),
            content: Text(errorMessage),
            actions: <Widget>[
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop(); // Ferme le popup
                },
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account creation'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextFormField(
              controller: nicknameController,
              decoration: const InputDecoration(labelText: 'Nickname'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: register,
              child: const Text('Sign up'),
            ),
          ],
        ),
      ),
    );
  }
}
