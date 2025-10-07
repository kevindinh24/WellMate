import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'profile.dart';
import 'goals/goals.dart'; // Import goals.dart
import 'home.dart';
import 'habits.dart';
import '../components/textfield.dart';
import '../../firebase_helper.dart';

class FriendsListTile {
  final String title;
  final String? routeName;
  final VoidCallback? onTap;
  final Widget image;

  FriendsListTile({
    required this.title,
    this.routeName,
    this.onTap,
    required this.image,
  });
}

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key, this.currentIndex = 3});

  static const String routeName = '/friends';
  final int currentIndex;

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final TextEditingController searchController = TextEditingController();

  // You can later replace this with a real friends list from Firebase
  final List<FriendsListTile> customListTile = List.generate(
    11,
    (index) => FriendsListTile(
      image: SizedBox(
        width: 50,
        height: 50,
        child: Image.network(
          'https://static.wikia.nocookie.net/thebiglebowski/images/7/7e/The_Dude.jpeg/revision/latest/scale-to-width-down/300?cb=20111216183045',
        ),
      ),
      title: "John Doe",
    ),
  );

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text('Friends'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: MyTextField(
                controller: searchController,
                hintText: 'search for friends',
                obscureText: false,
              ),
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(10),
                children: [
                  ...List.generate(
                    customListTile.length,
                    (index) {
                      final tile = customListTile[index];
                      return Card(
                        elevation: 4,
                        shadowColor: Colors.black12,
                        child: ListTile(
                          onTap: tile.onTap ??
                              (tile.routeName != null
                                  ? () {
                                      Navigator.pushNamed(
                                        context,
                                        tile.routeName!,
                                      );
                                    }
                                  : null),
                          leading: tile.image,
                          title: Text(tile.title),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        elevation: 8,
        currentIndex: widget.currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.check_mark), label: "Goals"),
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.book), label: "Habits"),
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.home), label: "Home"),
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.person_2), label: "Friends"),
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.person), label: "Profile"),
        ],
        onTap: (index) {
          if (index == 0) {
            Navigator.pushNamed(context, GoalsWidget.routeName);
          } else if (index == 1) {
            Navigator.pushNamed(context, HabitsPage.routeName);
          } else if (index == 2) {
            Navigator.pushNamed(context, HomePage.routeName);
          } else if (index == 3) {
            Navigator.pushNamed(context, FriendsPage.routeName);
          } else if (index == 4) {
            Navigator.pushNamed(context, ProfilePage.routeName);
          }
        },
      ),
    );
  }
}
