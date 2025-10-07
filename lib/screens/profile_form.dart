import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../firebase_helper.dart';

class ProfileForm extends StatefulWidget {
  static const String routeName = '/profile_form';

  const ProfileForm({super.key});

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final FirebaseHelper _firebaseHelper = FirebaseHelper();
  String? gender;
  String? age;
  String? weight;
  String? height;
  String? idealWeightKg;
  String? idealWeightLb;
  Map<String, dynamic>? lastAttributes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLastAttributes();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadLastAttributes();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadLastAttributes();
  }

  @override
  void didUpdateWidget(ProfileForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadLastAttributes();
  }

  Future<void> _loadLastAttributes() async {
    try {
      final attributes = await _firebaseHelper.getLastAttributes();
      if (mounted) {
        setState(() {
          lastAttributes = attributes;
          // Update the form fields if attributes exist
          if (attributes.isNotEmpty) {
            age = attributes['age']?.toString();
            weight = attributes['weight']?.toString();
            height = attributes['height']?.toString();
            gender = attributes['gender']?.toString();
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading last attributes: $e');
    }
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'attributes.db');
    return openDatabase(
      path,
      onCreate: (db, version) {
        db.execute(
          'CREATE TABLE profiles(id INTEGER PRIMARY KEY, age TEXT, weight TEXT, height TEXT, gender TEXT)',
        );
      },
      version: 1,
    );
  }

  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Future<void> _saveProfile(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      if (gender == null) {
        _showSnackBar(context, 'Please select a gender', isError: true);
        return;
      }

      _calculateIdealWeight();
      
      // Save to local database
      final db = await _initDatabase();
      await db.insert(
        'profiles',
        {'age': age, 'weight': weight, 'height': height, 'gender': gender},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Save to Firebase
      try {
        await _firebaseHelper.saveAttributes({
          'age': age,
          'weight': weight,
          'height': height,
          'gender': gender,
          'timestamp': DateTime.now().toIso8601String(),
        });
        
        if (!mounted) return;
        await _loadLastAttributes();
        
        _showSnackBar(context, 'Profile updated successfully!');
      } catch (e) {
        debugPrint('Error saving attributes to Firebase: $e');
        if (!mounted) return;
        _showSnackBar(context, 'Failed to save profile. Please try again.', isError: true);
      }
    }
  }

  void _calculateIdealWeight() {
    if (gender != null && height != null) {
      double? h = double.tryParse(height!);
      if (h != null) {
        double iwKg = (gender == 'male') ? 50 + 2.3 * (h - 60) : 45.5 + 2.3 * (h - 60);
        double iwLb = iwKg * 2.20462;
        idealWeightKg = '${iwKg.toStringAsFixed(2)} kg';
        idealWeightLb = '${iwLb.toStringAsFixed(2)} lb';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Form'),
        elevation: 2,
      ),
      body: Builder(
        builder: (BuildContext context) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Enter Your Information',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          _buildTextField('Age', (value) => age = value),
                          _buildTextField('Weight (lb)', (value) => weight = value),
                          _buildTextField('Height (in)', (value) => height = value),
                          const SizedBox(height: 10),
                          _buildGenderSelection(),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () => _saveProfile(context),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Save Profile',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (idealWeightKg != null && idealWeightLb != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Text(
                              'Your Ideal Weight',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '$idealWeightKg ($idealWeightLb)',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (lastAttributes != null && lastAttributes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Last Recorded Attributes',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (lastAttributes!['relativeTime'] != null)
                                  Text(
                                    lastAttributes!['relativeTime'],
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _buildAttributeRow('Age', lastAttributes!['age']),
                            _buildAttributeRow('Weight', '${lastAttributes!['weight']} lb'),
                            _buildAttributeRow('Height', '${lastAttributes!['height']} in'),
                            _buildAttributeRow('Gender', lastAttributes!['gender']),
                            if (lastAttributes!['lastWeightUpdate'] != null) ...[
                              const SizedBox(height: 10),
                              const Divider(),
                              const SizedBox(height: 10),
                              const Text(
                                'Weight Progress',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              FutureBuilder<List<Map<String, dynamic>>>(
                                future: _firebaseHelper.getWeightHistory(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                                    final history = snapshot.data!;
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
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField(String label, Function(String?) onSaved) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        keyboardType: TextInputType.number,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Enter $label';
          }
          if (label.contains('Age')) {
            final age = int.tryParse(value);
            if (age == null || age < 1 || age > 120) {
              return 'Enter a valid age (1-120)';
            }
          }
          if (label.contains('Weight')) {
            final weight = double.tryParse(value);
            if (weight == null || weight < 20 || weight > 500) {
              return 'Enter a valid weight (20-500 lbs)';
            }
          }
          if (label.contains('Height')) {
            final height = double.tryParse(value);
            if (height == null || height < 24 || height > 96) {
              return 'Enter a valid height (24-96 inches)';
            }
          }
          return null;
        },
        onSaved: onSaved,
      ),
    );
  }

  Widget _buildGenderSelection() {
    return Column(
      children: [
        const Text(
          'Select Gender:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        RadioListTile(
          title: const Text('Male'),
          value: 'male',
          groupValue: gender,
          onChanged: (value) => setState(() => gender = value),
        ),
        RadioListTile(
          title: const Text('Female'),
          value: 'female',
          groupValue: gender,
          onChanged: (value) => setState(() => gender = value),
        ),
      ],
    );
  }

  Widget _buildAttributeRow(String label, String value) {
    // Format the value based on the label
    String displayValue = value;
    if (label == 'Weight') {
      // Ensure the weight is displayed with one decimal place
      double? weightValue = double.tryParse(value.replaceAll(' lb', ''));
      if (weightValue != null) {
        displayValue = '${weightValue.toStringAsFixed(1)} lb';
      }
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            displayValue,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}




