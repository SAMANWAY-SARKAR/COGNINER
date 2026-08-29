import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'database_helper.dart'; 
import 'score.dart'; 
import 'sync_service.dart'; 
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final ValueNotifier<double> textScaleNotifier = ValueNotifier(1.0);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  await NotificationService.instance.init();
  await NotificationService.instance.scheduleHourlyHydrationReminder();
  await VoiceAssistantService.instance.init();
  
  final dbHelper = DatabaseHelper.instance;
  await dbHelper.database; 
  
  final prefs = await SharedPreferences.getInstance();
  
  final isDark = prefs.getBool('isDarkMode') ?? false; 
  final isLarge = prefs.getBool('isLargeText') ?? false; 
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light; 
  textScaleNotifier.value = isLarge ? 1.2 : 1.0; 
  
  // Check if someone is logged in AND what their role is
  final String? loggedInUserId = prefs.getString('sqlite_user_id');
  final String? userRole = prefs.getString('user_role'); // 'patient' or 'caregiver'
  final bool isRegistered = loggedInUserId != null;

  SyncService().trySync();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('hi'), Locale('bn')], 
      path: 'assets/translations', 
      fallbackLocale: const Locale('en'), 
      child: DementiaCareApp(isRegistered: isRegistered, userRole: userRole), 
    ),
  );
}

class DementiaCareApp extends StatelessWidget {
  final bool isRegistered;
  final String? userRole;
  
  const DementiaCareApp({super.key, required this.isRegistered, this.userRole});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: textScaleNotifier,
      builder: (context, textScale, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (context, currentMode, _) {
            
            // Route Logic: Send unregistered users to Login instead of Registration
            Widget initialScreen;
            if (!isRegistered) {
              initialScreen = const LoginScreen(); // NEW DEFAULT
            } else if (userRole == 'caregiver') {
              initialScreen = const CaregiverDashboard();
            } else {
              initialScreen = const PatientDashboard();
            }

            return MaterialApp(
              title: 'Cognitive Care',
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale, 
              
              theme: ThemeData(
                brightness: Brightness.light,
                primarySwatch: Colors.teal,
                scaffoldBackgroundColor: Colors.teal.shade50,
              ),
              darkTheme: ThemeData(
                brightness: Brightness.dark,
                primarySwatch: Colors.teal,
                scaffoldBackgroundColor: Colors.grey.shade900,
              ),
              themeMode: currentMode,
              
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
                  child: child!,
                );
              },
              home: initialScreen,
            );
          },
        );
      },
    );
  }
}

//////////////////////////////////////////////////
//////////////////////////////////////////////////
///                                            ///
///             LOG IN SCREEN                  ///
///                                            ///
//////////////////////////////////////////////////
//////////////////////////////////////////////////

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController identifierController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;

  Future<void> _login() async {
    if (identifierController.text.trim().isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Email/Phone and Password.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => isLoading = true);

    // Call the SQLite verification function
    final result = await DatabaseHelper.instance.verifyLogin(
      identifierController.text.trim(),
      passwordController.text,
    );

    if (result == null) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid credentials. Please try again.'), backgroundColor: Colors.red),
      );
      return;
    }

    // Login Success! Save data based on role
    final role = result['role'];
    final data = result['data'];
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('user_role', role);
    await prefs.setString('user_name', data['name']);
    await prefs.setString('user_email', data['email'] ?? '');
    await prefs.setString('user_phone', data['phone'] ?? '');

    if (role == 'patient') {
      await prefs.setString('sqlite_user_id', data['user_id']);
      SyncService().trySync();
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PatientDashboard()));
      }
    } else {
      await prefs.setString('sqlite_user_id', data['caregiver_id']);
      await prefs.setString('user_institution', data['institution'] ?? '');
      SyncService().trySync();
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CaregiverDashboard()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.psychology, size: 80, color: Colors.teal),
              const SizedBox(height: 20),
              const Text(
                'Welcome Back',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.teal),
              ),
              const SizedBox(height: 8),
              const Text('Log in to continue to Cognitive Care'),
              const SizedBox(height: 40),

              TextField(
                controller: identifierController,
                decoration: InputDecoration(
                  labelText: 'Email or Phone Number',
                  prefixIcon: const Icon(Icons.person, color: Colors.teal),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock, color: Colors.teal),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 30),

              isLoading 
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _login,
                      child: const Text('Log In', style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),
              
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RegistrationScreen()));
                },
                child: const Text('Don\'t have an account? Sign Up', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }
}


//////////////////////////////////////////////////
//////////////////////////////////////////////////
///                                            ///
///             REGISTRATION                   ///
///                                            ///
//////////////////////////////////////////////////
//////////////////////////////////////////////////

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  String _selectedRole = 'patient'; 

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController institutionController = TextEditingController();
  
  // --- NEW: PASSWORD CONTROLLERS ---
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  Uint8List? _profileImageBytes;
  String? _base64Image;

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      Uint8List imageBytes = await image.readAsBytes();
      setState(() {
        _profileImageBytes = imageBytes;
        _base64Image = base64Encode(imageBytes);
      });
    }
  }

  Future<void> _saveAndLogin() async {
    final emailRegex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
    final phoneRegex = RegExp(r"^[6-9]\d{9}$");

    if (nameController.text.trim().isEmpty || emailController.text.trim().isEmpty || phoneController.text.trim().isEmpty) {
      _showError('Name, Email, and Phone are required.');
      return;
    }
    
    if (!emailRegex.hasMatch(emailController.text.trim())) {
      _showError('Please enter a valid email address.');
      return;
    }
    
    if (!phoneRegex.hasMatch(phoneController.text.trim())) {
      _showError('Please enter a valid 10-digit Indian phone number.');
      return;
    }

    // --- NEW: PASSWORD VALIDATION ---
    if (passwordController.text.isEmpty || passwordController.text.length < 6) {
      _showError('Password must be at least 6 characters long.');
      return;
    }
    if (passwordController.text != confirmPasswordController.text) {
      _showError('Passwords do not match.');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    int lastId = prefs.getInt('global_last_registration_number') ?? 2500000;
    int newRegistrationNumber = lastId + 1;
    await prefs.setInt('global_last_registration_number', newRegistrationNumber);
    await prefs.setString('user_registration_number', newRegistrationNumber.toString());
    await prefs.setString('user_role', _selectedRole); 

    final dbHelper = DatabaseHelper.instance;
    String generatedUserId = "";

    if (_selectedRole == 'patient') {
      final int? parsedAge = int.tryParse(ageController.text.trim());
      if (parsedAge == null || parsedAge <= 0 || parsedAge > 130) {
        _showError('Please enter a valid age for the patient.');
        return;
      }
      generatedUserId = await dbHelper.insertPatient(
        registrationNumber: newRegistrationNumber.toString(), // NEW: Save to DB
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        phone: phoneController.text.trim(),
        password: passwordController.text, 
        age: parsedAge,
        photo: _base64Image, // NEW: Save to DB
      );
    } else {
      if (institutionController.text.trim().isEmpty) {
        _showError('Please enter your Institution/NGO/Hospital.');
        return;
      }
      generatedUserId = await dbHelper.insertCaregiver(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        phone: phoneController.text.trim(),
        password: passwordController.text, // Passed to DB
        institution: institutionController.text.trim(),
      );
    }

    await prefs.setString('sqlite_user_id', generatedUserId); 
    await prefs.setString('user_name', nameController.text.trim());
    await prefs.setString('user_email', emailController.text.trim());
    await prefs.setString('user_phone', phoneController.text.trim());
    await prefs.setString('user_address', addressController.text.trim());
    if (_selectedRole == 'caregiver') {
      await prefs.setString('user_institution', institutionController.text.trim());
    }
    
    if (_base64Image != null) {
      await prefs.setString('user_photo', _base64Image!);
    }

    SyncService().trySync();

    if (mounted) {
      if (_selectedRole == 'caregiver') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CaregiverDashboard()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PatientDashboard()));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration Successful!'), backgroundColor: Colors.green),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text(
              'Welcome to Cognitive Care',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal),
            ),
            const SizedBox(height: 8),
            const Text('Who are you creating this account for?'),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedRole = 'patient'),
                    child: Card(
                      color: _selectedRole == 'patient' ? Colors.teal : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            Icon(Icons.elderly, size: 40, color: _selectedRole == 'patient' ? Colors.white : Colors.teal),
                            const SizedBox(height: 8),
                            Text('Patient', style: TextStyle(fontWeight: FontWeight.bold, color: _selectedRole == 'patient' ? Colors.white : Colors.teal)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedRole = 'caregiver'),
                    child: Card(
                      color: _selectedRole == 'caregiver' ? Colors.teal : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            Icon(Icons.medical_services, size: 40, color: _selectedRole == 'caregiver' ? Colors.white : Colors.teal),
                            const SizedBox(height: 8),
                            Text('Caregiver', style: TextStyle(fontWeight: FontWeight.bold, color: _selectedRole == 'caregiver' ? Colors.white : Colors.teal)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 30),

            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.teal.shade100,
                    backgroundImage: _profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null,
                    child: _profileImageBytes == null ? const Icon(Icons.add_a_photo, size: 40, color: Colors.teal) : null,
                  ),
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.teal,
                    child: Icon(Icons.edit, size: 18, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            _buildTextField(nameController, 'Full Name', Icons.person),
            const SizedBox(height: 16),
            
            if (_selectedRole == 'patient') ...[
              _buildTextField(ageController, 'Patient Age', Icons.cake, keyboardType: TextInputType.number),
              const SizedBox(height: 16),
            ],
            if (_selectedRole == 'caregiver') ...[
              _buildTextField(institutionController, 'Institution / NGO / Hospital', Icons.local_hospital),
              const SizedBox(height: 16),
            ],

            _buildTextField(emailController, 'Email ID', Icons.email, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16),
            _buildTextField(phoneController, 'Phone Number', Icons.phone, keyboardType: TextInputType.phone),
            const SizedBox(height: 16),
            _buildTextField(addressController, 'Address', Icons.home, maxLines: 3),
            const SizedBox(height: 16),
            
            // --- NEW: PASSWORD FIELDS ---
            _buildTextField(passwordController, 'Password', Icons.lock, obscureText: true),
            const SizedBox(height: 16),
            _buildTextField(confirmPasswordController, 'Confirm Password', Icons.lock_outline, obscureText: true),
            
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _saveAndLogin,
                child: const Text('Save & Continue', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
            
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
              child: const Text('Already have an account? Log In', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1, TextInputType? keyboardType, bool obscureText = false}) {
    return TextField(
      controller: controller,
      maxLines: obscureText ? 1 : maxLines,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.teal),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.teal, width: 2),
        ),
      ),
    );
  }
}


//////////////////////////////////////////////////
//////////////////////////////////////////////////
///                                            ///
///        PATEINT DASHBOARD                   ///
///                                            ///
//////////////////////////////////////////////////
//////////////////////////////////////////////////

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  int totalStreakDays = 0; 
  int cumulativeScore = 0; 
  int totalDailyScore = 0;
  
  int dailyGameScore = 0; 
  int routinesCheckedToday = 0; 
  int routinePoints = 0; 

  String userName = "Loading...";
  String userId = ""; 

  List<bool> last7DaysStatus = [false, false, false, false, false, false, false];
  List<String> dayLabels = ['-', '-', '-', '-', '-', '-', '-']; 

  // Voice Assistant States
  bool isListening = false;
  String recognizedText = "";

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final prefs = await SharedPreferences.getInstance();
    String fetchedUserName = prefs.getString('user_name') ?? "User"; 
    String fetchedUserId = prefs.getString('sqlite_user_id') ?? ""; 

    DateTime now = DateTime.now();
    String todayDateString = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    
    List<String> activeDates = [];
    String? activeDatesJson = prefs.getString('active_dates');
    if (activeDatesJson != null) {
      activeDates = List<String>.from(jsonDecode(activeDatesJson));
    }
    
    if (!activeDates.contains(todayDateString)) {
      activeDates.add(todayDateString);
      if (activeDates.length > 30) activeDates.removeAt(0); 
      await prefs.setString('active_dates', jsonEncode(activeDates));
    }

    List<bool> new7DaysStatus = [];
    List<String> newDayLabels = [];
    List<String> weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    
    for (int i = 6; i >= 0; i--) {
      DateTime pastDay = now.subtract(Duration(days: i));
      String pastDayStr = "${pastDay.year}-${pastDay.month.toString().padLeft(2, '0')}-${pastDay.day.toString().padLeft(2, '0')}";
      
      new7DaysStatus.add(activeDates.contains(pastDayStr));
      newDayLabels.add(weekDays[pastDay.weekday - 1]);
    }

    int routinesDone = 0;
    String? savedRoutineDate = prefs.getString('routine_date');
    String? savedTasksJson = prefs.getString('routine_tasks');
    
    if (savedRoutineDate == todayDateString && savedTasksJson != null) {
      List<dynamic> decodedList = jsonDecode(savedTasksJson);
      for (var item in decodedList) {
        if (item['isCompleted'] == true) {
          routinesDone++;
        }
      }
    }

    int dbCumulative = 0;
    int dbDaily = 0;
    int dbStreak = 0;

    if (fetchedUserId.isNotEmpty) {
      final dbHelper = DatabaseHelper.instance;
      final patients = await dbHelper.getAllPatients();
      
      final patient = patients.firstWhere(
        (p) => p['user_id'] == fetchedUserId,
        orElse: () => {},
      );

      if (patient.isNotEmpty) {
        dbCumulative = patient['cumulative_score'] as int? ?? 0;
        dbDaily = patient['daily_score'] as int? ?? 0;
        dbStreak = patient['current_streak'] as int? ?? 0;
      }
    }

    setState(() {
      userName = fetchedUserName;
      userId = fetchedUserId;
      last7DaysStatus = new7DaysStatus;
      dayLabels = newDayLabels;
      totalStreakDays = dbStreak;
      cumulativeScore = dbCumulative;
      totalDailyScore = dbDaily;
      routinesCheckedToday = routinesDone;
      routinePoints = routinesDone * 20;
      dailyGameScore = totalDailyScore - routinePoints;
      if (dailyGameScore < 0) dailyGameScore = 0; 
    });
  }

  // --- NEW: VOICE ASSISTANT LOGIC ---
  void _listenForVoiceCommand() async {
    if (isListening) {
      await VoiceAssistantService.instance.stopListening();
      setState(() => isListening = false);
      return;
    }

    await VoiceAssistantService.instance.startListening(
      onListeningStatusChanged: (status) {
        setState(() => isListening = status);
      },
      onResult: (text) {
        setState(() => recognizedText = text);
        if (!isListening) { 
          // Process when listening stops naturally
          _handleVoiceIntent(text);
        }
      },
    );
  }

  void _handleVoiceIntent(String text) async {
    if (text.isEmpty) return;

    final intent = VoiceAssistantService.instance.parseIntent(text);

    switch (intent) {
      case 'start_memory_game':
        await VoiceAssistantService.instance.speak("Starting memory game.");
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MemoryGameScreen()))
            .then((_) => _loadDashboardData());
        break;

      case 'start_pattern_game':
        await VoiceAssistantService.instance.speak("Starting pattern game.");
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PatternRecognitionScreen()))
            .then((_) => _loadDashboardData());
        break;

      case 'start_task_sequencer':
        await VoiceAssistantService.instance.speak("Starting daily task sequencer.");
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyTaskSequencerGame()))
            .then((_) => _loadDashboardData());
        break;

      case 'open_music':
        await VoiceAssistantService.instance.speak("Opening music therapy.");
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MusicLibraryScreen()));
        break;

      case 'open_routine':
        await VoiceAssistantService.instance.speak("Opening daily routine.");
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyRoutineScreen()))
            .then((_) => _loadDashboardData());
        break;

      case 'open_family':
        await VoiceAssistantService.instance.speak("Opening family gallery.");
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => const FamilyScreen()));
        break;

      default:
        await VoiceAssistantService.instance.speak("I didn't quite catch that. Try saying 'Start a game' or 'Play music'.");
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, $userName'),
        centerTitle: true,
        elevation: 0,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.teal),
              child: Text('Menu', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(leading: const Icon(Icons.person), title: const Text('Account'), onTap: () {Navigator.pop(context); 
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen()));}),
            ListTile(leading: const Icon(Icons.language), title: const Text('Language Settings'), onTap: () {Navigator.pop(context); 
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LanguageScreen()));}),
            ListTile(leading: const Icon(Icons.settings), title: const Text('Settings'), onTap: () {Navigator.pop(context); 
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));}),
            ListTile(leading: const Icon(Icons.contact_support), title: const Text('Contact Us'), onTap: () {Navigator.pop(context); 
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactScreen()));}),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Voice Feedback Display
            if (recognizedText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  '"$recognizedText"',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic, color: Colors.teal.shade700),
                ),
              ),

            // Streak Tracker Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Your Streak', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
                        Row(
                          children: [
                            const Icon(Icons.local_fire_department, color: Colors.orange, size: 28),
                            const SizedBox(width: 5),
                            Text('$totalStreakDays Days', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(7, (index) {
                        bool isSuccess = last7DaysStatus[index];
                        bool isToday = index == 6; 
                        return Column(
                          children: [
                            Text(isToday ? 'Today' : dayLabels[index], style: TextStyle(fontSize: 12, fontWeight: isToday ? FontWeight.bold : FontWeight.normal, color: isToday ? Colors.teal : Colors.grey)),
                            const SizedBox(height: 5),
                            Container(
                              height: 35, width: 35,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: isSuccess ? Colors.orange.shade100 : Colors.grey.shade200, border: isToday ? Border.all(color: Colors.teal, width: 2) : null),
                              child: Icon(isSuccess ? Icons.local_fire_department : Icons.close, color: isSuccess ? Colors.orange : Colors.grey.shade400, size: 20),
                            ),
                          ],
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Scorecard Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Scorecard', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
                    const Divider(thickness: 1.5),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Game Score (Today):', style: TextStyle(fontSize: 16)), Text('+$dailyGameScore', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Routine Score ($routinesCheckedToday x 20):', style: const TextStyle(fontSize: 16)), Text('+$routinePoints', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
                    const Divider(),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Today\'s Total:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), Text('$totalDailyScore', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green))]),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(children: [Icon(Icons.star, color: Colors.amber, size: 28), SizedBox(width: 8), Text('Accumulative Score:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
                          Text('$cumulativeScore', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- MOOD REFLECTION CARD ---
            _buildMoodReflectionCard(),
            const SizedBox(height: 16),

            // Navigation Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(), 
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
              children: [
                _buildNavCard(context,'Daily routine', Icons.checklist, const Color.fromARGB(255, 3, 86, 26), onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyRoutineScreen())).then((_) => _loadDashboardData());
                  }),
                  _buildNavCard(context, 'Games', Icons.videogame_asset, const Color.fromARGB(255, 48, 3, 248), onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const GameSelectionScreen())).then((_) => _loadDashboardData());
                  }),
                  _buildNavCard(context, 'Music Therapy', Icons.music_note, const Color.fromARGB(255, 181, 14, 131), onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MusicLibraryScreen()));
                  }),
                  _buildNavCard(context, 'Family', Icons.family_restroom, const Color.fromARGB(255, 250, 2, 2), onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const FamilyScreen()));
                  }),
                  _buildNavCard(context, 'Reminders', Icons.alarm, Colors.orange.shade700, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const RemindersSelectionScreen()));
                  }),
              ],
            ),
            const SizedBox(height: 80), // Padding for the floating action button
          ],
        ),
      ),
      // --- NEW: VOICE ASSISTANT FLOATING BUTTON ---
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: isListening ? Colors.redAccent : Colors.teal,
        icon: Icon(isListening ? Icons.mic : Icons.mic_none, color: Colors.white),
        label: Text(
          isListening ? "Listening..." : "Voice Assistant",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: _listenForVoiceCommand,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildMoodReflectionCard() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getLatestMoodData(),
      builder: (context, snapshot) {
        String moodText = 'Feeling Calm & Nostalgic 🎵';
        String songInfo = '';
        String stateInfo = '';

        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final latest = snapshot.data!.first;
          moodText = latest['emotional_state'] as String? ?? 'Listening to Music';
          songInfo = latest['song_title'] as String? ?? '';
          stateInfo = latest['state_name'] as String? ?? '';
        }

        return Card(
          elevation: 3,
          color: Colors.indigo.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.self_improvement, color: Colors.indigo, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        moodText,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.indigo),
                      ),
                      if (songInfo.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '$songInfo · $stateInfo',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.indigo.shade200, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getLatestMoodData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('sqlite_user_id') ?? "";
    if (userId.isEmpty) return [];
    return await DatabaseHelper.instance.getRegionalMusicPlays(userId);
  }

  Widget _buildNavCard(BuildContext context, String title, IconData icon, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Card(
        color: const Color.fromARGB(255, 255, 252, 214),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15),side: BorderSide(color: color.withValues(alpha: 0.3), width: 2)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: color),
            const SizedBox(height: 10),
            Text(title,style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold,color: color,),),
          ],
        ),
      ),
    );
  }
}

  


