import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class FirebaseHelper {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final DatabaseReference _users = FirebaseDatabase.instance.ref().child('users');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // USER PROFILE METHODS
  Future<void> saveUserProfile(String age, String weight, String height, String gender) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _database.child('users/${user.uid}/profile').set({
      'age': age,
      'weight': weight,
      'height': height,
      'gender': gender,
      'lastUpdated': ServerValue.timestamp,
    });
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snapshot = await _database.child('users/${user.uid}/profile').get();
    if (!snapshot.exists) return null;
    return Map<String, dynamic>.from(snapshot.value as Map);
  }

  // WEIGHT TRACKING METHODS
  Future<void> recordWeightChange(double oldWeight, double newWeight) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('No user logged in');
        return;
      }

      debugPrint('Recording weight change: $oldWeight -> $newWeight');

      final newRecordRef = _database.child('users/${user.uid}/weightHistory').push();
      await newRecordRef.set({
        'oldWeight': oldWeight,
        'newWeight': newWeight,
        'change': newWeight - oldWeight,
        'date': ServerValue.timestamp,
      });

      debugPrint('Weight change recorded successfully');
    } catch (e) {
      debugPrint('Error recording weight change: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getWeightHistory() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('No user logged in');
        return [];
      }

      final snapshot = await _database.child('users/${user.uid}/weightHistory').get();
      if (!snapshot.exists) {
        debugPrint('No weight history found');
        return [];
      }

      final Map<dynamic, dynamic> values = snapshot.value as Map;
      debugPrint('Raw weight history data: $values');

      final history = values.entries.map((entry) {
        final data = Map<String, dynamic>.from(entry.value as Map);
        return {
          'id': entry.key,
          'oldWeight': (data['oldWeight'] as num).toDouble(),
          'newWeight': (data['newWeight'] as num).toDouble(),
          'change': (data['change'] as num).toDouble(),
          'date': DateTime.fromMillisecondsSinceEpoch(data['date'] as int),
        };
      }).toList()
        ..sort((a, b) => b['date'].compareTo(a['date'])); // Sort newest first

      debugPrint('Processed weight history: ${history.length} entries');
      return history;
    } catch (e) {
      debugPrint('Error getting weight history: $e');
      return [];
    }
  }

  // CUSTOM GOALS METHODS
  Future<void> addCustomGoal(String mainGoal, String customGoal) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final newGoalRef = _database.child('users/${user.uid}/customGoals').push();
    await newGoalRef.set({
      'mainGoal': mainGoal,
      'customGoal': customGoal,
      'createdAt': ServerValue.timestamp,
    });
  }

  Future<List<Map<String, dynamic>>> getCustomGoals() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _database.child('users/${user.uid}/customGoals').get();
    if (!snapshot.exists) return [];

    final Map<dynamic, dynamic> values = snapshot.value as Map;
    return values.entries.map((entry) {
      return {
        'id': entry.key,
        ...Map<String, dynamic>.from(entry.value as Map),
      };
    }).toList();
  }

  Future<void> deleteGoal(String goalId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _database.child('users/${user.uid}/customGoals/$goalId').remove();
  }

  // WEIGHT TARGET METHODS
  Future<void> setWeightTarget(String target) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _database.child('users/${user.uid}').update({
      'weightTarget': target,
    });
  }

  Future<String?> getWeightTarget() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snapshot = await _database.child('users/${user.uid}/weightTarget').get();
    return snapshot.value as String?;
  }

  // Weight Goal Completion Checkbox
  Future<void> setWeeklyWeightGoalCompleted(bool completed) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _database.child('users/${user.uid}/weeklyWeightGoalCompleted').set(completed);
  }

  Future<bool> getWeeklyWeightGoalCompleted() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final snapshot = await _database.child('users/${user.uid}/weeklyWeightGoalCompleted').get();
    return snapshot.exists ? snapshot.value as bool : false;
  }

  // SELECTED SUBGOALS METHODS
  Future<void> saveSelectedSubGoal(String goalKey, bool selected) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _database.child('users/${user.uid}/selectedSubGoals').update({
      goalKey: selected,
    });
  }

  Future<Map<String, bool>?> getSelectedSubGoals() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snapshot = await _database.child('users/${user.uid}/selectedSubGoals').get();
    if (!snapshot.exists) return null;
    return Map<String, bool>.from(snapshot.value as Map);
  }

  // PROFILE WEIGHT UPDATE
  Future<void> updateProfileWeight(double newWeight) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get current weight
      final currentWeight = await getCurrentWeight();
      if (currentWeight == null) return;

      // Update profile
      await _database.child('users/${user.uid}/profile').update({
        'weight': newWeight.toStringAsFixed(1),
        'lastWeightUpdate': ServerValue.timestamp,
      });

      // Record weight change
      await recordWeightChange(currentWeight, newWeight);
      
      debugPrint('Weight updated: $currentWeight -> $newWeight');
    } catch (e) {
      debugPrint('Error updating profile weight: $e');
      rethrow;
    }
  }

  Future<double?> getCurrentWeight() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snapshot = await _database.child('users/${user.uid}/profile/weight').get();
    return double.tryParse(snapshot.value.toString());
  }

  // GOAL COMPLETION STATUS
  Future<void> saveGoalCompletionStatus(Map<String, List<bool>> status) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _database.child('users/${user.uid}/goalCompletionStatus').set(status);
  }

  Future<Map<String, List<bool>>> getGoalCompletionStatus() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    final snapshot = await _database.child('users/${user.uid}/goalCompletionStatus').get();
    if (!snapshot.exists) return {};

    final Map<dynamic, dynamic> values = snapshot.value as Map;
    return Map<String, List<bool>>.from(
      values.map((key, value) => MapEntry(
        key.toString(),
        List<bool>.from(value as List),
      )),
    );
  }

  //Save completion status for all habits
  Future<void> saveHabitCompletionStatus(Map<String, bool> status) async { //Map of habit name strings to booleans
    final user = _auth.currentUser;
    if (user == null) return; //Checks if there is no user found

    await _database.child('users/${user.uid}/habitCompletionStatus').set(status);
  }
  
  Future<Map<String, bool>> getHabitCompletionStatus() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    final snapshot = await _database.child('users/${user.uid}/habitCompletionStatus').get();
    if (!snapshot.exists) return {};

    return Map<String, bool>.from(snapshot.value as Map);
  }

  // HIDDEN HABITS
  Future<void> saveHiddenHabits(Map<String, bool> hiddenHabits) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _database.child('users/${user.uid}/hiddenHabits').set(hiddenHabits);
  }

  Future<Map<String, bool>?> getHiddenHabits() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snapshot = await _database.child('users/${user.uid}/hiddenHabits').get();
    if (!snapshot.exists) return null;
    return Map<String, bool>.from(snapshot.value as Map);
  }

  // CUSTOM HABITS
  Future<void> saveCustomHabits(Map<String, bool> customHabits) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _database.child('users/${user.uid}/customHabits').set(customHabits);
  }

  Future<Map<String, bool>?> getCustomHabits() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snapshot = await _database.child('users/${user.uid}/customHabits').get();
    if (!snapshot.exists) return null;
    return Map<String, bool>.from(snapshot.value as Map);
  }

  Future<void> saveCustomHabitsCompletion(Map<String, bool> completionStatus) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _database.child('users/${user.uid}/customHabitsCompletion').set(completionStatus);
  }

  Future<Map<String, bool>?> getCustomHabitsCompletion() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snapshot = await _database.child('users/${user.uid}/customHabitsCompletion').get();
    if (!snapshot.exists) return null;
    return Map<String, bool>.from(snapshot.value as Map);
  }

  //DISPLAY NAME SAVING
  Future<void> setDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Update Firebase Auth display name
      await user.updateDisplayName(name);
      
      // Update database
      await _database.child('users/${user.uid}').update({
        "dname": name,
        "lastUpdated": ServerValue.timestamp
      });
    } catch (e) {
      debugPrint('Error updating display name: $e');
      rethrow;
    }
  }
  //SEARCHING FOR FRIENDS
  Future<List<Map<String, dynamic>>> searchUsers(String name) async {
    final user = _auth.currentUser;
    try {
      final snapshot = await _users.get();
      debugPrint("Raw all users snapshot value: ${snapshot.value}");
      List<Map<String, dynamic>> users = [];
      if (snapshot.exists && snapshot.value != null) {
        Map<dynamic, dynamic> usersMap = snapshot.value as Map<dynamic, dynamic>;
        usersMap.forEach((key, value) {
          if (key != user?.uid && value is Map) {
            final userData = Map<String, dynamic>.from(value);
            if (userData['dname'] != null && 
                userData['dname'].toString().toLowerCase().contains(name.toLowerCase())) {
              users.add({
                'uid': key,
                'displayName': userData['dname'],
              });
            }
          }
        });
      }
      return users;
    } catch (e) {
      debugPrint("FirebaseHelper: Error searching users: $e");
      return [];
    }
  }

  Future<void> saveLastHabitResetDate(DateTime date) async {
  final user = _auth.currentUser;
  if (user == null) return;

  await _database.child('users/${user.uid}/lastHabitReset').set(date.toIso8601String());
}

