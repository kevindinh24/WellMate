import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../firebase_helper.dart';
import '../home.dart';
import '../profile.dart';
import '../friends.dart';
import '../habits.dart';

class GoalsWidget extends StatefulWidget {
  const GoalsWidget({super.key, this.currentIndex = 0});
  static const String routeName = '/goals';
  final int currentIndex;

  @override
  State<GoalsWidget> createState() => _GoalsWidgetState();
}

class _GoalsWidgetState extends State<GoalsWidget> {
  int? _expandedIndex;
  final List<String> mainGoals = [
    'Weight',
    'Healthy Diet',
    'Fitness',
    'Self Care',
  ];

  final List<List<String>> subGoals = [
    [],
    ['Eat more vegetables', 'Reduce sugar', 'Balanced meals', 'Drink more water'],
    ['Weight loss', 'Exercise daily', 'Cardio workout', 'Gain muscle'],
    ['Hygiene', 'Rest', 'Journaling', 'Learning'],
  ];

  final List<List<String>> customGoals = [[], [], [], []];
  final List<List<bool>> goalCompletionStatus = [[], [], [], []];
  final List<int> goalProgress = [0, 0, 0, 0];
  String? _weeklyWeightLossTarget;
  bool _weeklyWeightGoalCompleted = false;
  final TextEditingController _weightTargetController = TextEditingController();
  final FirebaseHelper _firebaseHelper = FirebaseHelper();
  final GlobalKey _lastWeightKey = GlobalKey();
  int _lastWeightVersion = 0;
  bool _weeklyGoalReached = false;

  @override
  void initState() {
    super.initState();
    _initializeCompletionStatus();
    _loadData();
  }

  @override
  void dispose() {
    _weightTargetController.dispose();
    super.dispose();
  }

  void _initializeCompletionStatus() {
    for (int i = 0; i < mainGoals.length; i++) {
      goalCompletionStatus[i] = List<bool>.filled(
        subGoals[i].length + customGoals[i].length,
        false,
      );
    }
  }

  Future<void> _loadData() async {
    await _loadCustomGoals();
    await _loadWeightTarget();
    await _loadGoalCompletionStatus();
    await _checkWeeklyGoalStatus();
  }

  Future<void> _loadCustomGoals() async {
    try {
      final goals = await _firebaseHelper.getCustomGoals();
      setState(() {
        // Clear existing custom goals
        for (var list in customGoals) {
          list.clear();
        }
        
        // Add loaded goals
        for (var goal in goals) {
          final mainGoalIndex = mainGoals.indexOf(goal['mainGoal']);
          if (mainGoalIndex != -1) {
            customGoals[mainGoalIndex].add(goal['customGoal'] as String);
          }
        }
        _updateAllProgress();
      });
    } catch (e) {
      debugPrint('Error loading custom goals: $e');
    }
  }

 Future<void> _loadWeightTarget() async {
  try {
    final target = await _firebaseHelper.getWeightTarget();
    final completed = await _firebaseHelper.getWeeklyWeightGoalCompleted(); 
    setState(() {
      _weeklyWeightLossTarget = target;
      _weeklyWeightGoalCompleted = completed; 
    });
  } catch (e) {
    debugPrint('Error loading weight target or checkbox: $e');
  }
}

  Future<void> _loadGoalCompletionStatus() async {
    try {
      final status = await _firebaseHelper.getGoalCompletionStatus();
      setState(() {
        for (int i = 0; i < mainGoals.length; i++) {
          if (status.containsKey(mainGoals[i])) {
            final List<dynamic> rawList = status[mainGoals[i]] ?? [];
            goalCompletionStatus[i] = List<bool>.from(
              rawList.map((item) => item as bool).toList(),
            );
          }
        }
        _updateAllProgress();
      });
    } catch (e) {
      debugPrint('Error loading goal completion status: $e');
    }
  }

  Future<void> _saveGoalCompletionStatus() async {
    try {
      Map<String, List<bool>> status = {};
      for (int i = 0; i < mainGoals.length; i++) {
        status[mainGoals[i]] = goalCompletionStatus[i];
      }
      await _firebaseHelper.saveGoalCompletionStatus(status);
    } catch (e) {
      debugPrint('Error saving goal completion status: $e');
    }
  }

