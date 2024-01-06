import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:japanesegoodstool/RegisterPage.dart';
import 'package:japanesegoodstool/Accueil.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  String? userId = prefs.getString('userId');

  if (isLoggedIn && userId != null) {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null && user.uid == userId) {
      runApp(MaterialApp(home: Accueil(uid: userId)));
    } else {
      runApp(MyApp());
    }
  } else {
    runApp(MyApp());
  }
}



class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Firebase Auth',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool stayLoggedIn = false;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<void> signIn() async {
    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text,
        password: passwordController.text,
      );

      SharedPreferences prefs = await SharedPreferences.getInstance();
      if (stayLoggedIn && userCredential.user != null) {
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userId', userCredential.user!.uid); // Stocker l'UID
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => Accueil(uid: userCredential.user!.uid)),
      );
    } on FirebaseAuthException catch (e) {
      // Gestion des erreurs
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
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
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            Row(
              children: <Widget>[
                Checkbox(
                  value: stayLoggedIn,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value != null) {
                        stayLoggedIn = value;
                      }
                    });
                  },
                ),
                Text('Rester connecté'),
              ],
            ),
            ElevatedButton(
              onPressed: signIn,
              child: Text('Log In'),
            ),

            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => RegisterPage()),
                );
              },
              child: Text('Créer un compte'),
            ),
          ],
        ),
      ),
    );
  }
}

