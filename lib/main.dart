/*import 'login_page.dart';
//import 'package:mobile_app/screens/profile.dart';
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: LoginPage());
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required String title});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
*/

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'login_page.dart';
import 'screens/character_select.dart';
import 'screens/profile.dart';
import 'screens/goals/goals.dart';
import 'screens/profile_form.dart';
import 'screens/home.dart';
import 'screens/habits.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'register_page.dart';
import 'screens/friendsStateful.dart';
import 'screens/activity_page.dart';
import 'firebase_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WellMate',

      routes: {
        LoginPage.routeName: (context) => LoginPage(),
        ProfilePage.routeName: (context) => ProfilePage(),
        GoalsWidget.routeName: (context) => GoalsWidget(),
        ProfileForm.routeName: (context) => ProfileForm(),
        RegisterPage.routeName: (context) => RegisterPage(),
        HomePage.routeName: (context) => HomePage(),
        HabitsPage.routeName: (context) => HabitsPage(),
        FriendsPage.routeName: (context) => ChangeNotifierProvider<UserRepo>(create:(context) => UserRepo(firebaseHelper: FirebaseHelper()), child: FriendsPage(),),
        ActivityPage.routeName: (context) => ActivityPage(),
        CharSel.routeName: (context) => CharSel(),
      },
      initialRoute: LoginPage.routeName, // Set the initial route to LoginPage
    );
  }
}
