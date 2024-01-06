import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart'; // Assurez-vous que cette page est correctement importée
import 'package:cloud_firestore/cloud_firestore.dart';

Future<Map<String, dynamic>?> fetchUserData(String uid) async {
  try {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return userDoc.data() as Map<String, dynamic>?;
  } catch (e) {
    // Gérer l'erreur ou retourner null
    return null;
  }
}

class Accueil extends StatelessWidget {
  final String uid;

  Accueil({Key? key, required this.uid}) : super(key: key);

  Future<void> signOut(BuildContext context) async {
    // Déconnexion de FirebaseAuth
    await FirebaseAuth.instance.signOut();

    // Mise à jour des SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('userId');

    // Rediriger vers la page de connexion
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Page d'accueil"),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: fetchUserData(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Erreur de chargement des données"));
          } else if (snapshot.hasData) {
            String nickname = snapshot.data?['nickname'] ?? 'Utilisateur';
            return Center(
              child: Text(
                'Bonjour, $nickname',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          } else {
            return Center(child: Text("Aucune donnée utilisateur trouvée"));
          }
        },
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Accueil'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Paramètres'),
              onTap: () {
                // Naviguer vers la page des paramètres
              },
            ),
            // Autres éléments de liste...
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: const Text('Déconnexion'),
              onTap: () => signOut(context),
            ),
          ],
        ),
      ),
    );
  }
}
