import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter_facebook_login/flutter_facebook_login.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'signup.dart';
import '../main.dart';
import '../globals.dart' as globals;
import '../postSubmission/placepicker.dart';
import '../homePage/feed.dart';
import 'package:flutter/cupertino.dart';
import '../homePage/home.dart';
import 'selectSchool.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';

class LoginPage extends StatefulWidget {


     FirebaseApp app;
    static const routeName = 'loginPage';


     LoginPage({this.app});

  _LoginState createState() => new _LoginState(app: app);

}



class _LoginState extends State<LoginPage> {
  FirebaseApp app;
  bool userClickedFB = false;
  bool userClickedSC = false;

  AssetImage fbIcon = new AssetImage('assets/fb.png');

  _LoginState({this.app});


  static const platform = const MethodChannel('thumbsOutChannel');
  static final FacebookLogin facebookSignIn = new FacebookLogin();

  void initState() {
    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        body: new Stack(
          alignment: Alignment.center,
          children: <Widget>[
            new Container(
              child: new Column(
                children: <Widget>[
                  new Padding(padding: new EdgeInsets.only(top: 100.0),
                    child: new Image(
                        image: new AssetImage('assets/thumbsOutLogo.png'),
                        height: 275.0,
                        width: 175.0),
                  ),
                  new Text("Link Ridesharing", style: new TextStyle(fontSize: 20.0)),
                  new Padding(padding: new EdgeInsets.only(top: 20.0),
                    child: loginBtn(),
                  ),
                ],
              ),
            ), // here
            (userClickedSC) ? new Center(
              child: new CircularProgressIndicator(),
            ) : new Container(),
            new Align(
              alignment: new Alignment(0.0, 0.9),
              child: new Text("A Brett Young Production"),
            )
          ],
        )
    );
  }



  Widget loginBtn() {
    return new Container(
        child: new Container(
          height: 85.0,
          width: 300.0,
          child: new RaisedButton(
            color: Colors.blue,
            onPressed: (userClickedSC) ? () {} : () async {handleFbLogin();},
            child: new Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                new Padding(padding: new EdgeInsets.all(20.0),
                    child: new Container(
                      height: 40.0,
                      width: 40.0,
                      child: new Image(image: fbIcon,color: Colors.white,)
                    )
                ),
                new Text("Continue With Facebook!", style: new TextStyle(color: Colors.white, fontWeight: FontWeight.bold),)
              ],
            ),
          ),
        )
    );
  }



  Future<void> handleSnapLogin() async {
    var result;
    try {
      result = await logInWithSnapchat();
      if (result != null) {
        setState(() {
          userClickedSC = true;
        });
      }
    } catch (e) {
      _errorMenu("error", "Please make sure you have the correct username/email and password.", '');
      setState(() { userClickedSC = false;
      });
      print(e);
      return;
    }

    bool userexists = await checkIfUserExists(result["id"]);
    if (userexists) {
      DatabaseReference ref = FirebaseDatabase.instance.reference();
      Home home = Home(widget.app, result["id"], true);
      setState(() {userClickedSC = false;});
      globals.id = result["id"];
      Navigator.pushReplacement(context, new MaterialPageRoute(builder: (context) => home),);

    }else {
      setState(() {userClickedSC = false;});
      SelectSchool selectSchool = SelectSchool(app: app, userHasAlreadySignedIn: true, userInfo: result,);
      Navigator.pushReplacement(context, new MaterialPageRoute(builder: (context) => selectSchool),);
    }
  }

  Future<void> handleFbLogin()async{
    FacebookLoginResult result;
    try{
      result = await facebookSignIn.logInWithReadPermissions(['public_profile', 'user_link']);
    }catch(e){
      _errorMenu("error", "There was an error logging in.", " Please make sure your Snap credentials are correct");
      return;
    }
    if(result.accessToken == null){
      return;
    }

    bool userExists = await checkIfUserExists(result.accessToken.userId);
    if(userExists){
      Home homePage = Home(widget.app, result.accessToken.userId,true);
      globals.id = result.accessToken.userId;
      globals.cityCode = await getUserCityCode(result.accessToken.userId);
      Navigator.pushReplacement(context, new MaterialPageRoute(builder: (context) => homePage));
      return;
    }else{
      // add selected user data to snap data
      //do facebook graph stuff
      Map userInfo = new Map();
      var fbInfo = await graphFb(result.accessToken.token);
      userInfo['first_name'] = fbInfo['first_name'];
      userInfo['last_name'] = fbInfo['last_name'];
      userInfo['id'] = fbInfo['id'];
      userInfo['imgURL'] = fbInfo['url'];
      if(fbInfo.containsKey('link')){
        userInfo['link'] = fbInfo['link'];
      }

      SelectSchool selectSchool = SelectSchool(app: app, userHasAlreadySignedIn: true, userInfo: userInfo);
      Navigator.pushReplacement(context, new MaterialPageRoute(builder: (context) => selectSchool),);
    }

  }

  Future<String>getUserCityCode(String id)async{
    FirebaseDatabase database = FirebaseDatabase.instance;
    DataSnapshot snap = await database.reference().child('usersCities').child(id).child('cityCode').once();
    return snap.value;
  }


  Future<Map>graphFb(String token)async{

    FbGraph graph = FbGraph(token);
    Map info = await graph.me(['id', 'name', 'first_name', 'last_name', 'picture.type(large)', 'email','link']);
    return info;
  }




  Future<dynamic> logInWithSnapchat() async {
    dynamic result = await platform.invokeMethod('snapchatLogin');
    return result;
  }


  Future<bool> checkIfUserExists(String id) async {
    FirebaseDatabase database = FirebaseDatabase.instance;
    DataSnapshot snap = await database.reference().child("usersCities").child(
        id).once();
    if (snap.value != null) {
      return true;
    } else {
      return false;
    }
  }






  Future<Null> _errorMenu(String title, String primaryMsg,
      String secondaryMsg) async {
    return showDialog<Null>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return new AlertDialog(
          title: new Text(title),
          content: new SingleChildScrollView(
            child: new ListBody(
              children: <Widget>[
                new Text(primaryMsg),
                new Text(secondaryMsg),
              ],
            ),
          ),
          actions: <Widget>[
            new FlatButton(
              child: new Text(
                'Okay', style: new TextStyle(color: Colors.black),),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }




}


//Future<String> idk() async {
//  try {
//    var req = await HttpClient().getUrl(Uri.parse(
//        "https://firebasestorage.googleapis.com/v0/b/mu-ridesharing.appspot.com/o/profilePics%2Fbitmoji%2F-LICat3jHqQy9Ic0nT93?alt=media&token=86498d4b-360f-4baa-99f9-e04316e0d7d7"));
//    var res = await req.close();
//    var data = await res.first;
//    final StorageReference ref = await FirebaseStorage.instance.ref().child(
//        "bitmojis").child('idsk').child('idsds');
//    final dataRes = await ref.putData(data);
//    final dwldUrl = await dataRes.future;
//    return dwldUrl.downloadUrl.toString();
//  } catch (e) {
//    print(e);
//  }
//}






     //////////////////////////////////////// FACEBOOK CODE ////////////////////////////////////////////////////











//class MyGraph {
//
//  final String _baseGraphUrl = "https://graph.facebook.com/v3.0/";
//  final String token;
//  MyGraph(this.token);
//Future<Map<String, dynamic>> me(fields) async {
//    String _fields = fields.join(",");
//    final http.Response response = await http
//        .get("$_baseGraphUrl/me?fields=${_fields}&access_token=${token}");
// //   return new PublicProfile.fromMap(JSON.decode(response.body));
//
//      Map<String, dynamic>  info = JSON.decode(response.body);
//       Map<String, dynamic> pic = info['picture'];
//       Map<String, dynamic> data = pic['data'];
//       info['url'] = data['url'];
//
//       // as u can see i dont care about parsing json... I have more important issues
//
//
//      return info;
//  }
//}



//
//
//Future<Null> _login() async {
//
//  if(userClickedFB){
//    return;
//  }
//
//  setState(() {
//    userClickedFB = true;
//  });
//
//  final FacebookLoginResult result =
//  await facebookSignIn.logInWithReadPermissions(['public_profile','user_link']);
//
//  switch (result.status) {
//    case FacebookLoginStatus.loggedIn:
//      final FacebookAccessToken accessToken = result.accessToken;
//      FirebaseDatabase database = FirebaseDatabase.instance;
//      database.reference().child("usersCities").child(accessToken.userId).once().then((DataSnapshot snap) {
//        if(snap.value != null){
//          // if the user IS in the database....
//          updateGlobalInfo(accessToken.userId);
//          Home home = Home(widget.app, accessToken.userId,true);
//          setState(() {
//            userClickedFB = false;
//          });
//          Navigator.pushReplacement(context,
//            new MaterialPageRoute(builder: (context) => home),
//          );
//        }else{
//          // if the user is NOT in the database....
//          globals.id = accessToken.userId;
//          //  MyGraph graph = MyGraph(accessToken.token);
//          //  graph.me(['id', 'name', 'first_name', 'last_name', 'picture.type(large)', 'email','link']).then((info) {
//          //   UsersNumber signUp = UsersNumber(app: app, name: info['first_name'], imgURL: info['url'],fullName: info['name'],id: info['id'],fbLink: info['link']); /// will need to replace this later
//
//          SelectSchool selectSchool = SelectSchool(app: app,newDevice: false);
//          Navigator.pushReplacement(context, new MaterialPageRoute(builder: (context) => selectSchool));
////           }
////        );
//        }
//      });
//      return;
//    case FacebookLoginStatus.cancelledByUser:
//      setState(() {
//        userClickedFB = false;
//      });
//      break;
//    case FacebookLoginStatus.error:
//
//      setState(() {
//        userClickedFB = false;
//
//      });
//      break;
//  }
//}
//
//
//
//void updateGlobalInfo(String id) async {
//  FirebaseDatabase database = FirebaseDatabase.instance;
//  final snap = await database.reference().child('userInfo').child(id).once();
//  Map info = snap.value;
//  if(info != null ){
//    if(info.length == 8){
//      globals.id = id;
//      globals.name = info['name'];
//      globals.imgURL = info['imgURL'];
//      globals.city = info['city'];
//      globals.school = info['school'];
//      globals.fullName = info['fullName'];
//
//    }
//  }
//}
