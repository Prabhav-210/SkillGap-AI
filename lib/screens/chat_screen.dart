import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../data/progress_data.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final bool isThinking; // Flag for the animated thinking indicator

  ChatMessage({required this.text, required this.isUser, this.isThinking = false});
}

class ChatScreen extends StatefulWidget {
  final String? selectedCareer;
  final String? loadSessionKey;

  const ChatScreen({Key? key, this.selectedCareer, this.loadSessionKey}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();

  // Structured conversation state
  int _currentStep = 0;
  final List<String> _userResponses = [];
  bool _isAnalyzed = false;
  bool _isProcessing = false; // Prevent duplicate analysis triggers
  String _lastAIResponse = ''; // Stores the latest roadmap for follow-up context
  late String _sessionKey; // Unique key for this chat session
  List<Map<String, dynamic>> _chatSessions = []; // List of all saved chats for the sidebar
  
  // Voice & Resume Logic
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _waitingForResumeConsent = false;
  final ScrollController _scrollController = ScrollController();

  final List<String> _aiQuestions = [
    "What do you want to become?",
    "What skills do you have?",
    "Any projects?",
    "You can upload your resume for better analysis or continue without it.",
  ];

  late final List<ChatMessage> _messages = [
    ChatMessage(text: _aiQuestions[0], isUser: false),
  ];

  @override
  void initState() {
    super.initState();

    // Generate or reuse session key
    _sessionKey = widget.loadSessionKey ??
        'chat_session_${DateTime.now().millisecondsSinceEpoch}';

    // Load existing session if key was passed
    if (widget.loadSessionKey != null) {
      _loadSession();
    } else if (widget.selectedCareer != null && widget.selectedCareer!.isNotEmpty) {
      // If a career was passed from CareerSelectionScreen, auto-start the flow
      Future.microtask(() {
        _handleSubmitted("I want to become a ${widget.selectedCareer}");
      });
    }
    
    // Initial history load
    _loadHistory();
  }

  // ---------------------------------------------------------------------------
  // Sidebar: Load list of all chat sessions
  // ---------------------------------------------------------------------------
  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('chat_session_')).toList();
    keys.sort((a, b) => b.compareTo(a)); // Newest first

    // Load custom titles
    final titlesStr = prefs.getString('chat_titles') ?? '{}';
    final Map<String, dynamic> customTitles = jsonDecode(titlesStr);

    final sessions = <Map<String, dynamic>>[];
    for (final key in keys) {
      final jsonStr = prefs.getString(key);
      if (jsonStr == null) continue;

      final List<dynamic> messages = jsonDecode(jsonStr);
      if (messages.isEmpty) continue;

      // Use custom title if available, else derive from first user message
      String title = customTitles[key] ?? '';
      
      if (title.isEmpty) {
        for (final msg in messages) {
          if (msg['isUser'] == true) {
            title = msg['text'] as String;
            // Clean up common prefixes
            title = title.replaceFirst(RegExp(r'I want to become a ', caseSensitive: false), '');
            title = title.replaceFirst(RegExp(r'I want to be a ', caseSensitive: false), '');
            break;
          }
        }
      }
      
      if (title.isEmpty) title = 'New Chat';

      final timestamp = key.replaceFirst('chat_session_', '');
      sessions.add({
        'key': key,
        'title': title,
        'timestamp': timestamp,
      });
    }

