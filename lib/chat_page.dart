import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:studyx_app/main_app_scaffold.dart';
import 'dart:io';
import 'dart:async';
import 'chat_group.dart';
import 'chat_message.dart';
import 'dart:math';
import 'screens/group_call_screen.dart';
import 'screens/fullscreen_video_player.dart';
import 'services/call_service.dart';
import 'auth_service.dart';
import 'audio_player_wrapper.dart';
import 'widgets/animated_waveform.dart';
import 'widgets/apple_video_player.dart';
import 'package:flutter/services.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class ChatPage extends StatefulWidget {
  final Function(bool)? onGroupSelected;
  const ChatPage({super.key, this.onGroupSelected});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver, TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _inviteCodeController = TextEditingController();
  ChatGroup? _selectedGroup;
  final bool _isInCall = false;
  final CallService _callService = CallService();
  final AuthService _authService = AuthService();
  
  final  _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  String? _recordedFilePath;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  
  File? _selectedFile;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  
  final Map<String, bool> _playingVoiceNotes = {};
  final Map<String, AudioPlayerWrapper> _voiceNotePlayers = {};
  final Map<String, StreamSubscription> _playerStateSubscriptions = {};
  final Map<String, StreamSubscription> _playerPositionSubscriptions = {};
  final Map<String, Duration> _voiceNoteDurations = {};
  final Map<String, Duration> _voiceNotePositions = {};
  final Map<String, Timer> _positionUpdateTimers = {};
  final Map<String, bool> _voiceNoteLoaded = {};
  
  final ScrollController _scrollController = ScrollController();
  
  final GlobalKey<AnimatedListState> _messagesListKey = GlobalKey<AnimatedListState>();
  
  List<ChatMessage> _currentMessages = [];

  final Set<String> _loadedMessageIds = {};

  OverlayEntry? _backButtonOverlayEntry;
  late AnimationController _backIndicatorController;
  late Animation<double> _backIndicatorAnimation;

  @override
  void initState() {
    super.initState();
    _checkMicrophonePermission();
    WidgetsBinding.instance.addObserver(this);
    
    _backIndicatorController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    
    _backIndicatorAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _backIndicatorController,
      curve: Curves.easeOut,
    ));
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedGroup != null) {
        _backIndicatorController.forward(from: 0.0);
      }
    });
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _cleanupResources();
    }
  }
  
  void _cleanupResources() {
    for (final entry in _playingVoiceNotes.entries) {
      if (entry.value) {
        final player = _voiceNotePlayers[entry.key];
        if (player != null) {
          player.pause();
          _positionUpdateTimers[entry.key]?.cancel();
        }
      }
    }
    
    _playingVoiceNotes.clear();
  }

  Future<void> _checkMicrophonePermission() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      print('Microphone permission not granted');
    }
  }

  void _createNewGroup() async {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final accentColor = Theme.of(context).colorScheme.tertiary;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey.shade900 : Theme.of(context).dialogBackgroundColor,
        title: Text(
          'Create New Group',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _groupNameController,
              decoration: InputDecoration(
                labelText: 'Group Name',
                labelStyle: TextStyle(
                  color: isDarkMode ? Colors.white70 : primaryColor,
                ),
                border: const OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
                prefixIcon: Icon(Icons.group, 
                  color: isDarkMode ? Colors.white70 : primaryColor,
                ),
                fillColor: isDarkMode ? accentColor.withOpacity(0.2) : null,
                filled: true,
              ),
              style: TextStyle(
                color: isDarkMode ? Colors.black87 : Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: primaryColor,
            ),
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel', 
              style: TextStyle(
                color: isDarkMode ? Colors.white : primaryColor,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: primaryColor),
            onPressed: () {
              if (_groupNameController.text.isNotEmpty) {
                Navigator.pop(context, {
                  'name': _groupNameController.text,
                });
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == null) return;

    try {
      final docRef = FirebaseFirestore.instance.collection('chat_groups').doc();
      final inviteCode = _generateInviteCode();
      final now = DateTime.now();

      final group = ChatGroup(
        id: docRef.id,
        name: result['name']!,
        creatorId: user.uid,
        members: [user.uid],
        inviteCode: inviteCode,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(group.toMap(), SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _selectedGroup = group;
        });
        _showInviteCode(inviteCode);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating group: $e')),
        );
      }
    }
    
    _groupNameController.clear();
  }

  void _showInviteCode(String code) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.tertiary;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey.shade900 : Theme.of(context).dialogBackgroundColor,
        title: Text(
          'Group Created!',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Share this invite code with others:',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode ? accentColor.withOpacity(0.2) : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    code,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.black87 : Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.copy, 
                      color: isDarkMode ? Colors.black87 : Theme.of(context).iconTheme.color,
                    ),
                    onPressed: () {
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
  }

  void _joinGroup() async {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final accentColor = Theme.of(context).colorScheme.tertiary;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey.shade900 : Theme.of(context).dialogBackgroundColor,
        title: Text(
          'Join Group',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        content: TextField(
          controller: _inviteCodeController,
          decoration: InputDecoration(
            labelText: 'Enter Invite Code',
            labelStyle: TextStyle(
              color: isDarkMode ? Colors.white70 : primaryColor,
            ),
            border: const OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
            fillColor: isDarkMode ? accentColor.withOpacity(0.2) : null,
            filled: true,
          ),
          style: TextStyle(
            color: isDarkMode ? Colors.black87 : Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: isDarkMode ? Colors.white : primaryColor,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: primaryColor),
            onPressed: () => Navigator.pop(context, _inviteCodeController.text),
            child: const Text('Join'),
          ),
        ],
      ),
    );

    if (code == null || code.isEmpty) return;

    try {
      final groupQuery = await FirebaseFirestore.instance
          .collection('chat_groups')
          .where('inviteCode', isEqualTo: code.trim())
          .get();

      if (groupQuery.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid invite code')),
          );
        }
        return;
      }

      final groupDoc = groupQuery.docs.first;
      final groupData = groupDoc.data();
      final List<String> members = List<String>.from(groupData['members'] ?? []);

      if (members.contains(user.uid)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You are already in this group')),
          );
        }
        return;
      }

      members.add(user.uid);
      await groupDoc.reference.update({
        'members': members,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final joinedGroup = ChatGroup.fromMap(groupDoc.id, groupData);
      setState(() {
        _selectedGroup = joinedGroup;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully joined the group!')),
        );
      }
    } catch (e) {
      print('Error joining group: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining group: $e')),
        );
      }
    }
    
    _inviteCodeController.clear();
  }

  void _selectGroup(ChatGroup? group) {
    final isChangingGroups = _selectedGroup?.id != group?.id;
    
    _removeBackButtonOverlay();
    
    if (isChangingGroups) {
      _currentMessages = [];
      _loadedMessageIds.clear();
      
      _pauseAllVoiceNotes();
      
      _voiceNoteLoaded.clear();
      _voiceNoteDurations.clear();
      _voiceNotePositions.clear();
      
      _selectedFile = null;
      _isUploading = false;
      
      if (_isRecording) {
        _stopRecording();
      }
    }
    
    setState(() {
      _selectedGroup = group;
    });
    
    widget.onGroupSelected?.call(group != null);
    
    ChatGroupSelectedNotification(group != null).dispatch(context);
    
    if (group != null) {
      _backIndicatorController.reset();
      _backIndicatorController.forward();
    }
  }

  Widget _buildGroupsList(User user) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final accentColor = Theme.of(context).colorScheme.tertiary;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_groups')
          .where('members', arrayContains: user.uid)
          .orderBy('updatedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: LoadingAnimationWidget.stretchedDots(
              color: isDarkMode ? accentColor : primaryColor,
              size: 50,
            ),
          );
        }

        final groups = snapshot.data?.docs.map((doc) {
          try {
            return ChatGroup.fromMap(doc.id, doc.data() as Map<String, dynamic>);
          } catch (e) {
            print('Error parsing group: $e');
            return null;
          }
        }).whereType<ChatGroup>().toList() ?? [];

        if (groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: primaryColor.withOpacity(0.1),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    size: 40,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'No Groups Yet',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Create a new group or join one to start chatting',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Create New Group'),
                  onPressed: _createNewGroup,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: BorderSide(color: primaryColor),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.link),
                  label: const Text('Join with Code'),
                  onPressed: _joinGroup,
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Messages',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : primaryColor,
                    ),
                  ),
                  SizedBox(
                    width: 75,
                    height: 40,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          child: IconButton(
                            icon: Icon(Icons.link, size: 24, color: isDarkMode ? Colors.white : primaryColor),
                            onPressed: _joinGroup,
                            tooltip: 'Join Group',
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            splashRadius: 20,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          child: IconButton(
                            icon: Icon(Icons.add, size: 24, color: isDarkMode ? Colors.white : primaryColor),
                            onPressed: _createNewGroup,
                            tooltip: 'Create Group',
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            splashRadius: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 18, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Search',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: groups.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                  indent: 64,
                  endIndent: 16,
                ),
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return _buildInstagramStyleGroupItem(user, group);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInstagramStyleGroupItem(User user, ChatGroup group) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final accentColor = Theme.of(context).colorScheme.tertiary;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        _selectGroup(group);
      },
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chat_messages')
            .where('groupId', isEqualTo: group.id)
            .orderBy('timestamp', descending: true)
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          String lastMessage = "No messages yet";
          String time = "";
          bool hasUnread = false;
          
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            try {
              final message = ChatMessage.fromMap(
                snapshot.data!.docs.first.id,
                snapshot.data!.docs.first.data() as Map<String, dynamic>,
              );
              
              lastMessage = message.type == MessageType.text
                  ? message.content
                  : message.type == MessageType.voiceNote
                      ? "Voice message"
                      : "Attachment";
                      
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final yesterday = today.subtract(const Duration(days: 1));
              final messageDay = DateTime(
                message.timestamp.year,
                message.timestamp.month,
                message.timestamp.day,
              );
              
              if (messageDay == today) {
                time = "${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}";
              } else if (messageDay == yesterday) {
                time = "Yesterday";
              } else if (now.difference(message.timestamp).inDays < 7) {
                final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
                final weekday = message.timestamp.weekday;
                time = dayNames[weekday - 1];
              } else {
                time = "${message.timestamp.day}/${message.timestamp.month}";
              }
            } catch (e) {
              print('Error parsing last message: $e');
            }
          }
          
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor: accentColor,
                  child: Text(
                    group.name.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        group.name,
                        style: TextStyle(
                          fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastMessage,
                              style: TextStyle(
                                color: hasUnread 
                                    ? primaryColor 
                                    : isDarkMode 
                                        ? Colors.grey.shade400 
                                        : Colors.grey.shade600,
                                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (time.isNotEmpty) Text(
                            " · $time",
                            style: TextStyle(
                              fontSize: 10,
                              color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (hasUnread)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatScreen(User user) {
    final accentColor = Theme.of(context).colorScheme.tertiary;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDarkMode ? 
            Theme.of(context).appBarTheme.backgroundColor : 
            primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => _selectGroup(null),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: accentColor,
              child: Text(
                _selectedGroup!.name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _selectedGroup!.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call, color: Colors.white),
            onPressed: () => _toggleGroupCall(user),
            tooltip: 'Start/Join Call',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: _showGroupInfo,
            tooltip: 'Group Info',
          ),
        ],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(10),
          ),
        ),
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 500) {
            _selectGroup(null);
          }
        },
        child: Column(
          children: [
            Expanded(
              child: _buildMessages(user),
            ),
            _buildMessageInput(user),
          ],
        ),
      ),
    );
  }

  Future<void> _preloadVoiceNotes(List<ChatMessage> messages) async {
    final voiceNotesToLoad = messages.where((message) => 
      message.type == MessageType.voiceNote && 
      message.attachmentUrl != null && 
      !_voiceNoteLoaded.containsKey(message.id)
    ).toList();
    
    if (voiceNotesToLoad.isEmpty) return;
    
    Future.microtask(() {
      for (final message in voiceNotesToLoad) {
        try {
          if (!_voiceNotePlayers.containsKey(message.id)) {
            final player = AudioPlayerWrapper();
            _voiceNotePlayers[message.id] = player;
            _setupPlayerListeners(message.id, player);
            
            _voiceNoteLoaded[message.id] = true;
          }
        } catch (e) {
          print('Error preloading voice note: $e');
        }
      }
    });
  }

  Widget _buildMessages(User user) {
    if (_selectedGroup == null) return const SizedBox();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.tertiary;
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_messages')
          .where('groupId', isEqualTo: _selectedGroup!.id)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting && _currentMessages.isEmpty) {
          return Center(
            child: LoadingAnimationWidget.stretchedDots(
              color: isDarkMode ? accentColor : primaryColor,
              size: 50,
            ),
          );
        }

        if (snapshot.hasData) {
          final messages = snapshot.data?.docs.map((doc) {
            try {
              return ChatMessage.fromMap(
                  doc.id, doc.data() as Map<String, dynamic>);
            } catch (e) {
              print('Error parsing message: $e');
              return null;
            }
          }).whereType<ChatMessage>().toList() ?? [];
          
          if (messages.isNotEmpty) {
            final firstMsgGroupId = messages.first.groupId;
            
            if (firstMsgGroupId == _selectedGroup?.id) {
              _currentMessages = messages;
              
              for (var msg in messages) {
                _loadedMessageIds.add(msg.id);
              }
              
              _preloadVoiceNotesQuietly(messages);
            } else {
              print('Received messages for wrong group: $firstMsgGroupId != ${_selectedGroup?.id}');
            }
          }
        }

        if (_currentMessages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No messages in ${_selectedGroup!.name} yet',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text('Start the conversation!'),
                const Spacer(flex: 2),
              ],
            ),
          );
        }

        return Container(
          width: MediaQuery.of(context).size.width,
          height: double.infinity,
          color: isDarkMode ? Colors.grey.shade900 : Colors.grey.shade200,
          child: ListView.builder(
            key: ValueKey<String>('messages_list_${_selectedGroup!.id}'),
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            reverse: true,
            itemCount: _currentMessages.length,
            padding: EdgeInsets.only(
              left: 8, 
              right: 8, 
              top: 12,
              bottom: 12,
            ),
            itemBuilder: (context, index) {
              final message = _currentMessages[index];
              final isMe = message.senderId == user.uid;
              return _buildMessageBubble(message, isMe);
            },
          ),
        );
      },
    );
  }

  Future<void> _preloadVoiceNotesQuietly(List<ChatMessage> messages) async {
    final voiceNotesToLoad = messages.where((message) => 
      message.type == MessageType.voiceNote && 
      message.attachmentUrl != null && 
      !_voiceNoteLoaded.containsKey(message.id)
    ).toList();
    
    if (voiceNotesToLoad.isEmpty) return;
    
    Future.microtask(() {
      for (final message in voiceNotesToLoad) {
        try {
          if (!_voiceNotePlayers.containsKey(message.id)) {
            final player = AudioPlayerWrapper();
            _voiceNotePlayers[message.id] = player;
            _setupPlayerListeners(message.id, player);
            
            _voiceNoteLoaded[message.id] = true;
          }
        } catch (e) {
          print('Error preloading voice note: $e');
        }
      }
    });
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final accentColor = Theme.of(context).colorScheme.tertiary;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe 
              ? accentColor.withOpacity(0.7) 
              : isDarkMode 
                  ? Colors.grey.shade800 
                  : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05),
              offset: const Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.senderName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: primaryColor,
                  ),
                ),
              ),
            if (message.type == MessageType.text)
              Text(
                message.content,
                style: TextStyle(
                  fontSize: 16,
                  color: isMe 
                      ? (isDarkMode ? Colors.black : Colors.black)
                      : Theme.of(context).textTheme.bodyLarge?.color,
                ),
              )
            else if (message.type == MessageType.voiceNote)
              _buildVoiceNotePlayer(message)
            else if (message.type == MessageType.attachment)
              _buildAttachment(message),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatMessageTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (isMe)
                    Icon(
                      Icons.done_all,
                      size: 14,
                      color: Colors.blue.shade700,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMessageTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }

  Widget _buildVoiceNotePlayer(ChatMessage message) {
    final isPlaying = _playingVoiceNotes[message.id] ?? false;
    
    final durationSecs = int.tryParse(message.content) ?? 0;
    
    final position = _voiceNotePositions[message.id] ?? Duration.zero;
    final duration = _voiceNoteDurations[message.id] ?? Duration(seconds: durationSecs);
    
    final positionText = _formatDuration(position);
    final durationText = _formatDuration(duration);
    
    final progress = duration.inMilliseconds > 0 
        ? position.inMilliseconds / duration.inMilliseconds 
        : 0.0;
    
    _voiceNoteLoaded[message.id] = true;
    
    return Container(
      key: ValueKey('voice_note_${message.id}'),
      width: 220,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => _togglePlayVoiceNote(message),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isPlaying ? Colors.grey.shade300 : Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: isPlaying ? Colors.black : Colors.blue.shade700,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 24,
                      child: RepaintBoundary(
                        child: AnimatedWaveform(
                          key: ValueKey('waveform_${message.id}_${isPlaying}'),
                          isPlaying: isPlaying,
                          progress: progress,
                          activeColor: Colors.blue.shade600,
                          inactiveColor: Colors.grey.shade400,
                          height: 20,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          positionText,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          durationText,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString();
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  void _togglePlayVoiceNote(ChatMessage message) {
    if (_isUploading) return;
    
    final isCurrentlyPlaying = _playingVoiceNotes[message.id] ?? false;
    
    try {
      if (isCurrentlyPlaying) {
        _pauseVoiceNote(message.id);
        return;
      }
      
      _pauseAllVoiceNotes();
      
      setState(() {
        _playingVoiceNotes[message.id] = true;
      });
      
      var player = _voiceNotePlayers[message.id];
      if (player == null) {
        player = AudioPlayerWrapper();
        _voiceNotePlayers[message.id] = player;
        
        _setupPlayerListeners(message.id, player);
      }
      
      _playVoiceNoteNonBlocking(message, player);
    } catch (e) {
      print('Error with voice note: $e');
    }
  }
  
  void _setupPlayerListeners(String messageId, AudioPlayerWrapper player) {
    _playerStateSubscriptions[messageId]?.cancel();
    _playerPositionSubscriptions[messageId]?.cancel();
    
    _playerStateSubscriptions[messageId] = player.isPlayingStream.listen((isPlaying) {
      if (mounted) {
        setState(() {
          _playingVoiceNotes[messageId] = isPlaying;
          
          if (!isPlaying) {
            _voiceNotePositions[messageId] = Duration.zero;
          }
        });
      }
    });
    
    _playerPositionSubscriptions[messageId] = player.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _voiceNotePositions[messageId] = position;
        });
      }
    });
    
    player.durationStream.listen((duration) {
      if (mounted) {
        setState(() {
          _voiceNoteDurations[messageId] = duration;
        });
      }
    });
  }
  
  void _playVoiceNoteNonBlocking(ChatMessage message, AudioPlayerWrapper player) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      player.setSourceUrl(message.attachmentUrl!).then((_) {
        if (_playingVoiceNotes[message.id] == true) {
          player.play();
        }
      }).catchError((e) {
        print('Error setting audio source: $e');
        if (mounted) {
          setState(() {
            _playingVoiceNotes[message.id] = false;
          });
        }
      });
    });
  }
  
  void _pauseAllVoiceNotes() {
    for (final entry in Map<String, bool>.from(_playingVoiceNotes).entries) {
      if (entry.value) {
        _pauseVoiceNote(entry.key);
      }
    }
  }
  
  void _pauseVoiceNote(String messageId) {
    final player = _voiceNotePlayers[messageId];
    if (player != null) {
      player.pause();
    }
    
    if (mounted) {
      setState(() {
        _playingVoiceNotes[messageId] = false;
      });
    }
  }

  Widget _buildAttachment(ChatMessage message) {
    final isVideo = message.attachmentUrl != null && 
        (message.attachmentUrl!.toLowerCase().contains('.mp4') || 
         message.attachmentUrl!.toLowerCase().contains('.mov') ||
         message.attachmentUrl!.toLowerCase().contains('.webm') ||
         message.attachmentUrl!.toLowerCase().contains('.m4v'));
         
    final isImage = message.attachmentUrl != null && 
        (message.attachmentUrl!.toLowerCase().contains('.jpg') || 
         message.attachmentUrl!.toLowerCase().contains('.jpeg') || 
         message.attachmentUrl!.toLowerCase().contains('.png') || 
         message.attachmentUrl!.toLowerCase().contains('.gif') ||
         message.attachmentUrl!.toLowerCase().contains('.webp'));
         
    final fileName = message.content.contains('[') && message.content.contains(']')
        ? message.content.substring(
            message.content.lastIndexOf('[') + 1,
            message.content.lastIndexOf(']')
          )
        : 'Attachment';
        
    final hasCaption = message.content.contains('\n\n[') && message.content.indexOf('\n\n[') > 0;
    final caption = hasCaption 
        ? message.content.substring(0, message.content.indexOf('\n\n[')) 
        : null;
        
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.tertiary;
    final primaryColor = Theme.of(context).colorScheme.primary;
        
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (caption != null) ...[
          Text(
            caption,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          padding: isVideo ? const EdgeInsets.all(0) : const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isVideo 
                ? Colors.black 
                : isDarkMode 
                    ? Colors.grey.shade700 
                    : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(isVideo ? 8 : 8),
          ),
          child: isVideo && message.attachmentUrl != null
              ? _buildVideoPlayer(message.attachmentUrl!, fileName)
              : isImage && message.attachmentUrl != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          message.attachmentUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 150,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 150,
                              alignment: Alignment.center,
                              child: LoadingAnimationWidget.stretchedDots(
                                color: isDarkMode ? accentColor : primaryColor,
                                size: 40,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 100,
                              width: 150,
                              color: Colors.grey.shade300,
                              alignment: Alignment.center,
                              child: const Icon(Icons.error),
                            );
                          },
                        ),
                      ),
                      if (!hasCaption)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            fileName,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.insert_drive_file),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.download),
                        iconSize: 20,
                        onPressed: message.attachmentUrl != null
                            ? () => _downloadAttachment(message.attachmentUrl!, fileName)
                            : null,
                      ),
                    ],
                  ),
        ),
      ],
    );
  }
  
  Widget _buildVideoPlayer(String videoUrl, String fileName) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: double.infinity,
        height: 180,
        child: AppleVideoPlayer(
          key: ValueKey('video_player_$videoUrl'),
          videoUrl: videoUrl,
          autoPlay: false,
          showControls: true,
          aspectRatio: 16/9,
          onFullScreenToggle: () => _openFullScreenPlayer(videoUrl),
        ),
      ),
    );
  }
  
  void _openFullScreenPlayer(String videoUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullscreenVideoPlayer(
          videoUrl: videoUrl,
        ),
      ),
    );
  }

  Future<void> _downloadAttachment(String url, String fileName) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Opening $fileName...')),
      );
      
    } catch (e) {
      print('Error downloading attachment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not download attachment: $e')),
      );
    }
  }

  Widget _buildMessageInput(User user) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final accentColor = Theme.of(context).colorScheme.tertiary;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isRecording) _buildRecordingIndicator(),
            if (_selectedFile != null) _buildAttachmentPreview(),
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.attach_file, color: primaryColor),
                  onPressed: _isRecording ? null : _pickAttachment,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !_isRecording && _selectedFile == null,
                    decoration: InputDecoration(
                      hintText: _isRecording 
                          ? 'Recording...' 
                          : (_selectedFile != null ? 'Add a caption (optional)' : 'Type a message'),
                      filled: true,
                      fillColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      hintStyle: TextStyle(
                        color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    minLines: 1,
                    maxLines: 5,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: primaryColor,
                  child: _isRecording 
                  ? IconButton(
                      icon: const Icon(Icons.stop, color: Colors.white, size: 20),
                      onPressed: _stopRecording,
                    )
                  : _selectedFile != null
                  ? IconButton(
                      icon: _isUploading 
                          ? SizedBox(
                              width: 20, 
                              height: 20, 
                              child: LoadingAnimationWidget.stretchedDots(
                                color: Colors.white,
                                size: 20,
                              )
                            )
                          : const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _isUploading ? null : () => _sendAttachment(user),
                    )
                  : GestureDetector(
                      onLongPress: () => _startRecording(user),
                      onLongPressEnd: (_) => _stopRecording(),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white, size: 20),
                        onPressed: () => _sendMessage(user),
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
  
  Widget _buildRecordingIndicator() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    final minutes = (_recordingDuration ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordingDuration % 60).toString().padLeft(2, '0');
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.mic, color: Colors.red),
          const SizedBox(width: 8),
          Text(
            'Recording $minutes:$seconds',
            style: const TextStyle(color: Colors.red),
          ),
          const Spacer(),
          Text(
            'Tap stop to send',
            style: TextStyle(color: primaryColor),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAttachmentPreview() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    if (_selectedFile == null) return const SizedBox.shrink();
    
    final fileName = path.basename(_selectedFile!.path);
    final fileExt = path.extension(_selectedFile!.path).toLowerCase();
    
    final isImage = ['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(fileExt);
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDarkMode 
            ? primaryColor.withOpacity(0.2) 
            : primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              isImage
                  ? Icon(Icons.image, color: primaryColor)
                  : Icon(Icons.insert_drive_file, color: primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fileName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectedFile = null;
                  });
                },
              ),
            ],
          ),
          if (_isUploading) 
            LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
        ],
      ),
    );
  }

  Future<void> _startRecording(User user) async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await Directory.systemTemp.createTemp();
        final filePath = '${tempDir.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.aac';
        
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: filePath,
        );
        
        setState(() {
          _isRecording = true;
          _recordingDuration = 0;
          _recordedFilePath = filePath;
        });
        
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordingDuration++;
          });
        });
      }
    } catch (e) {
      print('Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start recording: $e')),
      );
    }
  }
  
  Future<void> _stopRecording() async {
    try {
      if (!_isRecording) return;
      
      _recordingTimer?.cancel();
      final path = await _audioRecorder.stop();
      
      setState(() {
        _isRecording = false;
      });
      
      if (path != null && _recordingDuration > 1) {
        await _sendVoiceNote(path);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording was too short')),
        );
      }
    } catch (e) {
      print('Error stopping recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not stop recording: $e')),
      );
      setState(() {
        _isRecording = false;
      });
    }
  }
  
  Future<void> _pickAttachment() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      
      if (result != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      print('Error picking file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick file: $e')),
      );
    }
  }
  
  String _getContentType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.pdf':
        return 'application/pdf';
      case '.doc':
      case '.docx':
        return 'application/msword';
      case '.xls':
      case '.xlsx':
        return 'application/vnd.ms-excel';
      case '.ppt':
      case '.pptx':
        return 'application/vnd.ms-powerpoint';
      case '.mp3':
        return 'audio/mpeg';
      case '.mp4':
        return 'video/mp4';
      case '.aac':
        return 'audio/aac';
      case '.txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _sendAttachment(User user) async {
    if (_selectedGroup == null || _selectedFile == null) return;
    
    try {
      setState(() {
        _isUploading = true;
        _uploadProgress = 0;
      });
      
      final fileName = path.basename(_selectedFile!.path);
      final fileExt = path.extension(_selectedFile!.path).toLowerCase();
      
      print('Attempting to upload: $fileName');
      print('User authenticated: ${user != null}');
      print('User ID: ${user.uid}');
      print('Group ID: ${_selectedGroup!.id}');

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('attachments')
          .child(_selectedGroup!.id)
          .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');
      
      print('Storage reference created: ${storageRef.fullPath}');
      
      
      final uploadTask = storageRef.putFile(
      _selectedFile!,
      SettableMetadata(
        contentType: _getContentType(_selectedFile!.path),
      ),
    );
      
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });
      
      await uploadTask;
      
      final downloadUrl = await storageRef.getDownloadURL();
      
      String content = fileName;
      if (_messageController.text.isNotEmpty) {
        content = '${_messageController.text}\n\n[$fileName]';
      }
      
      final senderName = await _authService.getUserName(user.uid);
      
      final message = ChatMessage(
        id: '',
        groupId: _selectedGroup!.id,
        senderId: user.uid,
        senderName: senderName,
        content: content,
        type: MessageType.attachment,
        attachmentUrl: downloadUrl,
        timestamp: DateTime.now(),
      );
      
      await FirebaseFirestore.instance
          .collection('chat_messages')
          .add(message.toMap());
      
      await FirebaseFirestore.instance
          .collection('chat_groups')
          .doc(_selectedGroup!.id)
          .update({
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      setState(() {
        _selectedFile = null;
        _isUploading = false;
        _messageController.clear();
      });
      
    } catch (e) {
      print('Error uploading attachment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not upload attachment: $e')),
      );
      setState(() {
        _isUploading = false;
      });
    }
  }
  
  Future<void> _sendVoiceNote(String filePath) async {
    if (_selectedGroup == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      setState(() {
        _isUploading = true;
        _uploadProgress = 0;
      });
      
      final fileName = path.basename(filePath);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('voice_notes')
          .child(_selectedGroup!.id)
          .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');
      
      final uploadTask = storageRef.putFile(File(filePath));
      
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });
      
      await uploadTask;
      
      final downloadUrl = await storageRef.getDownloadURL();
      
      final senderName = await _authService.getUserName(user.uid);
      
      final message = ChatMessage(
        id: '',
        groupId: _selectedGroup!.id,
        senderId: user.uid,
        senderName: senderName,
        content: _recordingDuration.toString(),
        type: MessageType.voiceNote,
        attachmentUrl: downloadUrl,
        timestamp: DateTime.now(),
      );
      
      await FirebaseFirestore.instance
          .collection('chat_messages')
          .add(message.toMap());
      
      await FirebaseFirestore.instance
          .collection('chat_groups')
          .doc(_selectedGroup!.id)
          .update({
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      setState(() {
        _isUploading = false;
        _recordedFilePath = null;
      });
      
    } catch (e) {
      print('Error uploading voice note: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not upload voice note: $e')),
      );
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _sendMessage(User user) async {
    if (_messageController.text.trim().isEmpty) return;

    try {
      final senderName = await _authService.getUserName(user.uid);

      final message = ChatMessage(
        id: '',
        groupId: _selectedGroup!.id,
        senderId: user.uid,
        senderName: senderName,
        content: _messageController.text,
        type: MessageType.text,
        timestamp: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('chat_messages')
          .add(message.toMap());
      
      await FirebaseFirestore.instance
          .collection('chat_groups')
          .doc(_selectedGroup!.id)
          .update({
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      _messageController.clear();
      
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }
  
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showGroupInfo() {
  final primaryColor = Theme.of(context).colorScheme.primary;
  final accentColor = Theme.of(context).colorScheme.tertiary;
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;
  final user = FirebaseAuth.instance.currentUser;
  final bool isAdmin = user?.uid == _selectedGroup?.creatorId;
  
  final List<Color> profileColors = [
    Colors.red.shade300,
    Colors.blue.shade300,
    Colors.green.shade300,
    Colors.orange.shade300,
    Colors.purple.shade300,
    Colors.teal.shade300,
    Colors.pink.shade300,
    Colors.indigo.shade300,
  ];
  
  final random = Random();
  
  showModalBottomSheet(
    context: context,
    backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    isScrollControlled: true,
    builder: (context) => Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: accentColor,
                child: Text(
                  _selectedGroup?.name[0].toUpperCase() ?? '?',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedGroup?.name ?? '',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      'Created ${_timeAgo(_selectedGroup?.createdAt)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.link,
                      color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Invite Code',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.copy,
                        color: primaryColor,
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _selectedGroup?.inviteCode ?? ''));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invite code copied to clipboard')),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedGroup?.inviteCode ?? '',
                  style: TextStyle(
                    fontSize: 18,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? accentColor : primaryColor,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          Text(
            'Members',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          
          const SizedBox(height: 12),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where(FieldPath.documentId, whereIn: _selectedGroup?.members ?? [])
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Could not load members'));
                }
                
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: LoadingAnimationWidget.stretchedDots(
                      color: isDarkMode ? accentColor : primaryColor,
                      size: 40,
                    ),
                  );
                }
                
                final members = snapshot.data?.docs ?? [];
                
                return ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index].data() as Map<String, dynamic>;
                    final memberId = members[index].id;
                    final memberName = member['name'] ?? 'Unknown';
                    final isCreator = memberId == _selectedGroup?.creatorId;
                    
                    final colorIndex = memberId.hashCode % profileColors.length;
                    final avatarColor = profileColors[colorIndex];
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: avatarColor,
                        child: Text(
                          memberName.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        memberName,
                        style: TextStyle(
                          fontWeight: isCreator ? FontWeight.bold : FontWeight.normal,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      subtitle: isCreator 
                          ? Text(
                              'Group Creator',
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 12,
                              ),
                            ) 
                          : null,
                    );
                  },
                );
              },
            ),
          ),
          
          if (isAdmin) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.delete),
                label: const Text('Delete Group'),
                onPressed: () => _showDeleteGroupConfirmation(),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

