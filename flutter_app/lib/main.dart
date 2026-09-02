import 'dart:async';
import 'dart:convert';
import 'dart:js' as js;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ========== CONFIGURATION ==========
const String kDefaultApiBase = 'https://rzgwoubtuyrpmwsezhqw.supabase.co/functions/v1';
const String kDefaultAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ6Z3dvdWJ0dXlycG13c2V6aHF3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgyNjgwNjEsImV4cCI6MjEwMzg0NDA2MX0.RhlE5RDZ2P7pn4NTYfP8klhTTxDYvvykK0cKQLXpV1w';


void main() {
  runApp(const AcademicResearchApp());
}

class AcademicResearchApp extends StatelessWidget {
  const AcademicResearchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Exam Focus AI — Edu Research',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8B5CF6), // Neon Violet
          secondary: Color(0xFF06B6D4), // Cyan
          surface: Color(0xFF131B2E),
          surfaceContainerHighest: Color(0xFF1E293B),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF131B2E),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF1E293B), width: 1),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B0F19),
          elevation: 0,
        ),
      ),
      home: const StudentHomeScreen(),
    );
  }
}

// ========== MAIN STUDENT HOME SCREEN ==========
class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> with SingleTickerProviderStateMixin {
  String apiBase = kDefaultApiBase;
  String anonKey = kDefaultAnonKey;

  bool isGuest = true;
  String studentName = "Guest Student";

  // Taxonomy State
  List<dynamic> standards = [];
  List<dynamic> streams = [];
  List<dynamic> subjects = [];

  int? selectedStandardId;
  int? selectedStreamId;
  int? selectedSubjectId;
  String? selectedSubjectName;

  // Search & Filter State
  int selectedYears = 10; // 5, 7, 10
  final TextEditingController _queryController = TextEditingController();
  bool isSearchingNLP = false;

  // Deep Research State
  bool isResearching = false;
  List<String> researchLogs = [];
  String? activeJobId;
  // 'idle' | 'running' | 'done' | 'failed' | 'timeout'
  String researchStatus = 'idle';
  String? researchError;
  int _pollCount = 0;
  static const int _maxPolls = 75; // 75 × 2s = 150s timeout

