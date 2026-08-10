import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const AcademicResearchApp());

class AcademicResearchApp extends StatelessWidget {
  const AcademicResearchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Academic Research AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5), // Premium Indigo
          primary: const Color(0xFF4F46E5),
          background: const Color(0xFFF8FAFC), // Slate 50
          surface: Colors.white,
          onBackground: const Color(0xFF0F172A), // Slate 900
          onSurface: const Color(0xFF0F172A),
        ),
        cardTheme: const CardTheme(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Color(0xFFE2E8F0), width: 1),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF1F5F9), // Slate 100
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
          ),
        ),
      ),
      home: const MainGate(),
    );
  }
}

class MainGate extends StatefulWidget {
  const MainGate({super.key});

  @override
  State<MainGate> createState() => _MainGateState();
}

class _MainGateState extends State<MainGate> {
  String? authToken;
  String? userName;
  String currentView = 'login'; // login, register, selection, workspace
  
  // Selections
  int? selectedStandardId;
  String? selectedStandardName;
  int? selectedStreamId;
  String? selectedStreamName;
  int? selectedSubjectId;
  String? selectedSubjectName;

  void onLoginSuccess(String token, String name) {
    setState(() {
      authToken = token;
      userName = name;
      currentView = 'selection';
    });
  }

  void onLogout() {
    setState(() {
      authToken = null;
      userName = null;
      currentView = 'login';
      selectedStandardId = null;
      selectedStreamId = null;
      selectedSubjectId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (currentView) {
      case 'login':
        return LoginScreen(
          onLoginSuccess: onLoginSuccess,
          onSwitchToRegister: () => setState(() => currentView = 'register'),
        );
      case 'register':
        return RegisterScreen(
          onRegisterSuccess: () => setState(() => currentView = 'login'),
          onSwitchToLogin: () => setState(() => currentView = 'login'),
        );
      case 'selection':
        return SelectionScreen(
          authToken: authToken,
          userName: userName,
          onLogout: onLogout,
          onSubjectSelected: (stdId, stdName, strmId, strmName, subId, subName) {
            setState(() {
              selectedStandardId = stdId;
              selectedStandardName = stdName;
              selectedStreamId = strmId;
              selectedStreamName = strmName;
              selectedSubjectId = subId;
              selectedSubjectName = subName;
              currentView = 'workspace';
            });
          },
        );
      case 'workspace':
        return WorkspaceScreen(
          authToken: authToken,
          userName: userName,
          standardId: selectedStandardId!,
          standardName: selectedStandardName!,
          streamId: selectedStreamId!,
          streamName: selectedStreamName!,
          subjectId: selectedSubjectId!,
          subjectName: selectedSubjectName!,
          onBack: () => setState(() => currentView = 'selection'),
          onLogout: onLogout,
        );
      default:
        return const Scaffold(body: Center(child: Text('Unknown State')));
    }
  }
}

// --- REGISTER SCREEN ---
class RegisterScreen extends StatefulWidget {
  final VoidCallback onRegisterSuccess;
  final VoidCallback onSwitchToLogin;

  const RegisterScreen({
    super.key,
    required this.onRegisterSuccess,
    required this.onSwitchToLogin,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  String errorMessage = '';
  bool isLoading = false;

  Future<void> register() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });
    try {
      final res = await http.post(
        Uri.parse('http://localhost:8000/api/v1/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': emailController.text,
          'password': passwordController.text,
          'name': nameController.text,
        }),
      );
      if (res.statusCode == 200) {
        widget.onRegisterSuccess();
      } else {
        final body = jsonDecode(res.body);
        setState(() => errorMessage = body['detail'] ?? 'Registration failed.');
      }
    } catch (e) {
      setState(() => errorMessage = 'Connection error. Make sure API is running.');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Create Account',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Academic Research AI',
                    style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (errorMessage.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Text(
                        errorMessage,
                        style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person_outline)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: isLoading ? null : register,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Sign Up', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: widget.onSwitchToLogin,
                    child: const Text('Already have an account? Log In'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- LOGIN SCREEN ---
class LoginScreen extends StatefulWidget {
  final Function(String, String) onLoginSuccess;
  final VoidCallback onSwitchToRegister;

  const LoginScreen({
    super.key,
    required this.onLoginSuccess,
    required this.onSwitchToRegister,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String errorMessage = '';
  bool isLoading = false;

  Future<void> login() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });
    try {
      final res = await http.post(
        Uri.parse('http://localhost:8000/api/v1/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': emailController.text,
          'password': passwordController.text,
        }),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        widget.onLoginSuccess(body['access_token'], body['name'] ?? 'Student');
      } else {
        final body = jsonDecode(res.body);
        setState(() => errorMessage = body['detail'] ?? 'Invalid credentials.');
      }
    } catch (e) {
      setState(() => errorMessage = 'Connection error. Make sure API is running.');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Student Login',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Academic Research AI Portal',
                    style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (errorMessage.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Text(
                        errorMessage,
                        style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: isLoading ? null : login,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Log In', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: widget.onSwitchToRegister,
                    child: const Text('Don\'t have an account? Sign Up'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- SELECTION SCREEN ---
class SelectionScreen extends StatefulWidget {
  final String? authToken;
  final String? userName;
  final VoidCallback onLogout;
  final Function(int, String, int, String, int, String) onSubjectSelected;

  const SelectionScreen({
    super.key,
    required this.authToken,
    required this.userName,
    required this.onLogout,
    required this.onSubjectSelected,
  });

  @override
  State<SelectionScreen> createState() => _SelectionScreenState();
}

class _SelectionScreenState extends State<SelectionScreen> {
  List<dynamic> standards = [];
  List<dynamic> streams = [];
  List<dynamic> subjects = [];

  int? selectedStandard;
  int? selectedStream;
  int? selectedSubject;

  @override
  void initState() {
    super.initState();
    fetchStandards();
  }

  Future<void> fetchStandards() async {
    try {
      final res = await http.get(Uri.parse('http://localhost:8000/api/v1/standards'));
      setState(() => standards = jsonDecode(res.body));
    } catch (_) {}
  }

  Future<void> fetchStreams(int stdId) async {
    try {
      final res = await http.get(Uri.parse('http://localhost:8000/api/v1/standards/$stdId/streams'));
      setState(() {
        streams = jsonDecode(res.body);
        subjects = [];
        selectedStream = null;
        selectedSubject = null;
      });
    } catch (_) {}
  }

  Future<void> fetchSubjects(int strmId) async {
    try {
      final res = await http.get(Uri.parse('http://localhost:8000/api/v1/streams/$strmId/subjects'));
      setState(() {
        subjects = jsonDecode(res.body);
        selectedSubject = null;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Academic Research AI'),
        actions: [
          Center(
            child: Text(
              'Hi, ${widget.userName ?? "Student"}',
              style: const TextStyle(fontWeight: FontWeight.w640),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: widget.onLogout,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.school_outlined, size: 72, color: Color(0xFF4F46E5)),
                const SizedBox(height: 24),
                const Text(
                  'Academic Taxonomy Selector',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select your standard, stream, and subject to begin deep exam analysis.',
                  style: TextStyle(color: Color(0xFF64748B)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                // Standards Dropdown
                DropdownButtonFormField<int>(
                  value: selectedStandard,
                  hint: const Text('Select Academic Standard'),
                  items: standards.map<DropdownMenuItem<int>>((s) {
                    return DropdownMenuItem<int>(
                      value: s['id'],
                      child: Text(s['name']),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      selectedStandard = val;
                      selectedStream = null;
                      selectedSubject = null;
                    });
                    if (val != null) fetchStreams(val);
                  },
                ),
                const SizedBox(height: 16),

                // Streams Dropdown
                DropdownButtonFormField<int>(
                  value: selectedStream,
                  hint: const Text('Select Stream'),
                  items: streams.map<DropdownMenuItem<int>>((s) {
                    return DropdownMenuItem<int>(
                      value: s['id'],
                      child: Text(s['name']),
                    );
                  }).toList(),
                  onChanged: selectedStandard == null ? null : (val) {
                    setState(() {
                      selectedStream = val;
                      selectedSubject = null;
                    });
                    if (val != null) fetchSubjects(val);
                  },
                ),
                const SizedBox(height: 16),

                // Subjects Dropdown
                DropdownButtonFormField<int>(
                  value: selectedSubject,
                  hint: const Text('Select Subject'),
                  items: subjects.map<DropdownMenuItem<int>>((s) {
                    return DropdownMenuItem<int>(
                      value: s['id'],
                      child: Text(s['name']),
                    );
                  }).toList(),
                  onChanged: selectedStream == null ? null : (val) {
                    setState(() => selectedSubject = val);
                  },
                ),
                const SizedBox(height: 32),

                FilledButton.icon(
                  onPressed: selectedSubject == null
                      ? null
                      : () {
                          final stdName = standards.firstWhere((x) => x['id'] == selectedStandard)['name'];
                          final strmName = streams.firstWhere((x) => x['id'] == selectedStream)['name'];
                          final subName = subjects.firstWhere((x) => x['id'] == selectedSubject)['name'];
                          widget.onSubjectSelected(
                            selectedStandard!,
                            stdName,
                            selectedStream!,
                            strmName,
                            selectedSubject!,
                            subName,
                          );
                        },
                  icon: const Icon(Icons.explore_outlined),
                  label: const Text('Launch Research Workspace'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- WORKSPACE SCREEN ---
class WorkspaceScreen extends StatefulWidget {
  final String? authToken;
  final String? userName;
  final int standardId;
  final String standardName;
  final int streamId;
  final String streamName;
  final int subjectId;
  final String subjectName;
  final VoidCallback onBack;
  final VoidCallback onLogout;

  const WorkspaceScreen({
    super.key,
    required this.authToken,
    required this.userName,
    required this.standardId,
    required this.standardName,
    required this.streamId,
    required this.streamName,
    required this.subjectId,
    required this.subjectName,
    required this.onBack,
    required this.onLogout,
  });

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  bool isResearching = false;
  List<String> logs = [];
  List<dynamic> topQuestions = [];
  dynamic activeQuestion;
  int? activeRunId;

  // Chat parameters
  final chatController = TextEditingController();
  final followUpController = TextEditingController();
  List<Map<String, String>> chatMessages = [];
  bool isChatLoading = false;

  @override
  void initState() {
    super.initState();
    chatMessages.add({
      'role': 'agent',
      'text': 'Hello! I am your Academic Exam Intelligence Agent. '
          'I can perform Deep Research across 10 years of question papers in ${widget.subjectName} to extract '
          'and cluster recurring exam topics. Ask me anything or trigger the Deep Research job.'
    });
    fetchExistingQuestions();
  }

  Future<void> fetchExistingQuestions() async {
    try {
      final res = await http.get(Uri.parse('http://localhost:8000/api/v1/subjects/${widget.subjectId}/top-questions'));
      if (res.statusCode == 200) {
        setState(() {
          topQuestions = jsonDecode(res.body);
          if (topQuestions.isNotEmpty && activeQuestion == null) {
            activeQuestion = topQuestions.first;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> triggerDeepResearch() async {
    setState(() {
      isResearching = true;
      logs = ['Enqueuing background analysis task...'];
    });

    try {
      final res = await http.post(
        Uri.parse('http://localhost:8000/api/v1/subjects/${widget.subjectId}/deep-research'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        activeRunId = data['run_id'];
        pollProgress();
      }
    } catch (e) {
      setState(() {
        isResearching = false;
        logs.add('Error: Could not connect to deep research worker.');
      });
    }
  }

  Future<void> pollProgress() async {
    while (isResearching && activeRunId != null) {
      await Future.delayed(const Duration(seconds: 3));
      try {
        final res = await http.get(Uri.parse('http://localhost:8000/api/v1/research-runs/$activeRunId/progress'));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          setState(() {
            logs = List<String>.from(data['progress'] ?? []);
          });
          
          if (data['status'] == 'completed') {
            setState(() {
              isResearching = false;
              logs.add('Processing Complete! Compiling list...');
            });
            chatMessages.add({
              'role': 'agent',
              'text': 'Deep research task has completed successfully. I have extracted and clustered all recurring exam questions. The Top 50 prep list is now ready for review!'
            });
            fetchExistingQuestions();
            break;
          } else if (data['status'] == 'failed') {
            setState(() {
              isResearching = false;
              logs.add('Failed. See logs above.');
            });
            break;
          }
        }
      } catch (e) {
        break;
      }
    }
  }

  Future<void> sendChatMessage(String prompt) async {
    if (prompt.trim().isEmpty) return;
    setState(() {
      chatMessages.add({'role': 'student', 'text': prompt});
      isChatLoading = true;
    });
    chatController.clear();

    try {
      // Perplexity style chatbot interaction, if deep research completed, answer using subject info
      // Simple direct question answer hit:
      final res = await http.post(
        Uri.parse('http://localhost:8000/api/v1/projects/1/questions'), // fallback standard
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'question': prompt}),
      );
      // Simulating a fast response from general tutor
      final responseText = "I'm analyzing the subject '${widget.subjectName}' to assist you. To ask a follow-up on a specific exam question, please select that question on the right panel and use the follow-up chat box there.";
      setState(() {
        chatMessages.add({'role': 'agent', 'text': responseText});
      });
    } catch (_) {
      setState(() {
        chatMessages.add({'role': 'agent', 'text': 'Connection error. Please try again.'});
      });
    } finally {
      setState(() => isChatLoading = false);
    }
  }

  Future<void> sendFollowUpQuestion(int clusterId, String prompt) async {
    if (prompt.trim().isEmpty) return;
    setState(() {
      chatMessages.add({'role': 'student', 'text': 'Follow-up regarding selected question: $prompt'});
      isChatLoading = true;
    });
    followUpController.clear();

    try {
      final res = await http.post(
        Uri.parse('http://localhost:8000/api/v1/questions/clusters/$clusterId/ask'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': prompt}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          chatMessages.add({'role': 'agent', 'text': data['response']});
        });
      } else {
        setState(() {
          chatMessages.add({'role': 'agent', 'text': 'Tutor failed to process that follow-up question.'});
        });
      }
    } catch (_) {
      setState(() {
        chatMessages.add({'role': 'agent', 'text': 'Connection error. Please try again.'});
      });
    } finally {
      setState(() => isChatLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_outlined),
          onPressed: widget.onBack,
        ),
        title: Text('${widget.subjectName} — Research Workspace'),
        actions: [
          Center(child: Text('${widget.userName ?? "Student"} (${widget.standardName})', style: const TextStyle(fontWeight: FontWeight.bold))),
          IconButton(icon: const Icon(Icons.logout_outlined), onPressed: widget.onLogout),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          // Left Panel (Conversational chatbot + logs)
          Expanded(
            flex: 4,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                children: [
                  // Topic Headers
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: Colors.white,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Conversational RAG Agent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        if (!isResearching)
                          FilledButton.icon(
                            onPressed: triggerDeepResearch,
                            icon: const Icon(Icons.play_arrow_outlined),
                            label: const Text('Start Deep Research'),
                          )
                        else
                          Row(
                            children: const [
                              SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              SizedBox(width: 8),
                              Text('Deep Researching...', style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
                            ],
                          ),
                      ],
                    ),
                  ),
                  
                  // Live Progress log if active
                  if (logs.isNotEmpty)
                    Container(
                      height: 130,
                      width: double.infinity,
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF5FF), // soft lavender
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE9D5FF)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Live Execution Logs:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6B21A8), fontSize: 12)),
                          const SizedBox(height: 4),
                          Expanded(
                            child: ListView.builder(
                              itemCount: logs.length,
                              itemBuilder: (ctx, i) => Text(
                                logs[i],
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF7E22CE)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Chat Messages Area
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: chatMessages.length,
                      itemBuilder: (ctx, i) {
                        final msg = chatMessages[i];
                        final isAgent = msg['role'] == 'agent';
                        return Align(
                          alignment: isAgent ? Alignment.centerLeft : Alignment.centerRight,
                          child: Container(
                            maxWidth: 500,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isAgent ? Colors.white : const Color(0xFFEEF2F6),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(12),
                                topRight: const Radius.circular(12),
                                bottomLeft: isAgent ? Radius.zero : const Radius.circular(12),
                                bottomRight: isAgent ? const Radius.circular(12) : Radius.zero,
                              ),
                              border: isAgent ? Border.all(color: const Color(0xFFE2E8F0)) : null,
                            ),
                            child: LaTeXMarkdownText(text: msg['text'] ?? ''),
                          ),
                        );
                      },
                    ),
                  ),

                  if (isChatLoading)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))),
                    ),

                  // Bottom Prompt Bar
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.white,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: chatController,
                            decoration: const InputDecoration(
                              hintText: 'Ask the research agent about exam patterns...',
                              contentPadding: EdgeInsets.symmetric(horizontal: 16),
                            ),
                            onSubmitted: sendChatMessage,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send_outlined, color: Color(0xFF4F46E5)),
                          onPressed: () => sendChatMessage(chatController.text),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Right Panel (Top 50 Prep list)
          Expanded(
            flex: 6,
            child: Container(
              color: const Color(0xFFF1F5F9),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Top Recurring Prep Questions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Chip(
                          label: Text('${topQuestions.length} Topics Clustered'),
                          backgroundColor: const Color(0xFFEEF2F6),
                        ),
                      ],
                    ),
                  ),
                  
                  if (topQuestions.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'No questions analyzed yet.\nClick "Start Deep Research" in the left panel to begin.',
                          style: TextStyle(color: Color(0xFF64748B)),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Row(
                        children: [
                          // Clustered Questions List
                          Expanded(
                            flex: 5,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: topQuestions.length,
                              itemBuilder: (ctx, i) {
                                final c = topQuestions[i];
                                final isSelected = activeQuestion != null && activeQuestion['id'] == c['id'];
                                return GestureDetector(
                                  onTap: () => setState(() => activeQuestion = c),
                                  child: Card(
                                    color: isSelected ? const Color(0xFFEEF2F6) : Colors.white,
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFECFDF5),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'Appeared: ${c['frequency_count']}x',
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                                                ),
                                              ),
                                              Text(
                                                'Years: ${c['years_appeared']}',
                                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            c['canonical_text'],
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 4,
                                            children: (c['concept_tags'] as List<dynamic>).map<Widget>((tag) {
                                              return Chip(
                                                label: Text(tag, style: const TextStyle(fontSize: 10)),
                                                padding: EdgeInsets.zero,
                                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          
                          // Solution Viewer
                          if (activeQuestion != null)
                            Expanded(
                              flex: 7,
                              child: Container(
                                color: Colors.white,
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Solution & Analysis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    const Divider(),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              activeQuestion['canonical_text'],
                                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 16),
                                            const Text('Model Answer:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                                            const SizedBox(height: 8),
                                            LaTeXMarkdownText(text: activeQuestion['solution_markdown']),
                                          ],
                                        ),
                                      ),
                                    ),
                                    
                                    // Local reference tag links
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      color: const Color(0xFFF8FAFC),
                                      child: Text(
                                        'Reference file stored in: /papers_repository',
                                        style: TextStyle(fontStyle: FontStyle.italic, fontSize: 10, color: Colors.slate[600]),
                                      ),
                                    ),
                                    
                                    // Follow-up Chat block for active question
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: followUpController,
                                            decoration: const InputDecoration(
                                              hintText: 'Ask follow-up on this answer...',
                                              contentPadding: EdgeInsets.symmetric(horizontal: 12),
                                            ),
                                            onSubmitted: (val) => sendFollowUpQuestion(activeQuestion['id'], val),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.question_answer_outlined, color: Color(0xFF4F46E5)),
                                          onPressed: () => sendFollowUpQuestion(activeQuestion['id'], followUpController.text),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- LIGHTWEIGHT CUSTOM LATEX & MARKDOWN FORMATTED TEXT WIDGET ---
class LaTeXMarkdownText extends StatelessWidget {
  final String text;
  
  const LaTeXMarkdownText({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    // Custom parser that displays LaTeX math formulas block/inline beautifully without compile-time SDK issues
    final List<Widget> spans = [];
    final List<String> lines = text.split('\n');
    
    for (var line in lines) {
      if (line.trim().isEmpty) continue;
      
      // Parse block equations $$
      if (line.trim().startsWith('\$\$') && line.trim().endsWith('\$\$')) {
        final equation = line.replaceAll('\$\$', '').trim();
        spans.add(
          Container(
            width: double.infinity,
            alignment: Alignment.center,
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2F6),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Text(
              equation,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontStyle: FontStyle.italic,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF312E81), // deep indigo
              ),
            ),
          ),
        );
        continue;
      }
      
      // Parse Header
      if (line.startsWith('### ')) {
        spans.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            line.replaceFirst('### ', ''),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF4F46E5)),
          ),
        ));
        continue;
      }
      
      // Parse Bullet points
      bool isBullet = line.trim().startsWith('- ') || line.trim().startsWith('* ');
      String cleanLine = line;
      if (isBullet) {
        cleanLine = line.trim().replaceFirst('- ', '').replaceFirst('* ', '');
      }

      // Parse inline Math $ ... $
      List<TextSpan> inlineSpans = [];
      final parts = cleanLine.split('\$');
      for (int idx = 0; idx < parts.length; idx++) {
        final part = parts[idx];
        if (idx % 2 == 1) {
          // Math block
          inlineSpans.add(
            TextSpan(
              text: ' $part ',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.bold,
                backgroundColor: Color(0xFFF1F5F9),
                color: Color(0xFF4338CA),
              ),
            ),
          );
        } else {
          // Regular text check for ** bold
          final boldParts = part.split('\*\*');
          for (int bIdx = 0; bIdx < boldParts.length; bIdx++) {
            final bPart = boldParts[bIdx];
            inlineSpans.add(
              TextSpan(
                text: bPart,
                style: TextStyle(
                  fontWeight: bIdx % 2 == 1 ? FontWeight.bold : FontWeight.normal,
                  color: const Color(0xFF1E293B),
                ),
              ),
            );
          }
        }
      }
      
      spans.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isBullet)
                const Padding(
                  padding: EdgeInsets.only(top: 6, right: 8),
                  child: Icon(Icons.circle, size: 6, color: Color(0xFF64748B)),
                ),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13, height: 1.5),
                    children: inlineSpans,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: spans,
    );
  }
}

