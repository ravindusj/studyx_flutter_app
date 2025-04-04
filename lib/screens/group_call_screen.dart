import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../webrtc_service.dart';
import '../services/call_service.dart'; // Fix this import path - remove studyx_app prefix
import '../auth_service.dart'; // Add this import
import 'dart:async';
import 'dart:ui';

class GroupCallScreen extends StatefulWidget {
  final String groupId;
  final String userId;
  final String groupName;

  const GroupCallScreen({
    super.key,
    required this.groupId,
    required this.userId,
    required this.groupName,
  });

  @override
  State<GroupCallScreen> createState() => _GroupCallScreenState();
}

class _GroupCallScreenState extends State<GroupCallScreen> with SingleTickerProviderStateMixin {
  late WebRTCService _webRTCService;
  bool _isMuted = false;
  final bool _isSpeakerOn = true;  // Added speaker control
  final Map<String, bool> _activeSpeakers = {};
  final Map<String, String> _userNames = {};
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String _statusMessage = 'Initializing...';
  Timer? _connectionTimeoutTimer;
  DateTime? _callStartTime;
  Timer? _callDurationTimer;
  String _callDuration = '00:00';
  final List<String> namesToFetch = [];
  
  // For animation
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  // Debug mode to show detailed status
  final bool _debugMode = true;
  final List<String> _logMessages = [];
  
  // Add a reference to CallService
  final _callService = CallService();
  
  // Add these fields to track Firebase participants
  Set<String> _currentParticipantIds = {};  // Track active participant IDs from Firestore
  StreamSubscription<DocumentSnapshot>? _callDocSubscription;

  // Add a flag to track if the timer is running
  bool _isTimerRunning = false;

  // Add this field at the class level
  bool _hasShownIndexDialog = false;

  // Enhanced connection tracking
  final Map<String, ConnectionStatus> _connectionStates = {};
  Timer? _connectionMonitorTimer;