////////////////////////////////////////////////////////
////////////////////////////////////////////////////////

//////         GAME SELECTION                     //////

////////////////////////////////////////////////////////
////////////////////////////////////////////////////////



class GameSelectionScreen extends StatelessWidget {
  const GameSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brain Games'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Memory Match
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            tileColor: Colors.white,
            leading: const Icon(Icons.memory, color: Colors.purple, size: 40),
            title: const Text('Memory Match', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Find and match the hidden pairs'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MemoryGameScreen())),
          ),
          const SizedBox(height: 12),

          // 2. Pattern Recognition
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            tileColor: Colors.white,
            leading: const Icon(Icons.color_lens, color: Colors.orange, size: 40),
            title: const Text('Pattern Recognition', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Memorize and recall the shown colors'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PatternRecognitionScreen())),
          ),
          const SizedBox(height: 12),

          // 3. Song Recognition
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            tileColor: Colors.white,
            leading: const Icon(Icons.library_music, color: Colors.blue, size: 40),
            title: const Text('Song Recognition', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Listen and guess the correct song'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SongRecognitionScreen())),
          ),
          const SizedBox(height: 12),

          // 4. Photo Recognition
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            tileColor: Colors.white,
            leading: const Icon(Icons.image_search, color: Colors.green, size: 40),
            title: const Text('Photo Recognition', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Identify daily objects, food, and animals'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PhotoRecognitionScreen())),
          ),
          const SizedBox(height: 12),

          // 5. Daily Task Sequencer
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            tileColor: Colors.white,
            leading: const Icon(Icons.sort, color: Colors.deepOrange, size: 40),
            title: const Text('Daily Task Sequencer', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Put daily tasks in the correct order'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyTaskSequencerGame())),
          ),
          const SizedBox(height: 12),

          // 6. Verbal Fluency
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            tileColor: Colors.white,
            leading: const Icon(Icons.record_voice_over, color: Colors.indigo, size: 40),
            title: const Text('Verbal Fluency', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Find words that belong to a category'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VerbalFluencyGame())),
          ),
        ],
      ),
    );
  }
}

// --- Placeholder Screens so your code compiles ---

class PatternRecognitionScreen extends StatefulWidget {
  const PatternRecognitionScreen({super.key});

  @override
  State<PatternRecognitionScreen> createState() => _PatternRecognitionScreenState();
}

class _PatternRecognitionScreenState extends State<PatternRecognitionScreen> {
  int level = 1;
  int lives = 10; // Increased to 10
  int score = 0;
  
  bool isMemorizePhase = true;
  int countdown = 15;
  Timer? _timer;

  List<Color> targetColors = [];
  List<Color> optionsColors = [];
  List<Color> selectedColors = [];

  final List<Color> masterColors = [
    Colors.red, Colors.blue, Colors.green, Colors.yellow, 
    Colors.orange, Colors.purple, Colors.pink, Colors.cyan, 
    Colors.teal, Colors.brown, Colors.indigo, Colors.lime, 
    Colors.amber, Colors.deepPurple
  ];

  @override
  void initState() {
    super.initState();
    _setupLevel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _setupLevel() {
    _timer?.cancel();
    
    int targetCount = min(level + 1, 6);
    
    masterColors.shuffle();
    targetColors = masterColors.take(targetCount).toList();

    optionsColors = List.from(targetColors);
    var remainingColors = masterColors.skip(targetCount).toList();
    remainingColors.shuffle();
    optionsColors.addAll(remainingColors.take(10 - targetCount));
    optionsColors.shuffle(); 

    selectedColors.clear();
    isMemorizePhase = true;
    countdown = 15;
    lives = 10; // Refill 10 stars on every new level

    setState(() {});
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (countdown > 0) {
        setState(() {
          countdown--;
        });
      } else {
        _timer?.cancel();
        setState(() {
          isMemorizePhase = false; 
        });
      }
    });
  }

  void _onColorTapped(Color color) {
    if (isMemorizePhase) return;

    setState(() {
      if (selectedColors.contains(color)) {
        selectedColors.remove(color); 
      } else {
        selectedColors.add(color);
      }
    });

    if (selectedColors.length == targetColors.length) {
      _checkWinCondition();
    }
  }

  Future<void> _checkWinCondition() async {
    bool isCorrect = selectedColors.every((color) => targetColors.contains(color));

    if (isCorrect) {
      int earnedPoints = 10 * level; // Calculate points

      setState(() {
        score += earnedPoints;
      });

      // --- SAVE TO DATABASE ---
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('sqlite_user_id') ?? "";
      if (userId.isNotEmpty) {
        await ScoreService().recordActivity(userId: userId, earnedPoints: earnedPoints);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Correct! Great job!'), backgroundColor: Colors.green),
      );
      
      await Future.delayed(const Duration(seconds: 1));
      level++;
      _setupLevel();
      
    } else {
      setState(() {
        lives--;
        selectedColors.clear(); 
      });

      if (lives <= 0) {
        _gameOver();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wrong! Try again.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _gameOver() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over'),
        content: Text('You ran out of stars.\n\nTotal Score: $score'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); 
              setState(() {
                level = 1;
                score = 0;
                _setupLevel();
              });
            },
            child: const Text('Try Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); 
            },
            child: const Text('Exit'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pattern Game - Level $level'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text('Score: $score', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          // 10 Lives Display with Wrap to prevent screen overflow
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              children: List.generate(10, (index) => Icon(
                index < lives ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 32,
              )),
            ),
          ),
          
          Expanded(
            child: isMemorizePhase ? _buildMemorizePhase() : _buildSelectionPhase(),
          ),
        ],
      ),
    );
  }

  Widget _buildMemorizePhase() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Memorize these ${targetColors.length} colors!',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          '00:${countdown.toString().padLeft(2, '0')}',
          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.teal),
        ),
        const SizedBox(height: 30),
        Wrap(
          spacing: 15,
          runSpacing: 15,
          alignment: WrapAlignment.center,
          children: targetColors.map((color) => Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))],
            ),
          )).toList(),
        ),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: () {
            _timer?.cancel();
            setState(() {
              isMemorizePhase = false;
            });
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Text('I am Ready!', style: TextStyle(fontSize: 18)),
          ),
        )
      ],
    );
  }

  Widget _buildSelectionPhase() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Select the ${targetColors.length} colors you saw',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.5,
            ),
            itemCount: optionsColors.length,
            itemBuilder: (context, index) {
              Color color = optionsColors[index];
              bool isSelected = selectedColors.contains(color);

              return GestureDetector(
                onTap: () => _onColorTapped(color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(15),
                    border: isSelected ? Border.all(color: Colors.black, width: 4) : null,
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))],
                  ),
                  child: isSelected 
                      ? const Center(child: Icon(Icons.check_circle, color: Colors.white, size: 40)) 
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}





class SongRecognitionScreen extends StatefulWidget {
  const SongRecognitionScreen({super.key});

  @override
  State<SongRecognitionScreen> createState() => _SongRecognitionScreenState();
}

class _SongRecognitionScreenState extends State<SongRecognitionScreen> {
  int level = 1;
  int lives = 10; 
  int score = 0;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isPlaying = false;
  
  List<Map<String, dynamic>> _masterSongPool = [];
  Map<String, dynamic>? currentSong;
  List<String> currentOptions = [];
  
  bool _hasGuessedCorrectly = false;
  String _feedbackMessage = '';

  final List<Map<String, dynamic>> appDefaultSongs = [
    {'name': 'Piano', 'path': 'audio/soft_piano.mp3', 'isLocal': false},
    {'name': 'Cello', 'path': 'audio/cello_calm.mp3', 'isLocal': false},
    {'name': 'Birds', 'path': 'audio/forest_birds.mp3', 'isLocal': false},
    {'name': 'Rain', 'path': 'audio/gentle_rain.mp3', 'isLocal': false},
    {'name': 'Flute', 'path': 'audio/relaxing_flute.mp3', 'isLocal': false},
    {'name': 'Ocean', 'path': 'audio/ocean_waves.mp3', 'isLocal': false},
  ];

  final List<String> encouragingMessages = [
    "That's a great guess! Let's listen a little closer.",
    "Not quite this one, but you're doing wonderfully! Try another one.",
    "Good try! Take a deep breath and listen again.",
    "You are doing a fantastic job. Let's give it one more try!"
  ];

  final List<String> correctMessages = [
    "Beautifully done! You got it right! 🌟",
    "Excellent memory! Spot on! 🎉",
    "Brilliant! Keep it up! ✨"
  ];

