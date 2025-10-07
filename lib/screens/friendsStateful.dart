import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'profile.dart';
import 'goals/goals.dart';
import 'home.dart';
import 'habits.dart';
import '../components/textfield.dart';
import '../../firebase_helper.dart';
import 'package:provider/provider.dart';

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

class UserRepo with ChangeNotifier {
  List<Map<String, dynamic>> _usersfrfr = [];
  List<Map<String, dynamic>> _currentUserFriends = [];
  final FirebaseHelper _firebaseHelper;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  UserRepo({
    required FirebaseHelper firebaseHelper,
  }) : _firebaseHelper = firebaseHelper;

  List<Map<String, dynamic>> get currentCachedUsers {
    return _usersfrfr;
  }

  List<Map<String, dynamic>> get actualLoggedInUserFriends => _currentUserFriends;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  set users(List<Map<String, dynamic>> list) {
    _usersfrfr = list;
    notifyListeners();
  }

  Future<void> addNewFriend(String userIdToAdd) async {
    try {
      await _firebaseHelper.addFriend(userIdToAdd);
      if (_auth.currentUser != null) {
        List<Map<String, dynamic>> updatedFriendsList = await _firebaseHelper.loadFriends();
        _currentUserFriends = updatedFriendsList;
      }
      notifyListeners();
    } catch (e) {
      print("Error adding friend: $e");
      _errorMessage = "Failed to add friend";
      notifyListeners();
    }
  }

  Future<void> fetchUsers(
      {String? searchQuery, User? loggedInUser}) async {
    final loggedInUserID = loggedInUser?.uid ?? _auth.currentUser?.uid;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    List<Map<String, dynamic>> list = [];
    try {
      if (searchQuery != null && searchQuery.isNotEmpty && loggedInUserID != null) {
        print('Loading users with display name: $searchQuery');
        list = await _firebaseHelper.searchUsers(searchQuery);
      } else if (loggedInUserID != null) {
        print('Loading friends...');
        list = await _firebaseHelper.loadFriends();
        _currentUserFriends = list;
      } else {
        print('No user ID found and no search query');
      }
    } catch (e) {
      print('Error in fetchUsers: $e');
      _errorMessage = "Failed to load users. Please try again.";
      _usersfrfr = [];
      _currentUserFriends = [];
    }
    _usersfrfr = list;
    _isLoading = false;
    notifyListeners();
  }
}

class FriendsPage extends StatefulWidget {
  FriendsPage({super.key, this.currentIndex = 3});
  final int currentIndex;

  final TextEditingController searchController = TextEditingController();

  static const String routeName = '/friends';



  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserRepo>().fetchUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userRepo = context.watch<UserRepo>();
    final List<Map<String, dynamic>> usersToDisplay = userRepo.currentCachedUsers;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        title: const Text("Friends"),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: MyTextField(
                controller: widget.searchController,
                hintText: 'search for friends',
                obscureText: false,
                onChanged:(String value) async {
                  print("onChanged called with value: '$value'");
                  await userRepo.fetchUsers(searchQuery: value);
                }),
          ),
          Expanded(
            child: userRepo.isLoading
                ? Center(child: CircularProgressIndicator())
                : userRepo.errorMessage != null
                ? Center(child: Text(userRepo.errorMessage!))
                : usersToDisplay.isEmpty
                ? Center(child: Text('No users found.'))
                : ListView.builder(
                itemCount: usersToDisplay.length,
                itemBuilder: (context, index) {
                  final displayedUserMap = usersToDisplay[index];
                  final String displayedUserId = displayedUserMap['uid'] ?? '';

                  bool isAlreadyFriend =
                  userRepo.actualLoggedInUserFriends.any((friendMap) {
                    return friendMap['uid'] == displayedUserId;
                  });

                  return ListTile(
                    title: Text(displayedUserMap['displayName'] ?? 'No Name'),
                    leading: Image.asset('assets/images/The_Dude.png'),
                    trailing: isAlreadyFriend
                        ? Icon(Icons.chevron_right)
                        : IconButton(
                      icon: Icon(Icons.add),
                      onPressed: () {
                        userRepo.addNewFriend(displayedUserId);
                      },
                    ),
                  );
                }),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: widget.currentIndex,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.check_mark),
            label: "Goals",
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.book),
            label: "Habits",
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_2),
            label: "Friends",
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person),
            label: "Profile",
          ),
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