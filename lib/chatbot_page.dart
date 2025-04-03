import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ChatbotPage extends StatefulWidget {
  final bool isModal;
  
  const ChatbotPage({
    Key? key, 
    this.isModal = false,
  }) : super(key: key);

  @override
  _ChatbotPageState createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  String _apiKey = "AIzaSyBWsICAzMbqqJOxaaR4Jvj9GuJDmk2b1UQ";
  
  late List<AnimationController> _typingAnimControllers;
  
  @override
  void initState() {
    super.initState();
    _typingAnimControllers = List.generate(3, (index) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 300 + (index * 100)),
      );
    });
    
    for (var i = 0; i < _typingAnimControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) {
          _typingAnimControllers[i].repeat(reverse: true);
        }
      });
    };
    
    _loadMessages();
  }
  
  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final messagesJson = prefs.getString('ai_chat_messages');
    
    if (messagesJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(messagesJson);
        final loadedMessages = decoded.map((item) => 
          ChatMessage(
            message: item['message'],
            isUser: item['isUser'],
          )
        ).toList();
        
        setState(() {
          _messages.clear();
          _messages.addAll(loadedMessages);
        });
        
        _scrollToBottom();
      } catch (e) {
        debugPrint('Error loading messages: $e');
        _addWelcomeMessage();
      }
    } else {
      _addWelcomeMessage();
    }
  }
  
  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final messagesJson = jsonEncode(
      _messages.map((msg) => {
        'message': msg.message,
        'isUser': msg.isUser,
      }).toList()
    );
    
    await prefs.setString('ai_chat_messages', messagesJson);
  }
  
  void _startNewConversation() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start New Conversation'),
        content: const Text('This will clear your current conversation. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      setState(() {
        _messages.clear();
      });
      
      _addWelcomeMessage();
      
      _saveMessages();
    }
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.add(
        ChatMessage(
          message: "Hi! I'm your StudyX AI assistant powered by Google Gemini. How can I help with your studies today?",
          isUser: false,
        ),
      );
    });
    
    _saveMessages();
  }

  @override
  void dispose() {
    for (var controller in _typingAnimControllers) {
      controller.dispose();
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    
    String message = _messageController.text;
    _messageController.clear();
    
    setState(() {
      _messages.add(ChatMessage(message: message, isUser: true));
      _isTyping = true;
    });
    
    _saveMessages();
    
    _scrollToBottom();
    
    try {
      final response = await _getGeminiResponse(message);
      
      setState(() {
        _messages.add(ChatMessage(message: response, isUser: false));
        _isTyping = false;
      });
      
      _saveMessages();
      
      _scrollToBottom();
    } catch (error) {
      setState(() {
        _messages.add(ChatMessage(
          message: "Sorry, I encountered an error: ${error.toString()}",
          isUser: false,
        ));
        _isTyping = false;
      });
      
      _saveMessages();
      
      _scrollToBottom();
    }
  }

  Future<String> _getGeminiResponse(String prompt) async {
    try {
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_apiKey');
      
      final payload = jsonEncode({
        "contents": [
          {
            "parts": [
              {
                "text": prompt
              }
            ],
            "role": "user"
          }
        ],
        "generationConfig": {
          "temperature": 0.7,
          "topK": 40,
          "topP": 0.95,
          "maxOutputTokens": 1024,
        }
      });
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: payload,
      );
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return jsonResponse['candidates'][0]['content']['parts'][0]['text'] ?? "Sorry, I couldn't generate a response.";
      } else {
        return "Error: ${response.statusCode} - ${response.body}";
      }
    } catch (e) {
      return "Error connecting to Gemini API: ${e.toString()}";
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final accentColor = Theme.of(context).colorScheme.tertiary;
    
    return Scaffold(
      appBar: widget.isModal 
        ? _buildModalHeader(isDarkMode, primaryColor)
        : AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  backgroundColor: accentColor.withOpacity(0.2),
                  radius: 16,
                  child: Icon(
                    Icons.auto_awesome,
                    size: 20,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 10),
                const Text('StudyX AI'),
              ],
            ),
            centerTitle: true,
            backgroundColor: isDarkMode 
                ? Theme.of(context).appBarTheme.backgroundColor 
                : Theme.of(context).colorScheme.primary,
            actions: [
              IconButton(
                icon: const Icon(Icons.add_comment_outlined),
                tooltip: 'New Conversation',
                onPressed: _startNewConversation,
              ),
            ],
          ),
      body: Container(
        color: isDarkMode ? Colors.black : const Color(0xFFF5F5F5),
        child: Column(
          children: [            
            Expanded(
              child: _messages.isEmpty
                ? _buildEmptyState(isDarkMode, accentColor)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < _messages.length) {
                        return _buildMessageBubble(
                          _messages[index], 
                          isDarkMode, 
                          primaryColor, 
                          accentColor,
                          showTail: index == _messages.length - 1 || 
                            (_messages[index + 1].isUser != _messages[index].isUser),
                        );
                      } else {
                        return _buildTypingIndicator(isDarkMode, accentColor);
                      }
                    },
                  ),
            ),
            
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[900] : Colors.white,
                boxShadow: [
                  BoxShadow(
                    offset: const Offset(0, -2),
                    blurRadius: 4.0,
                    color: Colors.black.withOpacity(0.1),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(
                        maxHeight: 110,
                      ),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Ask me...',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          hintStyle: TextStyle(
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        style: TextStyle(
                          fontSize: 16,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                        minLines: 1,
                        maxLines: 5,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (text) {
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  GestureDetector(
                    onTap: _isTyping ? null : 
                           (_messageController.text.trim().isEmpty ? null : _sendMessage),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _messageController.text.trim().isEmpty || _isTyping 
                            ? (isDarkMode ? Colors.grey[700] : Colors.grey[300])
                            : primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        color: _messageController.text.trim().isEmpty || _isTyping 
                            ? (isDarkMode ? Colors.grey[500] : Colors.grey[600])
                            : Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  PreferredSizeWidget _buildModalHeader(bool isDarkMode, Color primaryColor) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(70),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[900] : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            
            Positioned(
              left: 16,
              top: 20,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.tertiary.withOpacity(0.2),
                    radius: 14,
                    child: Icon(
                      Icons.auto_awesome,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'StudyX AI',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            Positioned(
              right: 56,
              top: 9,
              child: IconButton(
                icon: Icon(
                  Icons.add_comment_outlined,
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                  size: 22,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
                tooltip: 'New Conversation',
                onPressed: _startNewConversation,
              ),
            ),
            
            Positioned(
              right: 8,
              top: 8,
              child: IconButton(
                icon: Icon(
                  Icons.close,
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                  size: 24,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode, Color accentColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800]!.withOpacity(0.7) : Colors.white.withOpacity(0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              Icons.auto_awesome,
              size: 64,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Your AI Study Assistant',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              'I can help you understand concepts, solve problems, or generate study materials. What would you like to work on today?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(height: 40),
          _buildSuggestionChip('Explain quantum physics', isDarkMode),
          const SizedBox(height: 12),
          _buildSuggestionChip('Help me prepare for my history exam', isDarkMode),
          const SizedBox(height: 12),
          _buildSuggestionChip('Generate a study schedule', isDarkMode),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text, bool isDarkMode) {
    return InkWell(
      onTap: () {
        _messageController.text = text;
        _sendMessage();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isDarkMode, Color primaryColor, Color accentColor, {bool showTail = true}) {
    final isUser = message.isUser;
    
    final bubbleColor = isUser
        ? primaryColor
        : (isDarkMode ? Colors.grey[800]! : Colors.white);
    
    final textColor = isUser
        ? Colors.white
        : (isDarkMode ? Colors.white : Colors.black87);
    
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(isUser ? 20 : (showTail ? 5 : 20)),
      bottomRight: Radius.circular(isUser ? (showTail ? 5 : 20) : 20),
    );
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          
          Flexible(
            child: Container(
              margin: EdgeInsets.only(
                left: isUser ? 64 : 0,
                right: isUser ? 0 : 64,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: borderRadius,
                boxShadow: [
                  BoxShadow(
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                    color: Colors.black.withOpacity(0.1),
                  ),
                ],
              ),
              child: SelectableText(
                message.message,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDarkMode, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 0, top: 4, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(5),
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                  color: Colors.black.withOpacity(0.1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return _buildBouncingDot(index, isDarkMode, accentColor);
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBouncingDot(int index, bool isDarkMode, Color accentColor) {
    return AnimatedBuilder(
      animation: _typingAnimControllers[index],
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          height: 8 + (_typingAnimControllers[index].value * 4),
          width: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDarkMode ? accentColor : Theme.of(context).colorScheme.primary,
          ),
        );
      },
    );
  }
}

class ChatMessage {
  final String message;
  final bool isUser;

  ChatMessage({
    required this.message,
    required this.isUser,
  });
}