  @override
  void initState() {
    super.initState();

    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (mounted) {
        setState(() {
          isPlaying = state == PlayerState.playing;
        });
      }
    });

    _initializeGame();
  }

  Future<void> _initializeGame() async {
    _masterSongPool = List.from(appDefaultSongs);

    final prefs = await SharedPreferences.getInstance();
    final String? songsJson = prefs.getString('favourite_songs');
    if (songsJson != null) {
      List<dynamic> decoded = jsonDecode(songsJson);
      for (var item in decoded) {
        _masterSongPool.add({
          'name': item['name'],
          'path': item['path'],
          'isLocal': true, 
        });
      }
    }

    if (_masterSongPool.length < 4) {
      setState(() {
        _feedbackMessage = "Not enough songs to play. Add more favourites!";
      });
      return;
    }

    _setupLevel();
  }

  @override
  void dispose() {
    _audioPlayer.dispose(); 
    super.dispose();
  }

  void _setupLevel() {
    lives = 10; 
    _hasGuessedCorrectly = false;
    _feedbackMessage = '';

    _masterSongPool.shuffle();
    currentSong = _masterSongPool.first;

    _generateOptions();

    setState(() {});
  }

  void _generateOptions() {
    currentOptions.clear();
    currentOptions.add(currentSong!['name']);

    Set<String> optionsSet = {currentSong!['name']};
    int attempts = 0;
    while (optionsSet.length < 4 && attempts < 20) {
      optionsSet.add(_masterSongPool[Random().nextInt(_masterSongPool.length)]['name']);
      attempts++;
    }
    
    currentOptions = optionsSet.toList()..shuffle(); 
  }

  Future<void> _toggleAudio() async {
    if (currentSong == null) return;

    if (isPlaying) {
      await _audioPlayer.pause();
    } else {
      try {
        if (currentSong!['isLocal']) {
          await _audioPlayer.play(DeviceFileSource(currentSong!['path']));
        } else {
          await _audioPlayer.play(AssetSource(currentSong!['path'])); 
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Audio file "${currentSong!['path']}" not found.')),
        );
      }
    }
  }

  void _checkAnswer(String selectedName) async { 
    if (_hasGuessedCorrectly || lives <= 0) return;

    if (selectedName == currentSong!['name']) {
      _audioPlayer.stop();
      _hasGuessedCorrectly = true;
      
      int earnedPoints = 10 * level; 

      setState(() {
        score += earnedPoints;
        _feedbackMessage = correctMessages[Random().nextInt(correctMessages.length)];
      });

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('sqlite_user_id') ?? "";
      if (userId.isNotEmpty) {
        await ScoreService().recordActivity(userId: userId, earnedPoints: earnedPoints);
      }

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
            level++;
            _setupLevel();
        }
      });
    } else {
      setState(() {
        lives--;
      });

      if (lives <= 0) {
        _audioPlayer.stop();
        _gameOver();
      } else {
        setState(() {
          _feedbackMessage = encouragingMessages[Random().nextInt(encouragingMessages.length)];
        });
      }
    }
  }

  void _gameOver() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over'),
        content: Text('You ran out of stars.\n\nTotal Score: $score'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); 
              setState(() {
                level = 1;
                score = 0;
                _setupLevel();
              });
            },
            child: const Text('Try Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); 
            },
            child: const Text('Exit'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Song Recognition - Level $level'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text('Score: $score', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
      body: _masterSongPool.length < 4 
        ? Center(child: Text(_feedbackMessage, style: const TextStyle(fontSize: 18)))
        : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              children: List.generate(10, (index) => Icon(
                index < lives ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 32,
              )),
            ),
          ),
          
          const SizedBox(height: 30),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.teal.shade100,
            ),
            child: IconButton(
              iconSize: 80,
              color: Colors.teal,
              icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
              onPressed: _toggleAudio,
            ),
          ),
          
          const SizedBox(height: 20),
          const Text(
            'Listen to the song and guess its name!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          
          const Spacer(),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: currentOptions.map((optionName) {
                final bool isCorrect = _hasGuessedCorrectly && optionName == currentSong!['name'];

                Color btnColor = Colors.white;
                Color txtColor = Colors.teal.shade800;

                if (isCorrect) {
                  btnColor = Colors.green.shade100;
                  txtColor = Colors.green.shade900;
                } 

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      backgroundColor: btnColor,
                      foregroundColor: txtColor,
                      elevation: 2, 
                    ),
                    onPressed: () => _checkAnswer(optionName),
                    child: Text(
                      optionName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          if (_feedbackMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0, left: 16, right: 16),
              child: Text(
                _feedbackMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _hasGuessedCorrectly ? Colors.green : Colors.teal.shade700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}



class MemoryGameScreen extends StatefulWidget {
  const MemoryGameScreen({super.key});

  @override
  State<MemoryGameScreen> createState() => _MemoryGameScreenState();
}

class _MemoryGameScreenState extends State<MemoryGameScreen> {
  int level = 1;
  int lives = 10;
  int score = 0;
  List<MemoryCard> cards = [];
  List<int> flippedIndices = [];
  bool isProcessing = false;

  // Expanded to 30 emojis to safely support up to Level 15 (60 cards / 30 pairs)
  final List<String> allEmojis = [
    '🎵', '🌸', '😊', '🎲', '🐟', 
    '⚽', '❤️', '🔥', '👑', '🐱', 
    '🍃', '🌍', '☀️', '🍎', '🚗',
    '⭐', '🎈', '🍕', '🚀', '💎',
    '🎸', '🧩', '🦋', '🍦', '🚲',
    '🧸', '🌻', '🍩', '🏀', '🐢'
  ];

  @override
  void initState() {
    super.initState();
    _setupLevel();
  }

  void _setupLevel() {
    // Dynamically increase by 4 tiles every level (4, 8, 12, 16, 20...)
    int cardCount = level * 4;
    
    // Safety check: Prevent crashing if the user somehow beats Level 15
    int pairsNeeded = cardCount ~/ 2;
    if (pairsNeeded > allEmojis.length) {
      pairsNeeded = allEmojis.length;
      cardCount = pairsNeeded * 2;
    }
    
    List<String> currentLevelEmojis = List.from(allEmojis)..shuffle();
    
    cards.clear();
    for (int i = 0; i < pairsNeeded; i++) {
      String selectedEmoji = currentLevelEmojis[i];
      cards.add(MemoryCard(emoji: selectedEmoji));
      cards.add(MemoryCard(emoji: selectedEmoji)); 
    }
    cards.shuffle();
    lives = 10; // Refill 10 stars
    flippedIndices.clear();
    setState(() {});
  }

  void _onCardTap(int index) {
    if (isProcessing || cards[index].isFlipped || cards[index].isMatched) return;

    setState(() {
      cards[index].isFlipped = true;
      flippedIndices.add(index);
    });

    if (flippedIndices.length == 2) {
      _checkMatch();
    }
  }

  Future<void> _checkMatch() async {
    isProcessing = true;
    int idx1 = flippedIndices[0];
    int idx2 = flippedIndices[1];

    if (cards[idx1].emoji == cards[idx2].emoji) {
      await Future.delayed(const Duration(milliseconds: 500));
      
      int earnedPoints = 10 * level; 
      
      setState(() {
        cards[idx1].isMatched = true;
        cards[idx2].isMatched = true;
        score += earnedPoints; 
      });
      
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('sqlite_user_id') ?? "";
      if (userId.isNotEmpty) {
        await ScoreService().recordActivity(userId: userId, earnedPoints: earnedPoints);
      }

      _checkLevelComplete();
    } else {
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        cards[idx1].isFlipped = false;
        cards[idx2].isFlipped = false;
        lives--;
      });
      if (lives == 0) _gameOver();
    }
    
    flippedIndices.clear();
    isProcessing = false;
  }

  void _checkLevelComplete() {
    if (cards.every((card) => card.isMatched)) {
      setState(() {
        level++;
        _setupLevel();
      });
    }
  }

  void _gameOver() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Good Effort!'),
        content: Text('Let\'s take a breath and try again.\n\nTotal Score: $score'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); 
              setState(() {
                level = 1;
                score = 0;
                _setupLevel();
              });
            },
            child: const Text('Try Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); 
            },
            child: const Text('Exit'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Adjust layout based on how many cards exist
    int crossAxisCount = 4;
    if (cards.length <= 4) crossAxisCount = 2;
    else if (cards.length == 12) crossAxisCount = 3;

    return Scaffold(
      appBar: AppBar(
        title: Text('Memory Game - Level $level'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text('Score: $score', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              children: List.generate(10, (index) => Icon(
                index < lives ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 32,
              )),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount, 
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: cards.length,
              itemBuilder: (context, index) {
                if (cards[index].isMatched) return const SizedBox.shrink(); 
                
                // Shrink emoji font size as grid gets denser
                double emojiSize = cards.length > 20 ? 30 : (cards.length >= 12 ? 40 : 60);

                return GestureDetector(
                  onTap: () => _onCardTap(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: cards[index].isFlipped ? Colors.white : Colors.teal.shade300,
                      borderRadius: BorderRadius.circular(15),
                      border: cards[index].isFlipped 
                          ? Border.all(color: Colors.teal.shade200, width: 2) 
                          : null,
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2))
                      ],
                    ),
                    child: Center(
                      child: cards[index].isFlipped
                          ? Text(
                              cards[index].emoji,
                              style: TextStyle(fontSize: emojiSize), 
                            )
                          : Icon(
                              Icons.help_outline, 
                              color: Colors.white54, 
                              size: emojiSize * 0.7,
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MemoryCard {
  final String emoji;
  bool isFlipped;
  bool isMatched;

  MemoryCard({required this.emoji, this.isFlipped = false, this.isMatched = false});
}



class PhotoRecognitionScreen extends StatefulWidget {
  const PhotoRecognitionScreen({super.key});

  @override
  State<PhotoRecognitionScreen> createState() => _PhotoRecognitionScreenState();
}

class _PhotoRecognitionScreenState extends State<PhotoRecognitionScreen> {
  int currentIndex = 0;
  List<String> currentOptions = [];
  late Map<String, String> currentPhoto;

  // --- REPLACE THESE WITH YOUR ACTUAL IMAGE PATHS AND NAMES ---
  // Example: {'path': 'assets/images/apple.png', 'name': 'Apple'}
  final List<Map<String, String>> photoDatabase = [
    {'path': 'images/doctor.jpg', 'name': 'DOCTOR'},
    {'path': 'images/medicine.jpg', 'name': 'MEDICINE'},
    {'path': 'images/ball.jpg', 'name': 'BALL'},
    {'path': 'images/lotus.jpg', 'name': 'LOTUS'},
    {'path': 'images/dog.jpg', 'name': 'DOG'},
    {'path': 'images/moon.jpg', 'name': 'MOON'},
    {'path': 'images/spectacles.jpg', 'name': 'SPECTACLES'},
    {'path': 'images/tv.jpg', 'name': 'TV'},
    {'path': 'images/cow.jpg', 'name': 'COW'},
    {'path': 'images/doors.jpg', 'name': 'DOOR'},
  ];

  // A list of gentle, encouraging messages for incorrect guesses
  final List<String> encouragingMessages = [
    "That's a great guess! Let's take our time and look a little closer.",
    "Not quite this one, but you're doing wonderfully! Try another one.",
    "Good try! There's absolutely no rush, take a deep breath and look again.",
    "You are doing a fantastic job. Let's give it one more look!"
  ];

  @override
  void initState() {
    super.initState();
    photoDatabase.shuffle(); // Shuffle the order of photos every time they open the game
    _setupQuestion();
  }

  void _setupQuestion() {
    currentPhoto = photoDatabase[currentIndex];
    _generateOptions();
    setState(() {});
  }

  void _generateOptions() {
    currentOptions.clear();
    currentOptions.add(currentPhoto['name']!);

    // Get 3 random wrong answers from the database
    List<Map<String, String>> wrongChoices = List.from(photoDatabase)
      ..removeWhere((photo) => photo['name'] == currentPhoto['name']);
    wrongChoices.shuffle();

    for (int i = 0; i < 3; i++) {
      currentOptions.add(wrongChoices[i]['name']!);
    }

    currentOptions.shuffle(); // Shuffle options so the correct answer changes position
  }

  void _checkAnswer(String selectedName) {
    if (selectedName == currentPhoto['name']) {
      // Correct Answer - Positive Reinforcement
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Beautifully done! You got it right! 🌟', 
            style: TextStyle(fontSize: 16)
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Move to the next photo
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            currentIndex = (currentIndex + 1) % photoDatabase.length; // Loops back to start eventually
            _setupQuestion();
          });
        }
      });
    } else {
      // Gentle, encouraging feedback (No penalties, no lost lives)
      encouragingMessages.shuffle();
      String gentleMessage = encouragingMessages.first;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            gentleMessage, 
            style: const TextStyle(fontSize: 16)
          ),
          backgroundColor: Colors.teal.shade400,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Recognition'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            const Text(
              'What do you see in this picture?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: Colors.teal),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            // Image Display Area
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  // This Image.asset handles the placeholder text so your app won't crash
                  // while you are testing before adding real images.
                  child: Image.asset(
                    currentPhoto['path']!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
                            const SizedBox(height: 10),
                            Text(
                              '${currentPhoto['path']}', // Displays "Add picture 1", etc.
                              style: const TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 30),

            // Multiple Choice Options
            Expanded(
              flex: 5,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: currentOptions.map((optionName) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.teal.shade800,
                      elevation: 3,
                    ),
                    onPressed: () => _checkAnswer(optionName),
                    child: Text(
                      optionName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}








////////////////////////////////////////////////////////
////////////////////////////////////////////////////////

//////       DAILY TASK SEQUENCER GAME          //////

////////////////////////////////////////////////////////
////////////////////////////////////////////////////////


class DailyTaskSequencerGame extends StatefulWidget {
  const DailyTaskSequencerGame({super.key});

  @override
  State<DailyTaskSequencerGame> createState() => _DailyTaskSequencerGameState();
}

class _DailyTaskSequencerGameState extends State<DailyTaskSequencerGame> {
  int score = 0;
  int currentTaskIndex = 0;
  bool isGameComplete = false;

  // Each round is a list of daily tasks in correct order
  late List<DailyTaskItem> _correctOrder;
  late List<DailyTaskItem> _shuffledTasks;
  List<DailyTaskItem?> _placedTasks = [];

  final List<String> encouragingMessages = [
    "You're doing wonderfully! 🌟",
    "Great thinking! Keep going! ✨",
    "That's right! Well done! 🌻",
    "Beautiful work! Almost there! 🎉",
  ];

  final List<String> gentleRetryMessages = [
    "Almost! Think about what happens first in the morning. 🤗",
    "Good try! Let's think about which comes before the other. 💛",
    "Not quite — take your time, there's no rush at all. ☀️",
    "That's a thoughtful guess! Try another one. 🌸",
  ];

  @override
  void initState() {
    super.initState();
    _startNewRound();
  }

  void _startNewRound() {
    // Define common daily routines in chronological order
    final allSequences = [
      [
        DailyTaskItem(label: 'Wake Up', icon: Icons.wb_sunny),
        DailyTaskItem(label: 'Brush Teeth', icon: Icons.clean_hands),
        DailyTaskItem(label: 'Take a Bath', icon: Icons.bathtub),
        DailyTaskItem(label: 'Get Dressed', icon: Icons.checkroom),
        DailyTaskItem(label: 'Eat Breakfast', icon: Icons.free_breakfast),
      ],
      [
        DailyTaskItem(label: 'Wake Up', icon: Icons.wb_sunny),
        DailyTaskItem(label: 'Eat Breakfast', icon: Icons.free_breakfast),
        DailyTaskItem(label: 'Take Medicine', icon: Icons.medication),
        DailyTaskItem(label: 'Go for a Walk', icon: Icons.directions_walk),
        DailyTaskItem(label: 'Have Lunch', icon: Icons.restaurant),
      ],
      [
        DailyTaskItem(label: 'Eat Lunch', icon: Icons.restaurant),
        DailyTaskItem(label: 'Rest / Nap', icon: Icons.bedtime),
        DailyTaskItem(label: 'Listen to Music', icon: Icons.music_note),
        DailyTaskItem(label: 'Have Dinner', icon: Icons.dinner_dining),
        DailyTaskItem(label: 'Go to Sleep', icon: Icons.nightlight_round),
      ],
      [
        DailyTaskItem(label: 'Wake Up', icon: Icons.wb_sunny),
        DailyTaskItem(label: 'Brush Teeth', icon: Icons.clean_hands),
        DailyTaskItem(label: 'Eat Breakfast', icon: Icons.free_breakfast),
        DailyTaskItem(label: 'Read a Book', icon: Icons.menu_book),
        DailyTaskItem(label: 'Have Lunch', icon: Icons.restaurant),
      ],
    ];

    allSequences.shuffle();
    _correctOrder = List.from(allSequences.first);
    _shuffledTasks = List.from(allSequences.first)..shuffle();
    _placedTasks = List.filled(_correctOrder.length, null);
    currentTaskIndex = 0;
    isGameComplete = false;

    setState(() {});
  }

  void _onTaskTapped(DailyTaskItem task) {
    if (isGameComplete) return;
    // Prevent tapping the same task twice
    if (_placedTasks.contains(task)) return;

    // Check if correct
    if (task.label == _correctOrder[currentTaskIndex].label) {
      // Correct!
      setState(() {
        _placedTasks[currentTaskIndex] = task;
        currentTaskIndex++;
        score += 10;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            encouragingMessages[Random().nextInt(encouragingMessages.length)],
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.green.shade600,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );

      // Check if round complete
      if (currentTaskIndex >= _correctOrder.length) {
        _completeRound();
      }
    } else {
      // Wrong choice — gentle encouragement, no penalty
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            gentleRetryMessages[Random().nextInt(gentleRetryMessages.length)],
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.teal.shade400,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _completeRound() async {
    setState(() => isGameComplete = true);

    // Save score to database
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('sqlite_user_id') ?? "";
    if (userId.isNotEmpty) {
      await ScoreService().recordActivity(userId: userId, earnedPoints: 10);
    }
  }

  void _playAgain() {
    setState(() {
      score = 0;
    });
    _startNewRound();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Task Sequencer'),
        centerTitle: true,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 24),
                  const SizedBox(width: 4),
                  Text('$score', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: isGameComplete ? _buildCompletionScreen() : _buildGameBody(),
    );
  }

  Widget _buildGameBody() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Instruction card
          Card(
            elevation: 2,
            color: Colors.teal.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(Icons.sort, size: 40, color: Colors.teal.shade700),
                  const SizedBox(height: 8),
                  const Text(
                    'Put the daily tasks in the right order!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap the task that comes next.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.teal.shade600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Placed tasks (sequence being built)
          Expanded(
            flex: 3,
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Sequence:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal.shade700),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _placedTasks.length,
                        itemBuilder: (context, index) {
                          final placed = _placedTasks[index];
                          final isNext = index == currentTaskIndex;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 52),
                              decoration: BoxDecoration(
                                color: placed != null
                                    ? Colors.green.shade50
                                    : isNext
                                        ? Colors.amber.shade50
                                        : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: placed != null
                                      ? Colors.green.shade300
                                      : isNext
                                          ? Colors.amber.shade300
                                          : Colors.grey.shade200,
                                  width: 2,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: placed != null ? Colors.green : (isNext ? Colors.amber : Colors.grey.shade300),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            color: placed != null || isNext ? Colors.white : Colors.grey.shade600,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    if (placed != null) ...[
                                      Icon(placed.icon, color: Colors.green.shade700, size: 24),
                                      const SizedBox(width: 8),
                                      Text(
                                        placed.label,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade800,
                                        ),
                                      ),
                                    ] else if (isNext) ...[
                                      Text(
                                        'Tap a task below ↓',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontStyle: FontStyle.italic,
                                          color: Colors.amber.shade700,
                                        ),
                                      ),
                                    ] else ...[
                                      Text(
                                        '—',
                                        style: TextStyle(fontSize: 16, color: Colors.grey.shade400),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Available tasks to choose from
          Expanded(
            flex: 2,
            child: Card(
              elevation: 2,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Tasks:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _shuffledTasks.map((task) {
                          bool isAlreadyPlaced = _placedTasks.contains(task);
                          return SizedBox(
                            height: 60,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isAlreadyPlaced ? Colors.grey.shade200 : Colors.teal.shade50,
                                foregroundColor: isAlreadyPlaced ? Colors.grey.shade400 : Colors.teal.shade800,
                                elevation: isAlreadyPlaced ? 0 : 3,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isAlreadyPlaced ? Colors.grey.shade300 : Colors.teal.shade200,
                                    width: 2,
                                  ),
                                ),
                              ),
                              onPressed: isAlreadyPlaced ? null : () => _onTaskTapped(task),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(task.icon, size: 24),
                                  const SizedBox(width: 8),
                                  Text(
                                    task.label,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.celebration, size: 80, color: Colors.amber),
            const SizedBox(height: 20),
            const Text(
              'Wonderful Job!',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.teal),
            ),
            const SizedBox(height: 12),
            const Text(
              'You sorted all the tasks perfectly!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, color: Colors.black54),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.shade200, width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 32),
                  const SizedBox(width: 12),
                  Text(
                    '+10 Points!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber.shade800),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 4,
                ),
                onPressed: _playAgain,
                child: const Text(
                  'Play Again',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal,
                  side: const BorderSide(color: Colors.teal, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Back to Games',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DailyTaskItem {
  final String label;
  final IconData icon;

  DailyTaskItem({required this.label, required this.icon});
}


////////////////////////////////////////////////////////
////////////////////////////////////////////////////////

//////       VERBAL FLUENCY GAME               //////

////////////////////////////////////////////////////////
////////////////////////////////////////////////////////


class VerbalFluencyGame extends StatefulWidget {
  const VerbalFluencyGame({super.key});

  @override
  State<VerbalFluencyGame> createState() => _VerbalFluencyGameState();
}

class _VerbalFluencyGameState extends State<VerbalFluencyGame> {
  int _currentCategoryIndex = 0;
  bool _roundComplete = false;
  bool _showingHint = false;

  late List<_CategoryRound> _rounds;
  late _CategoryRound _currentRound;
  final Set<String> _selectedCorrect = {};
  final Set<String> _tappedWrong = {};

  final List<String> _encouragingMessages = [
    "Wonderful! You found one! 🌟",
    "That's right! Keep going! ✨",
    "Beautiful! You're doing so well! 🌻",
    "Excellent memory! 🎉",
    "Perfect! That belongs here! 👏",
  ];

  final List<String> _gentleMessages = [
    "Almost! That one doesn't belong in this group. Let's try another. 🤗",
    "Not quite — but that's okay! Pick a different one. 💛",
    "Good try! See if you can find one that fits better. ☀️",
    "That doesn't belong here, but you're doing great! 🌸",
  ];

  @override
  void initState() {
    super.initState();
    _initRounds();
    _currentRound = _rounds[_currentCategoryIndex];
  }

  void _initRounds() {
    _rounds = [
      _CategoryRound(
        category: 'Things found in a kitchen',
        icon: Icons.kitchen,
        correct: ['Spoon', 'Frying Pan', 'Plates', 'Cup'],
        distractors: ['Shoes', 'Umbrella', 'Book', 'Scarf'],
      ),
      _CategoryRound(
        category: 'Types of fruit',
        icon: Icons.apple,
        correct: ['Apple', 'Banana', 'Mango', 'Orange'],
        distractors: ['Chair', 'Spoon', 'Pillow', 'Hat'],
      ),
      _CategoryRound(
        category: 'Animals',
        icon: Icons.pets,
        correct: ['Dog', 'Cat', 'Elephant', 'Parrot'],
        distractors: ['Table', 'Shoe', 'Lamp', 'Window'],
      ),
      _CategoryRound(
        category: 'Things to wear',
        icon: Icons.checkroom,
        correct: ['Shirt', 'Sandals', 'Hat', 'Scarf'],
        distractors: ['Spoon', 'Chair', 'Clock', 'Lamp'],
      ),
      _CategoryRound(
        category: 'Things in a bathroom',
        icon: Icons.bathtub,
        correct: ['Soap', 'Toothbrush', 'Towel', 'Mirror'],
        distractors: ['Apple', 'Bicycle', 'Tree', 'Book'],
      ),
      _CategoryRound(
        category: 'Colours',
        icon: Icons.palette,
        correct: ['Red', 'Blue', 'Green', 'Yellow'],
        distractors: ['Spoon', 'Chair', 'Cloud', 'Stone'],
      ),
      _CategoryRound(
        category: 'Things you eat for breakfast',
        icon: Icons.free_breakfast,
        correct: ['Eggs', 'Toast', 'Milk', 'Cereal'],
        distractors: ['Shirt', 'Carpet', 'Clock', 'Door'],
      ),
      _CategoryRound(
        category: 'Things found in a garden',
        icon: Icons.local_florist,
        correct: ['Flowers', 'Grass', 'Tree', 'Bench'],
        distractors: ['Fork', 'Pillow', 'Shoe', 'Pen'],
      ),
    ];
    _rounds.shuffle();
  }

  void _onOptionTapped(String word) {
    if (_roundComplete) return;
    if (_selectedCorrect.contains(word)) return;
    if (_tappedWrong.contains(word)) return;

    if (_currentRound.correct.contains(word)) {
      setState(() {
        _selectedCorrect.add(word);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _encouragingMessages[DateTime.now().millisecond % _encouragingMessages.length],
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.green.shade600,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );

      if (_selectedCorrect.length == _currentRound.correct.length) {
        setState(() => _roundComplete = true);
        _saveScore();
      }
    } else {
      setState(() => _tappedWrong.add(word));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _gentleMessages[DateTime.now().millisecond % _gentleMessages.length],
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.teal.shade400,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _showAllAnswers() {
    setState(() => _showingHint = true);
  }

  void _nextCategory() {
    setState(() {
      _currentCategoryIndex = (_currentCategoryIndex + 1) % _rounds.length;
      _currentRound = _rounds[_currentCategoryIndex];
      _selectedCorrect.clear();
      _tappedWrong.clear();
      _roundComplete = false;
      _showingHint = false;
    });
  }

  Future<void> _saveScore() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('sqlite_user_id') ?? "";
    if (userId.isNotEmpty) {
      await ScoreService().recordActivity(userId: userId, earnedPoints: 10);
    }
  }

  List<String> _getShuffledOptions() {
    final allOptions = [..._currentRound.correct, ..._currentRound.distractors];
    allOptions.shuffle();
    return allOptions;
  }

  Color _getButtonColor(String word) {
    if (_selectedCorrect.contains(word)) return Colors.green.shade100;
    if (_showingHint && _currentRound.correct.contains(word)) return Colors.green.shade50;
    if (_tappedWrong.contains(word)) return Colors.orange.shade50;
    return Colors.white;
  }

  Color _getButtonBorder(String word) {
    if (_selectedCorrect.contains(word)) return Colors.green;
    if (_showingHint && _currentRound.correct.contains(word)) return Colors.green.shade300;
    if (_tappedWrong.contains(word)) return Colors.orange.shade300;
    return Colors.teal.shade200;
  }

  Color _getButtonTextColor(String word) {
    if (_selectedCorrect.contains(word)) return Colors.green.shade800;
    if (_showingHint && _currentRound.correct.contains(word)) return Colors.green.shade700;
    if (_tappedWrong.contains(word)) return Colors.orange.shade700;
    return Colors.teal.shade800;
  }

  @override
  Widget build(BuildContext context) {
    final options = _getShuffledOptions();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verbal Fluency'),
        centerTitle: true,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 24),
                  const SizedBox(width: 4),
                  Text('${_currentCategoryIndex + 1}/${_rounds.length}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Category prompt card
            Card(
              elevation: 3,
              color: Colors.teal.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(_currentRound.icon, size: 48, color: Colors.teal.shade700),
                    const SizedBox(height: 12),
                    Text(
                      'Which of these are',
                      style: TextStyle(fontSize: 18, color: Colors.teal.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentRound.category,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_selectedCorrect.length} of ${_currentRound.correct.length} found',
                      style: TextStyle(fontSize: 16, color: Colors.teal.shade500),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Progress dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_currentRound.correct.length, (index) {
                bool filled = index < _selectedCorrect.length;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Icon(
                    filled ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: filled ? Colors.green : Colors.teal.shade200,
                    size: 28,
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            // Option buttons grid
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.2,
                ),
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final word = options[index];
                  final bool isSelected = _selectedCorrect.contains(word);
                  final bool isWrongTap = _tappedWrong.contains(word);
                  final bool isHinted = _showingHint && _currentRound.correct.contains(word);

                  return SizedBox(
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getButtonColor(word),
                        foregroundColor: _getButtonTextColor(word),
                        elevation: isSelected ? 1 : 3,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: _getButtonBorder(word),
                            width: isSelected || isHinted ? 3 : 2,
                          ),
                        ),
                      ),
                      onPressed: isSelected ? null : () => _onOptionTapped(word),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isSelected) ...[
                            const Icon(Icons.check_circle, color: Colors.green, size: 22),
                            const SizedBox(width: 8),
                          ] else if (isHinted) ...[
                            Icon(Icons.lightbulb, color: Colors.green.shade400, size: 22),
                            const SizedBox(width: 8),
                          ] else if (isWrongTap) ...[
                            Icon(Icons.help_outline, color: Colors.orange.shade400, size: 22),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            word,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              decoration: isWrongTap ? TextDecoration.lineThrough : null,
                              decorationColor: Colors.orange.shade300,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // Hint button (only show if not all found and not already showing hint)
            if (!_roundComplete && !_showingHint)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: TextButton(
                  onPressed: _showAllAnswers,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.teal.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Show me a hint 💡',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.teal.shade600),
                  ),
                ),
              ),

            // Round complete — show success and next button
            if (_roundComplete)
              Card(
                elevation: 2,
                color: Colors.green.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Icon(Icons.celebration, size: 48, color: Colors.amber),
                      const SizedBox(height: 8),
                      const Text(
                        'Wonderful job!',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You found all the ${_currentRound.category.toLowerCase()}! 🌟',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, color: Colors.green.shade700),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _nextCategory,
                          child: const Text(
                            'Next Category →',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRound {
  final String category;
  final IconData icon;
  final List<String> correct;
  final List<String> distractors;

  _CategoryRound({
    required this.category,
    required this.icon,
    required this.correct,
    required this.distractors,
  });
}


////////////////////////////////////////////////////////
////////////////////////////////////////////////////////

//////           DAILY ROUTINE                    //////

////////////////////////////////////////////////////////
////////////////////////////////////////////////////////



class DailyRoutineScreen extends StatefulWidget {
  const DailyRoutineScreen({super.key});

  @override
  State<DailyRoutineScreen> createState() => _DailyRoutineScreenState();
}

class _DailyRoutineScreenState extends State<DailyRoutineScreen> {
  List<RoutineTask> tasks = [];
  bool isLoading = true;
  bool isEditMode = false;

  final List<String> warmMessages = [
    "Wonderful job! One step at a time. 🌟",
    "Great work! You're doing amazing today. 👏",
    "Beautiful! Keep up the excellent routine. 🌻",
    "Perfect! Another goal accomplished. ✨",
  ];

  @override
  void initState() {
    super.initState();
    _loadRoutineData();
  }

  // --- HELPER: Sort tasks chronologically by time ---
  void _sortTasksByTime() {
    tasks.sort((a, b) {
      DateTime timeA = _parseTimeString(a.scheduledTime);
      DateTime timeB = _parseTimeString(b.scheduledTime);
      return timeA.compareTo(timeB);
    });
  }

  // Converts strings like "06:30 AM" or "02:15 PM" into comparable DateTime objects
  DateTime _parseTimeString(String timeStr) {
    try {
      final parts = timeStr.split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);
      String period = parts.length > 1 ? parts[1].toUpperCase() : 'AM';

      if (period == 'PM' && hour < 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;

      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (e) {
      return DateTime.now(); // Fallback if parsing fails
    }
  }

  Future<void> _loadRoutineData() async {
    final prefs = await SharedPreferences.getInstance();
    
    DateTime now = DateTime.now();
    String todayDateString = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    
    String? savedDate = prefs.getString('routine_date');
    String? savedTasksJson = prefs.getString('routine_tasks');

    if (savedDate == todayDateString && savedTasksJson != null) {
      List<dynamic> decodedList = jsonDecode(savedTasksJson);
      setState(() {
        tasks = decodedList.map((item) => RoutineTask.fromJson(item)).toList();
        _sortTasksByTime(); // Sort on load
        isLoading = false;
      });
    } else if (savedTasksJson != null) {
      List<dynamic> decodedList = jsonDecode(savedTasksJson);
      setState(() {
        tasks = decodedList.map((item) {
          RoutineTask t = RoutineTask.fromJson(item);
          t.isCompleted = false;
          t.isMissed = false;
          t.completedTime = null;
          return t;
        }).toList();
        _sortTasksByTime(); // Sort on load
        isLoading = false;
      });
      await prefs.setString('routine_date', todayDateString);
      _saveRoutineData();
    } else {
      setState(() {
        tasks = []; 
        isLoading = false;
      });
      await prefs.setString('routine_date', todayDateString);
    }
  }

  Future<void> _saveRoutineData() async {
    _sortTasksByTime(); // Ensure they are sorted before saving
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> jsonList = tasks.map((t) => t.toJson()).toList();
    await prefs.setString('routine_tasks', jsonEncode(jsonList));
  }

  String _formatTime(DateTime time) {
    int hour = time.hour;
    int minute = time.minute;
    String period = hour >= 12 ? 'PM' : 'AM';
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    String minuteStr = minute.toString().padLeft(2, '0');
    return '$hour:$minuteStr $period';
  }

  void _markAsDone(int index) async {
    if (tasks[index].isCompleted || tasks[index].isMissed) return;

    setState(() {
      for (int i = 0; i < index; i++) {
        if (!tasks[i].isCompleted && !tasks[i].isMissed) {
          tasks[i].isMissed = true;
          
          // --- NEW: SEND ALERT TO CAREGIVER ---
          CaregiverAlertService.sendMissedAlert(
            'Routine', 
            tasks[i].title, 
            tasks[i].scheduledTime
          );
        }
      }
      tasks[index].isCompleted = true;
      tasks[index].completedTime = DateTime.now();
    });

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('sqlite_user_id') ?? "";
    if (userId.isNotEmpty) {
      final scoreService = ScoreService();
      await scoreService.recordActivity(userId: userId, earnedPoints: 20);
    }

    _saveRoutineData();

    warmMessages.shuffle();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          warmMessages.first,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
        backgroundColor: Colors.green.shade600,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showRoutineDialog({RoutineTask? existingTask, int? index}) {
    TextEditingController titleController = TextEditingController(text: existingTask?.title ?? '');
    TimeOfDay selectedTime = TimeOfDay.now();
    String timeString = existingTask?.scheduledTime ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existingTask == null ? 'Add Daily Routine' : 'Edit Routine'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Routine Name (e.g., Breakfast)', 
                      border: OutlineInputBorder()
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.access_time, color: Colors.teal),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          timeString.isEmpty ? 'Select Time' : timeString, 
                          style: const TextStyle(fontSize: 16)
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final TimeOfDay? time = await showTimePicker(
                            context: context, 
                            initialTime: selectedTime
                          );
                          if (time != null) {
                            setDialogState(() {
                              selectedTime = time;
                              timeString = time.format(context); 
                            });
                          }
                        },
                        child: const Text('Pick Time'),
                      )
                    ],
                  )
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: const Text('Cancel')
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: () {
                    if (titleController.text.trim().isNotEmpty && timeString.isNotEmpty) {
                      setState(() {
                        if (existingTask == null) {
                          tasks.add(RoutineTask(title: titleController.text.trim(), scheduledTime: timeString));
                        } else {
                          tasks[index!].title = titleController.text.trim();
                          tasks[index].scheduledTime = timeString;
                        }
                        _sortTasksByTime(); // Automatically re-sort after adding/editing
                      });
                      _saveRoutineData(); 
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Save'),
                )
              ],
            );
          }
        );
      },
    );
  }

  void _deleteRoutine(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Routine?'),
        content: const Text('Are you sure you want to permanently remove this task?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              setState(() => tasks.removeAt(index));
              _saveRoutineData();
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    int completedCount = tasks.where((task) => task.isCompleted).length;
    double progress = tasks.isEmpty ? 0 : completedCount / tasks.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Routine'),
        centerTitle: true,
        actions: [
          if (isEditMode)
            TextButton(
              onPressed: () {
                setState(() {
                  isEditMode = false;
                });
              },
              child: const Text('Done', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            )
        ],
      ),
      body: tasks.isEmpty 
          ? Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
                icon: const Icon(Icons.add, color: Colors.white, size: 28),
                label: const Text('Add Daily Routine', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                onPressed: () {
                  setState(() => isEditMode = true);
                  _showRoutineDialog();
                },
              )
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.teal.shade50,
                  child: Column(
                    children: [
                      Text(
                        'Great day! You have completed $completedCount of ${tasks.length} routines.',
                        style: const TextStyle(fontSize: 18, color: Colors.teal, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 15),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 12,
                        backgroundColor: Colors.teal.shade100,
                        color: Colors.teal,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      
                      Color cardColor = Colors.white;
                      Color borderColor = Colors.transparent;
                      Color iconBgColor = Colors.grey.shade200;
                      Color iconColor = Colors.grey.shade400;
                      IconData iconData = Icons.check;
                      Color titleColor = Colors.black87;
                      TextDecoration textDecoration = TextDecoration.none;

                      if (task.isCompleted) {
                        cardColor = Colors.green.shade50;
                        borderColor = Colors.green.shade300;
                        iconBgColor = Colors.green;
                        iconColor = Colors.white;
                        iconData = Icons.check;
                        titleColor = Colors.grey.shade600;
                        textDecoration = TextDecoration.none;
                      } else if (task.isMissed) {
                        cardColor = Colors.red.shade50;
                        borderColor = Colors.red.shade300;
                        iconBgColor = Colors.red.shade300;
                        iconColor = Colors.white;
                        iconData = Icons.close;
                        titleColor = Colors.red.shade400;
                        textDecoration = TextDecoration.lineThrough;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: InkWell(
                          onTap: isEditMode ? null : () => _markAsDone(index),
                          borderRadius: BorderRadius.circular(15),
                          child: Card(
                            elevation: (task.isCompleted || task.isMissed) ? 1 : 4,
                            color: cardColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                              side: BorderSide(color: borderColor, width: 2),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              child: Row(
                                children: [
                                  Container(
                                    height: 40,
                                    width: 40,
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: iconBgColor),
                                    child: Icon(iconData, color: iconColor, size: 28),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          task.title,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: titleColor,
                                            decoration: textDecoration,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Scheduled: ${task.scheduledTime}',
                                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                        ),
                                        if (task.isCompleted && task.completedTime != null)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4.0),
                                            child: Text(
                                              'Completed at: ${_formatTime(task.completedTime!)}',
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green),
                                            ),
                                          ),
                                        if (task.isMissed)
                                          const Padding(
                                            padding: EdgeInsets.only(top: 4.0),
                                            child: Text(
                                              'Missed',
                                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (isEditMode && !task.isCompleted && !task.isMissed) ...[
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blueGrey),
                                      onPressed: () => _showRoutineDialog(existingTask: task, index: index),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                                      onPressed: () => _deleteRoutine(index),
                                    ),
                                  ]
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: tasks.isEmpty
          ? null
          : isEditMode
              ? FloatingActionButton.extended(
                  backgroundColor: Colors.teal,
                  onPressed: () => _showRoutineDialog(),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Add Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              : FloatingActionButton.extended(
                  backgroundColor: Colors.teal,
                  onPressed: () {
                    setState(() {
                      isEditMode = true;
                    });
                  },
                  icon: const Icon(Icons.edit, color: Colors.white),
                  label: const Text('Edit Daily Routine', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
    );
  }
}

class RoutineTask {
  String title;
  String scheduledTime;
  bool isCompleted;
  bool isMissed;
  DateTime? completedTime;

  RoutineTask({
    required this.title,
    required this.scheduledTime,
    this.isCompleted = false,
    this.isMissed = false,
    this.completedTime,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'scheduledTime': scheduledTime,
        'isCompleted': isCompleted,
        'isMissed': isMissed,
        'completedTime': completedTime?.toIso8601String(),
      };

  factory RoutineTask.fromJson(Map<String, dynamic> json) => RoutineTask(
        title: json['title'],
        scheduledTime: json['scheduledTime'],
        isCompleted: json['isCompleted'],
        isMissed: json['isMissed'],
        completedTime: json['completedTime'] != null ? DateTime.parse(json['completedTime']) : null,
      );
}

////////////////////////////////////////////////////////
////////////////////////////////////////////////////////

//////                  MUSIC                     //////

////////////////////////////////////////////////////////
////////////////////////////////////////////////////////


class MusicTrack {
  final String title;
  final String path;

  MusicTrack({required this.title, required this.path});
}

class MusicFolder {
  final String name;
  final List<MusicTrack> tracks;
  final List<MusicFolder> subFolders;

  MusicFolder({
    required this.name,
    this.tracks = const [],
    this.subFolders = const [],
  });
}

// --- MAIN MUSIC LIBRARY SCREEN ---

class MusicLibraryScreen extends StatelessWidget {
  const MusicLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Therapy'),
        centerTitle: true,
        backgroundColor: Colors.purple,
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
        children: [
          _buildMusicCard(context, 'Calming', Icons.spa, Colors.teal, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => BuiltInMusicScreen(
              title: 'Calming Music',
              themeColor: Colors.teal,
              songs: const [
                {'name': 'Forest Birds', 'path': 'audio/forest_birds.mp3'},
                {'name': 'Ocean', 'path': 'audio/ocean_waves.mp3'},
                {'name': 'Rain', 'path': 'audio/gentle_rain.mp3'},
              ],
            )));
          }),
          _buildMusicCard(context, 'Classical', Icons.music_note, Colors.blue, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => BuiltInMusicScreen(
              title: 'Classical Music',
              themeColor: Colors.blue,
              songs: const [
                {'name': 'Cello Calm', 'path': 'audio/cello_calm.mp3'},
                {'name': 'Flute', 'path': 'audio/relaxing_flute.mp3'},
                {'name': 'Piano', 'path': 'audio/soft_piano.mp3'},
              ],
            )));
          }),
          _buildMusicCard(context, 'Favourites', Icons.favorite, Colors.redAccent, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const FavouritesScreen()));
          }),
          _buildMusicCard(context, 'Song Recognition', Icons.quiz, Colors.orange, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SongRecognitionScreen()));
          }),
          _buildMusicCard(context, 'Regional Music', Icons.album, Colors.deepPurple, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const RegionalMusicScreen()));
          }),
        ],
      ),
    );
  }

  Widget _buildMusicCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Card(
        color: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15), 
          side: BorderSide(color: color.withOpacity(0.5), width: 2)
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
            ),
          ],
        ),
      ),
    );
  }
}