  // Results State
  late TabController _tabController;
  List<dynamic> questionClusters = [];
  List<dynamic> sourcePapers = [];
  bool isLoadingResults = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStandards();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _queryController.dispose();
    super.dispose();
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $anonKey',
        'apikey': anonKey,
      };

  // ========== API METHODS ==========
  Future<void> _loadStandards() async {
    try {
      final res = await http.get(
        Uri.parse('$apiBase/taxonomy?type=standards'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        setState(() {
          standards = data;
          if (standards.isNotEmpty) {
            _selectStandard(standards.first['id']);
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _selectStandard(int standardId) async {
    setState(() {
      selectedStandardId = standardId;
      selectedStreamId = null;
      selectedSubjectId = null;
      selectedSubjectName = null;
      streams = [];
      subjects = [];
      questionClusters = [];
      sourcePapers = [];
    });

    try {
      final res = await http.get(
        Uri.parse('$apiBase/taxonomy?type=streams&standard_id=$standardId'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        setState(() {
          streams = data;
          if (streams.isNotEmpty) {
            _selectStream(streams.first['id']);
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _selectStream(int streamId) async {
    setState(() {
      selectedStreamId = streamId;
      selectedSubjectId = null;
      selectedSubjectName = null;
      subjects = [];
      questionClusters = [];
      sourcePapers = [];
    });

    try {
      final res = await http.get(
        Uri.parse('$apiBase/taxonomy?type=subjects&stream_id=$streamId'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        setState(() {
          subjects = data;
          if (subjects.isNotEmpty) {
            _selectSubject(subjects.first['id'], subjects.first['name']);
          }
        });
      }
    } catch (_) {}
  }

  void _selectSubject(int subjectId, String name) {
    setState(() {
      selectedSubjectId = subjectId;
      selectedSubjectName = name;
    });
    _fetchTopQuestionsAndPapers(subjectId);
  }

  Future<void> _fetchTopQuestionsAndPapers(int subjectId) async {
    setState(() => isLoadingResults = true);
    try {
      final res = await http.get(
        Uri.parse('$apiBase/top-questions?subject_id=$subjectId&limit=50'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          setState(() {
            questionClusters = data['clusters'] ?? [];
            sourcePapers = data['papers'] ?? [];
          });
        } else if (data is List) {
          setState(() {
            questionClusters = data;
          });
        }
      }
    } catch (_) {} finally {
      setState(() => isLoadingResults = false);
    }
  }

  // Smart client-side NLP query parser — works offline, no extra edge function needed
  Future<void> _handleNLPQuery(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => isSearchingNLP = true);

    final q = query.toLowerCase();

    // ---- Detect years horizon ----
    if (q.contains('10 year') || q.contains('10year') || q.contains('last 10')) {
      setState(() => selectedYears = 10);
    } else if (q.contains('7 year') || q.contains('7year') || q.contains('last 7')) {
      setState(() => selectedYears = 7);
    } else if (q.contains('5 year') || q.contains('5year') || q.contains('last 5')) {
      setState(() => selectedYears = 5);
    }

    // ---- Detect board/standard by keyword ----
    int? matchedStdId;
    for (final s in standards) {
      final name = (s['name'] as String).toLowerCase();
      if (q.contains(name) || name.split(' ').any((w) => w.length > 3 && q.contains(w))) {
        matchedStdId = s['id'];
        break;
      }
    }

    if (matchedStdId != null && matchedStdId != selectedStandardId) {
      await _selectStandard(matchedStdId);
    }

    // ---- Detect subject by keyword in current subjects list ----
    int? matchedSubId;
    String? matchedSubName;
    for (final sub in subjects) {
      final name = (sub['name'] as String).toLowerCase();
      if (q.contains(name) || name.split(' ').any((w) => w.length > 3 && q.contains(w))) {
        matchedSubId = sub['id'];
        matchedSubName = sub['name'];
        break;
      }
    }

    if (matchedSubId != null) {
      _selectSubject(matchedSubId, matchedSubName!);
      setState(() => isSearchingNLP = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF8B5CF6),
          content: Text('✅ Showing results for "$matchedSubName" · ${selectedYears} year analysis'),
        ),
      );
      return;
    }

    // ---- If subject not matched yet, auto-trigger deep research with the query as prompt ----
    if (selectedSubjectId != null) {
      setState(() => isSearchingNLP = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF8B5CF6),
          content: Text('🔬 Launching deep research with your query…'),
        ),
      );
      _startDeepResearch();
      return;
    }

    setState(() => isSearchingNLP = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFFF59E0B),
        content: Text('👆 Please select a Board & Subject first, then use AI search to refine results.'),
      ),
    );
  }

  // Trigger Deep Research
  Future<void> _startDeepResearch() async {
    if (selectedSubjectId == null) return;
    setState(() {
      isResearching = true;
      researchStatus = 'running';
      researchError = null;
      _pollCount = 0;
      researchLogs = [
        '⏱ ${_timestamp()} Initiating deep research for $selectedSubjectName ($selectedYears years)…',
        '🌐 ${_timestamp()} Connecting to academic research agent…',
      ];
    });

    // Simulated progress stage updates while backend AI models synthesize data
    int elapsed = 0;
    final progressTimer = Stream.periodic(const Duration(seconds: 4)).listen((_) {
      if (!isResearching) return;
      elapsed += 4;
      String? stageMsg;
      if (elapsed == 4) {
        stageMsg = '🔍 ${_timestamp()} Searching Google & official portals for $selectedSubjectName papers ($selectedYears yrs)…';
      } else if (elapsed == 10) {
        stageMsg = '📄 ${_timestamp()} Extracting exam archives, question structures & marking schemes…';
      } else if (elapsed == 18) {
        stageMsg = '🧠 ${_timestamp()} Gemini 2.0 analyzing frequency, clustering recurring patterns & compiling LaTeX…';
      } else if (elapsed == 28) {
        stageMsg = '📐 ${_timestamp()} Formatting step-by-step model solutions & step marking hints…';
      } else if (elapsed == 40) {
        stageMsg = '💾 ${_timestamp()} Storing question clusters and PDF source references to database…';
      } else if (elapsed % 15 == 0) {
        stageMsg = '⏳ ${_timestamp()} Finalizing research compilation (${elapsed}s elapsed)…';
      }
      if (stageMsg != null) {
        setState(() => researchLogs = [...researchLogs, stageMsg!]);
      }
    });

    try {
      final res = await http.post(
        Uri.parse('$apiBase/start-research'),
        headers: _headers,
        body: jsonEncode({
          'subject_id': selectedSubjectId,
          'years': selectedYears,
          'query_prompt': _queryController.text.trim().isNotEmpty
              ? _queryController.text.trim()
              : null,
        }),
      ).timeout(const Duration(seconds: 180)); // 3 minutes timeout for thorough AI generation

      progressTimer.cancel();

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        activeJobId = data['job_id']?.toString();
        final status = data['status']?.toString();
        final qCount = data['question_count'] ?? data['clusters']?.length ?? 50;

        if (status == 'done') {
          setState(() {
            isResearching = false;
            researchStatus = 'done';
            researchLogs = [
              ...researchLogs,
              '🎉 ${_timestamp()} Research complete! Generated $qCount recurring questions with solutions.',
            ];
          });
          await _fetchTopQuestionsAndPapersWithLog(selectedSubjectId!);
          return;
        }

        if (activeJobId != null) {
          setState(() => researchLogs = [
            ...researchLogs,
            '✅ ${_timestamp()} Job queued (ID: $activeJobId). Polling for completion…',
          ]);
          _pollJobProgress(activeJobId!);
        } else {
          _setResearchFailed('Server returned unexpected response: ${res.body}');
        }
      } else {
        _setResearchFailed('HTTP ${res.statusCode}: ${res.body}');
      }
    } on Exception catch (e) {
      progressTimer.cancel();
      _setResearchFailed('Network / timeout error: $e');
    }
  }

  Future<void> _pollJobProgress(String jobId) async {
    while (isResearching) {
      await Future.delayed(const Duration(seconds: 2));
      _pollCount++;

      // ---- Timeout check ----
      if (_pollCount >= _maxPolls) {
        _setResearchTimeout();
        return;
      }

      try {
        final res = await http.get(
          Uri.parse('$apiBase/job-progress?id=$jobId'),
          headers: _headers,
        ).timeout(const Duration(seconds: 15));

        if (res.statusCode != 200) {
          setState(() => researchLogs = [
            ...researchLogs,
            '⚠ ${_timestamp()} Poll returned HTTP ${res.statusCode}. Retrying…',
          ]);
          continue;
        }

        final data = jsonDecode(res.body);
        final status = (data['status'] as String?) ?? 'unknown';
        final rawLogs = List<String>.from(data['progress'] ?? []);

        setState(() {
          researchLogs = [
            '⏱ ${_timestamp()} Status: $status  (poll $_pollCount/$_maxPolls)',
            ...rawLogs,
          ];
        });

        if (status == 'done') {
          setState(() {
            isResearching = false;
            researchStatus = 'done';
            researchLogs = [
              ...researchLogs,
              '🎉 ${_timestamp()} Research complete! Loading results…',
            ];
          });
          await _fetchTopQuestionsAndPapersWithLog(selectedSubjectId!);
          return;
        }

        if (status == 'failed') {
          _setResearchFailed(data['error']?.toString() ?? 'Edge function reported failure');
          return;
        }
      } on Exception catch (e) {
        setState(() => researchLogs = [
          ...researchLogs,
          '⚠ ${_timestamp()} Poll error (will retry): $e',
        ]);
        // Don't break — retry next loop
      }
    }
  }

  Future<void> _fetchTopQuestionsAndPapersWithLog(int subjectId) async {
    setState(() => isLoadingResults = true);
    try {
      final res = await http.get(
        Uri.parse('$apiBase/top-questions?subject_id=$subjectId&limit=50'),
        headers: _headers,
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          setState(() {
            questionClusters = data['clusters'] ?? [];
            sourcePapers = data['papers'] ?? [];
            researchLogs = [
              ...researchLogs,
              '📊 ${_timestamp()} Loaded ${questionClusters.length} questions & ${sourcePapers.length} sources.',
            ];
          });
        } else if (data is List) {
          setState(() {
            questionClusters = data;
            researchLogs = [
              ...researchLogs,
              '📊 ${_timestamp()} Loaded ${questionClusters.length} questions.',
            ];
          });
        }
      } else {
        setState(() => researchLogs = [
          ...researchLogs,
          '❌ ${_timestamp()} Failed to load results: HTTP ${res.statusCode}',
        ]);
      }
    } on Exception catch (e) {
      setState(() => researchLogs = [
        ...researchLogs,
        '❌ ${_timestamp()} Error loading results: $e',
      ]);
    } finally {
      setState(() => isLoadingResults = false);
    }
  }

  void _setResearchFailed(String error) {
    setState(() {
      isResearching = false;
      researchStatus = 'failed';
      researchError = error;
      researchLogs = [
        ...researchLogs,
        '❌ ${_timestamp()} FAILED: $error',
      ];
    });
  }

  void _setResearchTimeout() {
    setState(() {
      isResearching = false;
      researchStatus = 'timeout';
      researchError = 'Research timed out after ${_maxPolls * 2} seconds. The AI agent may still be running — try refreshing in a minute.';
      researchLogs = [
        ...researchLogs,
        '⏰ ${_timestamp()} TIMEOUT: No response after ${_maxPolls * 2}s.',
      ];
    });
  }

  String _timestamp() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, "0")}:${now.minute.toString().padLeft(2, "0")}:${now.second.toString().padLeft(2, "0")}';
  }

  // Ask AI Tutor Modal
  void _openTutorModal(int clusterId, String questionText, String? solution) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131B2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => TutorChatSheet(
        clusterId: clusterId,
        questionText: questionText,
        solution: solution,
        apiBase: apiBase,
        anonKey: anonKey,
      ),
    );
  }

  // Configure Supabase Endpoint Settings Modal
  void _openSettingsDialog() {
    final baseController = TextEditingController(text: apiBase);
    final keyController = TextEditingController(text: anonKey);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        title: const Text('⚡ Cloud Endpoint Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: baseController,
              decoration: const InputDecoration(
                labelText: 'Supabase Functions URL',
                hintText: 'https://xxxx.supabase.co/functions/v1',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: keyController,
              decoration: const InputDecoration(
                labelText: 'Supabase Anon Public Key',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              setState(() {
                apiBase = baseController.text.trim();
                anonKey = keyController.text.trim();
              });
              Navigator.pop(ctx);
              _loadStandards();
            },
            child: const Text('Save & Reconnect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 850;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.school, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Exam Focus AI',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                Text(
                  'Academic Deep Research & Question Bank',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Guest mode indicator button (outlined, subtle)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF334155)),
              foregroundColor: const Color(0xFF94A3B8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            icon: const Icon(Icons.person_outline, size: 16),
            label: Text(
              studentName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Color(0xFF1E293B),
                  content: Text('👤 Browsing as Guest — results visible without an account'),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          // Login / Sign In button (filled, prominent)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            icon: const Icon(Icons.login, size: 16),
            label: const Text(
              'Login',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Color(0xFF8B5CF6),
                  content: Text('🔐 Login / Sign-up coming soon — track your progress & save questions!'),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Natural Language AI Search Bar
            _buildNLPSearchBar(),

            const SizedBox(height: 18),

            // 2. Academic Hierarchy Selectors (Standard -> Stream -> Subject)
            _buildHierarchyFilters(),

            const SizedBox(height: 18),

            // 3. Time Horizon Selector (5 / 7 / 10 Years) + Start Research CTA
            _buildYearAndResearchControls(),

            const SizedBox(height: 20),

            // 4. Results: Live Research Terminal + Question Bank + Sources
            _buildResultsSection(isDesktop),
          ],
        ),
      ),
    );
  }

  // ========== UI BUILDER COMPONENTS ==========

  Widget _buildNLPSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _queryController,
              onSubmitted: _handleNLPQuery,
              decoration: const InputDecoration(
                hintText: 'Ask AI: "CBSE 12th Physics 5 marks derivations for last 7 years"…',
                hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                border: InputBorder.none,
              ),
            ),
          ),
          if (isSearchingNLP)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8B5CF6)),
            )
          else
            IconButton(
              icon: const Icon(Icons.search, color: Color(0xFF06B6D4)),
              onPressed: () => _handleNLPQuery(_queryController.text),
            ),
        ],
      ),
    );
  }

  Widget _buildHierarchyFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step 1: Board & Class
          Row(
            children: const [
              Icon(Icons.school, size: 18, color: Color(0xFF8B5CF6)),
              SizedBox(width: 8),
              Text(
                '1. Academic Board & Class',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: standards.map((s) {
              final isSelected = s['id'] == selectedStandardId;
              return ChoiceChip(
                avatar: Icon(
                  isSelected ? Icons.check_circle : Icons.school_outlined,
                  size: 16,
                  color: isSelected ? Colors.white : const Color(0xFF8B5CF6),
                ),
                label: Text(
                  s['name'],
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                selected: isSelected,
                onSelected: (_) => _selectStandard(s['id']),
                selectedColor: const Color(0xFF8B5CF6),
                backgroundColor: const Color(0xFF0B0F19),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFF334155),
                ),
              );
            }).toList(),
          ),

          if (streams.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: Color(0xFF1E293B), height: 1),
            ),
            // Step 2: Stream / Group
            Row(
              children: const [
                Icon(Icons.category, size: 18, color: Color(0xFF06B6D4)),
                SizedBox(width: 8),
                Text(
                  '2. Stream / Group',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: streams.map((st) {
                final isSelected = st['id'] == selectedStreamId;
                return ChoiceChip(
                  avatar: Icon(
                    isSelected ? Icons.check_circle : Icons.layers_outlined,
                    size: 16,
                    color: isSelected ? Colors.white : const Color(0xFF06B6D4),
                  ),
                  label: Text(
                    st['name'],
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (_) => _selectStream(st['id']),
                  selectedColor: const Color(0xFF06B6D4),
                  backgroundColor: const Color(0xFF0B0F19),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF06B6D4) : const Color(0xFF334155),
                  ),
                );
              }).toList(),
            ),
          ],

          if (subjects.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: Color(0xFF1E293B), height: 1),
            ),
            // Step 3: Target Subject
            Row(
              children: const [
                Icon(Icons.menu_book, size: 18, color: Color(0xFF10B981)),
                SizedBox(width: 8),
                Text(
                  '3. Target Subject',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: subjects.map((sub) {
                final isSelected = sub['id'] == selectedSubjectId;
                return ChoiceChip(
                  avatar: Icon(
                    isSelected ? Icons.check_circle : Icons.book,
                    size: 16,
                    color: isSelected ? Colors.white : const Color(0xFF10B981),
                  ),
                  label: Text(
                    sub['name'],
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (_) => _selectSubject(sub['id'], sub['name']),
                  selectedColor: const Color(0xFF10B981),
                  backgroundColor: const Color(0xFF0B0F19),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF10B981) : const Color(0xFF334155),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildYearAndResearchControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 650;
          return isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.history, size: 18, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 8),
                        const Text(
                          'Analysis Horizon:',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            alignment: WrapAlignment.end,
                            children: [5, 7, 10].map((y) => _buildYearChip(y)).toList(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: isResearching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.rocket_launch, size: 18),
                      label: Text(
                        isResearching ? 'Deep Researching…' : 'Start Deep Research',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      onPressed: isResearching || selectedSubjectId == null ? null : _startDeepResearch,
                    ),
                  ],
                )
              : Row(
                  children: [
                    const Icon(Icons.history, size: 18, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 8),
                    const Text(
                      'Analysis Horizon: ',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 10),
                    ...[5, 7, 10].map((y) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _buildYearChip(y),
                        )),
                    const Spacer(),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: isResearching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.rocket_launch, size: 18),
                      label: Text(
                        isResearching ? 'Deep Researching…' : 'Start Deep Research',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      onPressed: isResearching || selectedSubjectId == null ? null : _startDeepResearch,
                    ),
                  ],
                );
        },
      ),
    );
  }

  Widget _buildYearChip(int y) {
    final isSel = selectedYears == y;
    return ChoiceChip(
      label: Text('$y Yrs'),
      selected: isSel,
      onSelected: (_) => setState(() => selectedYears = y),
      selectedColor: const Color(0xFFF59E0B),
      backgroundColor: const Color(0xFF0B0F19),
      labelStyle: TextStyle(
        color: isSel ? Colors.black : const Color(0xFFCBD5E1),
        fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
      ),
      side: BorderSide(
        color: isSel ? const Color(0xFFF59E0B) : const Color(0xFF334155),
      ),
    );
  }

  Widget _buildResearchTerminal() {
    final statusColor = researchStatus == 'done'
        ? const Color(0xFF10B981)
        : researchStatus == 'failed' || researchStatus == 'timeout'
            ? const Color(0xFFEF4444)
            : const Color(0xFF8B5CF6);

    final statusIcon = researchStatus == 'done'
        ? Icons.check_circle
        : researchStatus == 'failed'
            ? Icons.error
            : researchStatus == 'timeout'
                ? Icons.timer_off
                : Icons.radar;

    final statusLabel = researchStatus == 'done'
        ? '✅ Research Complete'
        : researchStatus == 'failed'
            ? '❌ Research Failed'
            : researchStatus == 'timeout'
                ? '⏰ Research Timed Out'
                : '🔬 AI Agent Deep Researching…';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.6), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Terminal header bar ──────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(children: [
              Icon(statusIcon, color: statusColor, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(statusLabel, style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 13))),
              if (isResearching)
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: statusColor)),
              if (!isResearching && researchStatus != 'idle')
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: statusColor, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Re-Run', style: TextStyle(fontSize: 12)),
                  onPressed: _startDeepResearch,
                ),
            ]),
          ),

          // ── Error/Timeout banner ────────────────────────────────
          if (researchError != null)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.5)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline, size: 14, color: Color(0xFFEF4444)),
                const SizedBox(width: 8),
                Expanded(child: Text(researchError!, style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444), height: 1.4))),
              ]),
            ),

          // ── Live log terminal ───────────────────────────────────
          Container(
            height: 200,
            padding: const EdgeInsets.all(12),
            child: researchLogs.isEmpty
                ? const Center(child: Text('Waiting for first log entry…', style: TextStyle(color: Color(0xFF4B5563), fontSize: 12)))
                : ListView.builder(
                    reverse: true,
                    itemCount: researchLogs.length,
                    itemBuilder: (ctx, i) {
                      final log = researchLogs[researchLogs.length - 1 - i];
                      final logColor = log.startsWith('❌') || log.startsWith('⏰')
                          ? const Color(0xFFEF4444)
                          : log.startsWith('✅') || log.startsWith('🎉') || log.startsWith('📊')
                              ? const Color(0xFF10B981)
                              : log.startsWith('⚠')
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF94A3B8);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1.5),
                        child: Text(
                          log,
                          style: TextStyle(fontSize: 11.5, color: logColor, fontFamily: 'monospace', height: 1.4),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection(bool isDesktop) {
    // Show terminal whenever there are logs (running, done, failed, or timeout)
    final showTerminal = researchLogs.isNotEmpty || isResearching;

    if (questionClusters.isEmpty && sourcePapers.isEmpty && !isLoadingResults && !showTerminal) {
      return _buildEmptyState('Select a subject above and click "Start Deep Research" to harvest top recurring questions, model solutions & research sources.');
    }


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Live Research Terminal (always visible when research ran) ─
        if (showTerminal) _buildResearchTerminal(),

        // ── Download Full Exam Kit Banner ──────────────────────────
        if (questionClusters.isNotEmpty)
          Container(

            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1E1B4B), Color(0xFF131B2E)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.5)),
            ),
            child: LayoutBuilder(builder: (ctx, constraints) {
              final isNarrow = constraints.maxWidth < 650;
              final kitLabel = 'Complete Exam Kit: ${selectedSubjectName ?? "Subject"} (${DateTime.now().year - selectedYears + 1}–${DateTime.now().year})';
              return isNarrow
                  ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        const Icon(Icons.folder_special, color: Color(0xFFF59E0B), size: 22),
                        const SizedBox(width: 10),
                        Expanded(child: Text(kitLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white))),
                      ]),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        icon: const Icon(Icons.download_for_offline, size: 18),
                        label: const Text('Download All Papers & Booklet', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _downloadFullExamKit,
                      ),
                    ])
                  : Row(children: [
                      const Icon(Icons.folder_special, color: Color(0xFFF59E0B), size: 22),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(kitLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                        const SizedBox(height: 2),
                        const Text('Download all recurring questions, LaTeX solutions & paper references in a single offline package.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      ])),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        icon: const Icon(Icons.download_for_offline, size: 18),
                        label: const Text('Download All Papers & Booklet', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _downloadFullExamKit,
                      ),
                    ]);
            }),
          ),

        // ── Tab Bar ───────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(color: const Color(0xFF131B2E), borderRadius: BorderRadius.circular(12)),
          child: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF8B5CF6),
            labelColor: const Color(0xFF8B5CF6),
            unselectedLabelColor: const Color(0xFF94A3B8),
            tabs: [
              Tab(icon: const Icon(Icons.auto_stories, size: 18), text: 'Top Recurring Questions (${questionClusters.length})'),
              Tab(icon: const Icon(Icons.travel_explore, size: 18), text: 'Research Sources (${sourcePapers.length})'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Tab Content — NO fixed height, scrolls with page ──────
        isLoadingResults
            ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            : AnimatedBuilder(
                animation: _tabController,
                builder: (ctx, _) {
                  if (_tabController.index == 0) {
                    // ── Tab 1: Question Bank ───────────────────────
                    if (questionClusters.isEmpty) {
                      return _buildEmptyState('No recurring questions yet. Click "Start Deep Research" above!');
                    }
                    return Column(
                      children: [
                        for (int i = 0; i < questionClusters.length; i++)
                          _buildQuestionClusterCard(questionClusters[i], i + 1),
                      ],
                    );
                  } else {
                    // ── Tab 2: Research Sources ────────────────────
                    return _buildResearchSourcesPanel();
                  }
                },
              ),
      ],
    );
  }



  /// Research Sources Panel — shows all web references used during AI research
  /// with domain favicon, title, URL, and a "Dig Deeper" button per source.
  Widget _buildResearchSourcesPanel() {
    if (sourcePapers.isEmpty) {
      return _buildEmptyState('No research sources yet.\nClick "Start Deep Research" above to let the AI agent search live web sources.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header explanation
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.travel_explore, size: 18, color: Color(0xFF06B6D4)),
                const SizedBox(width: 8),
                const Text('Live Web Research Trail', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
              ]),
              const SizedBox(height: 6),
              const Text(
                'These are the official sources the AI agent searched and analyzed to build your question bank. Review them to judge research depth — and click "Dig Deeper" on any source to re-run focused research on that specific paper or topic.',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.5),
              ),
            ],
          ),
        ),

        // Source cards
        for (final paper in sourcePapers)
          _buildResearchSourceCard(paper),

        // Dig Deeper from scratch CTA
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1B4B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🔁 Want even deeper research?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
              const SizedBox(height: 6),
              Text(
                'The AI analyzed ${sourcePapers.length} source${sourcePapers.length == 1 ? "" : "s"} this round. You can extend the analysis horizon or run a new deep research pass to find more patterns and sources.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.rocket_launch, size: 16),
                    label: const Text('Re-Run Deep Research', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: isResearching ? null : _startDeepResearch,
                  ),
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResearchSourceCard(dynamic paper) {
    final title = (paper['title'] ?? 'Research Source').toString();
    final year = paper['year'] ?? DateTime.now().year;
    final examType = (paper['exam_type'] ?? 'Web Source').toString();
    final paperUrl = (paper['paper_url'] ?? '').toString();
    final isDirectPdf = paperUrl.toLowerCase().contains('.pdf');

    // Extract readable domain from URL
    String domain = 'Web Source';
    try {
      final uri = Uri.parse(paperUrl);
      domain = uri.host.replaceFirst('www.', '');
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Domain badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDirectPdf ? const Color(0xFFEF4444).withOpacity(0.15) : const Color(0xFF06B6D4).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDirectPdf ? const Color(0xFFEF4444) : const Color(0xFF06B6D4), width: 0.5),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(isDirectPdf ? Icons.picture_as_pdf : Icons.language, size: 14, color: isDirectPdf ? const Color(0xFFEF4444) : const Color(0xFF06B6D4)),
                    const SizedBox(width: 5),
                    Text(isDirectPdf ? 'PDF' : domain, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDirectPdf ? const Color(0xFFEF4444) : const Color(0xFF06B6D4))),
                  ]),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white)),
                      const SizedBox(height: 3),
                      Text('$year • $examType', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // URL chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0F19),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Text(
                paperUrl.length > 80 ? '${paperUrl.substring(0, 80)}…' : paperUrl,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 10),
            // Action buttons row
            Row(children: [
              // Open source
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: isDirectPdf ? const Color(0xFFEF4444) : const Color(0xFF06B6D4)),
                  foregroundColor: isDirectPdf ? const Color(0xFFEF4444) : const Color(0xFF06B6D4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: Icon(isDirectPdf ? Icons.download : Icons.open_in_new, size: 14),
                label: Text(isDirectPdf ? 'Download PDF' : 'Open Source', style: const TextStyle(fontSize: 12)),
                onPressed: () => _openOrDownloadUrl(paperUrl, title),
              ),
              const SizedBox(width: 8),
              // Dig Deeper from this source
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.radar, size: 14),
                label: const Text('Dig Deeper', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: isResearching
                    ? null
                    : () {
                        _queryController.text = 'Focus on: $title ($year)';
                        _tabController.animateTo(0);
                        _startDeepResearch();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF8B5CF6),
                            content: Text('🔬 Re-searching focused on "$title"…'),
                          ),
                        );
                      },
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionClusterCard(dynamic item, int rank) {
    final text = item['canonical_text'] ?? '';
    final freq = item['frequency_count'] ?? 1;
    final years = List<int>.from(item['years_appeared'] ?? []);
    final solution = item['solution_markdown'];
    final marks = item['marks_hint'] ?? '4 Marks';
    final qType = item['question_type'] ?? 'Derivation';
    final clusterId = item['id'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: rank <= 3 ? const Color(0xFFF59E0B) : const Color(0xFF8B5CF6),
          child: Text('#$rank', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
        ),
        title: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Text('🔥 Repeated ${freq}x', style: const TextStyle(fontSize: 11, color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(marks, style: const TextStyle(fontSize: 11, color: Color(0xFF06B6D4))),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(qType, style: const TextStyle(fontSize: 11, color: Color(0xFF10B981))),
              ),
              Text(
                'Years: ${years.join(", ")}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF0B0F19),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '📖 Step-by-Step Model Solution & LaTeX Formula:',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6), fontSize: 13),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: const Color(0xFF06B6D4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.chat, size: 14),
                      label: const Text('Ask AI Tutor', style: TextStyle(fontSize: 12)),
                      onPressed: () => _openTutorModal(clusterId, text, solution),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildFormattedSolutionWidget(solution ?? 'Solution is compiling in the background...'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourcePaperCard(dynamic paper) {
    final title = paper['title'] ?? 'Board Exam Paper';
    final year = paper['year'] ?? 2024;
    final examType = paper['exam_type'] ?? 'Annual Public Exam';
    final fileSize = paper['file_size'] ?? '1.6 MB';
    final paperUrl = (paper['paper_url'] ?? '').toString();
    final isDirectPdf = paperUrl.toLowerCase().contains('.pdf');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (isDirectPdf ? const Color(0xFFEF4444) : const Color(0xFF06B6D4)).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isDirectPdf ? Icons.picture_as_pdf : Icons.language,
            color: isDirectPdf ? const Color(0xFFEF4444) : const Color(0xFF06B6D4),
            size: 24,
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(
          isDirectPdf
              ? '$year • $examType • $fileSize (Direct PDF)'
              : '$year • Official Portal • Web Archive Paper',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        ),
        trailing: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDirectPdf ? const Color(0xFF10B981) : const Color(0xFF0284C7),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: Icon(isDirectPdf ? Icons.file_download_outlined : Icons.open_in_new, size: 16),
          label: Text(isDirectPdf ? 'Download PDF' : 'Open Portal Page'),
          onPressed: () {
            if (paperUrl.isNotEmpty) {
              _openOrDownloadUrl(paperUrl, '$title.pdf');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: isDirectPdf ? const Color(0xFF10B981) : const Color(0xFF0284C7),
                  content: Text(isDirectPdf ? 'Opening & downloading $title...' : 'Opening $title portal page...'),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link not available for this paper.')),
              );
            }
          },
        ),
      ),
    );
  }

  void _downloadFullExamKit() {
    if (questionClusters.isEmpty && sourcePapers.isEmpty) return;

    final currentYear = DateTime.now().year;
    final fromYear = currentYear - selectedYears + 1;
    String standardName = 'Board';
    try {
      final std = standards.firstWhere((s) => s['id'] == selectedStandardId);
      standardName = std['name'] ?? 'Board';
    } catch (_) {}

    final subName = selectedSubjectName ?? 'Exam_Subject';
    final safeFileName = '${standardName}_${subName}_Papers_${fromYear}-${currentYear}'
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');

    final buffer = StringBuffer();
    buffer.writeln('''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$standardName - $subName Papers ($fromYear-$currentYear)</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; color: #1e293b; background: #f8fafc; padding: 24px; max-width: 900px; margin: 0 auto; }
    .header { background: #1e1b4b; color: white; padding: 24px; border-radius: 16px; margin-bottom: 24px; }
    .badge { display: inline-block; padding: 4px 10px; border-radius: 999px; font-size: 12px; font-weight: bold; margin-right: 6px; }
    .badge-amber { background: #fef3c7; color: #92400e; }
    .badge-cyan { background: #cffafe; color: #155e75; }
    .badge-green { background: #d1fae5; color: #065f46; }
    .card { background: white; border: 1px solid #e2e8f0; border-radius: 12px; padding: 20px; margin-bottom: 18px; box-shadow: 0 1px 3px rgba(0,0,0,0.05); }
    .question-title { font-size: 16px; font-weight: 700; color: #0f172a; margin-bottom: 12px; }
    .solution-box { background: #f8fafc; border: 1px solid #e2e8f0; border-left: 4px solid #8b5cf6; padding: 16px 20px; border-radius: 0 10px 10px 0; margin-top: 12px; font-size: 14px; }
    .sol-header { font-size: 14px; font-weight: bold; color: #6b21a8; margin-bottom: 10px; }
    h2 { font-size: 20px; color: #1e1b4b; margin-top: 24px; margin-bottom: 12px; }
    h3 { font-size: 16px; color: #5b21b6; margin-top: 14px; margin-bottom: 6px; border-bottom: 1px solid #e9d5ff; padding-bottom: 4px; }
    h4 { font-size: 14px; color: #0369a1; margin-top: 12px; margin-bottom: 4px; }
    p { margin: 6px 0; }
    ul { margin: 6px 0; padding-left: 20px; }
    li { margin-bottom: 4px; }
    .print-btn { background: #8b5cf6; color: white; border: none; padding: 10px 20px; border-radius: 8px; font-weight: bold; cursor: pointer; float: right; }
    .papers-list a { display: inline-block; background: #10b981; color: white; padding: 8px 14px; border-radius: 8px; text-decoration: none; font-weight: 500; font-size: 13px; margin: 4px; }
    @media print { .print-btn { display: none; } body { background: white; padding: 0; } .card { box-shadow: none; border-color: #cbd5e1; page-break-inside: avoid; } }
    .math-block { background: #f8f0ff; border-left: 3px solid #8b5cf6; padding: 8px 14px; border-radius: 0 8px 8px 0; margin: 8px 0; font-family: 'Cambria Math', serif; color: #3b0764; }
    code { background: #f1f5f9; padding: 1px 5px; border-radius: 3px; font-size: 13px; }
    ul { margin: 6px 0; padding-left: 22px; }
    ul li { margin-bottom: 4px; }
    hr { border: none; border-top: 1px solid #e2e8f0; margin: 12px 0; }
  </style>
  <!-- MathJax Configuration for Chemistry & Math formulas -->
  <script>
    window.MathJax = {
      tex: {
        inlineMath: [['\$', '\$'], ['\\\\(', '\\\\)']],
        displayMath: [['\$\$', '\$\$'], ['\\\\[', '\\\\]']],
        processEscapes: true
      },
      chtml: {
        scale: 1.05
      }
    };
  </script>
  <script id="MathJax-script" async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-chtml.js"></script>
</head>
<body>
  <div class="header">
    <button class="print-btn" onclick="window.print()">🖨️ Save as PDF / Print Booklet</button>
    <h1 style="margin:0 0 8px 0; font-size: 24px;">$standardName — $subName</h1>
    <p style="margin:0; opacity: 0.9;">Official Board Exam Analysis & Question Papers Booklet ($fromYear–$currentYear)</p>
    <div style="margin-top: 12px;">
      <span class="badge badge-amber">🔥 ${questionClusters.length} Recurring Questions</span>
      <span class="badge badge-cyan">📥 ${sourcePapers.length} Papers & References</span>
    </div>
  </div>

  <h2>📑 Top Recurring Questions & Model Solutions</h2>
''');

    for (int i = 0; i < questionClusters.length; i++) {
      final q = questionClusters[i];
      final text = q['canonical_text'] ?? '';
      final freq = q['frequency_count'] ?? 1;
      final years = (q['years_appeared'] as List<dynamic>?)?.join(', ') ?? '';
      final marks = q['marks_hint'] ?? '4 Marks';
      final qType = q['question_type'] ?? 'Theory';
      final sol = q['solution_markdown'] ?? 'Model solution provided in app.';

      buffer.writeln('''
  <div class="card">
    <div style="margin-bottom: 8px;">
      <span class="badge badge-amber">#${i + 1} • Repeated ${freq}x</span>
      <span class="badge badge-cyan">$marks</span>
      <span class="badge badge-green">$qType</span>
      <span style="font-size: 12px; color: #64748b;">Years: $years</span>
    </div>
    <div class="question-title">${_formatMarkdownToHtml(text)}</div>
    <div class="solution-box">
      <div class="sol-header">📖 Step-by-Step Model Solution:</div>
      ${_formatMarkdownToHtml(sol)}
    </div>
  </div>
''');
    }

    if (sourcePapers.isNotEmpty) {
      buffer.writeln('''
  <h2 style="margin-top: 32px;">📥 Question Papers & Official Source Archives</h2>
  <div class="card papers-list">
''');
      for (final p in sourcePapers) {
        final pTitle = p['title'] ?? 'Board Exam Paper';
        final pYear = p['year'] ?? currentYear;
        final pUrl = p['paper_url'] ?? '#';
        final pSize = p['file_size'] ?? '1.6 MB';
        buffer.writeln('''
    <div style="margin-bottom: 12px; padding-bottom: 12px; border-bottom: 1px solid #f1f5f9;">
      <strong>$pTitle ($pYear)</strong> — $pSize<br>
      <a href="$pUrl" target="_blank" rel="noopener noreferrer">📄 Open / Download Paper</a>
    </div>
''');
      }
      buffer.writeln('  </div>');
    }

    buffer.writeln('''
</body>
</html>''');

    _triggerHtmlDownload(buffer.toString(), '$safeFileName.html');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF10B981),
        content: Text('Downloaded Exam Kit: $safeFileName.html (Open to view or Save as PDF)!'),
      ),
    );
  }

  /// Converts Markdown text to clean HTML — for downloaded booklet.
  /// Critical: process #### before ### before ## to avoid partial matches.
  String _formatMarkdownToHtml(String md) {
    if (md.isEmpty) return '<p>No solution provided.</p>';

    final lines = md.split('\n');
    final out = StringBuffer();
    bool inList = false;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        if (inList) { out.writeln('</ul>'); inList = false; }
        continue;
      }

      // ---- Headings (#### must come before ### before ##) ----
      if (line.startsWith('#### ')) {
        if (inList) { out.writeln('</ul>'); inList = false; }
        out.writeln('<h4>${_inlineMarkdown(line.substring(5))}</h4>');
      } else if (line.startsWith('### ')) {
        if (inList) { out.writeln('</ul>'); inList = false; }
        out.writeln('<h3>${_inlineMarkdown(line.substring(4))}</h3>');
      } else if (line.startsWith('## ')) {
        if (inList) { out.writeln('</ul>'); inList = false; }
        out.writeln('<h2>${_inlineMarkdown(line.substring(3))}</h2>');
      } else if (line.startsWith('# ')) {
        if (inList) { out.writeln('</ul>'); inList = false; }
        out.writeln('<h2>${_inlineMarkdown(line.substring(2))}</h2>');
      }
      // ---- Bullet lists ----
      else if (line.startsWith('* ') || line.startsWith('- ')) {
        if (!inList) { out.writeln('<ul>'); inList = true; }
        out.writeln('<li>${_inlineMarkdown(line.substring(2))}</li>');
      }
      // ---- Numbered lists ----
      else if (RegExp(r'^\d+\.\s').hasMatch(line)) {
        if (inList) { out.writeln('</ul>'); inList = false; }
        final content = line.replaceFirst(RegExp(r'^\d+\.\s+'), '');
        out.writeln('<li style="list-style-type:decimal;margin-left:18px">${_inlineMarkdown(content)}</li>');
      }
      // ---- Display math block: $$ ... $$ ----
      else if (line.startsWith(r'$$') && line.endsWith(r'$$') && line.length > 4) {
        if (inList) { out.writeln('</ul>'); inList = false; }
        out.writeln('<div class="math-block">${_escapeHtml(line)}</div>');
      }
      // ---- Horizontal rule ----
      else if (line == '---' || line == '***') {
        if (inList) { out.writeln('</ul>'); inList = false; }
        out.writeln('<hr>');
      }
      // ---- Normal paragraph ----
      else {
        if (inList) { out.writeln('</ul>'); inList = false; }
        out.writeln('<p>${_inlineMarkdown(line)}</p>');
      }
    }
    if (inList) out.writeln('</ul>');
    return out.toString();
  }

  /// Converts inline Markdown (bold, inline code, inline math $...$) to HTML.
  String _inlineMarkdown(String text) {
    var t = _escapeHtml(text);
    // Inline code `...`
    t = t.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => '<code style="background:#e2e8f0;padding:1px 5px;border-radius:3px;font-size:13px">${m[1]}</code>');
    // Bold **...**
    t = t.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => '<strong>${m[1]}</strong>');
    // Italic *...*
    t = t.replaceAllMapped(RegExp(r'\*(.+?)\*'), (m) => '<em>${m[1]}</em>');
    return t;
  }

  /// Renders Markdown solution in-app as Flutter widgets, line by line.
  Widget _buildFormattedSolutionWidget(String raw) {
    final lines = raw.split('\n');
    final widgets = <Widget>[];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) { widgets.add(const SizedBox(height: 4)); continue; }

      // ---- Headings ----
      if (line.startsWith('#### ')) {
        widgets.add(_solHeading(line.substring(5), const Color(0xFF38BDF8), 13));
      } else if (line.startsWith('### ')) {
        widgets.add(_solHeading(line.substring(4), const Color(0xFFC084FC), 14));
      } else if (line.startsWith('## ') || line.startsWith('# ')) {
        final text = line.startsWith('## ') ? line.substring(3) : line.substring(2);
        widgets.add(_solHeading(text, Colors.white, 15));
      }
      // ---- Display math $$...$$ ----
      else if (line.startsWith(r'$$') && line.endsWith(r'$$') && line.length > 4) {
        final formula = line.substring(2, line.length - 2).trim();
        widgets.add(_solMathBlock(formula));
      }
      // ---- Bullet ----
      else if (line.startsWith('* ') || line.startsWith('- ')) {
        widgets.add(_solBullet(_stripInlineMarkdown(line.substring(2))));
      }
      // ---- Numbered list ----
      else if (RegExp(r'^\d+\.\s').hasMatch(line)) {
        final content = line.replaceFirst(RegExp(r'^\d+\.\s+'), '');
        widgets.add(_solBullet(_stripInlineMarkdown(content)));
      }
      // ---- Horizontal rule ---
      else if (line == '---') {
        widgets.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(color: Color(0xFF334155), height: 1),
        ));
      }
      // ---- Normal paragraph ----
      else {
        final cleanText = _stripInlineMarkdown(line);
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: SelectableText(
            cleanText,
            style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFFE2E8F0)),
          ),
        ));
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  Widget _solHeading(String text, Color color, double size) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 3),
    child: Text(
      _stripInlineMarkdown(text),
      style: TextStyle(fontWeight: FontWeight.bold, fontSize: size, color: color),
    ),
  );

  Widget _solMathBlock(String formula) => Container(
    margin: const EdgeInsets.symmetric(vertical: 6),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF0F172A),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF334155)),
    ),
    child: Row(children: [
      const Icon(Icons.functions, size: 16, color: Color(0xFFF59E0B)),
      const SizedBox(width: 8),
      Expanded(child: SelectableText(
        formula,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Color(0xFFFDE68A)),
      )),
    ]),
  );

  Widget _solBullet(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('• ', style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 14, fontWeight: FontWeight.bold)),
      Expanded(child: SelectableText(
        text,
        style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFFCBD5E1)),
      )),
    ]),
  );

  /// Strips all Markdown syntax for plain-text Flutter widgets.
  String _stripInlineMarkdown(String text) {
    return text
        .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1')
        .replaceAll('**', '')
        .replaceAll(RegExp(r'\*(.+?)\*'), r'$1')
        .replaceAll('*', '')
        .replaceAll('__', '')
        .replaceAll(RegExp(r'`([^`]+)`'), r'$1')
        .replaceAll(r'####', '')
        .replaceAll(r'###', '')
        .replaceAll(r'##', '')
        .replaceAll(r'#', '')
        .trim();
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  void _triggerHtmlDownload(String content, String filename) {
    try {
      final base64Content = base64Encode(utf8.encode(content));
      js.context.callMethod('eval', ["""
        (function(b64, name) {
          var a = document.createElement('a');
          a.href = 'data:text/html;charset=utf-8;base64,' + b64;
          a.download = name;
          document.body.appendChild(a);
          a.click();
          document.body.removeChild(a);
        })('$base64Content', '$filename')
      """]);
    } catch (_) {
      _openOrDownloadUrl('data:text/html;charset=utf-8;base64,' + base64Encode(utf8.encode(content)), filename);
    }
  }

  void _openOrDownloadUrl(String url, String filename) {
    try {
      js.context.callMethod('open', [url, '_blank']);
    } catch (_) {}
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_stories_outlined, size: 48, color: Color(0xFF475569)),
          const SizedBox(height: 12),
          Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
        ],
      ),
    );
  }
}