Future<DateTime?> getLastHabitResetDate() async {
  final user = _auth.currentUser;
  if (user == null) return null;

  final snapshot = await _database.child('users/${user.uid}/lastHabitReset').get();
  if (!snapshot.exists) return null;

  return DateTime.tryParse(snapshot.value as String);
}

  Future<void> updateWeightAndProfile(double newWeight, String? target) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get current weight
      final currentWeight = await getCurrentWeight();
      if (currentWeight == null) return;

      // Create a batch update
      Map<String, dynamic> updates = {};

      // Update profile
      updates['users/${user.uid}/profile/weight'] = newWeight.toStringAsFixed(1);
      updates['users/${user.uid}/profile/lastWeightUpdate'] = ServerValue.timestamp;
      updates['users/${user.uid}/profile/lastUpdated'] = ServerValue.timestamp;

      // Update current attributes
      updates['users/${user.uid}/currentAttributes'] = {
        'weight': newWeight.toStringAsFixed(1),
        'timestamp': ServerValue.timestamp,
        'lastWeightUpdate': ServerValue.timestamp,
      };

      // Update last recorded attributes
      updates['users/${user.uid}/lastRecordedAttributes'] = {
        'weight': newWeight.toStringAsFixed(1),
        'timestamp': ServerValue.timestamp,
        'lastWeightUpdate': ServerValue.timestamp,
      };

      // Update goal status
      updates['users/${user.uid}/weightGoalCompleted'] = false;
      updates['users/${user.uid}/weightGoalTarget'] = target;
      updates['users/${user.uid}/weightGoalLastUpdated'] = ServerValue.timestamp;

      // Perform all updates in a single transaction
      await _database.update(updates);

      // Record the weight change
      await recordWeightChange(currentWeight, newWeight);

      // Add to attributes history
      final newAttributeRef = _database.child('users/${user.uid}/attributesHistory').push();
      await newAttributeRef.set({
        'weight': newWeight.toStringAsFixed(1),
        'timestamp': ServerValue.timestamp,
        'lastWeightUpdate': ServerValue.timestamp,
      });

    } catch (e) {
      debugPrint('Error updating weight and profile: $e');
      rethrow;
    }
  }

  String getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
      } else {
        final months = (difference.inDays / 30).floor();
        return months == 1 ? '1 month ago' : '$months months ago';
      }
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  Future<Map<String, dynamic>> getLastAttributes() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Get both current attributes and profile data
      final currentSnapshot = await _database.child('users/${user.uid}/currentAttributes').get();
      final profileSnapshot = await _database.child('users/${user.uid}/profile').get();
      final lastRecordedSnapshot = await _database.child('users/${user.uid}/lastRecordedAttributes').get();

      Map<String, dynamic> data = {};

      // First try to get from lastRecordedAttributes
      if (lastRecordedSnapshot.exists) {
        data = Map<String, dynamic>.from(lastRecordedSnapshot.value as Map);
      }
      // Then try currentAttributes
      else if (currentSnapshot.exists) {
        data = Map<String, dynamic>.from(currentSnapshot.value as Map);
      }

      // Then merge with profile data
      if (profileSnapshot.exists) {
        data.addAll(Map<String, dynamic>.from(profileSnapshot.value as Map));
      }

      // Add relative time if lastWeightUpdate exists
      if (data['lastWeightUpdate'] != null) {
        final timestamp = data['lastWeightUpdate'] as int;
        final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        data['relativeTime'] = getRelativeTime(dateTime);
      }

      return data;
    } catch (e) {
      debugPrint('Error getting last attributes: $e');
      rethrow;
    }
  }

  Future<void> saveAttributes(Map<String, dynamic> attributes) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Update the profile with new attributes
      await _database.child('users/${user.uid}/profile').update({
        ...attributes,
        'lastUpdated': ServerValue.timestamp,
      });
      
      // Create a new entry in the attributes history
      final newAttributeRef = _database.child('users/${user.uid}/attributesHistory').push();
      await newAttributeRef.set({
        ...attributes,
        'timestamp': ServerValue.timestamp,
      });
      
      // Update current attributes
      await _database.child('users/${user.uid}/currentAttributes').set({
        ...attributes,
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('Error saving attributes: $e');
      rethrow;
    }
  }

  Future<int> getHabitStreak(String habitId) async {
  final user = _auth.currentUser; //Gets currently logged in user
  if (user == null) return 0;

  final snapshot = await _database //Fetches the habit data
      .child('users/${user.uid}/habitEntries/$habitId')
      .get();

  if (!snapshot.exists) return 0; //If there is no data

  final Map<String, dynamic> entries = Map<String, dynamic>.from(snapshot.value as Map);
  final completedDates = entries.entries
      .where((e) => e.value == true)
      .map((e) => e.key)
      .toSet();

  int streak = 0;
  DateTime date = DateTime.now();

  while (true) { //Loop until we find a day that is not completed
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    if (completedDates.contains(dateKey)) {
      streak++;
      date = date.subtract(Duration(days: 1));
    } else {
      break;
    }
  }

  return streak;
  }
  //FRIENDS LIST FETCHING
  Future<List<Map<String, dynamic>>> loadFriends() async {
    final user = _auth.currentUser;
    try {
      final snapshot = await _database.child('users/${user?.uid}/friends').get();
      List<Map<String, dynamic>> friends = [];
      if (snapshot.exists && snapshot.value != null) {
        Map<dynamic, dynamic> friendsMap = snapshot.value as Map<dynamic, dynamic>;
        friendsMap.forEach((key, value) {
          if (value is Map) {
            friends.add({
              'uid': key,
              'displayName': value['dname'],
              'addedAt': value['addedAt'],
            });
          }
        });
      }
      return friends;
    } catch (e) {
      debugPrint("FirebaseHelper: Error loading friends: $e");
      return [];
    }
  }

  Future<DateTime?> getLastWeightUpdate() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final snapshot = await _database.child('users/${user.uid}/profile/lastWeightUpdate').get();
      if (!snapshot.exists) return null;

      final timestamp = snapshot.value as int;
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e) {
      debugPrint('Error getting last weight update: $e');
      return null;
    }
  }

  Future<void> addFriend(String friendUid) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get friend's data
      final friendSnapshot = await _users.child(friendUid).get();
      if (!friendSnapshot.exists) throw Exception('Friend not found');

      final friendData = friendSnapshot.value as Map;
      
      // Add friend to user's friends list
      await _database.child('users/${user.uid}/friends/$friendUid').set({
        'dname': friendData['dname'],
        'addedAt': ServerValue.timestamp,
      });

      // Add user to friend's friends list
      await _database.child('users/$friendUid/friends/${user.uid}').set({
        'dname': user.displayName,
        'addedAt': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('Error adding friend: $e');
      rethrow;
    }
  }

  Future<void> removeFriend(String friendUid) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Remove friend from user's friends list
      await _database.child('users/${user.uid}/friends/$friendUid').remove();

      // Remove user from friend's friends list
      await _database.child('users/$friendUid/friends/${user.uid}').remove();
    } catch (e) {
      debugPrint('Error removing friend: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> calculateRemainingCalories() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'consumed': 0.0,
          'remaining': 0.0,
          'error': 'User not logged in'
        };
      }

      // Get user's profile to calculate daily calorie goal
      final profile = await getUserProfile();
      if (profile == null) {
        return {
          'consumed': 0.0,
          'remaining': 0.0,
          'error': 'Profile not found'
        };
      }

      // Get today's consumed calories
      final today = DateTime.now();
      final todayKey = DateFormat('yyyy-MM-dd').format(today);
      
      final snapshot = await _database
          .child('users/${user.uid}/calories/$todayKey')
          .get();

      double consumedCalories = 0.0;
      if (snapshot.exists) {
        final data = snapshot.value as Map;
        consumedCalories = (data['consumed'] as num?)?.toDouble() ?? 0.0;
      }

      // Calculate daily calorie goal based on profile
      final weight = double.tryParse(profile['weight'] ?? '0') ?? 0;
      final height = double.tryParse(profile['height'] ?? '0') ?? 0;
      final age = int.tryParse(profile['age'] ?? '0') ?? 0;
      final gender = profile['gender'] ?? 'male';
      final activityLevel = profile['activityLevel'] ?? 'sedentary';

      // Calculate BMR using Mifflin-St Jeor Equation
      double weightKg = weight * 0.453592;
      double heightCm = height * 2.54;
      double bmr;
      if (gender.toLowerCase() == 'male') {
        bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5;
      } else {
        bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
      }

      // Calculate TDEE
      final activityMultipliers = {
        'sedentary': 1.2,
        'light': 1.375,
        'moderate': 1.55,
        'active': 1.725,
        'very_active': 1.9,
      };
      final tdee = bmr * (activityMultipliers[activityLevel.toLowerCase()] ?? 1.2);

      // Calculate daily calorie goal (assuming weight loss goal)
      final dailyGoal = tdee - 500; // Subtract 500 calories for 1 pound per week weight loss
      final remainingCalories = dailyGoal - consumedCalories;

      return {
        'consumed': consumedCalories,
        'remaining': remainingCalories,
        'dailyGoal': dailyGoal,
        'tdee': tdee,
        'bmr': bmr
      };
    } catch (e) {
      debugPrint('Error calculating remaining calories: $e');
      return {
        'consumed': 0.0,
        'remaining': 0.0,
        'error': e.toString()
      };
    }
  }

  // Method to record consumed calories
  Future<void> recordCalories(double calories) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final today = DateTime.now();
      final todayKey = DateFormat('yyyy-MM-dd').format(today);

      // Get current consumed calories
      final snapshot = await _database
          .child('users/${user.uid}/calories/$todayKey')
          .get();

      double currentConsumed = 0.0;
      if (snapshot.exists) {
        final data = snapshot.value as Map;
        currentConsumed = (data['consumed'] as num?)?.toDouble() ?? 0.0;
      }

      // Update consumed calories
      await _database
          .child('users/${user.uid}/calories/$todayKey')
          .set({
        'consumed': currentConsumed + calories,
        'lastUpdated': ServerValue.timestamp
      });
    } catch (e) {
      debugPrint('Error recording calories: $e');
      rethrow;
    }
  }

  // Activity tracking methods
  Future<void> recordActivity(int steps, double caloriesBurned) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final today = DateTime.now();
      final todayKey = DateFormat('yyyy-MM-dd').format(today);

      await _database
          .child('users/${user.uid}/activity/$todayKey')
          .set({
        'steps': steps,
        'caloriesBurned': caloriesBurned,
        'lastUpdated': ServerValue.timestamp
      });
    } catch (e) {
      debugPrint('Error recording activity: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getTodayActivity() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'steps': 0,
          'caloriesBurned': 0.0,
          'error': 'User not logged in'
        };
      }

      final today = DateTime.now();
      final todayKey = DateFormat('yyyy-MM-dd').format(today);

      final snapshot = await _database
          .child('users/${user.uid}/activity/$todayKey')
          .get();

      if (!snapshot.exists) {
        return {
          'steps': 0,
          'caloriesBurned': 0.0
        };
      }

      final data = snapshot.value as Map;
      return {
        'steps': (data['steps'] as num?)?.toInt() ?? 0,
        'caloriesBurned': (data['caloriesBurned'] as num?)?.toDouble() ?? 0.0,
        'lastUpdated': data['lastUpdated']
      };
    } catch (e) {
      debugPrint('Error getting today\'s activity: $e');
      return {
        'steps': 0,
        'caloriesBurned': 0.0,
        'error': e.toString()
      };
    }
  }

  Future<void> initializeWeightHistory(double initialWeight) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('No user logged in');
        return;
      }

      debugPrint('Initializing weight history with weight: $initialWeight');

      // First, update the profile weight
      await _database.child('users/${user.uid}/profile').update({
        'weight': initialWeight.toString(),
        'lastWeightUpdate': ServerValue.timestamp,
      });

      // Then create the first weight history entry
      final newRecordRef = _database.child('users/${user.uid}/weightHistory').push();
      await newRecordRef.set({
        'oldWeight': initialWeight,
        'newWeight': initialWeight,
        'change': 0.0,
        'date': ServerValue.timestamp,
      });

      debugPrint('Weight history initialized successfully');
    } catch (e) {
      debugPrint('Error initializing weight history: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> calculateCaloriesFromWeightLoss() async {
    try {
      debugPrint('Starting calorie calculation from weight loss...');
      
      // 1. Get current weight from profile
      final currentWeight = await getCurrentWeight();
      if (currentWeight == null) {
        debugPrint('No current weight found in profile');
        return {'error': 'Please set your current weight in your profile first!'};
      }
      debugPrint('Current weight: $currentWeight');

      // 2. Get weight history
      final weightHistory = await getWeightHistory();
      debugPrint('Found ${weightHistory.length} weight entries');

      if (weightHistory.isEmpty) {
        debugPrint('No weight history available - initializing with current weight');
        // Initialize weight history with current weight
        await initializeWeightHistory(currentWeight);
        return {
          'weeklyWeightLoss': 0.0,
          'weeklyCalories': 0.0,
          'daysTracked': 0,
          'currentWeight': currentWeight,
          'previousWeight': currentWeight,
          'calculationDate': DateTime.now().toString(),
          'message': 'Weight tracking started! Record your weight regularly to see your progress.'
        };
      }

      // 3. Find weight from 7 days ago
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final pastWeights = weightHistory.where((entry) => 
        (entry['date'] as DateTime).isAfter(weekAgo)).toList();

      debugPrint('Found ${pastWeights.length} weights from past week');

      if (pastWeights.isEmpty) {
        // If no entries in past week, use oldest entry
        final oldestEntry = weightHistory.last;
        debugPrint('Using oldest entry from ${oldestEntry['date']}');
        
        final weightLost = (oldestEntry['newWeight'] as double) - currentWeight;
        final daysDiff = DateTime.now().difference(oldestEntry['date'] as DateTime).inDays;
        final caloriesBurned = weightLost * 3500; // 1 lb = 3500 calories

        debugPrint('Weight lost: $weightLost lbs over $daysDiff days');
        debugPrint('Calories burned: $caloriesBurned');

        return {
          'weeklyWeightLoss': weightLost,
          'weeklyCalories': caloriesBurned,
          'daysTracked': daysDiff,
          'currentWeight': currentWeight,
          'previousWeight': oldestEntry['newWeight'],
          'calculationDate': DateTime.now().toString(),
        };
      }

      // Use most recent entry from past week
      final oldestRecentWeight = pastWeights.last['newWeight'] as double;
      final daysDiff = DateTime.now().difference(pastWeights.last['date'] as DateTime).inDays;
      
      debugPrint('Weight from $daysDiff days ago: $oldestRecentWeight');

      // 4. Calculate changes
      final weightLost = oldestRecentWeight - currentWeight;
      final caloriesBurned = weightLost * 3500; // 1 lb = 3500 calories

      debugPrint('Weight lost: $weightLost lbs');
      debugPrint('Calories burned: $caloriesBurned');

      return {
        'weeklyWeightLoss': weightLost,
        'weeklyCalories': caloriesBurned,
        'daysTracked': daysDiff,
        'currentWeight': currentWeight,
        'previousWeight': oldestRecentWeight,
        'calculationDate': DateTime.now().toString(),
      };
    } catch (e) {
      debugPrint('Error calculating calories from weight loss: $e');
      return {'error': 'Failed to calculate calories: $e'};
    }
  }
  Future<void> recordDailyCompletion(DateTime date, bool completed, List<String> completedTasks, List<String> incompleteTasks) async {
  try {
    final user = _auth.currentUser;
    if (user == null) return;

    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    
    await _database.child('users/${user.uid}/dailyCompletion/$dateKey').set({
      'completed': completed,
      'completedTasks': completedTasks,
      'incompleteTasks': incompleteTasks,
      'timestamp': ServerValue.timestamp,
    });
    
    debugPrint('Daily completion recorded for $dateKey: $completed');
  } catch (e) {
    debugPrint('Error recording daily completion: $e');
    rethrow;
  }
}

Future<Map<String, dynamic>?> getDailyCompletion(DateTime date) async {
  try {
    final user = _auth.currentUser;
    if (user == null) return null;

    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final snapshot = await _database.child('users/${user.uid}/dailyCompletion/$dateKey').get();
    
    if (!snapshot.exists) return null;
    
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return {
      'completed': data['completed'] as bool? ?? false,
      'completedTasks': List<String>.from(data['completedTasks'] as List? ?? []),
      'incompleteTasks': List<String>.from(data['incompleteTasks'] as List? ?? []),
      'timestamp': data['timestamp'],
    };
  } catch (e) {
    debugPrint('Error getting daily completion: $e');
    return null;
  }
}

Future<Map<DateTime, Map<String, dynamic>>> getMonthlyCompletions(DateTime month) async {
  try {
    final user = _auth.currentUser;
    if (user == null) return {};

    final snapshot = await _database.child('users/${user.uid}/dailyCompletion').get();
    if (!snapshot.exists) return {};

    final Map<dynamic, dynamic> allData = snapshot.value as Map;
    final Map<DateTime, Map<String, dynamic>> monthlyData = {};

    allData.forEach((key, value) {
      try {
        final date = DateTime.parse(key as String);
        if (date.year == month.year && date.month == month.month) {
          final data = Map<String, dynamic>.from(value as Map);
          monthlyData[date] = {
            'completed': data['completed'] as bool? ?? false,
            'completedTasks': List<String>.from(data['completedTasks'] as List? ?? []),
            'incompleteTasks': List<String>.from(data['incompleteTasks'] as List? ?? []),
            'timestamp': data['timestamp'],
          };
        }
      } catch (e) {
        debugPrint('Error parsing date key: $key');
      }
    });

    return monthlyData;
  } catch (e) {
    debugPrint('Error getting monthly completions: $e');
    return {};
  }
}

// Get all tasks for a specific date (combines habits, goals, and custom tasks)
Future<Map<String, dynamic>> getDailyTasks(DateTime date) async {
  try {
    final user = _auth.currentUser;
    if (user == null) return {'completed': [], 'incomplete': []};

    List<String> allTasks = [];
    
    // Get habits
    final habitCompletion = await getHabitCompletionStatus();
    final customHabits = await getCustomHabits() ?? {};
    final customHabitsCompletion = await getCustomHabitsCompletion() ?? {};
    
    // Add default habits that are not hidden
    final hiddenHabits = await getHiddenHabits() ?? {};
    final defaultHabits = [
      'Drink 8 glasses of water',
      'Exercise for 30 minutes',
      'Read for 20 minutes',
      'Meditate for 10 minutes',
      'Get 8 hours of sleep',
    ];
    
    for (String habit in defaultHabits) {
      if (hiddenHabits[habit] != true) {
        allTasks.add(habit);
      }
    }
    
    // Add custom habits
    customHabits.forEach((habit, isActive) {
      if (isActive) {
        allTasks.add(habit);
      }
    });
    
    // Get goals
    final goalCompletion = await getGoalCompletionStatus();
    final customGoals = await getCustomGoals();
    
    for (var goal in customGoals) {
      allTasks.add(goal['customGoal'] ?? 'Custom Goal');
    }
    
    // For now, we'll simulate task completion
    // In a real app, you'd track individual task completion by date
    List<String> completedTasks = [];
    List<String> incompleteTasks = [];
    
    // Check if we have specific completion data for this date
    final dailyCompletion = await getDailyCompletion(date);
    if (dailyCompletion != null) {
      completedTasks = dailyCompletion['completedTasks'];
      incompleteTasks = dailyCompletion['incompleteTasks'];
    } else {
      // If no specific data, distribute tasks randomly for demo
      for (String task in allTasks) {
        if (DateTime.now().millisecondsSinceEpoch % 2 == 0) {
          completedTasks.add(task);
        } else {
          incompleteTasks.add(task);
        }
      }
    }
    
    return {
      'completed': completedTasks,
      'incomplete': incompleteTasks,
      'allTasks': allTasks,
    };
  } catch (e) {
    debugPrint('Error getting daily tasks: $e');
    return {'completed': [], 'incomplete': []};
  }
}

Future<void> updateTaskCompletion(DateTime date, String task, bool completed) async {
  try {
    final user = _auth.currentUser;
    if (user == null) return;

    final dailyTasks = await getDailyTasks(date);
    List<String> completedTasks = List<String>.from(dailyTasks['completed']);
    List<String> incompleteTasks = List<String>.from(dailyTasks['incomplete']);
    
    if (completed) {
      incompleteTasks.remove(task);
      if (!completedTasks.contains(task)) {
        completedTasks.add(task);
      }
    } else {
      completedTasks.remove(task);
      if (!incompleteTasks.contains(task)) {
        incompleteTasks.add(task);
      }
    }
    
    final overallCompleted = incompleteTasks.isEmpty && completedTasks.isNotEmpty;
    
    await recordDailyCompletion(date, overallCompleted, completedTasks, incompleteTasks);
  } catch (e) {
    debugPrint('Error updating task completion: $e');
    rethrow;
  }
}
}
