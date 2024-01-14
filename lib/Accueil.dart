import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login.dart';
import 'CreerAlerte.dart';
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;
import 'dart:convert';

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
  bool isTaskActive;

  Artiste({required this.nom, this.alertesActivees = false, this.imageUrl, this.isTaskActive = false});

  Map<String, dynamic> toJson() {
    return {
      'nom': nom,
      'alertesActivees': alertesActivees,
      'imageUrl': imageUrl,
      'isTaskActive': isTaskActive,
    };
  }

  factory Artiste.fromJson(Map<String, dynamic> json) {
    return Artiste(
      nom: json['nom'],
      alertesActivees: json['alertesActivees'],
      imageUrl: json['imageUrl'],
      isTaskActive: json['isTaskActive'],
    );
  }
}


class Accueil extends StatefulWidget {
  final String uid;

  const Accueil({Key? key, required this.uid}) : super(key: key);

  @override
  _AccueilState createState() => _AccueilState();

}

class _AccueilState extends State<Accueil> {
  List<Artiste> listeArtistes = [];

  void reloadAlerts() async {
    await loadAlerts();
  }

  void navigateToCreerAlerte() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) =>
          CreerAlerte(uid: widget.uid, onAlertAdded: reloadAlerts),
    ));
  }

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
        MaterialPageRoute(builder: (context) => const LoginPage()));
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
                const SizedBox(height: 60),
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
                            navigateToCreerAlerte();
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
          padding: EdgeInsets.zero, // Important pour s'assurer que le DrawerHeader n'a pas de padding supplémentaire
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                  'Menu',
                  style: TextStyle(color: Colors.white, fontSize: 24)
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
            // ... Autres éléments du menu, si nécessaire
            // Placez le ListTile de déconnexion en bas de la liste
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
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

  const ListeArtistesWidget({Key? key, required this.uid}) : super(key: key);

  @override
  _ListeArtistesWidgetState createState() => _ListeArtistesWidgetState();
}

class _ListeArtistesWidgetState extends State<ListeArtistesWidget> {
  List<Artiste> listeArtistes = [];

  Future<void> saveArtistsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> artistesString = listeArtistes.map((artiste) => json.encode(artiste.toJson())).toList();
    await prefs.setStringList('artistes', artistesString);
    print("SharedPreferences après la mise à jour: $artistesString");
  }

  Future<void> loadArtistsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? artistesString = prefs.getStringList('artistes');
    if (artistesString != null) {
      setState(() {
        listeArtistes = artistesString.map((str) => Artiste.fromJson(json.decode(str))).toList();
      });
    }
    print('SharedPreferences: $artistesString');
    print(listeArtistes[0].alertesActivees);
  }



  void navigateToCreerAlerte() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) =>
          CreerAlerte(uid: widget.uid, onAlertAdded: reloadAlerts),
    ));
  }

  void reloadAlerts() async {
    await loadAlerts();
  }

  @override
  void initState() {
    super.initState();
    loadArtistsFromPrefs().then((_) => loadAlerts());
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
        //isTaskActive: checkIfTaskIsActive(doc.id), // Vous devez implémenter cette logique
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
          Column(
            children: [
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Text(
                  '${listeArtistes.length} ${listeArtistes.length == 1 ? "alert" : "alerts"}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: listeArtistes.length,
                  itemBuilder: (context, index) {
                    Artiste artiste = listeArtistes[index];
                    bool hasImage = artiste.imageUrl != null && artiste.imageUrl!.isNotEmpty;
                    onChanged: (bool value) async {
                      // Mettre à jour l'artiste dans la liste
                      setState(() {
                        artiste.alertesActivees = value;
                        int index = listeArtistes.indexOf(artiste);
                        listeArtistes[index] = artiste; // Mise à jour de l'artiste dans la liste
                      });
                      await saveArtistsToPrefs();
                    };



                    return Card(
                      elevation: 4.0,
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Stack(
                        children: [
                          const SizedBox(height: 160),
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
                                horizontal: 25, vertical: 10),
                            title:
                                Text(artiste.nom,
                                style: const TextStyle(fontSize:20, fontWeight: FontWeight.bold)),
                            trailing: Switch(
                              value: artiste.alertesActivees,
                              onChanged: (bool value) async {
                                // Mettre à jour l'artiste dans la liste
                                setState(() {
                                  artiste.alertesActivees = value;
                                  int index = listeArtistes.indexOf(artiste);
                                  listeArtistes[index] = artiste; // Mise à jour de l'artiste dans la liste
                                });
                                await saveArtistsToPrefs();
                              },

                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 20.0,
            left: 0.0,
            right: 0.0,
            child: Center(
              child: FloatingActionButton(
                onPressed: () {
                  navigateToCreerAlerte();
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

