import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:camera/camera.dart';
// Replace with your actual Gemini API key
const String apiKey = 'AIzaSyBU0nYJ79vuTX5CbJReS43Ygz96l_zrpgs'; 
const String geminiEndpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro-latest:generateContent';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: '.env');
  
  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  
  final cameras = await availableCameras();
  runApp(SeedScanApp(cameras: cameras));
}

class SeedScanApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  
  const SeedScanApp({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SeedScan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        brightness: Brightness.light,
        fontFamily: 'Poppins',
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        brightness: Brightness.dark,
        fontFamily: 'Poppins',
      ),
      themeMode: ThemeMode.system,
      home: AuthWrapper(cameras: cameras),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  final List<CameraDescription> cameras;
  
  const AuthWrapper({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final authState = snapshot.data!;
          if (authState.session != null) {
            return HomePage(cameras: cameras);
          }
        }
        return LoginPage(cameras: cameras);
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  final List<CameraDescription> cameras; // Add this parameter
  
  // Add constructor to receive cameras
  const LoginPage({Key? key, required this.cameras}) : super(key: key);
  
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  String _errorMessage = '';

Future<void> _signIn() async {
  setState(() {
    _isLoading = true;
    _errorMessage = '';
  });

  try {
    final response = await Supabase.instance.client.auth.signInWithPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );
    
    // Forcefully proceed to home page regardless of any verification status
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage(cameras: widget.cameras)),
      );
    }

  } on AuthException catch (error) {
    // Ignore email not confirmed errors
    if (!error.message.toLowerCase().contains('email not confirmed')) {
      setState(() {
        _errorMessage = error.message;
      });
    } else {
      // Proceed anyway
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage(cameras: widget.cameras)),
        );
      }
    }
  } catch (error) {
    setState(() {
      _errorMessage = 'Unexpected error occurred';
    });
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

  Future<void> _resendVerificationEmail() async {
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: _emailController.text.trim(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email resent successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resend verification email: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login to SeedScan'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 40),
              // App Logo/Icon would go here
              Icon(
                Icons.eco,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              SizedBox(height: 20),
              Text(
                'Welcome to SeedScan',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Sign in to analyze your seeds',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 40),
              
              // Error Message
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              
              // Email Field
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 16),
              
              // Password Field
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                ),
                obscureText: true,
              ),
              SizedBox(height: 8),
              
              // Forgot Password Link
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // Add password reset functionality
                    _showPasswordResetDialog();
                  },
                  child: Text('Forgot Password?'),
                ),
              ),
              SizedBox(height: 16),
              
              // Sign In Button
              ElevatedButton(
                onPressed: _isLoading ? null : _signIn,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading 
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Sign In',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
              SizedBox(height: 24),
              
              // Sign Up Prompt
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Don't have an account?"),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SignUpPage()),
                      );
                    },
                    child: Text(
                      'Sign Up',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Add this helper method for password reset
  void _showPasswordResetDialog() async {
    final emailController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset Password'),
        content: TextField(
          controller: emailController,
          decoration: InputDecoration(
            labelText: 'Enter your email',
            hintText: 'email@example.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await Supabase.instance.client.auth.resetPasswordForEmail(
                  emailController.text.trim(),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Password reset email sent!')),
                );
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${e.toString()}')),
                );
              }
            },
            child: Text('Send Link'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

// Sign Up Page
class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

Future<void> _signUp() async {
  setState(() {
    _isLoading = true;
    _errorMessage = '';
  });

  try {
    // 1. Create the user account (no email verification)
    final response = await Supabase.instance.client.auth.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      data: {
        'name': _nameController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      },
      emailRedirectTo: null, // Disable email confirmation
    );

    // 2. Check if user was created
    if (response.user == null) {
      setState(() {
        _errorMessage = 'Sign up failed. Please try again.';
      });
      return;
    }

    // 3. Insert additional user data (optional)
    try {
      await Supabase.instance.client
        .from('users')
        .insert({
          'id': response.user!.id,
          'email': _emailController.text.trim(),
          'name': _nameController.text.trim(),
          'created_at': DateTime.now().toIso8601String(),
        });
    } catch (e) {
      print('Error saving user profile: $e');
      // Non-critical error - account was still created
    }

    // 4. Show success and return to login
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully!'),
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.pop(context); // Return to login page
    }

  } on AuthException catch (error) {
    setState(() {
      _errorMessage = error.message;
    });
  } catch (error) {
    setState(() {
      _errorMessage = 'An unexpected error occurred. Please try again.';
    });
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Account'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 40),
              Text(
                'Create New Account',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Join SeedScan to analyze your seeds',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 40),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _signUp,
                child: _isLoading 
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Sign Up'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('Already have an account? Sign In'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}

class HomePage extends StatefulWidget {
  final List<CameraDescription> cameras;
  
  const HomePage({Key? key, required this.cameras}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? _image;
  final picker = ImagePicker();
  bool _isLoading = false;
  double _viabilityScore = 0.0;
  bool _predictionMade = false;
  String _analysisDetails = '';
  List<String> _recommendations = [];
  bool _isValidSeed = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
  }

  Future pickImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source);

    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
        _predictionMade = false;
        _isValidSeed = true;
        _errorMessage = '';
        validateAndAnalyzeImage(_image!);
      }
    });
  }
  Future<void> _signOut() async {
    try {
      // Clear any current session
      await Supabase.instance.client.auth.signOut();
      
      // Ensure we're back on the login page
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => LoginPage(cameras: widget.cameras)),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: ${e.toString()}')),
        );
      }
    }
  }
  Future<void> validateAndAnalyzeImage(File imageFile) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // First, validate that the image contains maize or bean seeds
      final validationResult = await validateSeedImage(imageFile);
      
      if (validationResult.isValid) {
        // If valid, proceed to analyze the seed
        await analyzeImageWithGemini(imageFile);
      } else {
        setState(() {
          _isLoading = false;
          _predictionMade = true;
          _isValidSeed = false;
          _errorMessage = validationResult.message;
        });
      }
    } catch (e) {
      print("Error processing image: $e");
      setState(() {
        _isLoading = false;
        _predictionMade = true;
        _isValidSeed = false;
        _errorMessage = "An error occurred while processing the image. Please try again.";
      });
    }
  }

  Future<ValidationResult> validateSeedImage(File imageFile) async {
    try {
      // Convert image to base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      // Prepare the request payload for validation
      final payload = {
        "contents": [
          {
            "parts": [
              {
                "text": "This is an image validation task. Answer only YES or NO: Does this image contain maize (corn) or bean seeds? If no, briefly explain what is shown instead. Keep your response short and direct."
              },
              {
                "inline_data": {
                  "mime_type": "image/jpeg",
                  "data": base64Image
                }
              }
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.2,
          "topK": 32,
          "topP": 1,
          "maxOutputTokens": 1024,
        }
      };

      // Send request to Gemini API
      final response = await http.post(
        Uri.parse('$geminiEndpoint?key=$apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final generatedContent = jsonResponse['candidates'][0]['content']['parts'][0]['text'];
        
        // Check if the response indicates a valid seed image
        if (generatedContent.trim().toLowerCase().startsWith('yes')) {
          return ValidationResult(true, "");
        } else {
          // Extract explanation if available
          String explanation = generatedContent.replaceAll(RegExp(r'^no[.:,\s]*', caseSensitive: false), '').trim();
          if (explanation.isEmpty) {
            explanation = "This doesn't appear to be a maize or bean seed image.";
          }
          return ValidationResult(false, "Invalid image: $explanation Please take a clear photo of maize or bean seeds.");
        }
      } else {
        print("API Error during validation: ${response.statusCode} - ${response.body}");
        return ValidationResult(false, "Couldn't validate the image. Please try again.");
      }
    } catch (e) {
      print("Error validating image: $e");
      return ValidationResult(false, "Error validating the image. Please try again.");
    }
  }

  Future<void> analyzeImageWithGemini(File imageFile) async {
    try {
      // Convert image to base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      // Prepare the request payload
      final payload = {
        "contents": [
          {
            "parts": [
              {
                "text": "Analyze this seed image for viability and germination potential. The image shows either maize (corn) or bean seeds. Provide: \n1. A viability score between 0-100% \n2. Detailed analysis of the seeds' condition including color, shape, damage, and signs of diseases or pests if present \n3. Specific recommendations for improving germination especially if the seeds show signs of poor viability \n4. Treatment recommendations if seeds are not viable"
              },
              {
                "inline_data": {
                  "mime_type": "image/jpeg",
                  "data": base64Image
                }
              }
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.4,
          "topK": 32,
          "topP": 1,
          "maxOutputTokens": 4096,
        }
      };

      // Send request to Gemini API
      final response = await http.post(
        Uri.parse('$geminiEndpoint?key=$apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final generatedContent = jsonResponse['candidates'][0]['content']['parts'][0]['text'];
        
        // Extract viability score using regex (looking for percentage)
        final scoreRegex = RegExp(r'(\d{1,3})%');
        final scoreMatch = scoreRegex.firstMatch(generatedContent);
        
        // Parse the response to extract detailed analysis and recommendations
        final List<String> recommendations = [];
        String detailedAnalysis = '';
        
        // Improved parsing logic
        final lines = generatedContent.split('\n');
        bool inRecommendationSection = false;
        bool inAnalysisSection = false;
        
        for (final line in lines) {
          // Check for section headers
          if (line.toLowerCase().contains('recommendation') || 
              line.toLowerCase().contains('suggestion') ||
              line.toLowerCase().contains('treatment')) {
            inRecommendationSection = true;
            inAnalysisSection = false;
            continue;
          } else if (line.toLowerCase().contains('analysis') || 
                     line.toLowerCase().contains('condition') ||
                     line.toLowerCase().contains('assessment')) {
            inAnalysisSection = true;
            inRecommendationSection = false;
            continue;
          }
          
          if (inRecommendationSection && line.trim().isNotEmpty) {
            // Remove bullet points and other markers
            final cleanedLine = line.replaceAll(RegExp(r'^\s*[-•*\d.]\s*'), '').trim();
            if (cleanedLine.isNotEmpty) {
              recommendations.add(cleanedLine);
            }
          } else if ((inAnalysisSection || !inRecommendationSection) && 
                     line.trim().isNotEmpty && 
                     !line.toLowerCase().contains('viability score') &&
                     !line.toLowerCase().contains('recommendation')) {
            detailedAnalysis += line + '\n';
          }
        }
        
        setState(() {
          _isLoading = false;
          _predictionMade = true;
          _isValidSeed = true;
          
          // Set viability score from Gemini response
          if (scoreMatch != null) {
            _viabilityScore = double.parse(scoreMatch.group(1)!).clamp(0, 100);
          } else {
            // Fallback if no score is found in the response
            _viabilityScore = 50.0;
          }
          
          _analysisDetails = detailedAnalysis.trim();
          
          // Use extracted recommendations or generate basic ones based on score
          if (recommendations.isNotEmpty) {
            _recommendations = recommendations;
          } else {
            _recommendations = getDefaultRecommendations(_viabilityScore);
          }
        });
        
      } else {
        print("API Error: ${response.statusCode} - ${response.body}");
        setState(() {
          _isLoading = false;
          _predictionMade = true;
          _isValidSeed = false;
          _errorMessage = "Unable to analyze the seeds. Please try again.";
        });
      }
      
    } catch (e) {
      print("Error analyzing image: $e");
      setState(() {
        _isLoading = false;
        _predictionMade = true;
        _isValidSeed = false;
        _errorMessage = "Error analyzing the image. Please try again.";
      });
    }
  }

  List<String> getDefaultRecommendations(double score) {
    if (score >= 80) {
      return [
        "Seeds show excellent germination potential",
        "Plant in well-draining soil at appropriate depth",
        "Maintain consistent moisture until germination",
        "For maize: Plant when soil temperature is at least 60°F (16°C)",
        "For beans: Avoid over-watering to prevent rot"
      ];
    } else if (score >= 60) {
      return [
        "Seeds show moderate germination potential",
        "Soak seeds in water for 12-24 hours before planting",
        "Consider using seed-starting mix rather than garden soil",
        "Maintain optimal soil temperature and moisture levels",
        "Use bottom heat to encourage germination"
      ];
    } else {
      return [
        "Seeds show low germination potential",
        "Try seed priming with a diluted hydrogen peroxide solution (3%)",
        "Consider scarification for beans to improve water absorption",
        "For maize: Soak in warm water with a touch of hydrogen peroxide",
        "Apply beneficial fungi/bacteria that promote germination",
        "Plant extra seeds to account for poor germination rate",
        "Consider purchasing fresh seeds if these are old or damaged"
      ];
    }
  }

  Widget buildResultCard() {
    if (!_isValidSeed) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Invalid Image',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take Another Photo'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => pickImage(ImageSource.camera),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    Color cardColor = _viabilityScore >= 80 
        ? Colors.green 
        : (_viabilityScore >= 60 ? Colors.orange : Colors.red);
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Icon(
                  _viabilityScore >= 80 
                      ? Icons.check_circle 
                      : (_viabilityScore >= 60 ? Icons.info : Icons.warning),
                  color: cardColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Germination Score: ${_viabilityScore.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: cardColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _viabilityScore / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(cardColor),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            
            if (_analysisDetails.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Analysis:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _analysisDetails,
                style: const TextStyle(fontSize: 15),
              ),
            ],
            
            const SizedBox(height: 20),
            const Text(
              'Recommendations:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ..._recommendations.map((tip) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.arrow_right, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(tip, style: const TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text(
        'SeedScan',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 24,
          color: Colors.white,
        ),
      ),
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.green[700],
      actions: [
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: _signOut,
        ),
      ],
    ),
    body: Container(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Subtitle
            const Text(
              'Seed Viability Analysis',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // Seed image display area
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!, width: 1),
              ),
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Analyzing with SeedScan...',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : _image == null
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_search,
                                size: 80,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Take or select a photo of maize or bean seeds',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.file(
                            _image!,
                            fit: BoxFit.cover,
                          ),
                        ),
            ),
            const SizedBox(height: 24),
            
            // Camera and gallery buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt, size: 28),
                    label: const Text(
                      'Camera',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => pickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.photo_library, size: 28),
                    label: const Text(
                      'Gallery',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => pickImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // Divider with icon
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.eco, color: Colors.green[700]),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),
            
            // AI Powered badge with brain icon instead of neural_network
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.purple.shade300, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.psychology, color: Colors.purple[700], size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'AI-Powered Seed Analysis',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Results section
            if (_predictionMade) buildResultCard(),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}
}

class ValidationResult {
  final bool isValid;
  final String message;
  
  ValidationResult(this.isValid, this.message);
}