class BuiltInMusicScreen extends StatefulWidget {
  final String title;
  final Color themeColor;
  final List<Map<String, String>> songs;

  const BuiltInMusicScreen({super.key, required this.title, required this.themeColor, required this.songs});

  @override
  State<BuiltInMusicScreen> createState() => _BuiltInMusicScreenState();
}

class _BuiltInMusicScreenState extends State<BuiltInMusicScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? currentlyPlayingIndex;
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        isPlaying = false;
        currentlyPlayingIndex = null;
      });
    });
  }

  Future<void> _playPauseSong(int index, String path) async {
    if (currentlyPlayingIndex == index && isPlaying) {
      await _audioPlayer.pause();
      setState(() => isPlaying = false);
    } else {
      await _audioPlayer.play(AssetSource(path));
      setState(() {
        currentlyPlayingIndex = index;
        isPlaying = true;
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        backgroundColor: widget.themeColor,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: widget.songs.length,
        itemBuilder: (context, index) {
          final song = widget.songs[index];
          final isThisPlaying = currentlyPlayingIndex == index && isPlaying;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: isThisPlaying ? widget.themeColor : Colors.transparent, width: 2)
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isThisPlaying ? widget.themeColor : Colors.grey.shade200,
                child: Icon(
                  isThisPlaying ? Icons.music_note : Icons.play_arrow,
                  color: isThisPlaying ? Colors.white : widget.themeColor,
                ),
              ),
              title: Text(
                song['name']!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: IconButton(
                icon: Icon(isThisPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill),
                color: widget.themeColor,
                iconSize: 36,
                onPressed: () => _playPauseSong(index, song['path']!),
              ),
            ),
          );
        },
      ),
    );
  }
}
class FavouritesScreen extends StatefulWidget {
  const FavouritesScreen({super.key});

  @override
  State<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends State<FavouritesScreen> {
  List<Map<String, String>> favouriteSongs = [];
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? currentlyPlayingIndex;
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    _loadFavouriteSongs();
    
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        isPlaying = false;
        currentlyPlayingIndex = null;
      });
    });
  }

  Future<void> _loadFavouriteSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? songsJson = prefs.getString('favourite_songs');
    if (songsJson != null) {
      List<dynamic> decoded = jsonDecode(songsJson);
      setState(() {
        favouriteSongs = decoded.map((item) => Map<String, String>.from(item)).toList();
      });
    }
  }

  Future<void> _saveFavouriteSongs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('favourite_songs', jsonEncode(favouriteSongs));
  }

  Future<void> _addMusicFiles() async {
    // The new syntax directly returns a List of PlatformFile objects
    List<PlatformFile> files = await FilePicker.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    ) ?? []; // If the user cancels, it returns an empty list

    if (files.isNotEmpty) {
      setState(() {
        for (var file in files) {
          if (file.path != null) {
            // Clean up the file name to look nice
            String cleanName = file.name.replaceAll('.mp3', '').replaceAll('.wav', '');
            favouriteSongs.add({
              'name': cleanName,
              'path': file.path!,
            });
          }
        }
      });
      await _saveFavouriteSongs();
    }
  }

  Future<void> _deleteSong(int index) async {
    if (currentlyPlayingIndex == index) {
      await _audioPlayer.stop();
      setState(() {
        isPlaying = false;
        currentlyPlayingIndex = null;
      });
    }
    
    setState(() {
      favouriteSongs.removeAt(index);
    });
    await _saveFavouriteSongs();
  }

  Future<void> _playPauseSong(int index, String path) async {
    if (currentlyPlayingIndex == index && isPlaying) {
      await _audioPlayer.pause();
      setState(() => isPlaying = false);
    } else {
      await _audioPlayer.play(DeviceFileSource(path));
      setState(() {
        currentlyPlayingIndex = index;
        isPlaying = true;
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Favourites'),
        centerTitle: true,
        backgroundColor: Colors.redAccent,
      ),
      body: favouriteSongs.isEmpty
          ? const Center(
              child: Text(
                'No favourite songs added yet.\nTap + to add music from your device.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: favouriteSongs.length,
              itemBuilder: (context, index) {
                final song = favouriteSongs[index];
                final isThisPlaying = currentlyPlayingIndex == index && isPlaying;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: isThisPlaying ? Colors.redAccent : Colors.transparent, width: 2)
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isThisPlaying ? Colors.redAccent : Colors.grey.shade200,
                      child: Icon(
                        isThisPlaying ? Icons.music_note : Icons.play_arrow,
                        color: isThisPlaying ? Colors.white : Colors.redAccent,
                      ),
                    ),
                    title: Text(
                      song['name']!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(isThisPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill),
                          color: Colors.redAccent,
                          iconSize: 36,
                          onPressed: () => _playPauseSong(index, song['path']!),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.grey),
                          onPressed: () => _deleteSong(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.redAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Music', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _addMusicFiles,
      ),
    );
  }
}

// class _MusicLibraryScreenState extends State<MusicLibraryScreen> {
  
//   // --- PRE-LOADED FOLDERS AND SONGS ---
//   // Replace the 'add songs X' with your actual paths later
//   // Example: path: 'assets/audio/rain.mp3'
  
//   final List<MusicFolder> folders = [
//   MusicFolder(
//     name: 'Calming Nature',

//     tracks: [
//       MusicTrack(
//         title: 'Ocean Waves',
//         path: 'audio/ocean_waves.mp3',
//       ),
//       MusicTrack(
//         title: 'Forest Birds',
//         path: 'audio/forest_birds.mp3',
//       ),
//       MusicTrack(
//         title: 'Gentle Rain',
//         path: 'audio/gentle_rain.mp3',
//       ),
//     ],
//   ),

//   MusicFolder(
//     name: 'Classical Therapy',

//     tracks: [
//       MusicTrack(
//         title: 'Soft Piano',
//         path: 'audio/soft_piano.mp3',
//       ),
//       MusicTrack(
//         title: 'Relaxing Flute',
//         path: 'audio/relaxing_flute.mp3',
//       ),
//       MusicTrack(
//         title: 'Cello Calm',
//         path: 'audio/cello_calm.mp3',
//       ),
//     ],
//   ),

//   // =========================
//   // REGIONAL MUSIC
//   // =========================

//   MusicFolder(
//     name: 'Regional Music',

//     subFolders: [

//       MusicFolder(
//         name: 'Assam',

//         tracks: [
//           MusicTrack(
//             title: 'Assam Song 1',
//             path: 'assets/audio/assam/song1.mp3',
//           ),
//           MusicTrack(
//             title: 'Assam Song 2',
//             path: 'assets/audio/assam/song2.mp3',
//           ),
//         ],
//       ),

//       MusicFolder(
//         name: 'Meghalaya',

//         tracks: [
//           MusicTrack(
//             title: 'Meghalaya Song 1',
//             path: 'assets/audio/meghalaya/song1.mp3',
//           ),
//           MusicTrack(
//             title: 'Meghalaya Song 2',
//             path: 'assets/audio/meghalaya/song2.mp3',
//           ),
//         ],
//       ),

//       MusicFolder(
//         name: 'Manipur',

//         tracks: [
//           MusicTrack(
//             title: 'Manipur Song 1',
//             path: 'assets/audio/manipur/song1.mp3',
//           ),
//           MusicTrack(
//             title: 'Manipur Song 2',
//             path: 'assets/audio/manipur/song2.mp3',
//           ),
//         ],
//       ),

//       MusicFolder(
//         name: 'Mizo',

//         tracks: [
//           MusicTrack(
//             title: 'Mizo Song 1',
//             path: 'assets/audio/manipur/song1.mp3',
//           ),
//           MusicTrack(
//             title: 'Mizo Song 2',
//             path: 'assets/audio/manipur/song2.mp3',
//           ),
//         ],
//       ),

//       MusicFolder(
//         name: 'Naga',

//         tracks: [
//           MusicTrack(
//             title: 'Naga Song 1',
//             path: 'assets/audio/manipur/song1.mp3',
//           ),
//           MusicTrack(
//             title: 'Naga Song 2',
//             path: 'assets/audio/manipur/song2.mp3',
//           ),
//         ],
//       ),

//       MusicFolder(
//         name: 'Lepcha',

//         tracks: [
//           MusicTrack(
//             title: 'Lepcha Song 1',
//             path: 'assets/audio/manipur/song1.mp3',
//           ),
//           MusicTrack(
//             title: 'Lepcha Song 2',
//             path: 'assets/audio/manipur/song2.mp3',
//           ),
//         ],
//       ),
//     ],
//   ),
// ];


//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Music Therapy'),
//         centerTitle: true,
//       ),
//       body: GridView.builder(
//         padding: const EdgeInsets.all(16),
//         gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//           crossAxisCount: 2,
//           crossAxisSpacing: 16,
//           mainAxisSpacing: 16,
//         ),
//         itemCount: folders.length,
//         itemBuilder: (context, index) {
//           final folder = folders[index];
//           return InkWell(
//             onTap: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (_) => FolderDetailScreen(folder: folder)),
//               );
//             },
//             borderRadius: BorderRadius.circular(15),
//             child: Card(
//               color: Colors.teal.shade50,
//               elevation: 3,
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
//               child: Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     const Icon(Icons.library_music, size: 60, color: Colors.teal),
//                     const SizedBox(height: 10),
//                     Text(
//                       folder.name,
//                       style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                       textAlign: TextAlign.center,
//                     ),
//                     const SizedBox(height: 5),
//                     Text('${folder.tracks.length} songs', style: TextStyle(color: Colors.grey.shade600)),
//                   ],
//                 ),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }

// --- FOLDER DETAIL & AUDIO PLAYER SCREEN ---

class FolderDetailScreen extends StatefulWidget {
  final MusicFolder folder;
  
  const FolderDetailScreen({super.key, required this.folder});

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? currentlyPlayingTitle;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPauseTrack(MusicTrack track) async {
    if (currentlyPlayingTitle == track.title) {
      // If it's already playing, pause it
      await _audioPlayer.pause();
      setState(() => currentlyPlayingTitle = null);
    } else {
      // Stop current song, then play the new one
      await _audioPlayer.stop();
      setState(() => currentlyPlayingTitle = track.title);
      
      try {
        // We use UrlSource as a placeholder. 
        // When you add local assets later, change this to AssetSource(track.path)
        await _audioPlayer.play(AssetSource(track.path)); 
      } catch (e) {
        // Shows a friendly error because "add songs X" isn't a real audio file yet!
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not play "${track.title}". Add the real song path first!'),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
        setState(() => currentlyPlayingTitle = null);
      }
    }

    // Automatically reset the play button when the song finishes naturally
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() => currentlyPlayingTitle = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder.name),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: widget.folder.tracks.length,
        itemBuilder: (context, index) {
          final track = widget.folder.tracks[index];
          bool isPlaying = currentlyPlayingTitle == track.title;

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              leading: CircleAvatar(
                radius: 25,
                backgroundColor: isPlaying ? Colors.teal : Colors.teal.shade100,
                child: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: isPlaying ? Colors.white : Colors.teal,
                  size: 30,
                ),
              ),
              title: Text(
                track.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              onTap: () => _playPauseTrack(track),
            ),
          );
        },
      ),
    );
  }
}


