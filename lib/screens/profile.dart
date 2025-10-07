import '../../firebase_helper.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'profile_form.dart';
import 'goals/goals.dart';
import 'home.dart';
import 'friends.dart';
import 'habits.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'character_select.dart';
import 'activity_page.dart';


// Function to handle sign-out
void signOut(BuildContext context) async {
  await FirebaseAuth.instance.signOut();
  Navigator.pushReplacementNamed(context, '/login');
}

class CustomListTile {
  final IconData icon;
  final String title;
  final String? routeName;
  final VoidCallback? onTap;

  CustomListTile({required this.icon, required this.title, this.routeName, this.onTap});
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.currentIndex = 4});
  static const String routeName = '/profile';
  final int currentIndex;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final user = FirebaseAuth.instance.currentUser;
  late TextEditingController _nameController;
  bool _isSaving = false;
  final FirebaseHelper _firebaseHelper = FirebaseHelper();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: user?.displayName ?? user?.email ?? 'User',
    );
  }

  Future<void> _saveName() async {
    setState(() {
      _isSaving = true;
    });
    try {
      await user?.updateDisplayName(_nameController.text.trim());
      await _firebaseHelper.setDisplayName(_nameController.text.trim());
      await user?.reload(); // Refresh user info
      setState(() {});
    } catch (e) {
      print('Error updating name: $e');
    }
    setState(() {
      _isSaving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    List<CustomListTile> customListTile = [
      CustomListTile(
        icon: CupertinoIcons.calendar,
        title: "Activity",
        routeName: ActivityPage.routeName,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ActivityPage(),
            ),
          );
        },
      ),
      CustomListTile(
        icon: CupertinoIcons.profile_circled,
        title: "Profile Information",
        routeName: ProfileForm.routeName,
      ),
      CustomListTile(
        icon: CupertinoIcons.arrow_2_circlepath,
        title: "Change character",
        routeName: CharSel.routeName,
      ),
      CustomListTile(
        icon: Icons.search,
        title: "FAQ",
      ),
      CustomListTile(
        icon: CupertinoIcons.arrow_right_arrow_left,
        title: "Logout",
        onTap: () => signOut(context),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text('Profile'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Container(
        color: Colors.white,
        child: ListView(
          padding: const EdgeInsets.all(10),
          children: [
            Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage:
                  AssetImage("assets/images/profile_placeholder.png" //changed from NetworkImage() so as to not rely on website hosting image
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _nameController,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: "Enter display name",
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  user?.email ?? "No email",
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 25),
            const Row(
              children: [
                Text("Suggested Friends",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(
              height: 180,
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: 160,
                    child: Card(
                      shadowColor: Colors.black12,
                      child: Padding(
                        padding: const EdgeInsets.all(15.0),
                        child: Column(
                          children: [
                            const Icon(Icons.person, size: 30),
                            const SizedBox(height: 10),
                            const Text("John Doe", textAlign: TextAlign.center),
                            const Spacer(),
                            ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text("Add+"),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                separatorBuilder: (context, index) =>
                    const Padding(padding: EdgeInsets.only(right: 5)),
              ),
            ),
            const SizedBox(height: 35),
            Column(
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
                                    Navigator.pushNamed(context, tile.routeName!);
                                  }
                                : null),
                        leading: Icon(tile.icon),
                        title: Text(tile.title),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  },
                ),
              ],
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
          }
          else if (index == 1) {
            Navigator.pushNamed(context, HabitsPage.routeName);
          }
          else if (index == 2) {
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