    if (mounted) {
      setState(() {
        _chatSessions = sessions;
      });
    }
  }

  Future<void> _renameChat(String key, String newTitle) async {
    if (newTitle.trim().isEmpty) return;
    
    final prefs = await SharedPreferences.getInstance();
    final titlesStr = prefs.getString('chat_titles') ?? '{}';
    final Map<String, dynamic> customTitles = jsonDecode(titlesStr);
    
    customTitles[key] = newTitle.trim();
    await prefs.setString('chat_titles', jsonEncode(customTitles));
    
    _loadHistory();
  }

  Future<void> _deleteChat(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    
    // Also delete the linked roadmap
    await deleteRoadmapById(key);
    
    // Also remove from custom titles if exists
    final titlesStr = prefs.getString('chat_titles') ?? '{}';
    final Map<String, dynamic> customTitles = jsonDecode(titlesStr);
    if (customTitles.containsKey(key)) {
      customTitles.remove(key);
      await prefs.setString('chat_titles', jsonEncode(customTitles));
    }

    // If deleting current chat, start a new one
    if (key == _sessionKey) {
      setState(() {
        _sessionKey = 'chat_session_${DateTime.now().millisecondsSinceEpoch}';
        _messages.clear();
        _messages.add(ChatMessage(text: _aiQuestions[0], isUser: false));
        _isAnalyzed = false;
        _currentStep = 0;
        _userResponses.clear();
        _lastAIResponse = '';
      });
    }
    
    _loadHistory();
  }

  void _showChatOptions(Map<String, dynamic> session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(session['title'], maxLines: 1, overflow: TextOverflow.ellipsis),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(session);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(session);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(Map<String, dynamic> session) {
    final controller = TextEditingController(text: session['title']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rename Chat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter new title',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _renameChat(session['key'], controller.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Chat?'),
        content: const Text('This will permanently remove this conversation.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _deleteChat(session['key']);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _switchToSession(String key) {
    setState(() {
      _sessionKey = key;
      _messages.clear();
      _isAnalyzed = false;
      _currentStep = 0;
      _userResponses.clear();
      _lastAIResponse = '';
    });
    _loadSession();
    Navigator.pop(context); // Close drawer
  }

  void _startNewChat() {
    setState(() {
      _sessionKey = 'chat_session_${DateTime.now().millisecondsSinceEpoch}';
      _messages.clear();
      _messages.add(ChatMessage(text: _aiQuestions[0], isUser: false));
      _isAnalyzed = false;
      _currentStep = 0;
      _userResponses.clear();
      _lastAIResponse = '';
    });
    _loadHistory();
    Navigator.pop(context); // Close drawer
  }

  String _formatHistoryDate(String timestamp) {
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
      final now = DateTime.now();
      if (date.year == now.year && date.month == now.month && date.day == now.day) {
        return 'Today';
      }
      return '${date.day}/${date.month}';
    } catch (_) {
      return '';
    }
  }

  // ---------------------------------------------------------------------------
  // Persistence: save & load chat messages
  // ---------------------------------------------------------------------------
  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList = _messages
        .where((m) => !m.isThinking) // Don't persist thinking indicators
        .map((m) => {'text': m.text, 'isUser': m.isUser})
        .toList();
    await prefs.setString(_sessionKey, jsonEncode(jsonList));
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_sessionKey);
    if (jsonStr == null) return;

    final List<dynamic> jsonList = jsonDecode(jsonStr);
    if (jsonList.isEmpty) return;

    setState(() {
      _messages.clear();
      for (final item in jsonList) {
        _messages.add(ChatMessage(
          text: item['text'] as String,
          isUser: item['isUser'] as bool,
        ));
      }
      // Mark as analyzed if we loaded a session (follow-up mode)
      _isAnalyzed = true;
      // Try to recover the last AI response for follow-up context
      for (final msg in _messages) {
        if (!msg.isUser && msg.text.contains('Week')) {
          _lastAIResponse = msg.text;
          break;
        }
      }
    });
  }

  // Colors adapted from the primary palette
  final Color primaryColor = const Color(0xFF1E3A8A);
  final Color secondaryColor = const Color(0xFF3B82F6);
  final Color backgroundColor = const Color(0xFFF3F4F6);

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty || _isProcessing) return;

    _textController.clear();

    // --- Follow-up mode: user asks questions after roadmap ---
    if (_isAnalyzed) {
      setState(() {
        _messages.insert(0, ChatMessage(text: text, isUser: true));
      });
      _saveMessages();
      _sendFollowUp(text);
      _scrollToBottom();
      return;
    }

    // --- Resume Consent Flow ---
    if (_waitingForResumeConsent) {
      setState(() {
        _messages.insert(0, ChatMessage(text: text, isUser: true));
        _waitingForResumeConsent = false;
      });
      
      final lower = text.toLowerCase();
      if (lower.contains('yes') || lower.contains('yeah') || lower.contains('sure')) {
        _uploadResumeAndAnalyze();
      } else {
        _askNext("Okay! Feel free to ask me any questions about your roadmap or career path.");
      }
      _saveMessages();
      _scrollToBottom();
      return;
    }

    // --- Ethical Check ---
    if (_isHarmful(text)) {
      setState(() {
        _messages.insert(0, ChatMessage(text: text, isUser: true));
        _messages.insert(0, ChatMessage(text: "This is not a valid or ethical career path. I cannot assist with that. Let’s focus on a legal and productive career.", isUser: false));
      });
      _saveMessages();
      return;
    }

    setState(() {
      _messages.insert(0, ChatMessage(text: text, isUser: true));

      // Intelligent Flow Logic
      if (_currentStep == 0) {
        // 1. Goal: Save as title immediately
        _renameChat(_sessionKey, text);
        _userResponses.add(text);
        _currentStep = 1;
        _askNext(_aiQuestions[1]);
      } else if (_currentStep == 1) {
        // 2. Skills
        _userResponses.add(text);
        if (_hasNoSkills(text)) {
          _currentStep = 3; // Skip projects
          _runGeminiAnalysis();
        } else {
          _currentStep = 2;
          _askNext(_aiQuestions[2]);
        }
      } else if (_currentStep == 2) {
        // 3. Projects
        _userResponses.add(text);
        _currentStep = 3;
        _runGeminiAnalysis();
      }
    });
    _saveMessages();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _textController.text = val.recognizedWords;
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _uploadResumeAndAnalyze() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      setState(() {
        _messages.insert(
          0,
          ChatMessage(text: "Resume uploaded: ${result.files.single.name}. Analyzing...", isUser: true),
        );
        _isProcessing = true;
      });

      try {
        final career = _userResponses.isNotEmpty ? _userResponses[0] : "Career Path";
        final String resumePrompt = '''Analyze this resume based on the career goal: $career.
The user wants to become a $career. 
Provide:
- Strengths for this role
- Missing skills/Gaps
- Improvements needed

Use plain text and bullet points. No markdown.''';

        final response = await _callGemini(resumePrompt);
        
        if (mounted) {
          setState(() {
            _messages.insert(0, ChatMessage(text: response, isUser: false));
            _isProcessing = false;
          });
          _saveMessages();
          _scrollToBottom();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _messages.insert(0, ChatMessage(text: "Error analyzing resume. Please try again.", isUser: false));
            _isProcessing = false;
          });
        }
      }
    }
  }

  bool _isHarmful(String text) {
    final lower = text.toLowerCase();
    return lower.contains('thief') || lower.contains('fraud') || lower.contains('scam') || lower.contains('robbery') || lower.contains('killer');
  }

  bool _hasNoSkills(String text) {
    final lower = text.toLowerCase();
    return lower.contains('no skills') || lower.contains('don\'t have') || lower.contains('none') || lower.contains('zero');
  }

  void _askNext(String question) {
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _messages.insert(0, ChatMessage(text: question, isUser: false));
        });
        _saveMessages();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Follow-up: send user question with previous roadmap as context
  // ---------------------------------------------------------------------------
  Future<void> _sendFollowUp(String question) async {
    _isProcessing = true;

    setState(() {
      _messages.insert(
        0,
        ChatMessage(text: "Thinking...", isUser: false, isThinking: true),
      );
    });

    try {
      final String followUpPrompt = '''You are a strict, professional career advisor. The user already received this roadmap:

$_lastAIResponse

User now asks:
$question

Rules:
- Answer ONLY the user's question.
- Do NOT repeat the full roadmap.
- Be direct, practical, and concise.
- Use plain text with bullet points (dashes).
- No markdown symbols. No motivational language.''';

      final String reply = await _callGemini(followUpPrompt)
          .timeout(const Duration(seconds: 15), onTimeout: () {
        return "Could not process your question. Try again.";
      });

      if (mounted) {
        setState(() {
          if (_messages.isNotEmpty && _messages[0].isThinking) {
            _messages.removeAt(0);
          }
          _messages.insert(0, ChatMessage(text: reply, isUser: false));
        });
        _saveMessages();
      }
    } catch (e) {
      print("Follow-up ERROR: $e");
      if (mounted) {
        setState(() {
          if (_messages.isNotEmpty && _messages[0].isThinking) {
            _messages.removeAt(0);
          }
          _messages.insert(
            0,
            ChatMessage(text: "Could not process your question. Try again.", isUser: false),
          );
        });
        _saveMessages();
      }
    } finally {
      _isProcessing = false;
    }
  }


  // ---------------------------------------------------------------------------
  // Thinking animation: cycles through dots for ~2 seconds
  // ---------------------------------------------------------------------------
  Future<void> _showThinkingAnimation() async {
    // Insert the initial thinking message
    setState(() {
      _messages.insert(
        0,
        ChatMessage(text: "Analyzing your profile.", isUser: false, isThinking: true),
      );
    });

    final List<String> dots = [
      "Analyzing your profile.",
      "Analyzing your profile..",
      "Analyzing your profile...",
    ];

    // Cycle through dot variants over ~2 seconds (4 cycles × 500ms)
    for (int i = 0; i < 4; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() {
        _messages[0] = ChatMessage(
          text: dots[(i + 1) % dots.length],
          isUser: false,
          isThinking: true,
        );
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Build the structured fallback response with dynamic career insertion
  // ---------------------------------------------------------------------------
  String _buildFallbackResponse(String career) {
    final String searchTerm = Uri.encodeComponent(career);
    return '''Strengths:
- Interest in becoming a $career
- Willingness to start learning

Gaps:
- No foundational knowledge identified
- No practical experience provided
- No domain-specific skills listed

Action Plan:

Week 1: Study core fundamentals of $career
- Identify 2-3 reliable learning sources
- Complete introductory material

Resources:
- Coursera: https://www.coursera.org/search?query=$searchTerm
- YouTube: https://www.youtube.com/results?search_query=${Uri.encodeComponent('$career full course for beginners')}
- Google: https://www.google.com/search?q=${Uri.encodeComponent('$career free course')}

Week 2: Practice basic concepts through exercises
- Solve beginner-level problems daily
- Take notes on weak areas

Resources:
- YouTube: https://www.youtube.com/results?search_query=${Uri.encodeComponent('$career practice exercises')}
- Google: https://www.google.com/search?q=${Uri.encodeComponent('$career beginner exercises')}

Week 3: Build one small project from scratch
- Apply what was learned in Week 1 and 2
- Document the process

Resources:
- YouTube: https://www.youtube.com/results?search_query=${Uri.encodeComponent('$career beginner project tutorial')}
- Google: https://www.google.com/search?q=${Uri.encodeComponent('$career project ideas for beginners')}

Week 4: Review gaps and explore intermediate topics
- Revisit weak areas from Week 2
- Start one advanced concept

Resources:
- Coursera: https://www.coursera.org/search?query=${Uri.encodeComponent('$career intermediate')}
- YouTube: https://www.youtube.com/results?search_query=${Uri.encodeComponent('$career advanced topics')}''';
  }

  // ---------------------------------------------------------------------------
  // Deliver the response in staggered sections for a natural feel
  // ---------------------------------------------------------------------------
  Future<void> _deliverResponseInSections(String fullResponse) async {
    // Split the response into its logical sections (separated by double newline)
    final List<String> sections = fullResponse.split('\n\n');

    // Remove the thinking bubble before delivering the first section
    setState(() {
      if (_messages.isNotEmpty && _messages[0].isThinking) {
        _messages.removeAt(0);
      }
    });

    String accumulated = '';
    for (int i = 0; i < sections.length; i++) {
      accumulated += (i == 0 ? '' : '\n\n') + sections[i];
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      setState(() {
        // Replace/insert the growing message at position 0
        if (i == 0) {
          _messages.insert(0, ChatMessage(text: accumulated, isUser: false));
        } else {
          _messages[0] = ChatMessage(text: accumulated, isUser: false);
        }
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Extract "Week" lines from the AI response and store them in progressData
  // ---------------------------------------------------------------------------
  void _extractAndStoreRoadmap(String responseText) {
    final lines = responseText.split('\n');
    final weekLines = lines
        .where((line) => RegExp(r'Week\s*\d', caseSensitive: false).hasMatch(line))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    // Extract resources: "- [Platform]: [URL]"
    final resourceLines = lines
        .where((line) => line.trim().startsWith('-') && line.contains('http'))
        .toList();
    
    final List<Map<String, String>> resources = resourceLines.map((line) {
      final parts = line.replaceFirst('-', '').split(':');
      final platform = parts[0].trim();
      final url = parts.skip(1).join(':').trim();
      return {'title': platform, 'url': url};
    }).toList();

    if (weekLines.isNotEmpty) {
      final career = _userResponses.isNotEmpty ? _userResponses[0] : "Career Path";
      addRoadmap(id: _sessionKey, title: career, weekLines: weekLines, resources: resources);
    }
  }

  // ---------------------------------------------------------------------------
  // Main analysis pipeline: thinking → Gemini (or fallback) → staggered delivery
  // ---------------------------------------------------------------------------
  Future<void> _runGeminiAnalysis() async {
    _currentStep++; // Increment to prevent re-triggering completion block
    _isProcessing = true;

    // --- Step 1: Show animated thinking dots ---
    await _showThinkingAnimation();

    final String career = _userResponses.isNotEmpty ? _userResponses[0] : "Unspecified";
    final String skills = _userResponses.length > 1 ? _userResponses[1] : "None";
    final String projects = _userResponses.length > 2 ? _userResponses[2] : "None";

    final String prompt = '''You are a strict, professional career advisor.
Based on the following user details, generate a skill gap analysis and roadmap.

Target Career: $career
Current Skills: $skills
Completed Projects: $projects

Strict Format Rules:
- No markdown (** or ##).
- No motivational text or conversational fluff.
- Use this exact structure:

Strengths:
- [strength]

Gaps:
- [gap]

Action Plan:

Week 1:
- [task]

Week 2:
- [task]

Week 3:
- [task]

Week 4:
- [task]

Resources:
- [Platform]: [URL]
''';

    try {
      print("Calling Gemini...");

      // --- Step 2: Try Gemini API (with 15-second timeout) ---
      final String responseText = await _callGemini(prompt)
          .timeout(const Duration(seconds: 15), onTimeout: () {
        print("Gemini timed out — using fallback response");
        return _buildFallbackResponse(career);
      });

      _isAnalyzed = true;

      // --- Step 3: Deliver the response in staggered sections ---
      if (mounted) {
        await _deliverResponseInSections(responseText);
        _extractAndStoreRoadmap(responseText);
        _lastAIResponse = responseText;
        _saveMessages();
        
        // Final instruction
        setState(() {
           _messages.insert(0, ChatMessage(text: "Your roadmap is ready! Do you want to upload your resume for a more detailed analysis? (Yes/No)", isUser: false));
           _waitingForResumeConsent = true;
        });
        _saveMessages();
      }
    } catch (e) {
      print("ERROR: $e");

      // Fallback on any failure
      _isAnalyzed = true;
      if (mounted) {
        final fallback = _buildFallbackResponse(career);
        await _deliverResponseInSections(fallback);
        _extractAndStoreRoadmap(fallback);
        _lastAIResponse = fallback;
        _saveMessages();
      }
    } finally {
      _isProcessing = false;

      // --- Step 4: Prompt user for follow-up questions ---
      if (mounted) {
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          setState(() {
            _messages.insert(
              0,
              ChatMessage(text: "Ask me anything about this plan or how to execute it.", isUser: false),
            );
          });
          _saveMessages();
        }
      }
    }
  }

  // --- Backend Configuration ---
  // Replace with your actual Render backend URL after deployment
  // Example: https://your-app.onrender.com/generate
  static const String _backendUrl = 'YOUR_RENDER_BACKEND_URL';

  Future<String> _callGemini(String promptText) async {
    try {
      if (_backendUrl == 'YOUR_RENDER_BACKEND_URL') {
        throw Exception('Backend URL not configured. Please deploy to Render and update the URL.');
      }

      final response = await http.post(
        Uri.parse(_backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "input": promptText
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Render backend returns: { "result": "..." }
        if (data['result'] != null) {
          return data['result'] as String;
        }
      }
      
      throw Exception('Backend returned error: ${response.statusCode}');
    } catch (e) {
      print("API Call Error: $e");
      // Re-throw to be caught by the caller and trigger fallback
      rethrow;
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('AI Assistant', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              _loadHistory();
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
      ),
      drawer: _buildHistoryDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16.0),
                reverse: true, // Start from bottom of screen
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _buildMessageBubble(_messages[index]);
                },
              ),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final bool isUser = message.isUser;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: primaryColor.withOpacity(0.1),
              radius: 16,
              child: Icon(Icons.analytics_outlined, size: 20, color: primaryColor),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: isUser ? primaryColor : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 0),
                  bottomRight: Radius.circular(isUser ? 0 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    offset: const Offset(0, 2),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: message.isThinking
                  ? _buildThinkingContent(message.text)
                  : _buildRichText(message.text, isUser),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.grey[300],
              radius: 16,
              child: const Icon(Icons.person, size: 20, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  /// Renders the thinking bubble with a subtle pulsing indicator
  Widget _buildThinkingContent(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(secondaryColor),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 15,
            height: 1.3,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  /// Builds RichText with clickable URLs detected in the message
  Widget _buildRichText(String text, bool isUser) {
    final urlPattern = RegExp(
      r'(https?://[^\s]+)',
      caseSensitive: false,
    );

    final List<InlineSpan> spans = [];
    int lastEnd = 0;

    for (final match in urlPattern.allMatches(text)) {
      // Add text before the URL
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 15,
            height: 1.3,
          ),
        ));
      }

      // Add the clickable URL
      final url = match.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: TextStyle(
          color: isUser ? Colors.lightBlueAccent : secondaryColor,
          fontSize: 15,
          height: 1.3,
          decoration: TextDecoration.underline,
          decorationColor: isUser ? Colors.lightBlueAccent : secondaryColor,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            final uri = Uri.tryParse(url);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
      ));

      lastEnd = match.end;
    }

    // Add remaining text after last URL
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(
          color: isUser ? Colors.white : Colors.black87,
          fontSize: 15,
          height: 1.3,
        ),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(24.0),
              ),
              child: TextField(
                controller: _textController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 5,
                minLines: 1,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8.0),
          Container(
            decoration: BoxDecoration(
              color: _isListening ? Colors.red : secondaryColor,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(_isListening ? Icons.mic : Icons.mic_none, size: 20),
              color: Colors.white,
              onPressed: _listen,
            ),
          ),
          const SizedBox(width: 8.0),
          Container(
            decoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, size: 20),
              color: Colors.white,
              onPressed: () => _handleSubmitted(_textController.text),
            ),
          ),
          const SizedBox(width: 4.0),
        ],
      ),
    );
  }

  Widget _buildHistoryDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: primaryColor,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_outlined, color: Colors.white, size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    'Chat History',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.add, color: primaryColor),
            title: Text('New Chat', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
            onTap: _startNewChat,
          ),
          const Divider(),
          Expanded(
            child: _chatSessions.isEmpty
                ? Center(
                    child: Text('No history yet', style: TextStyle(color: Colors.grey[400])),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _chatSessions.length,
                    itemBuilder: (context, index) {
                      final session = _chatSessions[index];
                      final bool isSelected = session['key'] == _sessionKey;
                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: secondaryColor.withOpacity(0.1),
                        leading: Icon(
                          Icons.chat_bubble_outline,
                          size: 20,
                          color: isSelected ? secondaryColor : Colors.grey[600],
                        ),
                        title: Text(
                          session['title'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: Text(
                          _formatHistoryDate(session['timestamp'] as String),
                          style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                        ),
                        onTap: () => _switchToSession(session['key'] as String),
                        onLongPress: () => _showChatOptions(session),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  }