////////////////////////////////////////////////////////
////////////////////////////////////////////////////////

//////       REGIONAL NOSTALGIC MUSIC           //////

////////////////////////////////////////////////////////
////////////////////////////////////////////////////////

// --- Data Model for Regional Songs ---

enum NEState {
  assam, meghalaya, manipur, mizoram, nagaland, tripura, arunachalPradesh, sikkim
}

class RegionalSong {
  final String title;
  final String artist;
  final String era;
  final String description;
  final String audioPath; // unique audio asset path per song

  RegionalSong({
    required this.title,
    required this.artist,
    required this.era,
    required this.description,
    required this.audioPath,
  });
}

class NEStateInfo {
  final NEState state;
  final String displayName;
  final String description;
  final IconData icon;
  final Color color;
  final List<RegionalSong> songs;

  NEStateInfo({
    required this.state,
    required this.displayName,
    required this.description,
    required this.icon,
    required this.color,
    required this.songs,
  });
}

// --- Regional Song Database (1960s-1970s nostalgic folk) ---

final List<NEStateInfo> neStatesData = [
  // ========== ASSAM ==========
  NEStateInfo(
    state: NEState.assam,
    displayName: 'Assam',
    description: 'Traditional Bihu songs, Tokari Geet, Goalpariya Lokogeet & Bodo folk tunes',
    icon: Icons.terrain,
    color: Colors.green,
    songs: [
      RegionalSong(title: 'Bihu Naam - Spring Harvest Song', artist: 'Traditional Bihu Folk', era: '1965', description: 'Classic Bihu dance song celebrating the spring harvest festival', audioPath: 'audio/regional/assam/bihu_naam_spring_harvest.mp3'),
      RegionalSong(title: 'Tokari Geet - Devotional Ballad', artist: 'Assamese Folk Artists', era: '1962', description: 'Traditional Tokari song with ektara accompaniment', audioPath: 'audio/regional/assam/tokari_geet_devotional.mp3'),
      RegionalSong(title: 'Goalpariya Lokogeet - Boatman\'s Song', artist: 'Goalpara Region Folk', era: '1968', description: 'Melodious river song from the Goalpara district', audioPath: 'audio/regional/assam/goalpariya_lokogeet_boatman.mp3'),
      RegionalSong(title: 'Bodo Bwisagu Folk Tune', artist: 'Bodo Tribal Artists', era: '1966', description: 'Traditional Bwisagu festival song of the Bodo people', audioPath: 'audio/regional/assam/bodo_bwisagu_folk.mp3'),
      RegionalSong(title: 'Jhumur Nritya Geet', artist: 'Tea Garden Folk', era: '1970', description: 'Rhythmic Jhumur dance song from Assam\'s tea gardens', audioPath: 'audio/regional/assam/jhumur_nritya_geet.mp3'),
      RegionalSong(title: 'Ojapali Traditional Chant', artist: 'Assamese Traditional', era: '1963', description: 'Ancient Ojapali narrative folk performance', audioPath: 'audio/regional/assam/ojapali_traditional_chant.mp3'),
    ],
  ),
  // ========== MEGHALAYA ==========
  NEStateInfo(
    state: NEState.meghalaya,
    displayName: 'Meghalaya',
    description: 'Khasi & Garo folk songs, traditional Phawar & Wangala rhythms',
    icon: Icons.cloud,
    color: Colors.blue,
    songs: [
      RegionalSong(title: 'Phawar - Khasi Love Ballad', artist: 'Khasi Folk Tradition', era: '1964', description: 'Traditional poetic folk song of the Khasi hills', audioPath: 'audio/regional/meghalaya/phawar_khasi_love_ballad.mp3'),
      RegionalSong(title: 'Wangala Drum Song', artist: 'Garo Tribal Artists', era: '1967', description: 'Harvest festival song of the Garo tribe with traditional drums', audioPath: 'audio/regional/meghalaya/wangala_drum_song.mp3'),
      RegionalSong(title: 'Laho Dance Folk Tune', artist: 'Khasi Youth Folk', era: '1969', description: 'Lively group dance song from Shillong hills', audioPath: 'audio/regional/meghalaya/laho_dance_folk.mp3'),
      RegionalSong(title: 'Doregala - Garo Lullaby', artist: 'Garo Mothers\' Folk', era: '1961', description: 'Gentle lullaby passed down through Garo generations', audioPath: 'audio/regional/meghalaya/doregala_garo_lullaby.mp3'),
      RegionalSong(title: 'Nongkrem Festival Song', artist: 'Khasi Traditional', era: '1966', description: 'Sacred song from the Nongkrem harvest thanksgiving', audioPath: 'audio/regional/meghalaya/nongkrem_festival_song.mp3'),
    ],
  ),
  // ========== MANIPUR ==========
  NEStateInfo(
    state: NEState.manipur,
    displayName: 'Manipur',
    description: 'Lai Haraoba folk songs, Khullang Eshei & Pena-accompanied tracks',
    icon: Icons.sports_soccer,
    color: Colors.orange,
    songs: [
      RegionalSong(title: 'Lai Haraoba Ritual Song', artist: 'Meitei Traditional', era: '1963', description: 'Ancient ritualistic folk song from Lai Haraoba festival', audioPath: 'audio/regional/manipur/lai_haraoba_ritual_song.mp3'),
      RegionalSong(title: 'Khullang Eshei - Martial Ballad', artist: 'Manipuri Folk', era: '1965', description: 'Traditional heroic ballad celebrating martial arts', audioPath: 'audio/regional/manipur/khullang_eshei_martial.mp3'),
      RegionalSong(title: 'Pena Eshei - Lute Song', artist: 'Pena Folk Artists', era: '1968', description: 'Accompanied by the traditional Pena stringed instrument', audioPath: 'audio/regional/manipur/pena_eshei_lute_song.mp3'),
      RegionalSong(title: 'Nupa Pala - Dance Song', artist: 'Manipuri Classical Folk', era: '1962', description: 'Ras Lila inspired folk dance composition', audioPath: 'audio/regional/manipur/nupa_pala_dance_song.mp3'),
      RegionalSong(title: 'Thabal Chongba Moon Dance', artist: 'Meitei Youth Folk', era: '1970', description: 'Full moon festival dance song of the Meitei community', audioPath: 'audio/regional/manipur/thabal_chongba_moon_dance.mp3'),
    ],
  ),
  // ========== MIZORAM ==========
  NEStateInfo(
    state: NEState.mizoram,
    displayName: 'Mizoram',
    description: 'Traditional Lengzem, Cheraw drum/gong folk rhythms',
    icon: Icons.park,
    color: Colors.purple,
    songs: [
      RegionalSong(title: 'Cheraw Bamboo Dance Rhythm', artist: 'Mizo Traditional', era: '1964', description: 'Accompaniment for the famous Cheraw bamboo dance', audioPath: 'audio/regional/mizoram/cheraw_bamboo_dance.mp3'),
      RegionalSong(title: 'Lengzem - Mizo Folk Ballad', artist: 'Mizo Folk Artists', era: '1967', description: 'Traditional Lengzem narrative folk song', audioPath: 'audio/regional/mizoram/lengzem_folk_ballad.mp3'),
      RegionalSong(title: 'Chai Lam - Celebration Song', artist: 'Mizo Community', era: '1969', description: 'Joyous song for community celebrations and feasts', audioPath: 'audio/regional/mizoram/chai_lam_celebration.mp3'),
      RegionalSong(title: 'Sap Tlang - Bamboo Grove Song', artist: 'Mizo Hill Folk', era: '1963', description: 'Nature-inspired folk tune about the bamboo forests', audioPath: 'audio/regional/mizoram/sap_tlang_bamboo_grove.mp3'),
      RegionalSong(title: 'Chhawnghnawh - New Year Song', artist: 'Mizo Traditional', era: '1966', description: 'Traditional Pawl Kut harvest festival song', audioPath: 'audio/regional/mizoram/chhawnghnawh_new_year.mp3'),
    ],
  ),
  // ========== NAGALAND ==========
  NEStateInfo(
    state: NEState.nagaland,
    displayName: 'Nagaland',
    description: 'Angami, Ao & Tenyidie traditional folk chants and songs',
    icon: Icons.filter_hdr,
    color: Colors.red,
    songs: [
      RegionalSong(title: 'Angami War Chant', artist: 'Angami Tribal', era: '1962', description: 'Traditional warrior chant of the Angami Naga', audioPath: 'audio/regional/nagaland/angami_war_chant.mp3'),
      RegionalSong(title: 'Ao Morung Folk Song', artist: 'Ao Naga Artists', era: '1965', description: 'Song from the traditional bachelor\'s dormitory', audioPath: 'audio/regional/nagaland/ao_morung_folk_song.mp3'),
      RegionalSong(title: 'Tenyidie Harvest Song', artist: 'Angami Folk', era: '1968', description: 'Harvest celebration song in Tenyidie language', audioPath: 'audio/regional/nagaland/tenyidie_harvest_song.mp3'),
      RegionalSong(title: 'Sekrenyi Festival Tune', artist: 'Kohima Region Folk', era: '1964', description: 'Traditional purification festival song', audioPath: 'audio/regional/nagaland/sekrenyi_festival_tune.mp3'),
      RegionalSong(title: 'Konyak Headhunters\' Chant', artist: 'Konyak Tribal', era: '1960', description: 'Rare recording of ancient Konyak ceremonial chant', audioPath: 'audio/regional/nagaland/konyak_headhunters_chant.mp3'),
    ],
  ),
  // ========== TRIPURA ==========
  NEStateInfo(
    state: NEState.tripura,
    displayName: 'Tripura',
    description: 'Tripuri & Reang folk music, Dhamail songs',
    icon: Icons.local_florist,
    color: Colors.teal,
    songs: [
      RegionalSong(title: 'Dhamail Dance Song', artist: 'Tripuri Tribal', era: '1966', description: 'Traditional Dhamail circle dance song', audioPath: 'audio/regional/tripura/dhamail_dance_song.mp3'),
      RegionalSong(title: 'Hojagiri Ritual Tune', artist: 'Reang Community', era: '1963', description: 'Sacred Hojagiri performance folk song', audioPath: 'audio/regional/tripura/hojagiri_ritual_tune.mp3'),
      RegionalSong(title: 'Goria Puja Folk Song', artist: 'Tripuri Farmers', era: '1968', description: 'Agricultural festival song of the Tripuri people', audioPath: 'audio/regional/tripura/goria_puja_folk_song.mp3'),
      RegionalSong(title: 'Maimiti - Tripuri Lullaby', artist: 'Tripuri Mothers\' Folk', era: '1961', description: 'Gentle lullaby in Kokborok language', audioPath: 'audio/regional/tripura/maimiti_tripuri_lullaby.mp3'),
      RegionalSong(title: 'Jhum Cultivation Song', artist: 'Reang Tribal', era: '1970', description: 'Song accompanying jhum cultivation activities', audioPath: 'audio/regional/tripura/jhum_cultivation_song.mp3'),
    ],
  ),
  // ========== ARUNACHAL PRADESH ==========
  NEStateInfo(
    state: NEState.arunachalPradesh,
    displayName: 'Arunachal Pradesh',
    description: 'Nyishi, Galo & Apatani traditional folk songs',
    icon: Icons.landscape,
    color: Colors.indigo,
    songs: [
      RegionalSong(title: 'Apatani Rice Song', artist: 'Apatani Tribal', era: '1964', description: 'Song accompanying paddy field cultivation', audioPath: 'audio/regional/arunachal/apatani_rice_song.mp3'),
      RegionalSong(title: 'Nyishi Community Dance', artist: 'Nyishi Artists', era: '1967', description: 'Traditional Torgya festival community song', audioPath: 'audio/regional/arunachal/nyishi_community_dance.mp3'),
      RegionalSong(title: 'Galo Myoko Festival Tune', artist: 'Galo Folk', era: '1969', description: 'Sacred song from the Myoko purification festival', audioPath: 'audio/regional/arunachal/galo_myoko_festival.mp3'),
      RegionalSong(title: 'Wancho War Dance Chant', artist: 'Wancho Tribal', era: '1962', description: 'Traditional warrior dance accompaniment', audioPath: 'audio/regional/arunachal/wancho_war_dance.mp3'),
      RegionalSong(title: 'Monpa Buddhist Chant', artist: 'Tawang Region', era: '1965', description: 'Spiritual folk chant from the Monpa community', audioPath: 'audio/regional/arunachal/monpa_buddhist_chant.mp3'),
    ],
  ),
  // ========== SIKKIM ==========
  NEStateInfo(
    state: NEState.sikkim,
    displayName: 'Sikkim',
    description: 'Lepcha & Bhutia traditional folk tunes',
    icon: Icons.ac_unit,
    color: Colors.cyan,
    songs: [
      RegionalSong(title: 'Lepcha Tendong Song', artist: 'Lepcha Traditional', era: '1963', description: 'Traditional song invoking the Tendong mountain spirit', audioPath: 'audio/regional/sikkim/lepcha_tendong_song.mp3'),
      RegionalSong(title: 'Bhutia Losar Folk Tune', artist: 'Bhutia Community', era: '1966', description: 'New Year celebration song of the Bhutia people', audioPath: 'audio/regional/sikkim/bhutia_losar_folk.mp3'),
      RegionalSong(title: 'Chaam Dance Chant', artist: 'Sikkimese Monks', era: '1968', description: 'Sacred Buddhist masked dance accompaniment', audioPath: 'audio/regional/sikkim/chaam_dance_chant.mp3'),
      RegionalSong(title: 'Tamang Selo Rhythm', artist: 'Tamang Folk', era: '1965', description: 'Rhythmic folk tune played on the Damphu drum', audioPath: 'audio/regional/sikkim/tamang_selo_rhythm.mp3'),
      RegionalSong(title: 'Limbu Mundhum Chant', artist: 'Limbu Tribal', era: '1961', description: 'Ancient creation myth recitation of the Limbu people', audioPath: 'audio/regional/sikkim/limbu_mundhum_chant.mp3'),
    ],
  ),
];


// --- REGIONAL MUSIC SELECTION SCREEN ---

