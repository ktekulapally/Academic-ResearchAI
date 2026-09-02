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

  // NLP Query Decomposition Agent
  Future<void> _handleNLPQuery(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => isSearchingNLP = true);

    try {
      final res = await http.post(
        Uri.parse('$apiBase/parse-query'),
        headers: _headers,
        body: jsonEncode({'query': query}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final stdId = data['detected_standard_id'];
        final subId = data['detected_subject_id'];
        final years = data['years'];

        if (years != null && [5, 7, 10].contains(years)) {
          setState(() => selectedYears = years);
        }

        if (stdId != null) {
          await _selectStandard(stdId);
        }

        if (subId != null) {
          final subName = data['detected_subject_name'] ?? 'Subject';
          _selectSubject(subId, subName);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF8B5CF6),
            content: Text(data['search_summary'] ?? 'Search filter applied!'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.redAccent, content: Text('NLP Parser error: $e')),
      );
    } finally {
      setState(() => isSearchingNLP = false);
    }
  }

  // Trigger Deep Research
  Future<void> _startDeepResearch() async {
    if (selectedSubjectId == null) return;
    setState(() {
      isResearching = true;
      researchLogs = ['Initiating deep research for $selectedSubjectName (${selectedYears} Years)...'];
    });

    try {
      final res = await http.post(
        Uri.parse('$apiBase/start-research'),
        headers: _headers,
        body: jsonEncode({
          'subject_id': selectedSubjectId,
          'years': selectedYears,
          'query_prompt': _queryController.text.trim().isNotEmpty ? _queryController.text.trim() : null,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        activeJobId = data['job_id'];
        _pollJobProgress(activeJobId!);
      } else {
        setState(() => isResearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text('Research trigger failed: ${res.body}')),
        );
      }
    } catch (e) {
      setState(() => isResearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.redAccent, content: Text('Connection error: $e')),
      );
    }
  }

  Future<void> _pollJobProgress(String jobId) async {
    while (isResearching) {
      await Future.delayed(const Duration(seconds: 2));
      try {
        final res = await http.get(
          Uri.parse('$apiBase/job-progress?id=$jobId'),
          headers: _headers,
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final status = data['status'];
          final logs = List<String>.from(data['progress'] ?? []);

          setState(() {
            researchLogs = logs;
          });

          if (status == 'done') {
            setState(() => isResearching = false);
            _fetchTopQuestionsAndPapers(selectedSubjectId!);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: Color(0xFF10B981),
                content: Text('🎉 Deep Research & LaTeX Question Bank compiled successfully!'),
              ),
            );
            break;
          } else if (status == 'failed') {
            setState(() => isResearching = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(backgroundColor: Colors.redAccent, content: Text('Research failed: ${data['error']}')),
            );
            break;
          }
        }
      } catch (_) {
        break;
      }
    }
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
          // Guest / Profile badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: Color(0xFF8B5CF6)),
                const SizedBox(width: 6),
                Text(studentName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF94A3B8)),
            onPressed: _openSettingsDialog,
            tooltip: 'Configure Cloud API',
          ),
          const SizedBox(width: 8),
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

            // 4. Research Progress Overlay (if active)
            if (isResearching) _buildProgressOverlay(),

            const SizedBox(height: 16),

            // 5. Dual Tabs: Question Bank (LaTeX Solutions) & Downloadable Papers Hub
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

  Widget _buildProgressOverlay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B4B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF8B5CF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.radar, color: Color(0xFF8B5CF6), size: 20),
              SizedBox(width: 8),
              Text(
                'AI Agent Live Deep Researching…',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...researchLogs.map(
            (log) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '• $log',
                style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1), fontFamily: 'monospace'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection(bool isDesktop) {
    return Column(
      children: [
        // Tabs Header
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF131B2E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF8B5CF6),
            labelColor: const Color(0xFF8B5CF6),
            unselectedLabelColor: const Color(0xFF94A3B8),
            tabs: [
              Tab(
                icon: const Icon(Icons.auto_stories, size: 18),
                text: 'Top Recurring Questions (${questionClusters.length})',
              ),
              Tab(
                icon: const Icon(Icons.download, size: 18),
                text: 'Downloadable Papers Hub (${sourcePapers.length})',
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Tabs Content
        SizedBox(
          height: 600,
          child: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Question Bank
              isLoadingResults
                  ? const Center(child: CircularProgressIndicator())
                  : questionClusters.isEmpty
                      ? _buildEmptyState('No recurring questions yet. Click "Start Deep Research" above to harvest questions!')
                      : ListView.builder(
                          itemCount: questionClusters.length,
                          itemBuilder: (ctx, idx) => _buildQuestionClusterCard(questionClusters[idx], idx + 1),
                        ),

              // Tab 2: Downloadable Papers Hub
              isLoadingResults
                  ? const Center(child: CircularProgressIndicator())
                  : sourcePapers.isEmpty
                      ? _buildEmptyState('No PDF papers harvested yet for this subject.')
                      : ListView.builder(
                          itemCount: sourcePapers.length,
                          itemBuilder: (ctx, idx) => _buildSourcePaperCard(sourcePapers[idx]),
                        ),
            ],
          ),
        ),
      ],
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
                SelectableText(
                  solution ?? 'Solution is compiling in the background...',
                  style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFFE2E8F0)),
                ),
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
    final paperUrl = paper['paper_url'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.picture_as_pdf, color: Color(0xFFEF4444), size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text('$year • $examType • $fileSize', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        trailing: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.file_download_outlined, size: 16),
          label: const Text('Download PDF'),
          onPressed: () {
            if (paperUrl.toString().isNotEmpty) {
              _openOrDownloadUrl(paperUrl.toString(), '$title.pdf');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF10B981),
                  content: Text('Opening & downloading $title...'),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PDF link not available for this paper.')),
              );
            }
          },
        ),
      ),
    );
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
