import 'dart:ui';

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
  String? imageUrl;

  Artiste({required this.nom, this.alertesActivees = false, this.imageUrl});
}

class Accueil extends StatefulWidget {
  final String uid;

  Accueil({Key? key, required this.uid}) : super(key: key);

  @override
  _AccueilState createState() => _AccueilState();
}

class _AccueilState extends State<Accueil> {
  List<Artiste> listeArtistes = [];

  @override
  void initState() {
    super.initState();
    loadAlerts();
  }

  Future<void> loadAlerts() async {
    var userAlerts = await FirebaseFirestore.instance.collection('users')
        .doc(widget.uid)
        .collection('alerts')
        .get();

    var loadedArtistes = userAlerts.docs.map((doc) {
      return Artiste(
        nom: doc.data()['artist'] as String,
        alertesActivees: doc.data()['sendNotifications'] as bool,
        imageUrl: doc.data()['imageUrl'] as String?,
      );
    }).toList();

    setState(() {
      listeArtistes = loadedArtistes;
    });
  }

  Future<void> signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('userId');
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HomePage"),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: fetchUserData(widget.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text("Erreur de chargement des données"));
          } else if (snapshot.hasData) {
            String nickname = snapshot.data?['nickname'] ?? 'Utilisateur';
            return Column(
              children: [
                SizedBox(height: 90),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Hello $nickname',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: listeArtistes.isEmpty
                      ? Center( // Centre si la liste est vide
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      const Text(
                      'Create your first alert with the button',
                      style: TextStyle(
                        fontWeight: FontWeight.bold, // Ajoutez cette ligne pour le gras
                        fontSize: 16, // Ajustez la taille de la police si nécessaire
                      ),
                    ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) => CreerAlerte(uid: widget.uid)));
                          },
                          child: const Text('Create an alert'),
                        ),
                      ],
                    ),
                  )
                      : ListeArtistesWidget(uid: widget.uid), // Affiche la liste des artistes
                ),
              ],
            );
          } else {
            return const Center(child: Text("Pas d'alertes"));
          }
        },
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                  'Menu', style: TextStyle(color: Colors.white, fontSize: 24)),
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
  void initState() {
    super.initState();
    loadAlerts();
  }

  Future<void> loadAlerts() async {
    var userAlerts = await FirebaseFirestore.instance.collection('users')
        .doc(widget.uid)
        .collection('alerts')
        .get();

    List<Artiste> loadedArtistes = userAlerts.docs.map((doc) {
      return Artiste(
        nom: doc.data()['artist'] as String,
        alertesActivees: doc.data()['sendNotifications'] as bool,
        imageUrl: doc.data()['imageUrl'] as String?,
      );
    }).toList();

    setState(() {
      listeArtistes = loadedArtistes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          ListView.builder(
            itemCount: listeArtistes.length,
            itemBuilder: (context, index) {
              Artiste artiste = listeArtistes[index];
              bool hasImage = artiste.imageUrl != null && artiste.imageUrl!.isNotEmpty;

              return Card(
                elevation: 4.0,
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Stack(
                  children: [
                    SizedBox(height: 160),
                    if (hasImage)
                      Positioned.fill(
                        child: ClipRect(
                          child: Container(
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: NetworkImage(artiste.imageUrl!),
                                fit: BoxFit.cover,
                                colorFilter: ColorFilter.mode(
                                    Colors.black.withOpacity(0.5), BlendMode.dstATop),
                              ),
                            ),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                              child: Container(color: Colors.black.withOpacity(0.0)),
                            ),
                          ),
                        ),
                      ),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
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
                  ],
                ),
              );
            },
          ),
          Positioned(
            bottom: 20.0,
            left: 0.0,
            right: 0.0,
            child: Center(
              child: FloatingActionButton(
                onPressed: () {
                  // Action à effectuer quand le bouton est pressé
                },
                child: const Icon(Icons.add),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

