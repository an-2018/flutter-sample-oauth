import 'dart:html';

import 'package:flutter/material.dart';
// packages
import 'dart:convert';
import 'package:http/http.dart' as http;
// import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

final FlutterAppAuth appAuth = FlutterAppAuth();
final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

// Auth vars
final appBaseUrl = window.location.href;
const AUTH0_DOMAIN = "dev-i8ifovht.us.auth0.com";
const AUTH_CLIENT_ID = "B40eJzuG0flmvqa7FG7Px1uwN5zkMr0C";
final AUTH0_REDIRECT_URI = "$appBaseUrl";
const AUTH0_ISSUER = "https://$AUTH0_DOMAIN";
const DISCOVERY = "$AUTH0_DOMAIN/.well-known/openid-configuration";

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isBusy = false;
  bool isLoggedIn = false;
  String errorMessage = "";
  String name = "";
  String picture = "";

  Map<String, dynamic> parsedIdToken(String idToken) {
    final parts = idToken.split(r".");
    assert(parts.length == 3);

    return jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
  }

  Future<Map> getUserDetails(String accessToken) async {
    final url = "http://$AUTH0_DOMAIN/userinfo";
    final response = await http.get(
      Uri.parse(url),
      headers: {"Authorization": "Bearer $accessToken"},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to get user details");
    }
  }

  Future<void> loginAction() async {
    SharedPreferences webStorage = await SharedPreferences.getInstance();
    setState(() {
      isBusy = true;
      errorMessage = "";
    });

    try {
      final AuthorizationTokenResponse? result =
          await appAuth.authorizeAndExchangeCode(
            AuthorizationTokenRequest(
              AUTH_CLIENT_ID,
              AUTH0_REDIRECT_URI,
              issuer: "https://$AUTH0_DOMAIN",
              scopes: ["openid", "profile", "offline_access"],
              // promptValues: ["login"] // ignore any existing session; force interactive login prompt
            ),
          );

      final idToken = parsedIdToken((result?.idToken) as String);
      final profile = await getUserDetails((result?.accessToken) as String);


      // await secureStorage.write(
      //   key: "refresh_token", value: result?.refreshToken
      // );
      webStorage.setString("refresh_token", result?.refreshToken as String);

      setState(() {
        isBusy = false;
        isLoggedIn = true;
        name = idToken["name"];
        picture = profile["picture"];
      });
    }catch(e, s) {
      print("login error: $e - stack: $s");

      setState(() {
        isBusy = false;
        isLoggedIn = false;
        errorMessage = e.toString();
      });
    }
  }

  void logoutAction() async {
    SharedPreferences webStorage = await SharedPreferences.getInstance();
    // await secureStorage.delete(key: "refresh_token");
    await webStorage.remove("refresh_token");


    setState(() {
      isLoggedIn = false;
      isBusy = false;
    });
  }

  @override
  void initState() {
    initAction();
    super.initState();
  }

  void initAction() async {
    SharedPreferences webStorage = await SharedPreferences.getInstance();
    // final storedRefreshToken = await secureStorage.read(key: "refresh_token");
    final storedRefreshToken = await webStorage.getString("refresh_token");

    if(storedRefreshToken == null) return;

    setState(() {
      isBusy = true;
    });

    try{
      final response = await appAuth.token(TokenRequest(
          AUTH_CLIENT_ID,
          AUTH0_REDIRECT_URI,
          issuer: AUTH0_ISSUER,
        refreshToken: storedRefreshToken,
      ));

      final idToken = parsedIdToken((response?.idToken) as String);
      final profile = await getUserDetails((response?.accessToken) as String);

      // secureStorage.write(key: "refresh_token", value: response?.refreshToken);
      webStorage.setString("refresh_token", response?.refreshToken as String);

      setState(() {
        isBusy = false;
        isLoggedIn = true;
        name = idToken["name"];
        picture = profile["picture"];
      });
    }catch(e, s){
     print("error on refresh token: $e - stack: $s");
     logoutAction();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: "Flutter Auth Demo",
        home: Scaffold(
            body: Container(
          child: Center(
            child: isBusy
                ? CircularProgressIndicator()
                :isLoggedIn
                  ? Profile(logoutAction, name as String, picture as String)
                  : Login(loginAction, errorMessage as String)
          ),
        )));
  }
}

// profile widget
class Profile extends StatelessWidget {
  final logoutAction;
  final String name;
  final String picture;

  const Profile(this.logoutAction, this.name, this.picture, {Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.purpleAccent, width: 4.0),
            image: DecorationImage(
              fit: BoxFit.fill,
              image: NetworkImage(picture),
            ),
          ),
        ),
        SizedBox(
          height: 24,
        ),
        Text("Name $name"),
        ElevatedButton(
          onPressed: () {
            logoutAction();
          },
          child: Text("Logout"),
        ),
      ],
    );
  }
}

// Login Widget
class Login extends StatelessWidget {
  final loginAction;
  final String loginError;

  const Login(this.loginAction, this.loginError, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            loginAction();
          },
          child: Text("Login"),
        ),
        Text(loginError),
      ],
    );
  }
}

// App