class RegionalMusicScreen extends StatelessWidget {
  const RegionalMusicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Regional Nostalgic Music'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          // Header card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Colors.deepPurple.shade50,
            child: Column(
              children: [
                Icon(Icons.album, size: 48, color: Colors.deepPurple.shade300),
                const SizedBox(height: 8),
                const Text(
                  'Nostalgic Folk Music from\nNortheast India',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                ),
                const SizedBox(height: 4),
                Text(
                  'Vintage recordings from the 1960s–1970s era',
                  style: TextStyle(fontSize: 14, color: Colors.deepPurple.shade300),
                ),
              ],
            ),
          ),

          // State list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: neStatesData.length,
              itemBuilder: (context, index) {
                final stateInfo = neStatesData[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor: stateInfo.color.withValues(alpha: 0.15),
                        child: Icon(stateInfo.icon, color: stateInfo.color, size: 30),
                      ),
                      title: Text(
                        stateInfo.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      subtitle: Text(
                        '${stateInfo.songs.length} vintage tracks',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios, color: stateInfo.color, size: 20),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StateFolkListScreen(stateInfo: stateInfo),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


// --- STATE FOLK LIST SCREEN ---

class StateFolkListScreen extends StatelessWidget {
  final NEStateInfo stateInfo;

  const StateFolkListScreen({super.key, required this.stateInfo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${stateInfo.displayName} Folk Music'),
        centerTitle: true,
        backgroundColor: stateInfo.color,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // State header
          Container(
            padding: const EdgeInsets.all(20),
            color: stateInfo.color.withValues(alpha: 0.08),
            child: Column(
              children: [
                Icon(stateInfo.icon, size: 48, color: stateInfo.color),
                const SizedBox(height: 8),
                Text(
                  stateInfo.displayName,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: stateInfo.color),
                ),
                const SizedBox(height: 4),
                Text(
                  stateInfo.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

          // Song list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: stateInfo.songs.length,
              itemBuilder: (context, index) {
                final song = stateInfo.songs[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: stateInfo.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.audiotrack, color: stateInfo.color, size: 28),
                    ),
                    title: Text(
                      song.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(song.artist, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        Text('${song.era} · ${song.description}', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: Icon(Icons.play_circle_fill, color: stateInfo.color, size: 36),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RegionalAudioPlayerScreen(
                            song: song,
                            stateInfo: stateInfo,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


// --- DEMENTIA-FRIENDLY REGIONAL AUDIO PLAYER ---

class RegionalAudioPlayerScreen extends StatefulWidget {
  final RegionalSong song;
  final NEStateInfo stateInfo;

  const RegionalAudioPlayerScreen({
    super.key,
    required this.song,
    required this.stateInfo,
  });

  @override
  State<RegionalAudioPlayerScreen> createState() => _RegionalAudioPlayerScreenState();
}

class _RegionalAudioPlayerScreenState extends State<RegionalAudioPlayerScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLooping = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = const Duration(minutes: 3, seconds: 30);
  int _loopCount = 0;
  DateTime? _playStartTime;
  int _totalListeningSeconds = 0;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
        if (state == PlayerState.playing && _playStartTime == null) {
          _playStartTime = DateTime.now();
        }
        if (state == PlayerState.completed) {
          _loopCount++;
          _trackListeningTime();
          if (_isLooping) {
            _audioPlayer.play(AssetSource(widget.song.audioPath));
          }
        }
      }
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _totalDuration = duration);
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) setState(() => _currentPosition = position);
    });
  }

  void _trackListeningTime() {
    if (_playStartTime != null) {
      _totalListeningSeconds += DateTime.now().difference(_playStartTime!).inSeconds;
      _playStartTime = DateTime.now();
    }
  }

  @override
  void dispose() {
    _trackListeningTime();
    _savePlayLog();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _savePlayLog() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('sqlite_user_id') ?? "";
    if (userId.isNotEmpty && _totalListeningSeconds > 0) {
      await DatabaseHelper.instance.insertRegionalMusicPlay(
        userId: userId,
        stateName: widget.stateInfo.displayName,
        songTitle: widget.song.title,
        durationSeconds: _totalListeningSeconds,
        loopCount: _loopCount,
        emotionalState: _predictEmotionalState(),
        cognitiveResponse: _predictCognitiveResponse(),
      );
    }
  }

  String _predictEmotionalState() {
    // Simple heuristic-based prediction (ML service would enhance this)
    if (_totalListeningSeconds > 120 && _loopCount >= 2) {
      return 'Deep Reminiscence & Nostalgic Joy';
    } else if (_totalListeningSeconds > 60 && _loopCount >= 1) {
      return 'Calm & Engaged';
    } else if (_totalListeningSeconds > 30) {
      return 'Relaxed Listening';
    }
    return 'Initial Exploration';
  }

  String _predictCognitiveResponse() {
    if (_loopCount >= 3) return 'Strong Emotional Resonance - Fixation Detected';
    if (_loopCount >= 1) return 'Active Engagement & Memory Association';
    if (_totalListeningSeconds > 60) return 'Sustained Attention & Cognitive Focus';
    return 'Processing New Stimulus';
  }

  String _formatDuration(Duration d) {
    String minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    String seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      _trackListeningTime();
    } else {
      try {
        await _audioPlayer.play(AssetSource(widget.song.audioPath));
        _playStartTime ??= DateTime.now();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Audio file not found. Place the .mp3 at:\n${widget.song.audioPath}'),
              backgroundColor: Colors.teal.shade400,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  void _toggleLoop() {
    setState(() => _isLooping = !_isLooping);
    _audioPlayer.setReleaseMode(_isLooping ? ReleaseMode.loop : ReleaseMode.release);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Now Playing'),
        centerTitle: true,
        backgroundColor: widget.stateInfo.color,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Album art placeholder
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.stateInfo.color.withValues(alpha: 0.1),
                boxShadow: [
                  BoxShadow(
                    color: widget.stateInfo.color.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                widget.stateInfo.icon,
                size: 80,
                color: widget.stateInfo.color,
              ),
            ),
            const SizedBox(height: 30),

            // Song title
            Text(
              widget.song.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Artist & state
            Text(
              widget.song.artist,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: widget.stateInfo.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${widget.stateInfo.displayName} · ${widget.song.era}',
                style: TextStyle(fontSize: 13, color: widget.stateInfo.color, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 30),

            // Progress bar
            Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 8,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                    activeTrackColor: widget.stateInfo.color,
                    inactiveTrackColor: widget.stateInfo.color.withValues(alpha: 0.2),
                    thumbColor: widget.stateInfo.color,
                  ),
                  child: Slider(
                    value: _currentPosition.inSeconds.toDouble(),
                    max: _totalDuration.inSeconds.toDouble().clamp(1, double.infinity),
                    onChanged: (value) {
                      _audioPlayer.seek(Duration(seconds: value.toInt()));
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(_currentPosition), style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                      Text(_formatDuration(_totalDuration), style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Play/Pause - large target
            SizedBox(
              width: 80,
              height: 80,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  backgroundColor: widget.stateInfo.color,
                  elevation: 6,
                ),
                onPressed: _togglePlay,
                child: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Loop toggle - large target
            SizedBox(
              width: 64,
              height: 64,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  backgroundColor: _isLooping ? widget.stateInfo.color.withValues(alpha: 0.2) : Colors.grey.shade200,
                  elevation: 2,
                ),
                onPressed: _toggleLoop,
                child: Icon(
                  Icons.repeat,
                  color: _isLooping ? widget.stateInfo.color : Colors.grey,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isLooping ? 'Looping On' : 'Loop Off',
              style: TextStyle(
                fontSize: 14,
                color: _isLooping ? widget.stateInfo.color : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 30),

            // Listening stats card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Listening Session',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: widget.stateInfo.color),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStat('Duration', '${_totalListeningSeconds}s', Icons.timer),
                        _buildStat('Loops', '$_loopCount', Icons.repeat),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Gentle description
            Card(
              color: Colors.amber.shade50,
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Text(
                  widget.song.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: widget.stateInfo.color, size: 24),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}


////////////////////////////////////////////////////////
////////////////////////////////////////////////////////

//////               REMINDERS                    //////

////////////////////////////////////////////////////////
////////////////////////////////////////////////////////

class RemindersSelectionScreen extends StatelessWidget {
  const RemindersSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            tileColor: Colors.white,
            leading: const Icon(Icons.medication, color: Colors.redAccent, size: 40),
            title: const Text('Medicine', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            subtitle: const Text('Daily medicine tracker'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MedicineScreen())),
          ),
          const SizedBox(height: 12),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            tileColor: Colors.white,
            leading: const Icon(Icons.medical_information, color: Colors.blue, size: 40),
            title: const Text('Doctor Appointments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            subtitle: const Text('Upcoming checkups and visits'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DoctorAppointmentScreen())),
          ),
        ],
      ),
    );
  }
}

// --- MEDICINE SCREEN & LOGIC ---

// --- MEDICINE SCREEN & LOGIC ---

class MedicineItem {
  String id;
  String name;
  String time;
  bool isChecked;
  String lastCheckedDate;

  MedicineItem({required this.id, required this.name, required this.time, this.isChecked = false, this.lastCheckedDate = ''});

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'time': time, 'isChecked': isChecked, 'lastCheckedDate': lastCheckedDate,
  };

  factory MedicineItem.fromJson(Map<String, dynamic> json) => MedicineItem(
    id: json['id'], name: json['name'], time: json['time'], isChecked: json['isChecked'], lastCheckedDate: json['lastCheckedDate'] ?? '',
  );
}

class MedicineScreen extends StatefulWidget {
  const MedicineScreen({super.key});

  @override
  State<MedicineScreen> createState() => _MedicineScreenState();
}

class _MedicineScreenState extends State<MedicineScreen> {
  List<MedicineItem> medicines = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  Future<void> _loadMedicines() async {
    final prefs = await SharedPreferences.getInstance();
    String? medsJson = prefs.getString('medicine_list');
    
    DateTime now = DateTime.now();
    String todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    if (medsJson != null) {
      List<dynamic> decoded = jsonDecode(medsJson);
      medicines = decoded.map((item) => MedicineItem.fromJson(item)).toList();
      
      bool hasUpdates = false;

      for (var med in medicines) {
        // If the date has rolled over to a new day
        if (med.lastCheckedDate.isNotEmpty && med.lastCheckedDate != todayStr) {
          // If the medicine was left unchecked, send the missed alert to the caregiver
          if (!med.isChecked) {
            await CaregiverAlertService.sendMissedAlert(
              'Medicine',
              med.name,
              med.time,
            );
          }
          
          // Reset checkbox for today
          med.isChecked = false;
          hasUpdates = true;
        }
      }

      // Persist the reset state so alerts are not triggered repeatedly on every reload
      if (hasUpdates) {
        await _saveMedicines();
      }
    }
    
    setState(() => isLoading = false);
  }

  Future<void> _saveMedicines() async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> jsonList = medicines.map((m) => m.toJson()).toList();
    await prefs.setString('medicine_list', jsonEncode(jsonList));
  }

  void _showMedicineDialog({MedicineItem? existingMed, int? index}) {
    TextEditingController nameController = TextEditingController(text: existingMed?.name ?? '');
    TimeOfDay selectedTime = TimeOfDay.now();
    String timeString = existingMed?.time ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existingMed == null ? 'Add Medicine' : 'Edit Medicine'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Medicine Name', border: OutlineInputBorder()),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.access_time, color: Colors.teal),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(timeString.isEmpty ? 'Select Time' : timeString, style: const TextStyle(fontSize: 16)),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final TimeOfDay? time = await showTimePicker(context: context, initialTime: selectedTime);
                          if (time != null) {
                            setDialogState(() {
                              selectedTime = time;
                              timeString = time.format(context);
                            });
                          }
                        },
                        child: const Text('Pick Time'),
                      )
                    ],
                  )
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: () {
                    if (nameController.text.trim().isNotEmpty && timeString.isNotEmpty) {
                      setState(() {
                        if (existingMed == null) {
                          String newId = DateTime.now().millisecondsSinceEpoch.toString();
                          medicines.add(MedicineItem(id: newId, name: nameController.text.trim(), time: timeString));
                          
                          // --- NEW: SCHEDULE MEDICINE NOTIFICATION ---
                          NotificationService.instance.scheduleDailyTimeNotification(
                            id: newId.hashCode,
                            title: 'Medicine Reminder 💊',
                            body: 'Time to take: ${nameController.text.trim()}',
                            hour: selectedTime.hour,
                            minute: selectedTime.minute,
                          );
                        } else {
                          medicines[index!].name = nameController.text.trim();
                          medicines[index].time = timeString;

                          // --- NEW: UPDATE MEDICINE NOTIFICATION ---
                          NotificationService.instance.scheduleDailyTimeNotification(
                            id: existingMed.id.hashCode,
                            title: 'Medicine Reminder 💊',
                            body: 'Time to take: ${nameController.text.trim()}',
                            hour: selectedTime.hour,
                            minute: selectedTime.minute,
                          );
                        }
                      });
                      _saveMedicines();
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Save'),
                )
              ],
            );
          }
        );
      },
    );
  }

  void _toggleMedication(int index) {
    setState(() {
      medicines[index].isChecked = !medicines[index].isChecked;
      if (medicines[index].isChecked) {
        DateTime now = DateTime.now();
        medicines[index].lastCheckedDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      } else {
        medicines[index].lastCheckedDate = '';
      }
    });
    _saveMedicines();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Medicine Chart'), centerTitle: true),
      body: medicines.isEmpty 
          ? const Center(child: Text('No medicines added yet.', style: TextStyle(color: Colors.grey, fontSize: 18)))
          : Column(
              children: [
                Container(
                  color: Colors.teal.shade100,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: const Row(
                    children: [
                      Expanded(flex: 3, child: Text('Medicine Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                      Expanded(flex: 2, child: Text('Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                      SizedBox(width: 48),
                      SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: medicines.length,
                    itemBuilder: (context, index) {
                      final med = medicines[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: Text(med.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
                              Expanded(flex: 2, child: Text(med.time, style: const TextStyle(fontSize: 16))),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blueGrey),
                                onPressed: () => _showMedicineDialog(existingMed: med, index: index),
                              ),
                              Checkbox(
                                value: med.isChecked,
                                activeColor: Colors.green,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                onChanged: (bool? value) => _toggleMedication(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        onPressed: () => _showMedicineDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// --- DOCTOR APPOINTMENTS SCREEN & LOGIC ---

class DoctorAppointment {
  String id;
  String name;
  String dateTimeStr;

  DoctorAppointment({required this.id, required this.name, required this.dateTimeStr});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'dateTimeStr': dateTimeStr};
  factory DoctorAppointment.fromJson(Map<String, dynamic> json) => DoctorAppointment(id: json['id'], name: json['name'], dateTimeStr: json['dateTimeStr']);
}

class DoctorAppointmentScreen extends StatefulWidget {
  const DoctorAppointmentScreen({super.key});

  @override
  State<DoctorAppointmentScreen> createState() => _DoctorAppointmentScreenState();
}

class _DoctorAppointmentScreenState extends State<DoctorAppointmentScreen> {
  List<DoctorAppointment> appointments = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    final prefs = await SharedPreferences.getInstance();
    String? apptsJson = prefs.getString('appointment_list');
    if (apptsJson != null) {
      List<dynamic> decoded = jsonDecode(apptsJson);
      appointments = decoded.map((item) => DoctorAppointment.fromJson(item)).toList();
    }
    setState(() => isLoading = false);
  }

  Future<void> _saveAppointments() async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> jsonList = appointments.map((a) => a.toJson()).toList();
    await prefs.setString('appointment_list', jsonEncode(jsonList));
  }

  void _showAppointmentDialog({DoctorAppointment? existingAppt, int? index}) {
    TextEditingController nameController = TextEditingController(text: existingAppt?.name ?? '');
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    String combinedDateTime = existingAppt?.dateTimeStr ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existingAppt == null ? 'Add Appointment' : 'Edit Appointment'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Doctor / Clinic Name', border: OutlineInputBorder()),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month, color: Colors.blue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(combinedDateTime.isEmpty ? 'Select Date & Time' : combinedDateTime, style: const TextStyle(fontSize: 14)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_calendar, color: Colors.blue),
                        onPressed: () async {
                          final DateTime? date = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime(2030));
                          if (date != null) {
                            if (!context.mounted) return;
                            final TimeOfDay? time = await showTimePicker(context: context, initialTime: selectedTime);
                            if (time != null) {
                              setDialogState(() {
                                selectedDate = date;
                                selectedTime = time;
                                String formattedDate = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
                                combinedDateTime = "$formattedDate, ${time.format(context)}";
                              });
                            }
                          }
                        },
                      )
                    ],
                  )
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  onPressed: () {
                    if (nameController.text.trim().isNotEmpty && combinedDateTime.isNotEmpty) {
                      
                      // Construct the exact DateTime for the notification scheduling
                      DateTime appointmentDateTime = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      );

                      setState(() {
                        if (existingAppt == null) {
                          String newId = DateTime.now().millisecondsSinceEpoch.toString();
                          appointments.add(DoctorAppointment(id: newId, name: nameController.text.trim(), dateTimeStr: combinedDateTime));
                          
                          // --- NEW: SCHEDULE APPOINTMENT NOTIFICATION ---
                          NotificationService.instance.scheduleAppointmentNotification(
                            id: newId.hashCode,
                            doctorName: nameController.text.trim(),
                            appointmentDateTime: appointmentDateTime,
                          );
                        } else {
                          appointments[index!].name = nameController.text.trim();
                          appointments[index].dateTimeStr = combinedDateTime;

                          // --- NEW: UPDATE APPOINTMENT NOTIFICATION ---
                          NotificationService.instance.scheduleAppointmentNotification(
                            id: existingAppt.id.hashCode,
                            doctorName: nameController.text.trim(),
                            appointmentDateTime: appointmentDateTime,
                          );
                        }
                      });
                      _saveAppointments();
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Save'),
                )
              ],
            );
          }
        );
      },
    );
  }

  void _completeAppointment(int index) {
    // --- NEW: CANCEL NOTIFICATION ON COMPLETION ---
    NotificationService.instance.cancelNotification(appointments[index].id.hashCode);

    setState(() {
      appointments.removeAt(index);
    });
    _saveAppointments();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Appointment completed and removed.'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Doctor Appointments'), centerTitle: true),
      body: appointments.isEmpty 
          ? const Center(child: Text('No upcoming appointments.', style: TextStyle(color: Colors.grey, fontSize: 18)))
          : Column(
              children: [
                Container(
                  color: Colors.blue.shade100,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: const Row(
                    children: [
                      Expanded(flex: 3, child: Text('Doctor/Clinic', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                      Expanded(flex: 3, child: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                      SizedBox(width: 40),
                      SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: appointments.length,
                    itemBuilder: (context, index) {
                      final appt = appointments[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: Text(appt.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
                              Expanded(flex: 3, child: Text(appt.dateTimeStr, style: const TextStyle(fontSize: 14))),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blueGrey, size: 20),
                                onPressed: () => _showAppointmentDialog(existingAppt: appt, index: index),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 12),
                              Checkbox(
                                value: false,
                                activeColor: Colors.green,
                                shape: const CircleBorder(), 
                                onChanged: (bool? value) {
                                  if (value == true) {
                                    _completeAppointment(index);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        onPressed: () => _showAppointmentDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

///////////////////////////////////////////////////
///////////////////////////////////////////////////
///
///               ACCOUNT
///
///////////////////////////////////////////////////
///////////////////////////////////////////////////





class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  String registrationNumber = "Loading...";
  String name = "Loading...";
  String email = "Loading...";
  String phone = "Loading...";
  String address = "Loading...";
  Uint8List? profilePhotoBytes;
  
  // Changed from 'final' to dynamic integers so they can update from the DB
  int highestStreak = 0;
  int highestScore = 0;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Fetch SQLite Data for Scores
    final String userId = prefs.getString('sqlite_user_id') ?? "";
    int dbCumulativeScore = 0;
    int dbCurrentStreak = 0;

    if (userId.isNotEmpty) {
      final dbHelper = DatabaseHelper.instance;
      final patients = await dbHelper.getAllPatients();
      
      // Find the logged-in patient in the database
      final patient = patients.firstWhere(
        (p) => p['user_id'] == userId,
        orElse: () => {},
      );

      if (patient.isNotEmpty) {
        dbCumulativeScore = patient['cumulative_score'] as int? ?? 0;
        dbCurrentStreak = patient['current_streak'] as int? ?? 0;
      }
    }

    // 2. Calculate All-Time Highest Streak
    // Since current_streak resets when a day is missed, we save the historical highest
    int savedHighestStreak = prefs.getInt('highest_historical_streak') ?? 0;
    if (dbCurrentStreak > savedHighestStreak) {
      savedHighestStreak = dbCurrentStreak;
      await prefs.setInt('highest_historical_streak', savedHighestStreak);
    }
    
    setState(() {
      // Load SharedPreferences text data
      registrationNumber = prefs.getString('user_registration_number') ?? "Not Assigned";
      name = prefs.getString('user_name') ?? "Guest User";
      email = prefs.getString('user_email') ?? "No email provided";
      phone = prefs.getString('user_phone') ?? "No phone provided";
      address = prefs.getString('user_address') ?? "No address provided";
      
      // Set the dynamic score values
      highestScore = dbCumulativeScore; // Cumulative score acts as the all-time high
      highestStreak = savedHighestStreak; 

      // Load Profile Photo
      String? savedPhotoString = prefs.getString('user_photo');
      if (savedPhotoString != null) {
        profilePhotoBytes = base64Decode(savedPhotoString);
      }
    });
  }

  void _editField(String title, String currentValue, Function(String) onSave) {
    TextEditingController controller = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $title'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter new $title',
            border: const OutlineInputBorder(),
          ),
          maxLines: title == 'Address' ? 3 : 1,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                onSave(controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          )
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sqlite_user_id');
    await prefs.remove('user_registration_number');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_phone');
    await prefs.remove('user_role');
    
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Account'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Log Out',
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.teal.shade100,
                    backgroundImage: profilePhotoBytes != null 
                        ? MemoryImage(profilePhotoBytes!) 
                        : null,
                    child: profilePhotoBytes == null 
                        ? const Icon(Icons.person, size: 60, color: Colors.teal) 
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.pin, color: Colors.teal),
                      title: const Text('Registration Number', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      subtitle: Text(registrationNumber, style: const TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.lock_outline, color: Colors.grey, size: 20),
                    ),
                    const Divider(height: 1),
                    
                    ListTile(
                      leading: const Icon(Icons.badge, color: Colors.teal),
                      title: const Text('Name', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      subtitle: Text(name, style: const TextStyle(fontSize: 18, color: Colors.black87)),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.teal),
                        onPressed: () => _editField('Name', name, (newValue) {
                          setState(() => name = newValue);
                        }),
                      ),
                    ),
                    const Divider(height: 1),
                    
                    ListTile(
                      leading: const Icon(Icons.email, color: Colors.teal),
                      title: const Text('Email ID', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      subtitle: Text(email, style: const TextStyle(fontSize: 16, color: Colors.black87)),
                      trailing: const Icon(Icons.lock_outline, color: Colors.grey, size: 20),
                    ),
                    const Divider(height: 1),
                    
                    ListTile(
                      leading: const Icon(Icons.phone, color: Colors.teal),
                      title: const Text('Phone Number', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      subtitle: Text(phone, style: const TextStyle(fontSize: 16, color: Colors.black87)),
                      trailing: const Icon(Icons.lock_outline, color: Colors.grey, size: 20),
                    ),
                    const Divider(height: 1),
                    
                    ListTile(
                      leading: const Icon(Icons.home, color: Colors.teal),
                      title: const Text('Address', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      subtitle: Text(address, style: const TextStyle(fontSize: 16, color: Colors.black87)),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.teal),
                        onPressed: () => _editField('Address', address, (newValue) {
                          setState(() => address = newValue);
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),

            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
                child: Text(
                  'All-Time Records',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: Colors.orange.shade50,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Column(
                        children: [
                          const Icon(Icons.local_fire_department, color: Colors.orange, size: 40),
                          const SizedBox(height: 10),
                          Text(
                            '$highestStreak Days',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const Text('Highest Streak', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Card(
                    color: Colors.amber.shade50,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Column(
                        children: [
                          const Icon(Icons.emoji_events, color: Colors.amber, size: 40),
                          const SizedBox(height: 10),
                          Text(
                            '$highestScore',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const Text('Highest Score', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


//////////////////////////////////////////////////
//////////////////////////////////////////////////
///                                            ///
///              LANGUAGE SETTING              ///
///                                            ///
//////////////////////////////////////////////////
//////////////////////////////////////////////////


class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  // Default to English
  Locale currentLocale = const Locale('en', 'US');

  final List<Map<String, dynamic>> supportedLanguages = const [
    {'name': 'English', 'locale': Locale('en', 'US')},
    {'name': 'हिन्दी', 'locale': Locale('hi', 'IN')},
    {'name': 'বাংলা', 'locale': Locale('bn', 'IN')},
    {'name': 'தமிழ்', 'locale': Locale('ta', 'IN')},
    {'name': 'తెలుగు', 'locale': Locale('te', 'IN')},
    {'name': 'मराठी', 'locale': Locale('mr', 'IN')},
    {'name': 'ગુજરાતી', 'locale': Locale('gu', 'IN')},
    {'name': 'অসমীয়া', 'locale': Locale('as', 'IN')},
    {'name': 'नेपाली', 'locale': Locale('ne', 'IN')},
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedLanguage();
  }

  // Loads the language from memory when the screen opens
  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedLangCode = prefs.getString('app_language');

    if (savedLangCode != null) {
      setState(() {
        // Find the matching locale from our list
        currentLocale = supportedLanguages.firstWhere(
          (lang) => lang['locale'].languageCode == savedLangCode,
          orElse: () => supportedLanguages[0],
        )['locale'];
      });
    }
  }

  void _confirmLanguageChange(Map<String, dynamic> language) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('Change Language?'),
          content: Text('Are you sure you want to change the app language to ${language['name']}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext), 
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () async {
                Navigator.pop(dialogContext); // Close dialog
                
                // 1. Visually update the checkmark
                setState(() {
                  currentLocale = language['locale'];
                });

                // 2. Save the choice permanently to the device/browser
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('app_language', language['locale'].languageCode);
                
                // 3. Show success message
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Language changed to ${language['name']}'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('Yes, Change'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Language Settings'),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: supportedLanguages.length,
        itemBuilder: (context, index) {
          final language = supportedLanguages[index];
          final isSelected = currentLocale == language['locale'];

          return Card(
            elevation: isSelected ? 4 : 1,
            color: isSelected ? Colors.teal.shade50 : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isSelected ? Colors.teal : Colors.transparent, 
                width: 2
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              title: Text(
                language['name'],
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: isSelected 
                  ? const Icon(Icons.check_circle, color: Colors.teal, size: 30)
                  : const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
              onTap: () {
                if (!isSelected) {
                  _confirmLanguageChange(language);
                }
              },
            ),
          );
        },
      ),
    );
  }
}


//////////////////////////////////////////////////
//////////////////////////////////////////////////
///                                            ///
///                 SETTING                    ///
///                                            ///
//////////////////////////////////////////////////
//////////////////////////////////////////////////


// Assuming you have these global notifiers defined in main.dart
// final ValueNotifier<ThemeMode> themeNotifier = ...
// final ValueNotifier<double> textScaleNotifier = ...

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isDarkMode = false;
  bool isLargeText = false;
  bool notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = prefs.getBool('isDarkMode') ?? false;
      isLargeText = prefs.getBool('isLargeText') ?? false;
      notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    });
  }

  Future<void> _toggleDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
    setState(() => isDarkMode = value);
    
    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> _toggleLargeText(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLargeText', value);
    setState(() => isLargeText = value);
    
    textScaleNotifier.value = value ? 1.2 : 1.0;
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', value);
    setState(() => notificationsEnabled = value);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value ? 'Daily reminders enabled' : 'Daily reminders disabled')),
    );
  }

  void _resetAppProgress() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Reset All Progress?'),
          content: const Text(
            'This will permanently delete your current streak, highest scores, and daily routine data. Are you sure?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(dialogContext); 
                
                final prefs = await SharedPreferences.getInstance();
                final String userId = prefs.getString('sqlite_user_id') ?? "";

                // 1. Reset SQLite Database Scores
                if (userId.isNotEmpty) {
                  await DatabaseHelper.instance.updatePatientScores(
                    userId: userId,
                    cumulativeScore: 0,
                    dailyScore: 0,
                    currentStreak: 0,
                    lastActivityDate: '',
                  );
                }

                // 2. Clear SharedPreferences Progress Data
                await prefs.remove('routine_tasks');
                await prefs.remove('routine_date');
                await prefs.remove('active_dates');
                await prefs.remove('highest_historical_streak');

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All progress has been reset.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Yes, Reset'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8.0, bottom: 8.0, top: 8.0),
            child: Text('Appearance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
          ),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Column(
              children: [
                SwitchListTile(
                  activeThumbColor: Colors.teal,
                  title: const Text('Dark Mode'),
                  subtitle: const Text('Reduces screen glare'),
                  secondary: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode, color: Colors.teal),
                  value: isDarkMode,
                  onChanged: _toggleDarkMode,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  activeThumbColor: Colors.teal,
                  title: const Text('Large Text'),
                  subtitle: const Text('Makes words easier to read'),
                  secondary: const Icon(Icons.format_size, color: Colors.teal),
                  value: isLargeText,
                  onChanged: _toggleLargeText,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),

          const Padding(
            padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Text('Notifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
          ),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: SwitchListTile(
              activeThumbColor: Colors.teal,
              title: const Text('Daily Reminders'),
              subtitle: const Text('Receive alerts for routine tasks'),
              secondary: const Icon(Icons.notifications_active, color: Colors.teal),
              value: notificationsEnabled,
              onChanged: _toggleNotifications,
            ),
          ),
          
          const SizedBox(height: 40),

          const Padding(
            padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Text('Data Management', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent)),
          ),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: const BorderSide(color: Colors.redAccent, width: 1),
            ),
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
              title: const Text('Reset Progress', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              subtitle: const Text('Clear streak and score data'),
              onTap: _resetAppProgress,
            ),
          ),
        ],
      ),
    );
  }
}

//////////////////////////////////////////////////
//////////////////////////////////////////////////
///                                            ///
///               CONTACT US                   ///
///                                            ///
//////////////////////////////////////////////////
//////////////////////////////////////////////////


class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Us'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 30),
            
            // --- SUPPORT GRAPHIC ---
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.support_agent,
                size: 80,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 24),
            
            // --- HEADER TEXT ---
            const Text(
              'We are here to help!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'If you have any questions, feedback, or need technical support, please reach out to our development team.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.5),
            ),
            const SizedBox(height: 40),

            // --- EMAIL CARD ---
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: const ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                leading: CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: Icon(Icons.email, color: Colors.white),
                ),
                title: Text('Email Us', style: TextStyle(color: Colors.grey, fontSize: 14)),
                // SelectableText allows the user to long-press and copy the email
                subtitle: SelectableText(
                  'developer@cognitivecare.com',
                  style: TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.bold),
                ),
                trailing: Icon(Icons.copy, color: Colors.grey, size: 20),
              ),
            ),
            
            const SizedBox(height: 16),

            // --- PHONE CARD ---
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: const ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                leading: CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: Icon(Icons.phone, color: Colors.white),
                ),
                title: Text('Call Us', style: TextStyle(color: Colors.grey, fontSize: 14)),
                // SelectableText allows the user to long-press and copy the number
                subtitle: SelectableText(
                  '+91 9876543210',
                  style: TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.bold),
                ),
                trailing: Icon(Icons.copy, color: Colors.grey, size: 20),
              ),
            ),
            
            const SizedBox(height: 40),
            
            // --- FOOTER ---
            const Text(
              'App Version 1.0.0\nDeveloped with care in Kolkata.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            )
          ],
        ),
      ),
    );
  }
}


