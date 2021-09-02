import 'dart:convert';
import 'dart:html' as html;
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

// Auth vars
final appBaseUrl = html.window.location.href;
const AUTH0_DOMAIN = "dev-i8ifovht.us.auth0.com";
const AUTH_CLIENT_ID = "MnKnqptcSo4Wuqa6aJL3CTVfEWbPa3qj";
final AUTH0_REDIRECT_URI = "$appBaseUrl";
const AUTH0_ISSUER = "https://$AUTH0_DOMAIN";
const DISCOVERY = "$AUTH0_DOMAIN/.well-known/openid-configuration";

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

  //z dart html example
  String _token = "";
  html.WindowBase? _popupWin;

  @override
  void initState() {
    super.initState();

    /// Listen to message send with `postMessage`.
    // html.window.onMessage.listen((event) {
    //   /// The event contains the token which means the user is connected.
    //   if (event.data.toString().contains('access_token=')) {
    //     _login(event.data);
    //   }
    // });
    //
    // WidgetsBinding.instance!.addPostFrameCallback((_) {
    //   final currentUri = Uri.base;
    //   final redirectUri = Uri(
    //     host: currentUri.host,
    //     scheme: currentUri.scheme,
    //     port: currentUri.port,
    //     path: 'static.html',
    //   );
    //
    //   final authUri =
    //       'https://$AUTH0_DOMAIN/authorize?response_type=token&client_id='
    //       '$AUTH_CLIENT_ID&redirect_uri='
    //       '$redirectUri&scope=viewing_activity_read';
    //
    //   _popupWin = html.window.open(authUri, "Auth0 Auth", "width=800, height=900, scrollbars=yes");
    // });
  }

  Future<String> _validateToken() async {
    final response = await http.get(
      Uri.parse('https://$AUTH0_DOMAIN/validate'),
      headers: {'Authorization': 'OAuth $_token'},
    );
    return (jsonDecode(response.body) as Map<String, dynamic>)["login"]
        .toString();
  }

  void _login(String data) {
    final receivedUri = Uri.parse(data);

    if (_popupWin != null) {
      _popupWin!.close();
      _popupWin = null;
    }

    setState(() {
      _token = receivedUri.fragment
          .split('&')
          .firstWhere((e) => e.startsWith('access_token='))
          .substring('access_token='.length);
    });
  }

  Future<void> loginAction() async {
    html.window.onMessage.listen((event) {
      /// The event contains the token which means the user is connected.
      if (event.data.toString().contains('access_token=')) {
        _login(event.data);
        setState(() {
          isLoggedIn = true;
          isBusy = false;
        });
      }
    });

    WidgetsBinding.instance!.addPostFrameCallback((_) {
      final currentUri = Uri.base;
      final redirectUri = Uri(
        host: currentUri.host,
        scheme: currentUri.scheme,
        port: currentUri.port,
        path: 'static.html',
      );

      final authUri =
          'https://$AUTH0_DOMAIN/authorize?response_type=token&client_id='
          '$AUTH_CLIENT_ID&redirect_uri='
          '$redirectUri&scope=viewing_activity_read';

      _popupWin = html.window
          .open(authUri, "Auth0 Auth", "width=800, height=900, scrollbars=yes");
    });
  }

  Future<Map> getUserDetails(String accessToken) async {
    final url = "http://$AUTH0_DOMAIN/userinfo";
    final response = await http.get(
      Uri.parse(url),
      headers: {"Authorization": "Bearer $accessToken"},
    );

    if (response.statusCode == 200) {
      print(response);
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to get user details");
    }
  }

  void logoutAction() async {
    SharedPreferences webStorage = await SharedPreferences.getInstance();
    // await secureStorage.delete(key: "refresh_token");
    await webStorage.remove("refresh_token");
    _token = "";
    setState(() {
      isLoggedIn = false;
      isBusy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUri = Uri.base;

    return MaterialApp(
        title: "Flutter Auth Demo",
        home: Scaffold(
            body: Column(
          children: [
            Text("$currentUri"),
            Container(
              child: Center(
                child:
                isLoggedIn
                    ? Profile(logoutAction, _token, picture)
                : Login(loginAction,""),
                // _token != null && _token.isNotEmpty
                //     ? FutureBuilder<String>(
                //         future: _validateToken(),
                //         builder: (_, snapshot) {
                //           if (_token != null && _token.isNotEmpty) {
                //             print("token $_token");
                //             var userDetails = getUserDetails("$_token");
                //             print(userDetails);
                //           }
                //           // print(snapshot.data);
                //           if (!snapshot.hasData)
                //             return CircularProgressIndicator();
                //           return Container(
                //             child: Text("Wellcome ${snapshot.data}"),
                //           );
                //         })
                //     : Container(
                //         child: Text("You are not connected"),
                //       ),
              ),
            ),
          ],
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
        Text("Token $name"),
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
        Text("login"),
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