  void _updateAllProgress() {
    for (int i = 0; i < mainGoals.length; i++) {
      _updateGoalProgress(i);
    }
  }

  void _updateGoalProgress(int mainGoalIndex) {
    setState(() {
      final totalGoals = subGoals[mainGoalIndex].length + customGoals[mainGoalIndex].length;
      if (totalGoals > 0) {
        final completedGoals = goalCompletionStatus[mainGoalIndex]
            .where((completed) => completed)
            .length;
        goalProgress[mainGoalIndex] = ((completedGoals / totalGoals) * 100).toInt();
      } else {
        goalProgress[mainGoalIndex] = 0;
      }
    });
  }

  void _refreshLastWeight() {
    setState(() {
      _lastWeightVersion++;
    });
  }

  Future<void> _checkWeeklyGoalStatus() async {
    try {
      final lastUpdate = await _firebaseHelper.getLastWeightUpdate();
      if (lastUpdate != null) {
        final now = DateTime.now();
        final difference = now.difference(lastUpdate);
        setState(() {
          _weeklyGoalReached = difference.inDays < 7;
        });
      }
    } catch (e) {
      debugPrint('Error checking weekly goal status: $e');
    }
  }

  void _toggleGoalCompletion(int mainGoalIndex, int goalIndex) async {
    if (mainGoalIndex >= goalCompletionStatus.length || 
        goalIndex >= goalCompletionStatus[mainGoalIndex].length) {
      debugPrint('Invalid goal index: [$mainGoalIndex][$goalIndex]');
      return;
    }

    // If this is a weight loss goal, update the profile data
    if (mainGoalIndex == 0 && goalIndex == 0) { // Weight loss goal
      if (_weeklyGoalReached) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have already reached your weekly goal!'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      try {
        // Set the completion status to true before updating
        setState(() {
          goalCompletionStatus[mainGoalIndex][goalIndex] = true;
          _weeklyWeightGoalCompleted = true;
        });

        // Get current weight
        final currentWeight = await _firebaseHelper.getCurrentWeight();
        if (currentWeight == null) return;

        // Calculate new weight based on target
        double? targetWeight = double.tryParse(_weeklyWeightLossTarget ?? '0');
        if (targetWeight == null) return;

        // Calculate new weight
        final newWeight = currentWeight - targetWeight;

        // Update the weight and profile
        await _firebaseHelper.updateWeightAndProfile(newWeight, _weeklyWeightLossTarget);
        
        // Reset the checkbox state after updating
        if (mounted) {
          setState(() {
            _weeklyWeightGoalCompleted = false;
            goalCompletionStatus[mainGoalIndex][goalIndex] = false;
            _weeklyGoalReached = true;
          });
        }

        // Force reload the data
        await _loadData();
        await _loadWeightTarget();
        
        // Refresh the last weight display
        _refreshLastWeight();

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Weight updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error updating weight goal completion: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update weight. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // For non-weight goals, just toggle the completion status
      setState(() {
        goalCompletionStatus[mainGoalIndex][goalIndex] =
            !goalCompletionStatus[mainGoalIndex][goalIndex];
        _updateGoalProgress(mainGoalIndex);
      });
    }

    await _saveGoalCompletionStatus();
  }

