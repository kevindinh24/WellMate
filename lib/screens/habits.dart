import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile_app/firebase_helper.dart';
import 'goals/goals.dart';
import 'home.dart';
import 'profile.dart';
import 'friends.dart';

class HabitsPage extends StatefulWidget {
  const HabitsPage({super.key, this.currentIndex = 1});
  static const String routeName = '/habits';
  final int currentIndex;

  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
  bool isStepsCompleted = false;
  bool isWaterCompleted = false;
  bool isExerciseCompleted = false;
  bool isMeditationCompleted = false;
  bool isHomeworkCompleted = false;

  // Map to track which habits are hidden
  Map<String, bool> hiddenHabits = {
    'Daily Steps': false,
    'Water Intake': false,
    'Exercise': false,
    'Meditation': false,
    'Homework': false,
  };

  // Map to store custom habits and their completion status
  Map<String, bool> customHabits = {};
  Map<String, bool> customHabitsCompletion = {};
  Map<String, int> habitStreaks = {};

  final FirebaseHelper _firebaseHelper = FirebaseHelper();
  final TextEditingController _newHabitController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkAndResetHabits().then((_) async {
      await _loadHabitCompletionStatus();
      await _loadHiddenHabits();
      await _loadCustomHabits();
      await _loadHabitStreaks();
    });
  }

  Future<void> _loadHabitStreaks() async {
    try {
      Map<String, int> loadedStreaks = {};

      // Load default habit streaks
      for (String habit in hiddenHabits.keys) {
        int streak = await _firebaseHelper.getHabitStreak(habit);
        loadedStreaks[habit] = streak;
      }

      // Load custom habit streaks
      for (String habit in customHabits.keys) {
        int streak = await _firebaseHelper.getHabitStreak(habit);
        loadedStreaks[habit] = streak;
      }

      setState(() {
        habitStreaks = loadedStreaks;
      });
    } catch (e) {
      debugPrint('Error loading habit streaks: $e');
    }
  }

  Future<void> _checkAndResetHabits() async {
    final lastReset = await _firebaseHelper.getLastHabitResetDate();
    final now = DateTime.now();

    if (lastReset == null ||
        lastReset.day != now.day ||
        lastReset.month != now.month ||
        lastReset.year != now.year) {
      await _firebaseHelper.saveHabitCompletionStatus({
        'Daily Steps': false,
        'Water Intake': false,
        'Exercise': false,
        'Meditation': false,
        'Homework': false,
      });

      final currentCustomHabits = await _firebaseHelper.getCustomHabits();
      if (currentCustomHabits != null) {
        final resetCompletion = Map<String, bool>.fromEntries(
          currentCustomHabits.keys.map((key) => MapEntry(key, false)),
        );
        await _firebaseHelper.saveCustomHabitsCompletion(resetCompletion);
      }

      await _firebaseHelper.saveLastHabitResetDate(now);
    }
  }

  @override
  void dispose() {
    _newHabitController.dispose();
    super.dispose();
  }

  Future<void> _loadHabitCompletionStatus() async {
    try {
      final status = await _firebaseHelper.getHabitCompletionStatus();
      setState(() {
        isStepsCompleted = status['Daily Steps'] ?? false;
        isWaterCompleted = status['Water Intake'] ?? false;
        isExerciseCompleted = status['Exercise'] ?? false;
        isMeditationCompleted = status['Meditation'] ?? false;
        isHomeworkCompleted = status['Homework'] ?? false;
      });
    } catch (e) {
      debugPrint('Error loading habit completion status: $e');
    }
  }

  Future<void> _loadHiddenHabits() async {
    try {
      final hidden = await _firebaseHelper.getHiddenHabits();
      if (hidden != null) {
        setState(() {
          hiddenHabits = hidden;
        });
      }
    } catch (e) {
      debugPrint('Error loading hidden habits: $e');
    }
  }

  Future<void> _loadCustomHabits() async {
    try {
      final habits = await _firebaseHelper.getCustomHabits();
      if (habits != null) {
        setState(() {
          customHabits = habits;
          // Initialize completion status for new habits
          for (var habit in habits.keys) {
            if (!customHabitsCompletion.containsKey(habit)) {
              customHabitsCompletion[habit] = false;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading custom habits: $e');
    }
  }

  Future<void> _saveHabitCompletionStatus() async {
    try {
      Map<String, bool> status = {
        'Daily Steps': isStepsCompleted,
        'Water Intake': isWaterCompleted,
        'Exercise': isExerciseCompleted,
        'Meditation': isMeditationCompleted,
        'Homework': isHomeworkCompleted,
      };
      await _firebaseHelper.saveHabitCompletionStatus(status);
    } catch (e) {
      debugPrint('Error saving habit completion status: $e');
    }
  }

  Future<void> _saveHiddenHabits() async {
    try {
      await _firebaseHelper.saveHiddenHabits(hiddenHabits);
    } catch (e) {
      debugPrint('Error saving hidden habits: $e');
    }
  }

  Future<void> _saveCustomHabits() async {
    try {
      await _firebaseHelper.saveCustomHabits(customHabits);
      await _firebaseHelper.saveCustomHabitsCompletion(customHabitsCompletion);
    } catch (e) {
      debugPrint('Error saving custom habits: $e');
    }
  }

  void _toggleHabit(String habitName) {
    setState(() {
      if (habitName == 'Daily Steps') {
        isStepsCompleted = !isStepsCompleted;
      } else if (habitName == 'Water Intake') {
        isWaterCompleted = !isWaterCompleted;
      } else if (habitName == 'Exercise') {
        isExerciseCompleted = !isExerciseCompleted;
      } else if (habitName == 'Meditation') {
        isMeditationCompleted = !isMeditationCompleted;
      } else if (habitName == 'Homework') {
        isHomeworkCompleted = !isHomeworkCompleted;
      }
      _saveHabitCompletionStatus();
      _loadHabitStreaks(); // Reload streaks after toggling
    });
  }

  void _toggleHabitVisibility(String habitName) {
    setState(() {
      hiddenHabits[habitName] = !hiddenHabits[habitName]!;
      _saveHiddenHabits();
    });
  }

  void _showAddHabitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Habit'),
        content: TextField(
          controller: _newHabitController,
          decoration: const InputDecoration(
            hintText: 'Enter habit name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _newHabitController.clear();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (_newHabitController.text.isNotEmpty) {
                setState(() {
                  customHabits[_newHabitController.text] = false;
                  customHabitsCompletion[_newHabitController.text] = false;
                });
                _saveCustomHabits();
                _loadHabitStreaks(); // Reload streaks after adding
                Navigator.pop(context);
                _newHabitController.clear();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _deleteCustomHabit(String habitName) {
    setState(() {
      customHabits.remove(habitName);
      customHabitsCompletion.remove(habitName);
    });
    _saveCustomHabits();
    _loadHabitStreaks(); // Reload streaks after deleting
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text("Daily Habits"),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Active Habits List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Default Habits Section
                  const Text(
                    "Default Habits",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildHabitCard(
                    'Daily Steps',
                    'Take 10,000 steps today',
                    isStepsCompleted,
                    () => _toggleHabit('Daily Steps'),
                    () => _toggleHabitVisibility('Daily Steps'),
                    habitStreaks['Daily Steps'] ?? 0,
                  ),
                  const SizedBox(height: 12),
                  _buildHabitCard(
                    'Water Intake',
                    'Drink 8 glasses of water',
                    isWaterCompleted,
                    () => _toggleHabit('Water Intake'),
                    () => _toggleHabitVisibility('Water Intake'),
                    habitStreaks['Water Intake'] ?? 0,
                  ),
                  const SizedBox(height: 12),
                  _buildHabitCard(
                    'Exercise',
                    '30 minutes of physical activity',
                    isExerciseCompleted,
                    () => _toggleHabit('Exercise'),
                    () => _toggleHabitVisibility('Exercise'),
                    habitStreaks['Exercise'] ?? 0,
                  ),
                  const SizedBox(height: 12),
                  _buildHabitCard(
                    'Meditation',
                    '10 minutes of mindfulness',
                    isMeditationCompleted,
                    () => _toggleHabit('Meditation'),
                    () => _toggleHabitVisibility('Meditation'),
                    habitStreaks['Meditation'] ?? 0,
                  ),
                  const SizedBox(height: 12),
                  _buildHabitCard(
                    'Homework',
                    'Complete your daily assignments',
                    isHomeworkCompleted,
                    () => _toggleHabit('Homework'),
                    () => _toggleHabitVisibility('Homework'),
                    habitStreaks['Homework'] ?? 0,
                  ),
                  const SizedBox(height: 24),
                  // Custom Habits Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Custom Habits",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: _showAddHabitDialog,
                        tooltip: 'Add new habit',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...customHabits.entries.map((entry) => Column(
                    children: [
                      _buildCustomHabitCard(
                        entry.key,
                        customHabitsCompletion[entry.key] ?? false,
                        () {
                          setState(() {
                            customHabitsCompletion[entry.key] =
                                !(customHabitsCompletion[entry.key] ?? false);
                          });
                          _saveCustomHabits();
                          _loadHabitStreaks(); // Reload streaks after toggling
                        },
                        () => _deleteCustomHabit(entry.key),
                        habitStreaks[entry.key] ?? 0,
                      ),
                      const SizedBox(height: 12),
                    ],
                  )).toList(),
                  const SizedBox(height: 24),
                  // Hidden Habits Section
                  if (hiddenHabits.values.any((hidden) => hidden))
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Hidden Habits",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: hiddenHabits.entries
                              .where((entry) => entry.value)
                              .map((entry) => ActionChip(
                                    label: Text(entry.key),
                                    onPressed: () => _toggleHabitVisibility(entry.key),
                                    backgroundColor: Colors.grey[200],
                                  ))
                              .toList(),
                        ),
                      ],
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

  Widget _buildHabitCard(
    String habitName,
    String description,
    bool isCompleted,
    VoidCallback onToggle,
    VoidCallback onHide,
    int streak,
  ) {
    if (hiddenHabits[habitName] == true) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCompleted ? Colors.green.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
          border: Border.all(
            color: isCompleted ? Colors.green.shade300 : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? Colors.green : Colors.grey.shade200,
                border: Border.all(
                  color: isCompleted ? Colors.green : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 24,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        habitName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isCompleted ? Colors.green.shade800 : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.local_fire_department, color: Colors.orange, size: 18),
                      Text(
                        '$streak',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.visibility_off),
              onPressed: onHide,
              tooltip: 'Hide habit',
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomHabitCard(
    String habitName,
    bool isCompleted,
    VoidCallback onToggle,
    VoidCallback onDelete,
    int streak,
  ) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCompleted ? Colors.green.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
          border: Border.all(
            color: isCompleted ? Colors.green.shade300 : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? Colors.green : Colors.grey.shade200,
                border: Border.all(
                  color: isCompleted ? Colors.green : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 24,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Row(
                children: [
                  Text(
                    habitName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? Colors.green.shade800 : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.local_fire_department, color: Colors.orange, size: 18),
                  Text(
                    '$streak',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
              tooltip: 'Delete habit',
              color: Colors.red[300],
            ),
          ],
        ),
      ),
    );
  }
}