// ========== AI TUTOR CHAT SHEET ==========
class TutorChatSheet extends StatefulWidget {
  final int clusterId;
  final String questionText;
  final String? solution;
  final String apiBase;
  final String anonKey;

  const TutorChatSheet({
    super.key,
    required this.clusterId,
    required this.questionText,
    this.solution,
    required this.apiBase,
    required this.anonKey,
  });

  @override
  State<TutorChatSheet> createState() => _TutorChatSheetState();
}

class _TutorChatSheetState extends State<TutorChatSheet> {
  final TextEditingController _promptController = TextEditingController();
  final List<Map<String, String>> messages = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    messages.add({
      'sender': 'tutor',
      'text': 'Hello! I am your AI Academic Tutor. Feel free to ask any doubt or ask me to explain any step of this question!',
    });
  }

  Future<void> _sendPrompt() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      messages.add({'sender': 'student', 'text': prompt});
      isLoading = true;
    });
    _promptController.clear();

    try {
      final res = await http.post(
        Uri.parse('${widget.apiBase}/ask-tutor'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.anonKey}',
          'apikey': widget.anonKey,
        },
        body: jsonEncode({
          'cluster_id': widget.clusterId,
          'prompt': prompt,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          messages.add({'sender': 'tutor', 'text': data['response'] ?? 'Answer received.'});
        });
      } else {
        setState(() {
          messages.add({'sender': 'tutor', 'text': 'Sorry, I encountered an error answering that.'});
        });
      }
    } catch (e) {
      setState(() {
        messages.add({'sender': 'tutor', 'text': 'Connection error: $e'});
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SizedBox(
        height: 550,
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.school, color: Color(0xFF8B5CF6)),
                const SizedBox(width: 8),
                const Text('AI Academic Tutor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(color: Color(0xFF1E293B)),
            Expanded(
              child: ListView.builder(
                itemCount: messages.length,
                itemBuilder: (ctx, idx) {
                  final m = messages[idx];
                  final isStudent = m['sender'] == 'student';
                  return Align(
                    alignment: isStudent ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isStudent ? const Color(0xFF8B5CF6) : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(m['text'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.white)),
                    ),
                  );
                },
              ),
            ),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(color: Color(0xFF8B5CF6)),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _promptController,
                      onSubmitted: (_) => _sendPrompt(),
                      decoration: const InputDecoration(
                        hintText: 'Ask a doubt on this question...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFF8B5CF6)),
                    onPressed: _sendPrompt,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