  // Add auth service for better name lookup
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    
    // Setup animation
    _animationController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut)
    );
    
    // Initialize WebRTC in a non-blocking way
    _webRTCService = WebRTCService(
      groupId: widget.groupId,
      userId: widget.userId,
    );
    
    _webRTCService.onStreamUpdate = _handleStreamUpdate;
    _webRTCService.onStatusUpdate = _handleStatusUpdate;
    
    // Set connection timeout timer - more generous 45 seconds
    _connectionTimeoutTimer = Timer(const Duration(seconds: 45), () {
      if (_isLoading && mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
          _errorMessage = 'Connection timeout. Please check your internet connection and try again.';
        });
      }
    });
    
    // Add current user to active speakers initially
    _activeSpeakers[widget.userId] = true;
    _connectionStates[widget.userId] = ConnectionStatus.connected;
    
    // Start initialization process without blocking UI
    _initializeCall();
    
    // Set up real-time listener for call participants
    _setupCallParticipantsListener();

    // Add a timer to periodically check and clean up the participant list
    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      if (_isLoading || _hasError) return;
      
      // Clean out any participants that shouldn't be there
      _cleanupParticipantsList();
    });

    // Add a real-time connection monitor that updates more frequently
    _connectionMonitorTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      if (_isLoading || _hasError) return;
      
      _updateConnectionStates();
    });
  }
  
  void _handleStatusUpdate(String message) {
    print("WebRTC Status: $message");
    
    // Handle the index error message specially
    if (message.contains("INDEX REQUIRED")) {
      _showIndexRequiredDialog();
    }
    
    if (mounted) {
      setState(() {
        _statusMessage = message;
        // Add to log messages for debug view
        _logMessages.add("${DateTime.now().toString().substring(11, 19)}: $message");
        // Keep log size manageable
        if (_logMessages.length > 100) {
          _logMessages.removeAt(0);
        }
      });
    }
  }

  void _showIndexRequiredDialog() {
    // Only show once
    if (_hasShownIndexDialog) return;
    _hasShownIndexDialog = true;
    
    // Show the dialog after a short delay to ensure the UI is ready
    Future.delayed(Duration(seconds: 1), () {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Database Index Required'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This app requires a Firebase database index for optimal performance.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Text(
                  'The app will continue to function, but with reduced performance. ' 
                  'Please contact the app administrator to create the required index.'
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Continue'),
              ),
            ],
          ),
        );
      }
    });
  }

  Future<void> _initializeCall() async {
    try {
      // First, fetch current user name - IMPROVED VERSION
      await _fetchCurrentUserName();
      
      // Add current user to active speakers initially
      setState(() {
        _activeSpeakers[widget.userId] = true;
      });
      
      // Get initial list of participants
      await _fetchParticipantsFromFirestore();
      
      // Then initialize the actual WebRTC connection
      await _webRTCService.joinCall();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Don't immediately set _callStartTime
          // We'll set it when others join
        });
        
        _connectionTimeoutTimer?.cancel();
        
        // Check if there are other participants now
        _updateCallTimerState();
      }
    } catch (e) {
      print('Error initializing call: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
          _errorMessage = 'Failed to connect: ${e.toString()}';
        });
        
       
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error connecting to call: $e'))
        );
      }
    }
  }

  
  void _updateCallTimerState() {
    if (!mounted) return;
    
    
    final otherParticipantsCount = _currentParticipantIds
        .where((id) => id != widget.userId)
        .length;
    
    if (otherParticipantsCount > 0 && !_isTimerRunning) {
     
      _handleStatusUpdate("Starting call timer - others have joined");
      _startCallTimer();
    } else if (otherParticipantsCount == 0 && _isTimerRunning) {
     
      _handleStatusUpdate("Pausing call timer - nobody else in call");
      _stopCallTimer();
    }
  }
  
  
  void _startCallTimer() {
    setState(() {
      _callStartTime = DateTime.now();
      _callDuration = "00:00";
      _isTimerRunning = true;
    });
    
    // Setup timer for call duration
    _callDurationTimer?.cancel();
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _callStartTime != null) {
        final duration = DateTime.now().difference(_callStartTime!);
        final minutes = duration.inMinutes.toString().padLeft(2, '0');
        final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
        setState(() {
          _callDuration = "$minutes:$seconds";
        });
      }
    });
  }
  
  // Method to stop the call timer
  void _stopCallTimer() {
    _callDurationTimer?.cancel();
    setState(() {
      _isTimerRunning = false;
      _callDuration = "00:00"; // Reset to 00:00 when no one else is in the call
    });
  }

  void _handleStreamUpdate(String userId, dynamic stream) {
    if (!mounted) return;
    
    _handleStatusUpdate("Stream update from: $userId, has stream: ${stream != null}");
    
    setState(() {
      // Update active speakers (legacy)
      _activeSpeakers[userId] = stream != null;
      
      // Update connection states (new)
      _connectionStates[userId] = stream != null 
          ? ConnectionStatus.connected 
          : ConnectionStatus.connecting;
    });
    
    // Always fetch the name to ensure we have it
    _fetchUserName(userId);
  }
  
  // Improved user name fetching
  Future<void> _fetchUserName(String userId) async {
    // Don't fetch again if we already have it
    if (_userNames.containsKey(userId) && _userNames[userId] != 'Unknown') return;
    
    try {
      // Use the auth service for consistent name lookup
      final name = await _authService.getUserName(userId);
      
      if (mounted && name != 'Unknown') {
        setState(() {
          _userNames[userId] = name;
        });
      } else if (mounted) {
        // If still unknown, try direct Firestore lookup as fallback
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        
        if (userDoc.exists && mounted) {
          final userData = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _userNames[userId] = userData['name'] ?? 
                                userData['displayName'] ?? 
                                'Unknown';
          });
        }
      }
    } catch (e) {
      print('Error fetching username: $e');
      if (mounted && !_userNames.containsKey(userId)) {
        setState(() {
          _userNames[userId] = 'Unknown';
        });
      }
    }
  }
  
  Future<void> _fetchCurrentUserName() async {
    try {
      // Use auth service for current user
      final name = await _authService.getUserName(widget.userId);
      if (mounted) {
        setState(() {
          _userNames[widget.userId] = name;
        });
      }
    } catch (e) {
      print('Error fetching current user name: $e');
      // Fallback to previous method
      await _fetchUserName(widget.userId);
    }
  }
  
  // Optimized method to fetch multiple user names at once
  Future<void> _fetchMultipleUserNames(List<String> userIds) async {
    try {
      final names = await _authService.getUserNames(userIds);
      if (mounted) {
        setState(() {
          _userNames.addAll(names);
        });
      }
    } catch (e) {
      print('Error fetching multiple user names: $e');
      // Fallback to individual fetches
      for (final userId in userIds) {
        await _fetchUserName(userId);
      }
    }
  }

  // Replace _setupParticipantsDiscovery with this real-time listener
  void _setupCallParticipantsListener() {
    _callDocSubscription = FirebaseFirestore.instance
      .collection('group_calls')
      .doc(widget.groupId)
      .snapshots()
      .listen((snapshot) {
        if (!snapshot.exists || !mounted) return;
        
        _updateCallParticipants(snapshot.data());
      }, onError: (error) {
        _handleStatusUpdate("Error in call document listener: $error");
      });
  }
  
  // New method to update participant list from Firestore document
  void _updateCallParticipants(Map<String, dynamic>? data) {
    if (data == null || !mounted) return;
    
    // Extract participants list
    final isActive = data['isActive'] ?? false;
    final List<dynamic> rawParticipants = data['participants'] ?? [];
    
    // Convert to typed list and extract IDs safely
    List<Map<String, dynamic>> participants;
    try {
      participants = List<Map<String, dynamic>>.from(rawParticipants);
    } catch (e) {
      _handleStatusUpdate("Error parsing participants: $e");
      participants = [];
    }
    
    final Set<String> participantIds = 
        participants.map((p) => p['userId'] as String).toSet();
    
    // Add current user's ID if not present
    participantIds.add(widget.userId);
    
    // Check if call is no longer active
    if (!isActive) {
      _handleStatusUpdate("Call has ended on the server");
      if (mounted) {
        setState(() {
          // Clear all remote participants, but keep current user
          _activeSpeakers.removeWhere((key, _) => key != widget.userId);
          _currentParticipantIds = {widget.userId};
        });
        // Stop the timer if it's running
        _stopCallTimer();
      }
      return;
    }
    
    // Track which participants should be removed
    final List<String> keysToRemove = [];
    
    // Find participants in UI that should be removed
    for (final key in _activeSpeakers.keys) {
      // Don't remove the current user
      if (key != widget.userId && !participantIds.contains(key)) {
        keysToRemove.add(key);
      }
    }
    
    // If we have participants to remove, update the UI
    if (keysToRemove.isNotEmpty || participantIds.length > _currentParticipantIds.length) {
      if (mounted) {
        setState(() {
          // Remove participants no longer in the list
          for (final key in keysToRemove) {
            _activeSpeakers.remove(key);
            _handleStatusUpdate("Removed participant from UI: ${_userNames[key] ?? key}");
          }
          
          // Add any new participants
          for (final participant in participants) {
            final id = participant['userId'] as String;
            // Add to UI if new, but don't overwrite existing connection status
            if (id != widget.userId && !_activeSpeakers.containsKey(id)) {
              _activeSpeakers[id] = false; // Start as not connected
              _connectionStates[id] = ConnectionStatus.waiting; // New
              
              // Update name if available
              if (participant.containsKey('userName')) {
                final name = participant['userName'] as String;
                // Only use the name from the participant if it's not "Unknown"
                if (name != 'Unknown') {
                  _userNames[id] = name;
                  _handleStatusUpdate("Added new participant: $name ($id)");
                } else {
                  // If name is Unknown, add to the fetch list
                  namesToFetch.add(id);
                }
              } else {
                // If no name available, add to fetch list
                namesToFetch.add(id);
              }
            }
          }
          
          // Fetch missing names in bulk for better performance
          if (namesToFetch.isNotEmpty) {
            _fetchMultipleUserNames(namesToFetch);
          }
          
          // Update current participants set
          _currentParticipantIds = Set<String>.from(participantIds);
        });
        
        // Update timer state based on new participant list
        _updateCallTimerState();
      }
    }
  }
  
  // Update the fetchParticipantsFromFirestore method to only update once
  Future<void> _fetchParticipantsFromFirestore() async {
    try {
      final callDoc = await FirebaseFirestore.instance
          .collection('group_calls')
          .doc(widget.groupId)
          .get();
          
      if (!callDoc.exists || !mounted) return;
      
      _updateCallParticipants(callDoc.data());
    } catch (e) {
      print('Error fetching participants: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.grey.shade900, Colors.black],
              ),
            ),
          ),
          
          // Main content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _isLoading 
                    ? _buildLoadingState()
                    : _hasError 
                      ? _buildErrorState()
                      : _buildCallContent(),
                ),
                _buildCallControls(),
              ],
            ),
          ),
          
          // Debug overlay if debug mode is enabled
          if (_debugMode && !_isLoading && !_hasError)
            _buildDebugOverlay(),
        ],
      ),
    );
  }
  
  Widget _buildDebugOverlay() {
    return Positioned(
      bottom: 100,
      right: 0,
      child: GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Debug Log'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _logMessages.length,
                  itemBuilder: (context, index) => Text(
                    _logMessages[_logMessages.length - 1 - index],
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
          ),
          child: const Icon(
            Icons.bug_report,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey.shade800,
            radius: 16,
            child: Text(
              widget.groupName.isNotEmpty 
                ? widget.groupName.substring(0, 1).toUpperCase()
                : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.groupName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                _isLoading ? "Connecting..." : "Voice call",
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              Icons.keyboard_arrow_down,
              color: Colors.grey.shade400,
              size: 28,
            ),
            onPressed: _leaveCall,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Pulsating connecting animation
          FadeTransition(
            opacity: _animation,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade800,
              ),
              child: const Icon(
                Icons.call,
                color: Colors.white,
                size: 42,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Connecting to call...",
            style: TextStyle(
              color: Colors.grey.shade300,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _statusMessage,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 60,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            "Connection Failed",
            style: TextStyle(
              color: Colors.grey.shade300,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
              _initializeCall();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade800,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildCallContent() {
    // Create a filtered list of participants who are actually in the call
    // based on Firestore data (in _currentParticipantIds)
    final participants = _activeSpeakers.entries
        .where((entry) => _currentParticipantIds.contains(entry.key))
        .map((entry) {
          final isCurrentUser = entry.key == widget.userId;
          return _buildParticipantTile(
            userId: entry.key, 
            isActive: entry.value,
            isCurrentUser: isCurrentUser,
          );
        }).toList();
    
    // Count stats
    final activeSpeakers = participants.length;
    final connectedSpeakers = _activeSpeakers.entries
        .where((e) => _currentParticipantIds.contains(e.key) && e.value)
        .length;
    
    // Count other participants (not including current user)
    final otherParticipantsCount = _currentParticipantIds
        .where((id) => id != widget.userId)
        .length;
    
    return Column(
      children: [
        const SizedBox(height: 20),
        
        // Call duration timer - only show meaningful time when others are present
        Text(
          otherParticipantsCount > 0 ? _callDuration : "Waiting for others",
          style: TextStyle(
            color: otherParticipantsCount > 0 ? Colors.grey.shade500 : Colors.amber.shade700,
            fontSize: 14,
          ),
        ),
        
        // Show participant count
        Text(
          "$connectedSpeakers/$activeSpeakers participants connected",
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 12,
          ),
        ),
        
        const SizedBox(height: 30),
        
        // Participants grid/list - only showing actual call participants
        Expanded(
          // If there's only one participant (the current user), show the waiting message
          child: participants.length <= 1 
            ? _buildNoParticipantsMessage()
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: participants.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) => participants[index],
              ),
        ),
      ],
    );
  }
  
  Widget _buildNoParticipantsMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 50,
            color: Colors.grey.shade600,
          ),
          const SizedBox(height: 16),
          Text(
            "Waiting for others to join...",
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantTile({
    required String userId, 
    required bool isActive,
    required bool isCurrentUser,
  }) {
    final name = _userNames[userId] ?? 'Unknown';
    final initialLetter = name.isNotEmpty ? name[0].toUpperCase() : '?';

    // Get enhanced connection status
    final connectionStatus = _connectionStates[userId] ?? ConnectionStatus.unknown;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade800, width: 1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                // Avatar with connection status indicator
                Stack(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _getAvatarColor(isCurrentUser, connectionStatus),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _getAvatarShadowColor(isCurrentUser, connectionStatus),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          initialLetter,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    
                    // Show active connection indicator
                    if (connectionStatus == ConnectionStatus.connecting || 
                        connectionStatus == ConnectionStatus.waiting)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade800,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.black,
                              width: 1,
                            ),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 8,
                              height: 8,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                    // Show error indicator
                    if (connectionStatus == ConnectionStatus.failed)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.black,
                              width: 1,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.error,
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(width: 16),
                
                // Name and status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCurrentUser ? "$name (You)" : name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _getStatusColor(connectionStatus),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getStatusText(connectionStatus, isCurrentUser),
                            style: TextStyle(
                              color: _getStatusColor(connectionStatus),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Mic status for current user
                if (isCurrentUser)
                  Icon(
                    _isMuted ? Icons.mic_off : Icons.mic,
                    color: _isMuted ? Colors.red : Colors.white,
                  ),
                  
                // Retry button for failed connections
                if (!isCurrentUser && connectionStatus == ConnectionStatus.failed)
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                    onPressed: () {
                      _handleStatusUpdate("Manual reconnection requested for $userId");
                      _webRTCService.reconnectPeer(userId);
                    },
                    tooltip: "Retry connection",
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method for getting avatar color based on connection status
  Color _getAvatarColor(bool isCurrentUser, ConnectionStatus status) {
    if (isCurrentUser) {
      return Colors.blue.shade700;
    }
    
    switch (status) {
      case ConnectionStatus.connected:
        return Colors.green.shade700;
      case ConnectionStatus.connecting:
      case ConnectionStatus.waiting:
        return Colors.amber.shade700;
      case ConnectionStatus.disconnected:
      case ConnectionStatus.failed:
        return Colors.red.shade700;
      case ConnectionStatus.notConnected:
      case ConnectionStatus.unknown:
      default:
        return Colors.grey.shade700;
    }
  }
  
  // Helper method for avatar shadow color
  Color _getAvatarShadowColor(bool isCurrentUser, ConnectionStatus status) {
    if (isCurrentUser) {
      return Colors.blue.shade900.withOpacity(0.5);
    }
    
    switch (status) {
      case ConnectionStatus.connected:
        return Colors.green.shade900.withOpacity(0.5);
      case ConnectionStatus.connecting:
      case ConnectionStatus.waiting:
        return Colors.amber.shade900.withOpacity(0.5);
      case ConnectionStatus.disconnected:
      case ConnectionStatus.failed:
        return Colors.red.shade900.withOpacity(0.5);
      default:
        return Colors.transparent;
    }
  }
  
  // Helper method for status indicator color
  Color _getStatusColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return Colors.greenAccent;
      case ConnectionStatus.connecting:
      case ConnectionStatus.waiting:
        return Colors.amber;
      case ConnectionStatus.disconnected:
      case ConnectionStatus.notConnected:
        return Colors.grey.shade400;
      case ConnectionStatus.failed:
        return Colors.red.shade400;
      default:
        return Colors.grey;
    }
  }
  
  // Helper method for connection status text
  String _getStatusText(ConnectionStatus status, bool isCurrentUser) {
    if (isCurrentUser) {
      return _isMuted ? "Muted" : "Speaking";
    }
    
    switch (status) {
      case ConnectionStatus.connected:
        return "Connected";
      case ConnectionStatus.connecting:
        return "Connecting...";
      case ConnectionStatus.waiting:
        return "Waiting...";
      case ConnectionStatus.disconnected:
        return "Reconnecting...";
      case ConnectionStatus.failed:
        return "Connection failed";
      case ConnectionStatus.notConnected:
        return "Not connected";
      case ConnectionStatus.unknown:
      default:
        return "Unknown state";
    }
  }

  Widget _buildCallControls() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: Colors.grey.shade900.withOpacity(0.7),
            border: Border(
              top: BorderSide(
                color: Colors.grey.shade800,
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton(
                  icon: _isMuted ? Icons.mic_off : Icons.mic,
                  label: _isMuted ? 'Unmute' : 'Mute',
                  color: _isMuted ? Colors.red : Colors.white,
                  backgroundColor: _isMuted 
                    ? Colors.red.withOpacity(0.2)
                    : Colors.grey.shade800,
                  onTap: _toggleMute,
                ),
                _buildControlButton(
                  icon: Icons.call_end,
                  label: 'End',
                  color: Colors.white,
                  backgroundColor: Colors.red,
                  onTap: _leaveCall,
                ),
                _buildControlButton(
                  icon: Icons.volume_up,
                  label: 'Speaker',
                  color: Colors.white,
                  backgroundColor: Colors.grey.shade800,
                  onTap: () {
                    // Toggle speaker would go here
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(30),
            child: Ink(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 26,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _webRTCService.toggleMute(_isMuted);
    });
  }

  void _leaveCall() async {
    // Immediately navigate out to prevent UI freeze
    if (mounted) {
      // First, pop the navigation - do this before async operations
      Navigator.of(context).pop();
      
      // Show a temporary snackbar to indicate cleanup is happening
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Disconnecting from call...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
    
    // Then perform the cleanup operations
    try {
      // First, update the Firebase call status
      await _callService.leaveCall(widget.groupId, widget.userId);
      
      // Then handle WebRTC cleanup
      await _webRTCService.leaveCall();
    } catch (e) {
      print('Error during call cleanup: $e');
      // No setState here as widget might be disposed
    }
  }

  @override
  void dispose() {
    _connectionTimeoutTimer?.cancel();
    _callDurationTimer?.cancel(); // Ensure timer is cancelled
    _animationController.dispose();
    
    // Cancel subscriptions before calling leaveCall
    _webRTCService.onStreamUpdate = null;
    _webRTCService.onStatusUpdate = null;
    
    // Ensure we update Firestore when leaving the call, whether by back button or by widget disposal
    _callService.leaveCall(widget.groupId, widget.userId).catchError((e) {
      print('Error updating call status during dispose: $e');
    });
    
    // Don't await here to prevent blocking
    _webRTCService.leaveCall().catchError((e) {
      print('Error during disposal: $e');
    });
    
    // Cancel the call document subscription
    _callDocSubscription?.cancel();
    _connectionMonitorTimer?.cancel();
    
    super.dispose();
  }

  // Add this method to make sure UI stays clean
  void _cleanupParticipantsList() {
    if (!mounted) return;
    
    // Find keys to remove - participants not in the current set
    final keysToRemove = _activeSpeakers.keys
        .where((key) => key != widget.userId && !_currentParticipantIds.contains(key))
        .toList();
        
    if (keysToRemove.isNotEmpty) {
      setState(() {
        for (final key in keysToRemove) {
          _activeSpeakers.remove(key);
          _connectionStates.remove(key); // Also clean up connection states
          _handleStatusUpdate("Cleanup: removed stale participant $key");
        }
      });
    }
  }

  // New method to actively query connection states
  void _updateConnectionStates() {
    if (!mounted) return;
    
    try {
      for (final userId in _currentParticipantIds) {
        // Skip self - we already know our own state
        if (userId == widget.userId) continue;
        
        // Check WebRTC state directly
        final connectionState = _webRTCService.getConnectionState(userId);
        final hasPeerConnection = _webRTCService.hasPeerConnection(userId);
        final hasActiveStream = _webRTCService.hasRemoteStream(userId);
        
        // No connection attempt yet
        if (!hasPeerConnection) {
          _updateSingleConnectionState(userId, ConnectionStatus.notConnected);
          continue;
        }
        
        // Connected with stream (best case)
        if (hasActiveStream) {
          _updateSingleConnectionState(userId, ConnectionStatus.connected);
          continue;
        }
        
        // Connection attempt in progress but not yet stable
        if (connectionState != null) {
          if (connectionState.contains('connected') || 
              connectionState.contains('completed')) {
            // Connected but without stream (mic muted or not sending audio)
            _updateSingleConnectionState(userId, ConnectionStatus.connected);
          } else if (connectionState.contains('checking') ||
                     connectionState.contains('new')) {
            // Actively trying to establish connection
            _updateSingleConnectionState(userId, ConnectionStatus.connecting);
          } else if (connectionState.contains('failed')) {
            // Connection attempt failed
            _updateSingleConnectionState(userId, ConnectionStatus.failed);
          } else if (connectionState.contains('disconnected')) {
            // Was connected but lost connection
            _updateSingleConnectionState(userId, ConnectionStatus.disconnected);
          } else {
            // Other states (closed, etc.)
            _updateSingleConnectionState(userId, ConnectionStatus.unknown);
          }
        } else {
          // State unknown but connection exists
          _updateSingleConnectionState(userId, ConnectionStatus.connecting);
        }
      }
    } catch (e) {
      print("Error updating connection states: $e");
    }
  }
  
  // Update a single user's connection state if it has changed
  void _updateSingleConnectionState(String userId, ConnectionStatus newStatus) {
    final currentStatus = _connectionStates[userId];
    if (currentStatus != newStatus) {
      setState(() {
        _connectionStates[userId] = newStatus;
        
        // Also update active speaker status for compatibility with existing code
        _activeSpeakers[userId] = newStatus == ConnectionStatus.connected;
      });
      
      _handleStatusUpdate("Connection status changed for $userId: $newStatus");
    }
  }
}

// Define connection status enum for better tracking
enum ConnectionStatus {
  notConnected,  // No connection attempt made
  waiting,       // Waiting to start connection
  connecting,    // Connection in progress
  connected,     // Successfully connected
  disconnected,  // Was connected but lost connection
  failed,        // Connection attempt failed
  unknown        // Status unknown
}
