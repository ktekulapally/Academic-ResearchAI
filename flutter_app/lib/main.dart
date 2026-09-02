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
        // Download Full Exam Kit Banner (Folder / Bundle)
        if (questionClusters.isNotEmpty || sourcePapers.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF131B2E)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.5)),
            ),
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final isNarrow = constraints.maxWidth < 650;
                return isNarrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.folder_special, color: Color(0xFFF59E0B), size: 24),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Complete Exam Kit (${selectedSubjectName ?? "Subject"} ${DateTime.now().year - selectedYears + 1}–${DateTime.now().year})',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.download_for_offline, size: 18),
                            label: const Text('Download All Papers & Booklet', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _downloadFullExamKit,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          const Icon(Icons.folder_special, color: Color(0xFFF59E0B), size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Complete Exam Kit: ${selectedSubjectName ?? "Subject"} (${DateTime.now().year - selectedYears + 1}–${DateTime.now().year})',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Download all 50 recurring questions, LaTeX solutions & paper references in a single offline package.',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.download_for_offline, size: 18),
                            label: const Text('Download All Papers & Booklet', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _downloadFullExamKit,
                          ),
                        ],
                      );
              },
            ),
          ),

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

  String _formatMarkdownToHtml(String md) {
    if (md.isEmpty) return '<p>No solution provided.</p>';

    var html = md;
    html = html.replaceAllMapped(RegExp(r'^### (.+)$', multiLine: true), (m) => '<h3>${m[1]}</h3>');
    html = html.replaceAllMapped(RegExp(r'^#### (.+)$', multiLine: true), (m) => '<h4>${m[1]}</h4>');
    html = html.replaceAllMapped(RegExp(r'^## (.+)$', multiLine: true), (m) => '<h2>${m[1]}</h2>');
    html = html.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => '<strong>${m[1]}</strong>');
    html = html.replaceAllMapped(RegExp(r'^[*-] (.+)$', multiLine: true), (m) => '<li>${m[1]}</li>');
    html = html.replaceAllMapped(RegExp(r'^\d+\.\s+(.+)$', multiLine: true), (m) => '<li style="list-style-type: decimal;">${m[1]}</li>');

    final lines = html.split('\n');
    final processed = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('<h') || trimmed.startsWith('<li') || trimmed.startsWith(r'$$')) {
        processed.add(trimmed);
      } else {
        processed.add('<p>$trimmed</p>');
      }
    }
    return processed.join('\n');
  }

  Widget _buildFormattedSolutionWidget(String raw) {
    final lines = raw.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(
            trimmed.replaceFirst('### ', ''),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFC084FC)),
          ),
        ));
      } else if (trimmed.startsWith('#### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 2),
          child: Text(
            trimmed.replaceFirst('#### ', ''),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF38BDF8)),
          ),
        ));
      } else if (trimmed.startsWith(r'$$') && trimmed.endsWith(r'$$')) {
        final formula = trimmed.replaceAll(r'$$', '').trim();
        widgets.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Row(
            children: [
              const Icon(Icons.functions, size: 16, color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  formula,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Color(0xFFFDE68A)),
                ),
              ),
            ],
          ),
        ));
      } else if (trimmed.startsWith('* ') || trimmed.startsWith('- ')) {
        final cleanBullet = _stripMarkdownChars(trimmed.substring(2));
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 14, fontWeight: FontWeight.bold)),
              Expanded(
                child: SelectableText(
                  cleanBullet,
                  style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFFCBD5E1)),
                ),
              ),
            ],
          ),
        ));
      } else {
        final cleanText = _stripMarkdownChars(trimmed);
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

  String _stripMarkdownChars(String text) {
    return text.replaceAll(r'**', '').replaceAll(r'__', '').replaceAll(r'###', '').replaceAll(r'####', '');
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