  void _addCustomGoal(int mainGoalIndex, String newGoal) async {
    if (newGoal.isEmpty) return;
    
    try {
      // First add to Firebase
      await _firebaseHelper.addCustomGoal(mainGoals[mainGoalIndex], newGoal);
      
      // Then update local state
      setState(() {
        customGoals[mainGoalIndex].add(newGoal);
        goalCompletionStatus[mainGoalIndex].add(false);
        _updateGoalProgress(mainGoalIndex);
        _saveGoalCompletionStatus();
      });
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Goal added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding custom goal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add goal. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deleteCustomGoal(int mainGoalIndex, int goalIndex) async {
    try {
      final goals = await _firebaseHelper.getCustomGoals();
      final customGoalIndex = goalIndex - subGoals[mainGoalIndex].length;
      
      if (customGoalIndex >= 0 && customGoalIndex < customGoals[mainGoalIndex].length) {
        final goalToDelete = goals.firstWhere(
          (g) => g['mainGoal'] == mainGoals[mainGoalIndex] && 
                 g['customGoal'] == customGoals[mainGoalIndex][customGoalIndex]
        );
        
        await _firebaseHelper.deleteGoal(goalToDelete['id'] as String);
        
        setState(() {
          customGoals[mainGoalIndex].removeAt(customGoalIndex);
          goalCompletionStatus[mainGoalIndex].removeAt(goalIndex);
          _updateGoalProgress(mainGoalIndex);
          _saveGoalCompletionStatus();
        });
      }
    } catch (e) {
      debugPrint('Error deleting custom goal: $e');
    }
  }

  void _setWeeklyWeightLossTarget(String target) async {
    if (target.isEmpty) return;
    
    try {
      await _firebaseHelper.setWeightTarget(target);
      setState(() {
        _weeklyWeightLossTarget = target;
        _weeklyWeightGoalCompleted = false;
        _updateGoalProgress(0);
      });
    } catch (e) {
      debugPrint('Error setting weight target: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text('Goals'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
          ),
        ],
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
          }
          else if (index == 3) {
            Navigator.pushNamed(context, FriendsPage.routeName);
          }
          else if (index == 4) {
            Navigator.pushNamed(context, ProfilePage.routeName);
          }
        },
      ),
      body: Container(
        color: Colors.white,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _buildProgressChart(),
            const SizedBox(height: 20),
            ...List.generate(mainGoals.length, (index) {
              return Column(
                children: [
                  _buildMainGoalCard(index),
                  if (_expandedIndex == index) ...[
                    _buildExpandedContent(index),
                  ],
                ],
              );
            }),
            // Add extra padding at the bottom to ensure content is visible above the bottom navigation bar
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressChart() {
    return GestureDetector(
      onTap: _showProgressDetails,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.blue),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          children: [
            const Text(
              'Overall Progress',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            CircularProgressIndicator(
              value: goalProgress.reduce((a, b) => a + b) / (mainGoals.length * 100),
              strokeWidth: 10,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 10),
            Text(
              '${(goalProgress.reduce((a, b) => a + b) / mainGoals.length).toStringAsFixed(1)}% Completed',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainGoalCard(int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        title: Text(
          mainGoals[index],
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        trailing: Icon(
          _expandedIndex == index ? Icons.expand_less : Icons.expand_more,
        ),
        onExpansionChanged: (expanded) {
          setState(() {
            _expandedIndex = expanded ? index : null;
          });
        },
      ),
    );
  }

  Widget _buildExpandedContent(int index) {
    return Column(
      children: [
        if (index == 0) _buildWeightLossGoal(),
        if (index != 0) ...[
          _buildSubGoalsSection(index),
          _buildCustomGoalsSection(index),
        ],
      ],
    );
  }

  Widget _buildWeightLossGoal() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _weightTargetController,
                        decoration: InputDecoration(
                          labelText: 'Weekly Weight Loss Target (lbs)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          if (value.isNotEmpty) {
                            _setWeeklyWeightLossTarget(value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (_weeklyWeightLossTarget != null)
                      Checkbox(
                        value: _weeklyWeightGoalCompleted,
                        onChanged: _weeklyGoalReached ? null : (bool? value) {
                          setState(() {
                            _weeklyWeightGoalCompleted = value ?? false;
                          });
                          _toggleGoalCompletion(0, 0);
                        },
                      ),
                  ],
                ),
                if (_weeklyWeightLossTarget != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Target: $_weeklyWeightLossTarget lbs per week',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_weeklyGoalReached) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.info_outline, 
                                color: Colors.orange,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'You have already reached your weekly goal!',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Add Last Updated Weight Card
        Card(
          key: _lastWeightKey,
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Last Updated Weight',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                FutureBuilder<Map<String, dynamic>>(
                  future: Future.value(_lastWeightVersion).then((_) => _firebaseHelper.getLastAttributes()),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      final data = snapshot.data!;
                      final weight = data['weight']?.toString() ?? 'N/A';
                      final relativeTime = data['relativeTime']?.toString() ?? '';
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$weight lbs',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (relativeTime.isNotEmpty)
                                Text(
                                  relativeTime,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          FutureBuilder<List<Map<String, dynamic>>>(
                            future: _firebaseHelper.getWeightHistory(),
                            builder: (context, historySnapshot) {
                              if (historySnapshot.hasData && historySnapshot.data!.isNotEmpty) {
                                final history = historySnapshot.data!;
                                final latestChange = history.first;
                                final change = latestChange['change'] as double;
                                final isWeightLoss = change < 0;
                                
                                return Row(
                                  children: [
                                    Icon(
                                      isWeightLoss ? Icons.trending_down : Icons.trending_up,
                                      color: isWeightLoss ? Colors.green : Colors.red,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${isWeightLoss ? 'Lost' : 'Gained'} ${change.abs().toStringAsFixed(1)} lbs',
                                      style: TextStyle(
                                        color: isWeightLoss ? Colors.green : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      );
                    }
                    return const Text(
                      'No weight data available',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubGoalsSection(int index) {
    return Column(
      children: [
        ...subGoals[index].asMap().entries.map((entry) {
          final goalIndex = entry.key;
          return _buildGoalItem(
            index,
            goalIndex,
            entry.value,
            goalCompletionStatus[index].length > goalIndex 
              ? goalCompletionStatus[index][goalIndex]
              : false,
          );
        }),
      ],
    );
  }

  Widget _buildCustomGoalsSection(int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Custom Goals',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (customGoals[index].isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'No custom goals yet. Add one below!',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ),
        ...customGoals[index].asMap().entries.map((entry) {
          final goalIndex = entry.key + subGoals[index].length;
          return Dismissible(
            key: Key('custom_${index}_${entry.key}'),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (direction) {
              _deleteCustomGoal(index, goalIndex);
            },
            child: _buildGoalItem(
              index,
              goalIndex,
              entry.value,
              goalCompletionStatus[index].length > goalIndex 
                ? goalCompletionStatus[index][goalIndex]
                : false,
            ),
          );
        }),
        const SizedBox(height: 10),
        Center(
          child: ElevatedButton.icon(
            onPressed: () => _showCustomGoalDialog(context, index),
            icon: const Icon(Icons.add),
            label: const Text('Add Custom Goal'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildGoalItem(int mainGoalIndex, int goalIndex, String goal, bool isCompleted) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        title: Text(
          goal,
          style: TextStyle(
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            color: isCompleted ? Colors.grey : null,
          ),
        ),
        trailing: Checkbox(
          value: isCompleted,
          onChanged: (bool? value) {
            _toggleGoalCompletion(mainGoalIndex, goalIndex);
          },
        ),
        onTap: () {
          _toggleGoalCompletion(mainGoalIndex, goalIndex);
        },
      ),
    );
  }

  Future<void> _showProgressDetails() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Progress Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: mainGoals.map((goal) => ListTile(
            title: Text(goal),
            trailing: Text('${goalProgress[mainGoals.indexOf(goal)]}%'),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCustomGoalDialog(BuildContext context, int mainIndex) async {
    final controller = TextEditingController();
    
    final newGoal = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Custom Goal'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Goal description',
            hintText: 'e.g. Run 3 times this week',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(context, controller.text);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (newGoal != null && newGoal.isNotEmpty) {
      _addCustomGoal(mainIndex, newGoal);
    }
  }

  Future<void> _showHelpDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help'),
        content: const Text(
          '1. Tap on a goal to expand it and view sub-goals\n'
          '2. Check completed goals to track progress\n'
          '3. Add custom goals for personal targets\n'
          '4. Set weekly weight loss targets in the Weight section\n'
          '5. Progress chart shows your overall completion',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}