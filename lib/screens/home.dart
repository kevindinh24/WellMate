import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'goals/goals.dart';
import 'profile.dart';
import 'character_select.dart';
import 'habits.dart';
import 'friends.dart';
import 'package:intl/intl.dart';
import '../firebase_helper.dart';

class ConversationStep {
  String message;
  final List<String> responses;
  final List<int> nextStep;
  final bool isSummary;
  
  ConversationStep({
    required this.message,
    required this.responses,
    required this.nextStep,
    this.isSummary = false,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.currentIndex = 2});
  static const String routeName = '/home';
  final int currentIndex;

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _fadeController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _fadeAnimation;
  final FirebaseHelper _firebaseHelper = FirebaseHelper();

  // Conversation state
  int _currentMessageIndex = 0;
  int _currentResponseIndex = -1;
  bool _isProcessing = false;
  bool _isNavigating = false;

  // Character data
  final List<String> characters = [
    'panda.png',
    'lion.png',
    'pig.png',
    'monkey.png',
    'dino.png',
    'deer.png'
  ];

  // Messages with pre-defined responses
  final List<ConversationStep> conversationFlow = [
    ConversationStep(
      message: "Hi! How can I help you today? 😊",
      responses: ["I need motivation!", "Help me set goals", "Show me my progress"],
      nextStep: [1, 2, 3],
    ),
    ConversationStep(
      message: "Here's a motivational quote to keep you going: 'The only bad workout is the one that didn't happen!' 💪",
      responses: ["Thanks!", "Show me more options"],
      nextStep: [0, 0],
    ),
    ConversationStep(
      message: "Let's set some goals! What would you like to focus on?",
      responses: ["Set a step goal", "Set a water goal", "Set a calorie goal"],
      nextStep: [4, 4, 4],  // All lead to the goals confirmation
    ),
    ConversationStep(
      message: "Calculating your progress...",
      isSummary: true,
      responses: [],  // No buttons for summary
      nextStep: [],  // No next steps needed
    ),
    ConversationStep(
      message: "Let's set up your goals! I'll take you to the goals page where you can set your targets.",
      responses: ["Go to Goals", "Not now"],
      nextStep: [0, 0],  // Both options return to start, but "Go to Goals" will navigate
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    // Bounce animation controller
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _bounceAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(
        parent: _bounceController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Fade animation controller
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeInOut,
      ),
    );
    
    _bounceController.repeat(reverse: true);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _handleResponse(int index) async {
    if (_isProcessing || _isNavigating) return;
    
    setState(() {
      _isProcessing = true;
      _currentResponseIndex = index;
    });

    try {
      // Fade out current message
      await _fadeController.reverse();
      
      final currentStep = conversationFlow[_currentMessageIndex];
      if (index >= currentStep.nextStep.length) {
        throw Exception('Invalid response index');
      }
      
      final nextStep = currentStep.nextStep[index];
      if (nextStep >= conversationFlow.length) {
        throw Exception('Invalid next step index');
      }
      
      // If we're going to show the summary, update it first
      if (nextStep == 3) {
        await _updateProgressSummary();
      }
      
      // If we're on the goals confirmation step and user wants to go to goals
      if (_currentMessageIndex == 4 && index == 0) {
        if (mounted) {
          Navigator.pushNamed(context, GoalsWidget.routeName);
          setState(() {
            _isProcessing = false;
            _currentResponseIndex = -1;
            _currentMessageIndex = 0;  // Reset to start after navigation
          });
          return;
        }
      }
      
      // Add a small delay for better UX
      await Future.delayed(const Duration(milliseconds: 150));
      
      if (mounted) {
        setState(() {
          _currentMessageIndex = nextStep;
          _currentResponseIndex = -1;
          _isProcessing = false;
        });
        
        // Fade in new message
        _fadeController.forward();
      }
    } catch (e) {
      print('Error handling response: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _currentResponseIndex = -1;
          _currentMessageIndex = 0;  // Reset to start on error
        });
        _fadeController.forward();
      }
    }
  }

  Future<void> _updateProgressSummary() async {
    try {
      // Get all data in parallel
      final results = await Future.wait([
        _firebaseHelper.getTodayActivity(),
        _firebaseHelper.calculateRemainingCalories(),
        _firebaseHelper.calculateCaloriesFromWeightLoss(),
      ]);
      
      final activityData = results[0] as Map<String, dynamic>;
      final calorieData = results[1] as Map<String, dynamic>;
      final weightData = results[2] as Map<String, dynamic>;
      
      String summaryMessage = "Here's your progress summary:\n\n";
      
      // Today's progress
      summaryMessage += "Today's Progress:\n";
      
      // Safely handle activity data
      if (activityData != null) {
        final caloriesBurned = activityData['caloriesBurned'] ?? 0;
        summaryMessage += "• Calories burned: ${caloriesBurned.toStringAsFixed(0)}\n";
      } else {
        summaryMessage += "• Calories burned: 0\n";
      }
      
      // Safely handle calorie data
      if (calorieData != null) {
        final consumed = calorieData['consumed'] ?? 0;
        final remaining = calorieData['remaining'] ?? 0;
        summaryMessage += "• Calories consumed: ${consumed.toStringAsFixed(0)}\n";
        summaryMessage += "• Remaining calories: ${remaining.toStringAsFixed(0)}\n\n";
      } else {
        summaryMessage += "• Calories consumed: 0\n";
        summaryMessage += "• Remaining calories: 0\n\n";
      }
      
      // Weekly progress
      if (weightData != null) {
        if (weightData.containsKey('error')) {
          summaryMessage += "Note: ${weightData['error']}\n";
        } else if (weightData.containsKey('message')) {
          summaryMessage += weightData['message'] as String;
        } else {
          final daysTracked = weightData['daysTracked'] ?? 0;
          final weightLost = weightData['weeklyWeightLoss'] ?? 0.0;
          final totalCaloriesBurned = weightData['weeklyCalories'] ?? 0;
          
          if (daysTracked > 0) {
            summaryMessage += "Progress over $daysTracked days:\n";
            summaryMessage += "• Weight lost: ${weightLost.toStringAsFixed(1)} pounds\n";
            summaryMessage += "• Total calories burned: ${totalCaloriesBurned.toStringAsFixed(0)}";
          } else {
            summaryMessage += "No weight tracking data available yet. Start tracking your weight to see your progress!";
          }
        }
      } else {
        summaryMessage += "No weight tracking data available yet. Start tracking your weight to see your progress!";
      }
      
      if (mounted) {
        setState(() {
          conversationFlow[3].message = summaryMessage;
        });
      }
    } catch (e) {
      print('Error updating progress summary: $e');
      if (mounted) {
        setState(() {
          conversationFlow[3].message = "Oops! There was an error getting your progress data. "
              "Please try again later.";
        });
      }
    }
  }

  void _restartConversation() {
    if (_isProcessing || _isNavigating) return;
    
    _bounceController.stop();
    _bounceController.reset();
    _fadeController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _currentMessageIndex = 0;
          _currentResponseIndex = -1;
        });
        _bounceController.repeat(reverse: true);
        _fadeController.forward();
      }
    });
  }

  void _handleNavigation(int index) {
    if (_isNavigating) return;
    
    setState(() {
      _isNavigating = true;
    });

    try {
      switch (index) {
        case 0:
          Navigator.pushNamed(context, GoalsWidget.routeName);
          break;
        case 1:
          Navigator.pushNamed(context, HabitsPage.routeName);
          break;
        case 2:
          Navigator.pushNamed(context, HomePage.routeName);
          break;
        case 3:
          Navigator.pushNamed(context, FriendsPage.routeName);
          break;
        case 4:
          Navigator.pushNamed(context, ProfilePage.routeName);
          break;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isNavigating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = conversationFlow[_currentMessageIndex];
    
    return WillPopScope(
      onWillPop: () async {
        if (_isProcessing || _isNavigating) return false;
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          title: const Text("Home"),
          centerTitle: true,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _restartConversation,
              tooltip: 'Restart Conversation',
            ),
          ],
        ),
        body: Stack(
          children: [
            // Character with bounce animation
            AnimatedBuilder(
              animation: _bounceController,
              builder: (context, child) {
                return Positioned(
                  left: 0,
                  right: 0,
                  top: 100,
                  child: Center(
                    child: Transform.translate(
                      offset: Offset(0, _bounceAnimation.value),
                      child: GestureDetector(
                        onTap: _isProcessing ? null : () => _handleResponse(0),
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(90.0),
                            child: Image.asset(
                              CharSel.chosenCharacter,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            
            // Character speech bubble with fade animation
            Positioned(
              top: currentStep.isSummary ? MediaQuery.of(context).size.height * 0.3 : 20,
              left: 20,
              right: 20,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildSpeechBubble(currentStep.message),
              ),
            ),
            
            // User response options (only show if there are responses)
            if (currentStep.responses.isNotEmpty)
              Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...currentStep.responses.map((response) => 
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: _buildResponseButton(
                          response,
                          currentStep.responses.indexOf(response),
                          isProcessing: _isProcessing || _isNavigating,
                        ),
                      ),
                    ).toList(),
                    const SizedBox(height: 20),
                    TextButton.icon(
                      onPressed: _isProcessing || _isNavigating ? null : _restartConversation,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Restart Conversation'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
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
              icon: Icon(CupertinoIcons.check_mark), 
              label: "Goals"
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.book), 
              label: "Habits"
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.home), 
              label: "Home"
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.person_2), 
              label: "Friends"
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.person), 
              label: "Profile"
            ),
          ],
          onTap: _handleNavigation,
        ),
      ),
    );
  }

  Widget _buildSpeechBubble(String text) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildResponseButton(String text, int index, {bool isProcessing = false}) {
    final isSelected = _currentResponseIndex == index;
    
    return GestureDetector(
      onTap: isProcessing ? null : () => _handleResponse(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: MediaQuery.of(context).size.width * 0.8,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
          border: Border.all(
            color: isSelected ? Colors.blue.shade300 : Colors.grey.shade200,
            width: 2,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.blue.shade700 : 
                   isProcessing ? Colors.grey : Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}