//////////////////////////////////////////////////
//////////////////////////////////////////////////
///                                            ///
///                  FAMILY                    ///
///                                            ///
//////////////////////////////////////////////////
//////////////////////////////////////////////////


// --- DATA MODEL ---
class FamilyMember {
  final String id;
  final String name;
  final String base64Image;

  FamilyMember({required this.id, required this.name, required this.base64Image});

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'base64Image': base64Image,
  };

  factory FamilyMember.fromJson(Map<String, dynamic> json) => FamilyMember(
    id: json['id'],
    name: json['name'],
    base64Image: json['base64Image'],
  );
}

// --- MAIN SCREEN ---
class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  List<FamilyMember> familyMembers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFamilyMembers();
  }

  Future<void> _loadFamilyMembers() async {
    final prefs = await SharedPreferences.getInstance();
    String? familyJson = prefs.getString('family_gallery');

    if (familyJson != null) {
      List<dynamic> decodedList = jsonDecode(familyJson);
      setState(() {
        familyMembers = decodedList.map((item) => FamilyMember.fromJson(item)).toList();
      });
    }
    setState(() => isLoading = false);
  }

  Future<void> _saveFamilyMembers() async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> jsonList = familyMembers.map((m) => m.toJson()).toList();
    await prefs.setString('family_gallery', jsonEncode(jsonList));
  }

  Future<void> _addPhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      Uint8List imageBytes = await image.readAsBytes();
      String base64String = base64Encode(imageBytes);
      _promptForName(base64String);
    }
  }

  void _promptForName(String base64String) {
    TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => AlertDialog(
        title: const Text('Who is in this photo?'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            hintText: 'e.g., Mother, David, Daughter',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                setState(() {
                  familyMembers.add(FamilyMember(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text.trim(),
                    base64Image: base64String,
                  ));
                });
                _saveFamilyMembers();
                Navigator.pop(context); 
              }
            },
            child: const Text('Save'),
          )
        ],
      ),
    );
  }

  void _deleteMember(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Photo?'),
        content: Text('Are you sure you want to remove ${familyMembers[index].name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              setState(() => familyMembers.removeAt(index));
              _saveFamilyMembers();
              Navigator.pop(context);
            },
            child: const Text('Remove'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Family'),
        centerTitle: true,
      ),
      body: familyMembers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.family_restroom, size: 80, color: Colors.teal.shade200),
                  const SizedBox(height: 16),
                  const Text('Your gallery is empty.', style: TextStyle(fontSize: 20, color: Colors.grey)),
                  const SizedBox(height: 12),
                  const Text('Tap the button below to add a photo.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, 
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85, 
              ),
              itemCount: familyMembers.length,
              itemBuilder: (context, index) {
                final member = familyMembers[index];
                final imageBytes = base64Decode(member.base64Image);

                return InkWell(
                  // When the user taps the card, it opens the detail screen
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FamilyMemberDetailScreen(member: member),
                      ),
                    );
                  },
                  child: Card(
                    elevation: 4,
                    clipBehavior: Clip.antiAlias, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Hero creates a smooth expanding animation to the next screen
                        Hero(
                          tag: member.id,
                          child: Image.memory(
                            imageBytes,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 0, left: 0, right: 0,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.black87, Colors.transparent],
                              ),
                            ),
                            padding: const EdgeInsets.only(top: 12, bottom: 24, left: 8, right: 8),
                            child: Center(
                              child: Text(
                                member.name.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.white70),
                            onPressed: () => _deleteMember(index),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              minimumSize: const Size.fromHeight(60), 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 4,
            ),
            icon: const Icon(Icons.add_a_photo, color: Colors.white, size: 28),
            label: const Text(
              'ADD NEW PHOTO',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold, 
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            onPressed: _addPhoto,
          ),
        ),
      ),
    );
  }
}

// --- NEW FULL SCREEN PHOTO VIEW ---
class FamilyMemberDetailScreen extends StatelessWidget {
  final FamilyMember member;

  const FamilyMemberDetailScreen({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    final imageBytes = base64Decode(member.base64Image);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family View'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // The photo in medium/large size
              Hero(
                tag: member.id,
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.memory(
                    imageBytes,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // The name in a large, readable font below the image
              Text(
                member.name.toUpperCase(),
                style: const TextStyle(
                  fontSize: 36, // Large font for visibility
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                  letterSpacing: 2.0,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Your loved one',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              )
            ],
          ),
        ),
      ),
    );
  }
}

////////////////////////////////////////////
////////////////////////////////////////////
///        CAREGIVER DASHBOARD           ///
////////////////////////////////////////////
////////////////////////////////////////////

class CaregiverDashboard extends StatefulWidget {
  const CaregiverDashboard({super.key});

  @override
  State<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends State<CaregiverDashboard> {
  String userName = "Caregiver";
  String institution = "";
  String caregiverId = "";
  final TextEditingController _searchController = TextEditingController();
  
  // --- NEW: Timer for polling alerts ---
  Timer? _alertTimer;

  @override
  void initState() {
    super.initState();
    _loadCaregiverData();
    
    // --- NEW: Check for patient alerts every 10 seconds ---
    _alertTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      CaregiverAlertService.checkForNewAlerts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _alertTimer?.cancel(); // --- NEW: Cancel timer when screen closes ---
    super.dispose();
  }

  Future<void> _loadCaregiverData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('user_name') ?? "Caregiver";
      institution = prefs.getString('user_institution') ?? "Independent";
      caregiverId = prefs.getString('sqlite_user_id') ?? "";
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sqlite_user_id');
    await prefs.remove('user_registration_number');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_phone');
    await prefs.remove('user_role');
    await prefs.remove('user_institution');
    
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const RegistrationScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  void _triggerSync() {
    SyncService().trySync();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Syncing data with server...'), backgroundColor: Colors.teal),
    );
  }

  Future<void> _searchPatient() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final patient = await DatabaseHelper.instance.searchPatientByRegistration(query);
    _searchController.clear();

    if (!mounted) return;

    if (patient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No patient found with that Registration ID.'), backgroundColor: Colors.red),
      );
      return;
    }

    // Prepare photo decoding
    Uint8List? photoBytes;
    if (patient['photo'] != null && patient['photo'].toString().isNotEmpty) {
      photoBytes = base64Decode(patient['photo']);
    }

    // Show Patient Profile Dialog
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Patient Found', textAlign: TextAlign.center, style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.teal.shade100,
                backgroundImage: photoBytes != null ? MemoryImage(photoBytes) : null,
                child: photoBytes == null ? const Icon(Icons.person, size: 50, color: Colors.teal) : null,
              ),
              const SizedBox(height: 16),
              Text(patient['name'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Age: ${patient['age'] ?? 'N/A'}', style: const TextStyle(fontSize: 16, color: Colors.grey)),
              Text('ID: ${patient['registration_number']}', style: const TextStyle(fontSize: 16, color: Colors.grey)),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () async {
                await DatabaseHelper.instance.linkPatientToCaregiver(caregiverId, patient['user_id']);
                if (mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${patient['name']} added to your patients.'), backgroundColor: Colors.green),
                  );
                }
              },
              child: const Text('Add Patient', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caregiver Portal'),
        centerTitle: true,
        backgroundColor: Colors.blueGrey,
        actions: [
          IconButton(icon: const Icon(Icons.sync), onPressed: _triggerSync, tooltip: 'Sync Data'),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout, tooltip: 'Log Out')
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- PATIENT SEARCH BAR ---
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.blueGrey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(hintText: 'Enter Patient Registration No...', border: InputBorder.none),
                        onSubmitted: (_) => _searchPatient(),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.arrow_forward, color: Colors.blueGrey), onPressed: _searchPatient),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- CAREGIVER WELCOME CARD ---
            Card(
              color: Colors.blueGrey.shade50,
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const CircleAvatar(radius: 40, backgroundColor: Colors.blueGrey, child: Icon(Icons.medical_services, size: 40, color: Colors.white)),
                    const SizedBox(height: 12),
                    Text('Welcome, $userName', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    const SizedBox(height: 4),
                    Text(institution, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            const Text('Patient Management', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 12),

            // --- CAREGIVER GRID MENU ---
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
              children: [
                _buildCaregiverCard('My Patients', Icons.group, Colors.indigo, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MyPatientsScreen()));
                }),
                _buildCaregiverCard('Analytics', Icons.bar_chart, Colors.purple, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CaregiverAnalyticsScreen()));
                }),
                _buildCaregiverCard('Settings', Icons.settings, Colors.blueGrey, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                }),
                _buildCaregiverCard('Music Insights', Icons.album, Colors.deepPurple, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CaregiverMusicInsightsScreen()));
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaregiverCard(String title, IconData icon, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title module coming soon!')));
      },
      child: Card(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: color.withValues(alpha: 0.3), width: 2)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: color),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade700)),
          ],
        ),
      ),
    );
  }
}

////////////////////////////////////////////////
////////////////////////////////////////////////
///      CAREGIVER MUSIC INSIGHTS            ///
////////////////////////////////////////////////
////////////////////////////////////////////////

class CaregiverMusicInsightsScreen extends StatefulWidget {
  const CaregiverMusicInsightsScreen({super.key});

