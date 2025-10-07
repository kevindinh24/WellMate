import 'package:mobile_app/firebase_helper.dart';

class CalorieCalculator {
  final FirebaseHelper _firebaseHelper;

  CalorieCalculator(this._firebaseHelper);

  // Activity level multipliers
  static const Map<String, double> activityLevels = {
    'sedentary': 1.2,      // Little or no exercise
    'light': 1.375,        // Light exercise 1-3 days/week
    'moderate': 1.55,      // Moderate exercise 3-5 days/week
    'active': 1.725,       // Hard exercise 6-7 days/week
    'very_active': 1.9,    // Very hard exercise & physical job or training twice per day
  };

  // Calculate BMR using Mifflin-St Jeor Equation
  double calculateBMR(double weight, double height, int age, String gender) {
    // Convert weight from pounds to kg and height from inches to cm
    double weightKg = weight * 0.453592;
    double heightCm = height * 2.54;

    if (gender.toLowerCase() == 'male') {
      return (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5;
    } else {
      return (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
    }
  }

  // Calculate TDEE (Total Daily Energy Expenditure)
  double calculateTDEE(double bmr, String activityLevel) {
    return bmr * (activityLevels[activityLevel.toLowerCase()] ?? 1.2);
  }

  // Calculate daily calorie needs
  Future<Map<String, dynamic>> calculateDailyCalories() async {
    final profile = await _firebaseHelper.getUserProfile();
    if (profile == null) {
      return {
        'error': 'Profile not found',
        'bmr': 0.0,
        'tdee': 0.0,
        'calorieGoal': 0.0
      };
    }

    final weight = double.tryParse(profile['weight'] ?? '0') ?? 0;
    final height = double.tryParse(profile['height'] ?? '0') ?? 0;
    final age = int.tryParse(profile['age'] ?? '0') ?? 0;
    final gender = profile['gender'] ?? 'male';
    final activityLevel = profile['activityLevel'] ?? 'sedentary';

    final bmr = calculateBMR(weight, height, age, gender);
    final tdee = calculateTDEE(bmr, activityLevel);

    // Calculate calorie goal (assuming weight loss goal)
    // Subtract 500 calories for 1 pound per week weight loss
    final calorieGoal = tdee - 500;

    return {
      'bmr': bmr,
      'tdee': tdee,
      'calorieGoal': calorieGoal,
      'activityLevel': activityLevel
    };
  }

  // Calculate remaining calories for the day
  Future<Map<String, dynamic>> calculateRemainingCalories() async {
    final dailyCalories = await calculateDailyCalories();
    if (dailyCalories.containsKey('error')) {
      return dailyCalories;
    }

    // TODO: Get consumed calories from food tracking
    final consumedCalories = 0.0; // This should be fetched from food tracking data

    final remainingCalories = dailyCalories['calorieGoal'] - consumedCalories;

    return {
      'dailyGoal': dailyCalories['calorieGoal'],
      'consumed': consumedCalories,
      'remaining': remainingCalories,
      'tdee': dailyCalories['tdee'],
      'activityLevel': dailyCalories['activityLevel']
    };
  }
} 