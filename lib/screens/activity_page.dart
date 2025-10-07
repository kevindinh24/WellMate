import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../firebase_helper.dart';

// Extension for comparing dates
extension DateTimeComparison on DateTime {
  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }
}

class ActivityPage extends StatefulWidget {
  static const String routeName = '/activity';
  static final FirebaseHelper _firebaseHelper = FirebaseHelper();

  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  Map<DateTime, Map<String, dynamic>> _monthlyCompletions = {};
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDay;
  Map<String, dynamic> _selectedDayTasks = {'completed': [], 'incomplete': []};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMonthlyData();
  }

  Future<void> _loadMonthlyData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final completions = await ActivityPage._firebaseHelper.getMonthlyCompletions(_focusedMonth);
      setState(() {
        _monthlyCompletions = completions;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading monthly data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDayTasks(DateTime date) async {
    try {
      final tasks = await ActivityPage._firebaseHelper.getDailyTasks(date);
      setState(() {
        _selectedDay = date;
        _selectedDayTasks = tasks;
      });
    } catch (e) {
      debugPrint('Error loading day tasks: $e');
    }
  }

  Future<void> _toggleTaskCompletion(String task, bool completed) async {
    if (_selectedDay == null) return;

    try {
      await ActivityPage._firebaseHelper.updateTaskCompletion(_selectedDay!, task, completed);
      
      // Reload the day's tasks and monthly data
      await _loadDayTasks(_selectedDay!);
      await _loadMonthlyData();
    } catch (e) {
      debugPrint('Error toggling task completion: $e');
    }
  }

  Color _getDayColor(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final completion = _monthlyCompletions[dateOnly];
    
    if (completion == null) {
      return Colors.grey.shade300; // No data
    }
    
    final isCompleted = completion['completed'] as bool? ?? false;
    return isCompleted ? Colors.green.shade400 : Colors.red.shade400;
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final firstDayWeekday = firstDayOfMonth.weekday % 7; // Convert to 0-6 (Sunday-Saturday)
    final daysInMonth = lastDayOfMonth.day;
    
    List<Widget> dayWidgets = [];
    
    // Add day labels
    const dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    for (String label in dayLabels) {
      dayWidgets.add(
        Container(
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      );
    }
    
    // Add empty spaces for days before the first day of month
    for (int i = 0; i < firstDayWeekday; i++) {
      dayWidgets.add(Container());
    }
    
    // Add days of the month
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
      final isSelected = _selectedDay != null && _selectedDay!.isSameDay(date);
      final isToday = DateTime.now().isSameDay(date);
      
      dayWidgets.add(
        GestureDetector(
          onTap: () => _loadDayTasks(date),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: _getDayColor(date),
              shape: BoxShape.circle,
              border: isSelected 
                ? Border.all(color: Colors.blue.shade700, width: 3)
                : isToday 
                  ? Border.all(color: Colors.orange.shade700, width: 2)
                  : null,
            ),
            child: Center(
              child: Text(
                day.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: isSelected ? 16 : 14,
                ),
              ),
            ),
          ),
        ),
      );
    }
    
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: dayWidgets,
    );
  }

  Widget _buildTaskList() {
    if (_selectedDay == null) {
      return const Center(
        child: Text(
          'Select a day to view tasks',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final completedTasks = _selectedDayTasks['completed'] as List<String>;
    final incompleteTasks = _selectedDayTasks['incomplete'] as List<String>;
    final allTasks = [...completedTasks, ...incompleteTasks];

    if (allTasks.isEmpty) {
      return const Center(
        child: Text(
          'No tasks for this day',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: allTasks.length,
      itemBuilder: (context, index) {
        final task = allTasks[index];
        final isCompleted = completedTasks.contains(task);
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: Checkbox(
              value: isCompleted,
              onChanged: (bool? value) {
                if (value != null) {
                  _toggleTaskCompletion(task, value);
                }
              },
              activeColor: Colors.green,
            ),
            title: Text(
              task,
              style: TextStyle(
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted ? Colors.grey.shade600 : Colors.black,
              ),
            ),
            trailing: Icon(
              isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isCompleted ? Colors.green : Colors.grey.shade400,
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildLegendItem(Colors.green.shade400, 'Completed'),
          _buildLegendItem(Colors.red.shade400, 'Incomplete'),
          _buildLegendItem(Colors.grey.shade300, 'No Data'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Calendar'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMonthlyData,
          ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // Month navigation
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        setState(() {
                          _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                        });
                        _loadMonthlyData();
                      },
                    ),
                    Text(
                      DateFormat('MMMM yyyy').format(_focusedMonth),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        setState(() {
                          _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                        });
                        _loadMonthlyData();
                      },
                    ),
                  ],
                ),
              ),
              
              // Calendar grid
              Container(
                padding: const EdgeInsets.all(8),
                child: _buildCalendarGrid(),
              ),
              
              // Legend
              _buildLegend(),
              
              // Selected day info
              if (_selectedDay != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Tasks for ${DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay!)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              
              // Task list
              Expanded(
                child: _buildTaskList(),
              ),
            ],
          ),
    );
  }
}