  @override
  State<CaregiverMusicInsightsScreen> createState() => _CaregiverMusicInsightsScreenState();
}

class _CaregiverMusicInsightsScreenState extends State<CaregiverMusicInsightsScreen> {
  List<Map<String, dynamic>> linkedPatients = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    final prefs = await SharedPreferences.getInstance();
    final caregiverId = prefs.getString('sqlite_user_id') ?? "";
    if (caregiverId.isNotEmpty) {
      final patients = await DatabaseHelper.instance.getPatientsForCaregiver(caregiverId);
      setState(() => linkedPatients = patients);
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Music & Mood Insights'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: linkedPatients.isEmpty
          ? const Center(
              child: Text(
                'No patients linked yet.\nAdd patients from the dashboard to view their music insights.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: linkedPatients.length,
              itemBuilder: (context, index) {
                final patient = linkedPatients[index];
                return _buildPatientInsightCard(patient);
              },
            ),
    );
  }

  Widget _buildPatientInsightCard(Map<String, dynamic> patient) {
    return FutureBuilder<Map<String, dynamic>>(
      future: DatabaseHelper.instance.getRegionalMusicSummary(patient['user_id']),
      builder: (context, snapshot) {
        final summary = snapshot.data ?? {};
        final totalDuration = summary['total_duration_seconds'] as int? ?? 0;
        final totalLoops = summary['total_loops'] as int? ?? 0;
        final mostPlayed = summary['most_played_state'] as String? ?? 'None';
        final stateDurations = Map<String, int>.from(summary['state_durations'] as Map? ?? {});
        final stateLoops = Map<String, int>.from(summary['state_loops'] as Map? ?? {});

        String durationFormatted = '';
        if (totalDuration >= 60) {
          durationFormatted = '${(totalDuration / 60).floor()} min ${totalDuration % 60}s';
        } else {
          durationFormatted = '$totalDuration seconds';
        }

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patient header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.deepPurple.shade50,
                      child: const Icon(Icons.person, color: Colors.deepPurple, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(patient['name'] ?? 'Patient',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('ID: ${patient['registration_number'] ?? "-"}',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Summary stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildInsightStat('Total Time', durationFormatted, Icons.timer, Colors.teal),
                    _buildInsightStat('Loops', '$totalLoops', Icons.repeat, Colors.orange),
                    _buildInsightStat('Tracks', '${summary['total_plays'] ?? 0}', Icons.audiotrack, Colors.blue),
                  ],
                ),
                const SizedBox(height: 16),

                // Most played state
                if (mostPlayed != 'None')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.favorite, color: Colors.deepPurple, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Most Played: $mostPlayed',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Per-state breakdown
                if (stateDurations.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Listening by Region:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                  const SizedBox(height: 8),
                  ...stateDurations.entries.map((entry) {
                    int dur = entry.value;
                    int loops = stateLoops[entry.key] ?? 0;
                    String durStr = dur >= 60 ? '${(dur / 60).floor()}m ${dur % 60}s' : '${dur}s';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: Colors.deepPurple.shade300),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('${entry.key}', style: const TextStyle(fontSize: 14)),
                          ),
                          Text('$durStr · Looped $loops x',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                        ],
                      ),
                    );
                  }),
                ],

                // Cognitive insight
                const SizedBox(height: 12),
                _buildCognitiveInsightCard(totalDuration, totalLoops),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInsightStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildCognitiveInsightCard(int totalDuration, int totalLoops) {
    String moodIndicator;
    String moodEmoji;
    Color moodColor;

    if (totalLoops >= 5 && totalDuration > 300) {
      moodIndicator = 'Strong Emotional Resonance';
      moodEmoji = '🌟';
      moodColor = Colors.amber;
    } else if (totalLoops >= 2 && totalDuration > 120) {
      moodIndicator = 'Active Engagement & Reminiscence';
      moodEmoji = '🎶';
      moodColor = Colors.teal;
    } else if (totalDuration > 60) {
      moodIndicator = 'Calm & Relaxed Listening';
      moodEmoji = '😌';
      moodColor = Colors.blue;
    } else if (totalDuration > 0) {
      moodIndicator = 'Initial Exploration';
      moodEmoji = '🎵';
      moodColor = Colors.purple;
    } else {
      moodIndicator = 'No listening data yet';
      moodEmoji = '🎶';
      moodColor = Colors.grey;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: moodColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: moodColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(moodEmoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cognitive-Emotional Insight',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                Text(moodIndicator,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: moodColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


////////////////////////////////////////////////
///           MY PATIENT SCREEN              ///
////////////////////////////////////////////////
////////////////////////////////////////////////

class MyPatientsScreen extends StatefulWidget {
  const MyPatientsScreen({super.key});

  @override
  State<MyPatientsScreen> createState() => _MyPatientsScreenState();
}

class _MyPatientsScreenState extends State<MyPatientsScreen> {
  List<Map<String, dynamic>> linkedPatients = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLinkedPatients();
  }

  Future<void> _loadLinkedPatients() async {
    final prefs = await SharedPreferences.getInstance();
    final caregiverId = prefs.getString('sqlite_user_id') ?? "";

    if (caregiverId.isNotEmpty) {
      final patients = await DatabaseHelper.instance.getPatientsForCaregiver(caregiverId);
      setState(() {
        linkedPatients = patients;
      });
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Patients'),
        centerTitle: true,
        backgroundColor: Colors.indigo,
      ),
      body: linkedPatients.isEmpty
          ? const Center(
              child: Text(
                'You have no patients added yet.\nUse the search bar on the dashboard to add them.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal, // Allows table to scroll left/right on small screens
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.indigo.shade50),
                      columnSpacing: 24,
                      columns: const [
                        DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Age', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Daily Score', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Cum. Score', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Streak', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: linkedPatients.map((patient) {
                        return DataRow(
                          cells: [
                            DataCell(Text(patient['name'].toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(patient['age']?.toString() ?? '-')),
                            DataCell(Text(patient['daily_score']?.toString() ?? '0', style: const TextStyle(color: Colors.green))),
                            DataCell(Text(patient['cumulative_score']?.toString() ?? '0')),
                            DataCell(
                              Row(
                                children: [
                                  const Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
                                  const SizedBox(width: 4),
                                  Text('${patient['current_streak'] ?? '0'}'),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}


//////////////////////////////////////////////////
//////////////////////////////////////////////////
///                                            ///
///               VOICE ASST                   ///
///                                            ///
//////////////////////////////////////////////////
//////////////////////////////////////////////////

class VoiceAssistantService {
  static final VoiceAssistantService instance = VoiceAssistantService._internal();
  VoiceAssistantService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isSpeechInitialized = false;

  Future<void> init() async {
    // 0.4 rate is clear, calm, and slow for elderly users
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    _isSpeechInitialized = await _speech.initialize();
  }

  Future<void> speak(String text) async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('app_language') ?? 'en';
    
    // Map standard codes to TTS locales
    String ttsLang = 'en-IN';
    if (langCode == 'bn') ttsLang = 'bn-IN';
    if (langCode == 'hi') ttsLang = 'hi-IN';
    
    await _flutterTts.setLanguage(ttsLang);
    await _flutterTts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
  }

  Future<void> startListening({
    required Function(String text) onResult,
    required Function(bool isListening) onListeningStatusChanged,
  }) async {
    if (!_isSpeechInitialized) {
      _isSpeechInitialized = await _speech.initialize();
    }

    if (_isSpeechInitialized) {
      final prefs = await SharedPreferences.getInstance();
      final langCode = prefs.getString('app_language') ?? 'en';
      
      String localeId = 'en_IN';
      if (langCode == 'bn') localeId = 'bn_IN';
      if (langCode == 'hi') localeId = 'hi_IN';

      onListeningStatusChanged(true);

      await _speech.listen(
        localeId: localeId,
        onResult: (result) {
          onResult(result.recognizedWords);
          if (result.finalResult) {
            onListeningStatusChanged(false);
          }
        },
      );
    } else {
      onListeningStatusChanged(false);
    }
  }

  Future<void> stopListening() async {
    await _speech.stop();
  }

  // --- HYBRID INTENT ENGINE ---
  String parseIntent(String spokenText) {
    final text = spokenText.toLowerCase();

    if (text.contains('memory') || text.contains('মেমরি') || text.contains('स्मृति')) {
      return 'start_memory_game';
    }
    if (text.contains('pattern') || text.contains('প্যাটার্ন') || text.contains('रंग')) {
      return 'start_pattern_game';
    }
    if (text.contains('task') || text.contains('sequence') || text.contains('order') || text.contains('দৈনিক') || text.contains('क्रम')) {
      return 'start_task_sequencer';
    }
    if (text.contains('music') || text.contains('গান') || text.contains('संगीत')) {
      return 'open_music';
    }
    if (text.contains('routine') || text.contains('কাজ') || text.contains('दिनचर्या')) {
      return 'open_routine';
    }
    if (text.contains('family') || text.contains('পরিবার') || text.contains('परिवार')) {
      return 'open_family';
    }
    return 'unknown';
  }
}

////////////////////////////////////////////////
////////////////////////////////////////////////
///          CAREGIVER ANALYTICS             ///
////////////////////////////////////////////////
////////////////////////////////////////////////

class CaregiverAnalyticsScreen extends StatefulWidget {
  const CaregiverAnalyticsScreen({super.key});

  @override
  State<CaregiverAnalyticsScreen> createState() => _CaregiverAnalyticsScreenState();
}

class _CaregiverAnalyticsScreenState extends State<CaregiverAnalyticsScreen> {
  List<Map<String, dynamic>> linkedPatients = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    final prefs = await SharedPreferences.getInstance();
    final caregiverId = prefs.getString('sqlite_user_id') ?? "";

    if (caregiverId.isNotEmpty) {
      final patients = await DatabaseHelper.instance.getPatientsForCaregiver(caregiverId);
      setState(() {
        linkedPatients = patients;
      });
    }
    setState(() => isLoading = false);
  }

  Color _getTrendColor(int diff) {
    if (diff < -100) return Colors.red;
    if (diff >= -100 && diff < -50) return Colors.orange;
    if (diff >= -50 && diff < 0) return Colors.yellow;
    if (diff >= 0 && diff <= 10) return Colors.white; 
    if (diff > 10 && diff <= 50) return Colors.lightGreen;
    return Colors.green.shade800; 
  }

  int _getLatestPerformanceDiff(Map<String, dynamic> patient) {
    int dailyScore = patient['daily_score'] as int? ?? 0;
    String lastActivityDate = patient['last_activity_date']?.toString() ?? "";

    DateTime now = DateTime.now();
    String todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    // If the last activity wasn't today, their true score for today is 0.
    if (lastActivityDate != todayStr) return 0;
    
    // Since past historical daily records aren't stored, difference is today vs 0.
    return dailyScore;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Analytics'),
        centerTitle: true,
        backgroundColor: Colors.purple,
      ),
      backgroundColor: Colors.grey.shade100,
      body: linkedPatients.isEmpty
          ? const Center(
              child: Text(
                'No patients found.\nAdd patients from the dashboard to analyze them.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, 
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: linkedPatients.length,
              itemBuilder: (context, index) {
                final patient = linkedPatients[index];
                
                Uint8List? photoBytes;
                if (patient['photo'] != null && patient['photo'].toString().isNotEmpty) {
                  photoBytes = base64Decode(patient['photo']);
                }

                int latestDiff = _getLatestPerformanceDiff(patient);
                Color trendColor = _getTrendColor(latestDiff);

                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PatientAnalyticsDetailScreen(
                          patientData: patient,
                          trendColor: trendColor,
                        ),
                      ),
                    );
                  },
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(color: trendColor == Colors.white ? Colors.grey.shade300 : trendColor, width: 4),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.purple.shade50,
                          backgroundImage: photoBytes != null ? MemoryImage(photoBytes) : null,
                          child: photoBytes == null ? const Icon(Icons.person, size: 40, color: Colors.purple) : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          patient['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text('Age: ${patient['age'] ?? '-'}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        Text('ID: ${patient['registration_number']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// --- 7-DAY ANALYTICS TABLE SCREEN ---

class PatientAnalyticsDetailScreen extends StatefulWidget {
  final Map<String, dynamic> patientData;
  final Color trendColor;

  const PatientAnalyticsDetailScreen({super.key, required this.patientData, required this.trendColor});

  @override
  State<PatientAnalyticsDetailScreen> createState() => _PatientAnalyticsDetailScreenState();
}

class _PatientAnalyticsDetailScreenState extends State<PatientAnalyticsDetailScreen> {
  List<Map<String, dynamic>> weeklyData = [];

  @override
  void initState() {
    super.initState();
    _generateWeeklyHistory();
  }

  void _generateWeeklyHistory() {
    int currentCumScore = widget.patientData['cumulative_score'] as int? ?? 0;
    int currentDaily = widget.patientData['daily_score'] as int? ?? 0;
    String lastActivityDate = widget.patientData['last_activity_date']?.toString() ?? "";
    
    DateTime now = DateTime.now();
    String todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    int actualTodayDaily = (lastActivityDate == todayStr) ? currentDaily : 0;
    
    // Deduct today's score to find out what the cumulative score was yesterday
    int pastCumScore = currentCumScore - actualTodayDaily;
    if (pastCumScore < 0) pastCumScore = 0;

    for (int i = 0; i < 7; i++) {
      DateTime day = now.subtract(Duration(days: i));
      String dateStr = "${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}";

      int dayScore = 0;
      int diff = 0;
      int runningCumScore = pastCumScore; 

      if (i == 0) {
        dayScore = actualTodayDaily;
        diff = actualTodayDaily; // difference from 0 yesterday
        runningCumScore = currentCumScore;
      } else {
        // If data is missing for previous days, output 0 as requested
        dayScore = 0;
        diff = 0;
        runningCumScore = pastCumScore;
      }

      weeklyData.add({
        'date': dateStr,
        'daily_score': dayScore,
        'cum_score': runningCumScore,
        'difference': diff,
      });
    }
  }

  Color _getTrendColor(int diff) {
    if (diff < -100) return Colors.red;
    if (diff >= -100 && diff < -50) return Colors.orange;
    if (diff >= -50 && diff < 0) return Colors.yellow;
    if (diff >= 0 && diff <= 10) return Colors.white; 
    if (diff > 10 && diff <= 50) return Colors.lightGreen;
    return Colors.green.shade800; 
  }

  @override
  Widget build(BuildContext context) {
    Uint8List? photoBytes;
    if (widget.patientData['photo'] != null && widget.patientData['photo'].toString().isNotEmpty) {
      photoBytes = base64Decode(widget.patientData['photo']);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Analyzer'),
        centerTitle: true,
        backgroundColor: Colors.purple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.purple.shade50,
                      backgroundImage: photoBytes != null ? MemoryImage(photoBytes) : null,
                      child: photoBytes == null ? const Icon(Icons.person, size: 30, color: Colors.purple) : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.patientData['name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('ID: ${widget.patientData['registration_number']}', style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            const Text('7-Day Activity Trend', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple)),
            const SizedBox(height: 12),

            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(Colors.purple.shade50),
                    columnSpacing: 20,
                    columns: const [
                      DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Daily', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Trend', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: weeklyData.map((data) {
                      int diff = data['difference'];
                      Color rowTrendColor = _getTrendColor(diff);
                      String diffString = diff > 0 ? '+$diff' : '$diff';
                      
                      BoxBorder? border = rowTrendColor == Colors.white 
                          ? Border.all(color: Colors.grey.shade400) 
                          : null;

                      Color textColor = (rowTrendColor == Colors.white || rowTrendColor == Colors.yellow || rowTrendColor == Colors.lightGreen)
                          ? Colors.black87
                          : Colors.white;

                      return DataRow(
                        cells: [
                          DataCell(Text(data['date'].toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(data['daily_score'].toString())),
                          DataCell(Text(data['cum_score'].toString())),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: rowTrendColor,
                                borderRadius: BorderRadius.circular(12),
                                border: border,
                              ),
                              child: Text(
                                diffString,
                                style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


////////////////////////////////////////////
////////////////////////////////////////////
///           NOTIFICAITION              ///
////////////////////////////////////////////
////////////////////////////////////////////

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(initSettings);

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // --- Hourly Hydration (Custom Sound) ---
  Future<void> scheduleHourlyHydrationReminder() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'hydration_channel',
      'Hydration Reminders',
      channelDescription: 'Hourly reminders to drink water',
      importance: Importance.high,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('gentle_alert'), // Custom Sound
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.periodicallyShow(
      999,
      'Time to Drink Water 💧',
      'Please drink a glass of water to stay hydrated and healthy.',
      RepeatInterval.hourly,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // --- Daily Routine & Medicine (Custom Sound) ---
  Future<void> scheduleDailyTimeNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_routine_channel',
      'Routine & Medicine Reminders',
      channelDescription: 'Scheduled reminders for daily activities and meds',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('gentle_alert'), // Custom Sound
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // --- Doctor Appointment (Main + 1 Hour Early Warning) ---
  Future<void> scheduleAppointmentNotification({
    required int id,
    required String doctorName,
    required DateTime appointmentDateTime,
  }) async {
    final tz.TZDateTime mainScheduledDate = tz.TZDateTime.from(appointmentDateTime, tz.local);
    final tz.TZDateTime earlyWarningDate = mainScheduledDate.subtract(const Duration(hours: 1));
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'doctor_channel',
      'Doctor Appointments',
      channelDescription: 'Reminders for upcoming doctor visits',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('gentle_alert'), // Custom Sound
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    // 1. Main Appointment Alert (At exact time)
    if (mainScheduledDate.isAfter(now)) {
      await _notificationsPlugin.zonedSchedule(
        id,
        'Doctor Appointment Now 🏥',
        'It is time for your appointment with $doctorName.',
        mainScheduledDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // 2. Early Warning Alert (1 Hour Prior)
    if (earlyWarningDate.isAfter(now)) {
      await _notificationsPlugin.zonedSchedule(
        id + 10000, // Offset ID so it doesn't overwrite the main alert
        'Upcoming Appointment ⏰',
        'You have an appointment with $doctorName in 1 hour.',
        earlyWarningDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
    await _notificationsPlugin.cancel(id + 10000); // Also cancel the early warning if it exists
  }
}


////////////////////////////////////////////
////////////////////////////////////////////
///       CAREGIVER ALERT SYSTEM         ///
////////////////////////////////////////////
////////////////////////////////////////////

class CaregiverAlertService {
  // --- 1. PATIENT SIDE: Log the missed activity ---
  static Future<void> sendMissedAlert(String type, String activityName, String scheduledTime) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get the patient's registration ID
    String regId = prefs.getString('user_registration_number') ?? "Unknown ID";
    String patientName = prefs.getString('user_name') ?? "Patient";

    // Create the alert message
    String alertMessage = "Patient [$regId] $patientName missed their $type: '$activityName' scheduled at $scheduledTime.";

    // Use getStringList and setStringList for string arrays
    List<String> pendingAlerts = prefs.getStringList('pending_caregiver_alerts') ?? [];
    pendingAlerts.add(alertMessage);
    await prefs.setStringList('pending_caregiver_alerts', pendingAlerts);
  }

  // --- 2. CAREGIVER SIDE: Check for alerts and notify ---
  static Future<void> checkForNewAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> pendingAlerts = prefs.getStringList('pending_caregiver_alerts') ?? [];

    if (pendingAlerts.isNotEmpty) {
      for (int i = 0; i < pendingAlerts.length; i++) {
        // Trigger the local notification on the Caregiver's dashboard
        await NotificationService.instance.scheduleDailyTimeNotification(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000) + i, 
          title: 'Missed Activity Alert ⚠️',
          body: pendingAlerts[i],
          hour: DateTime.now().hour,
          minute: DateTime.now().minute,
        );
      }
      
      // Clear the alerts using setStringList with an empty list
      await prefs.setStringList('pending_caregiver_alerts', []);
    }
  }
}