String _timeAgo(DateTime? dateTime) {
  if (dateTime == null) return '';
  
  final now = DateTime.now();
  final difference = now.difference(dateTime);
  
  if (difference.inDays > 365) {
    return '${(difference.inDays / 365).floor()} ${(difference.inDays / 365).floor() == 1 ? 'year' : 'years'} ago';
  } else if (difference.inDays > 30) {
    return '${(difference.inDays / 30).floor()} ${(difference.inDays / 30).floor() == 1 ? 'month' : 'months'} ago';
  } else if (difference.inDays > 0) {
    return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
  } else if (difference.inHours > 0) {
    return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
  } else {
    return 'Just now';
  }
}

void _showDeleteGroupConfirmation() {
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;
  final primaryColor = Theme.of(context).colorScheme.primary;
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.white,
      title: const Text('Delete Group?'),
      content: const Text(
        'This action cannot be undone. All messages and data for this group will be permanently deleted.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: isDarkMode ? Colors.white : primaryColor,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
            _deleteGroup();
          },
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

Future<void> _deleteGroup() async {
  if (_selectedGroup == null) return;
  
  try {
    final loadingDialog = showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Deleting group...'),
          ],
        ),
      ),
    );
    
    final messagesQuery = await FirebaseFirestore.instance
        .collection('chat_messages')
        .where('groupId', isEqualTo: _selectedGroup!.id)
        .get();
    
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in messagesQuery.docs) {
      batch.delete(doc.reference);
    }
    
    batch.delete(FirebaseFirestore.instance.collection('chat_groups').doc(_selectedGroup!.id));
    
    final callDoc = FirebaseFirestore.instance.collection('group_calls').doc(_selectedGroup!.id);
    if ((await callDoc.get()).exists) {
      batch.delete(callDoc);
    }
    
    await batch.commit();
    
    Navigator.of(context).pop();
    
    _selectGroup(null);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Group deleted successfully')),
    );
    
  } catch (e) {
    Navigator.of(context).pop();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error deleting group: $e')),
    );
  }
}

  void _toggleGroupCall(User user) async {
    if (_selectedGroup == null) return;

    try {
      final userName = await _authService.getUserName(user.uid);

      await _callService.cleanupStaleCall(_selectedGroup!.id);

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => StreamBuilder<DocumentSnapshot>(
          stream: _callService.getCallStatus(_selectedGroup!.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return _buildCallUI(false, [], false, user.uid, userName);
            }

            final callData = snapshot.data!.data() as Map<String, dynamic>;
            final isCallActive = callData['isActive'] ?? false;
            final participants = List<Map<String, dynamic>>.from(
                callData['participants'] ?? []);
            
            final bool actuallyActive = isCallActive && participants.isNotEmpty;
            final isInCall = participants.any((p) => p['userId'] == user.uid);

            return _buildCallUI(actuallyActive, participants, isInCall, user.uid, userName);
          },
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Widget _buildCallUI(bool isCallActive, List<Map<String, dynamic>> participants, 
      bool isInCall, String userId, String userName) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final accentColor = Theme.of(context).colorScheme.tertiary;
      
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isCallActive ? 'Ongoing Audio Call' : 'Start Audio Call',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (isCallActive && participants.isNotEmpty) ...[
            Text('${participants.length} participant(s)'),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: participants.map((p) => Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      CircleAvatar(
                        backgroundColor: accentColor,
                        child: Text(
                          p['userName'][0].toUpperCase(),
                          style: TextStyle(color: primaryColor),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(p['userName']),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: isInCall ? Colors.red : primaryColor,
            ),
            icon: Icon(isInCall ? Icons.call_end : Icons.call),
            label: Text(isInCall ? 'Leave Call' : 
                      (isCallActive ? 'Join Call' : 'Start Call')),
            onPressed: () => _handleCallAction(isInCall, isCallActive, userId, userName),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCallAction(bool isInCall, bool isCallActive, 
      String userId, String userName) async {
    try {
      Navigator.pop(context);
      
      if (isInCall) {
        await _callService.leaveCall(_selectedGroup!.id, userId);
      } else {
        bool isLoading = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preparing call...'),
            duration: Duration(seconds: 2),
          ),
        );
        
        try {
          final currentUserName = await _authService.getUserName(userId);
          
          final callDoc = await FirebaseFirestore.instance
              .collection('group_calls')
              .doc(_selectedGroup!.id)
              .get();
          
          final callData = callDoc.data() ?? {};
          final stillActive = callData['isActive'] == true && 
                            (callData['participants'] as List?)?.isNotEmpty == true;
          
          if (isCallActive && stillActive) {
            await _callService.joinCall(_selectedGroup!.id, userId, currentUserName);
          } else {
            await _callService.startCall(_selectedGroup!.id, userId, currentUserName);
          }
          
          isLoading = false;
          
          if (mounted) {
            _navigateToCallScreen();
          }
        } catch (e) {
          isLoading = false;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error preparing call: $e'))
            );
          }
          rethrow;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
  
  void _navigateToCallScreen() {
    if (_selectedGroup == null || FirebaseAuth.instance.currentUser == null) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GroupCallScreen(
          groupId: _selectedGroup!.id,
          userId: FirebaseAuth.instance.currentUser!.uid,
          groupName: _selectedGroup!.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    if (user == null) {
      return const Center(child: Text('Please sign in to use chat'));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _selectedGroup == null
          ? SafeArea(child: _buildGroupsList(user)) 
          : _buildChatScreen(user),
      floatingActionButton: null,
    );
  }

  void _showBackButtonOverlay() {
    if (_backButtonOverlayEntry != null) return;
    
    _backButtonOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 8,
        child: GestureDetector(
          onTap: () {
            _removeBackButtonOverlay();
            _selectGroup(null);
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
    
    Overlay.of(context).insert(_backButtonOverlayEntry!);
    
    Future.delayed(const Duration(seconds: 2), _removeBackButtonOverlay);
  }

  void _removeBackButtonOverlay() {
    _backButtonOverlayEntry?.remove();
    _backButtonOverlayEntry = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    _cleanupResources();
    
    for (final subscription in _playerStateSubscriptions.values) {
      subscription.cancel();
    }
    
    for (final timer in _positionUpdateTimers.values) {
      timer.cancel();
    }
    
    _recordingTimer?.cancel();
    
    for (final player in _voiceNotePlayers.values) {
      player.dispose();
    }
    
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _messageController.dispose();
    _groupNameController.dispose();
    _inviteCodeController.dispose();
    
    _scrollController.dispose();
    _backIndicatorController.dispose();
    _removeBackButtonOverlay();
    super.dispose();
  }
}