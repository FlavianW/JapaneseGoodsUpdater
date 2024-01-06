import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login.dart';
import 'CreerAlerte.dart';

Future<Map<String, dynamic>?> fetchUserData(String uid) async {
  try {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return userDoc.data() as Map<String, dynamic>?;
  } catch (e) {
    return null;
  }
}

class Artiste {
  String nom;
  bool alertesActivees;
  String? imagePath;

  Artiste({required this.nom, this.alertesActivees = false, this.imagePath});
}

class Accueil extends StatelessWidget {
  final String uid;

  Accueil({Key? key, required this.uid}) : super(key: key);

  Future<void> signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('userId');
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Page d'accueil"),
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<Map<String, dynamic>?>(
              future: fetchUserData(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return const Center(child: Text("Erreur de chargement des données"));
                } else if (snapshot.hasData) {
                  String nickname = snapshot.data?['nickname'] ?? 'Utilisateur';
                  return Center(
                    child: Text(
                      'Bonjour, $nickname',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  );
                } else {
                  return const Center(child: Text("Aucune donnée utilisateur trouvée"));
                }
              },
            ),
          ),
          Expanded(
            child: ListeArtistesWidget(uid: uid),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text('Menu', style: TextStyle(color: Colors.white, fontSize: 24)),
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

class ListeArtistesWidget extends StatefulWidget {
  final String uid;

  ListeArtistesWidget({Key? key, required this.uid}) : super(key: key);

  @override
  _ListeArtistesWidgetState createState() => _ListeArtistesWidgetState();
}

class _ListeArtistesWidgetState extends State<ListeArtistesWidget> {
  List<Artiste> listeArtistes = [];

  @override
  Widget build(BuildContext context) {
    if (listeArtistes.isEmpty) {
      return Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => CreerAlerte(uid: widget.uid)));
          },
          child: const Text('Add an alert'),
        ),
      );
    } else {
      return ListView.builder(
        itemCount: listeArtistes.length,
        itemBuilder: (context, index) {
          Artiste artiste = listeArtistes[index];
          return Card(
            elevation: 4.0,
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              leading: CircleAvatar(child: Text(artiste.nom[0])),
              title: Text(artiste.nom),
              trailing: Switch(
                value: artiste.alertesActivees,
                onChanged: (bool value) {
                  setState(() {
                    artiste.alertesActivees = value;
                  });
                },
              ),
            ),
          );
        },
      );
    }
  }
}
