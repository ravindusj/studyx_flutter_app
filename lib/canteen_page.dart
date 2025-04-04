import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'dart:async';
import 'models/canteen_model.dart';
import 'services/canteen_service.dart';
import 'services/notification_service.dart';

class CanteenPage extends StatefulWidget {
  const CanteenPage({Key? key}) : super(key: key);

  @override
  State<CanteenPage> createState() => _CanteenPageState();
}

class _CanteenPageState extends State<CanteenPage> {
  final CanteenService _canteenService = CanteenService();
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = true;
  bool _hasPermissionError = false;
  Stream<List<CanteenModel>>? _canteensStream;
  StreamSubscription? _canteensSubscription;
  String _statusMessage = '';
  List<CanteenModel>? _cachedCanteens;
  bool _notificationsEnabled = false;
  int _notificationThreshold = 30;
  bool _loadingPreferences = true;

  @override
  void initState() {
    super.initState();
    _initializeCanteens();
    _loadNotificationPreferences();
  }

  @override
  void dispose() {
    _canteensSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadNotificationPreferences() async {
    if (!mounted) return;

    setState(() {
      _loadingPreferences = true;
    });

    try {
      await _notificationService.initialize();

      final notificationsEnabled =
          await _notificationService.isCanteenNotificationsEnabled();
      final threshold = await _notificationService.getCanteenThreshold();

      if (!mounted) return;

      setState(() {
        _notificationsEnabled = notificationsEnabled;
        _notificationThreshold = threshold;
        _loadingPreferences = false;
      });
    } catch (e) {
      debugPrint('Error loading notification preferences: $e');
      if (mounted) {
        setState(() {
          _loadingPreferences = false;
        });
      }
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    if (!mounted) return;

    setState(() {
      _notificationsEnabled = value;
    });

    await _notificationService.setCanteenNotificationsEnabled(value);
  }

  Future<void> _initializeCanteens() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Connecting to database...';
    });

    try {
      bool firestoreAvailable = await _canteenService.isFirestoreAvailable();

      if (!mounted) return;

      if (!firestoreAvailable) {
        setState(() {
          _hasPermissionError = true;
          _statusMessage =
              'Could not connect to the database. Using local data instead.';
        });
      } else {
        setState(() {
          _statusMessage = 'Initializing canteen data...';
        });
      }

      await _canteenService.initializeCanteens();

      final stream = _canteenService.getCanteens();

      _canteensSubscription = stream.listen(
        (canteens) {
          if (mounted) {
            setState(() {
              _cachedCanteens = canteens;
            });
          }
        },
        onError: (e) {
          debugPrint('Error in canteens stream: $e');
          if (mounted) {
            setState(() {
              _hasPermissionError = true;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _canteensStream = stream;
          _statusMessage = '';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error initializing canteens: $e');

      if (!mounted) return;

      setState(() {
        _hasPermissionError = true;
        _statusMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  void _refreshCanteens() {
    _canteensSubscription?.cancel();

    final stream = _canteenService.getCanteens();

    _canteensSubscription = stream.listen(
      (canteens) {
        if (mounted) {
          setState(() {
            _cachedCanteens = canteens;
          });
        }
      },
      onError: (e) {
        debugPrint('Error in canteens stream: $e');
      },
    );

    if (mounted) {
      setState(() {
        _canteensStream = stream;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final accentColor = Theme.of(context).colorScheme.tertiary;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Center(
        child: LoadingAnimationWidget.stretchedDots(
          color: isDarkMode ? accentColor : primaryColor,
          size: 50,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Canteen Availability',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check and update real-time availability',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),

              IconButton(
                onPressed: () => _showNotificationSettings(context),
                icon: Icon(
                  _notificationsEnabled
                      ? Icons.notifications_active
                      : Icons.notifications_off,
                  color:
                      _notificationsEnabled
                          ? Theme.of(context).primaryColor
                          : Colors.grey,
                ),
                tooltip: 'Notification Settings',
              ),
            ],
          ),

          if (_hasPermissionError) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.amber.shade900.withOpacity(0.2)
                        : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.amber.shade700
                          : Colors.orange.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.amber.shade500
                            : Colors.orange.shade700,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Using local data. Updates won\'t be shared with other users.',
                      style: TextStyle(
                        color:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.amber.shade300
                                : Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                _refreshCanteens();
              },
              child: StreamBuilder<List<CanteenModel>>(
                stream: _canteensStream,
                initialData: _cachedCanteens,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData &&
                      _cachedCanteens == null) {
                    return Center(
                      child: LoadingAnimationWidget.stretchedDots(
                        color: isDarkMode ? accentColor : primaryColor,
                        size: 50,
                      ),
                    );
                  }

                  if (snapshot.hasError && _cachedCanteens == null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Theme.of(context).colorScheme.error,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading data: ${snapshot.error}',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _refreshCanteens,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  final canteens = snapshot.data ?? _cachedCanteens ?? [];

                  if (canteens.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.restaurant,
                            color: Colors.grey,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No canteens available',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: canteens.length,
                    itemBuilder: (context, index) {
                      final canteen = canteens[index];
                      return _buildCanteenCard(context, canteen);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanteenCard(BuildContext context, CanteenModel canteen) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  canteen.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: canteen.statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    canteen.availabilityStatus,
                    style: TextStyle(
                      color: canteen.statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Occupancy',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    Text(
                      '${(canteen.occupancyRate * 100).round()}%',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: canteen.occupancyRate,
                    minHeight: 10,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      canteen.statusColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Available: ${canteen.availabilityPercentage.round()}%',
                  style: const TextStyle(color: Colors.grey),
                ),
                Text(
                  'Updated ${_formatLastUpdated(canteen.lastUpdated)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showUpdateDialog(context, canteen),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Update Availability'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastUpdated(DateTime lastUpdated) {
    final now = DateTime.now();
    final difference = now.difference(lastUpdated);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM d, h:mm a').format(lastUpdated);
    }
  }

  void _showUpdateDialog(BuildContext context, CanteenModel canteen) {
    double availabilityPercentage = canteen.availabilityPercentage;
    bool isUpdating = false;

    showDialog(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text('Update ${canteen.name}'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Estimate how full the canteen is by adjusting the slider. 100% means all seats are available, 0% means it\'s completely full.',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Availability:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getColorForPercentage(
                                availabilityPercentage,
                              ).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${availabilityPercentage.round()}%',
                              style: TextStyle(
                                color: _getColorForPercentage(
                                  availabilityPercentage,
                                ),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          const Text('0%', style: TextStyle(fontSize: 12)),
                          Expanded(
                            child: Slider(
                              value: availabilityPercentage,
                              min: 0,
                              max: 100,
                              divisions: 10,
                              activeColor: _getColorForPercentage(
                                availabilityPercentage,
                              ),
                              label: '${availabilityPercentage.round()}%',
                              onChanged:
                                  isUpdating
                                      ? null
                                      : (value) {
                                        setDialogState(() {
                                          availabilityPercentage = value;
                                        });
                                      },
                            ),
                          ),
                          const Text('100%', style: TextStyle(fontSize: 12)),
                        ],
                      ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            availabilityPercentage > 70
                                ? Icons.sentiment_very_satisfied
                                : availabilityPercentage > 30
                                ? Icons.sentiment_satisfied
                                : Icons.sentiment_dissatisfied,
                            color: _getColorForPercentage(
                              availabilityPercentage,
                            ),
                            size: 28,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            availabilityPercentage > 70
                                ? 'Plenty of space'
                                : availabilityPercentage > 30
                                ? 'Moderate'
                                : 'Crowded',
                            style: TextStyle(
                              color: _getColorForPercentage(
                                availabilityPercentage,
                              ),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      if (isUpdating)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Center(
                            child: LoadingAnimationWidget.stretchedDots(
                              color:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Theme.of(context).colorScheme.tertiary
                                      : Theme.of(context).colorScheme.primary,
                              size: 40,
                            ),
                          ),
                        ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          isUpdating
                              ? null
                              : () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed:
                          isUpdating
                              ? null
                              : () async {
                                final user = FirebaseAuth.instance.currentUser;
                                if (user != null) {
                                  setDialogState(() {
                                    isUpdating = true;
                                  });

                                  try {
                                    bool success = await _canteenService
                                        .updateCanteenAvailability(
                                          canteen.id,
                                          availabilityPercentage,
                                          user.uid,
                                        );

                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext);

                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              success
                                                  ? 'Availability updated successfully!'
                                                  : 'Update saved in local mode only',
                                            ),
                                            backgroundColor:
                                                success
                                                    ? Colors.green
                                                    : Colors.orange,
                                          ),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    debugPrint(
                                      'Error updating availability: $e',
                                    );

                                    if (dialogContext.mounted) {
                                      setDialogState(() {
                                        isUpdating = false;
                                      });

                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text('Error updating: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                }
                              },
                      child: const Text('Update'),
                    ),
                  ],
                ),
          ),
    );
  }

  Color _getColorForPercentage(double percentage) {
    if (percentage >= 70) {
      return Colors.green;
    } else if (percentage >= 30) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  void _showNotificationSettings(BuildContext context) {
    bool notificationsEnabled = _notificationsEnabled;
    int threshold = _notificationThreshold;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Row(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        color: Theme.of(context).primaryColor,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      const Text('Canteen Alerts'),
                    ],
                  ),
                  content:
                      _loadingPreferences
                          ? const Center(child: CircularProgressIndicator())
                          : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SwitchListTile(
                                title: const Text('Get Notifications'),
                                subtitle: const Text(
                                  'You\'ll be alerted about canteen availability',
                                ),
                                value: notificationsEnabled,
                                onChanged: (value) {
                                  setDialogState(() {
                                    notificationsEnabled = value;
                                  });
                                },
                              ),

                              const Divider(height: 24),

                              if (notificationsEnabled) ...[
                                const Text(
                                  'Notify me when canteens are:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),

                                const SizedBox(height: 16),

                                Row(
                                  children: [
                                    const Icon(
                                      Icons.sentiment_very_dissatisfied,
                                      color: Colors.red,
                                    ),
                                    Expanded(
                                      child: Slider(
                                        value: threshold.toDouble(),
                                        min: 10,
                                        max: 70,
                                        divisions: 6,
                                        label: '$threshold% full',
                                        onChanged: (value) {
                                          setDialogState(() {
                                            threshold = value.round();
                                          });
                                        },
                                      ),
                                    ),
                                    const Icon(
                                      Icons.sentiment_very_satisfied,
                                      color: Colors.green,
                                    ),
                                  ],
                                ),

                                Align(
                                  alignment: Alignment.center,
                                  child: Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getColorForPercentage(
                                        threshold.toDouble(),
                                      ).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: _getColorForPercentage(
                                          threshold.toDouble(),
                                        ).withOpacity(0.5),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          threshold <= 30
                                              ? Icons.warning_rounded
                                              : threshold >= 70
                                              ? Icons.check_circle
                                              : Icons.info_outline,
                                          color: _getColorForPercentage(
                                            threshold.toDouble(),
                                          ),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          threshold <= 30
                                              ? 'Alert when very crowded'
                                              : threshold >= 70
                                              ? 'Alert when plenty of space'
                                              : 'Alert when moderately busy',
                                          style: TextStyle(
                                            color: _getColorForPercentage(
                                              threshold.toDouble(),
                                            ),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCEL'),
                    ),
                    FilledButton(
                      onPressed: () async {
                        await _notificationService
                            .setCanteenNotificationsEnabled(
                              notificationsEnabled,
                            );
                        await _notificationService.setCanteenThreshold(
                          threshold,
                        );

                        if (mounted) {
                          setState(() {
                            _notificationsEnabled = notificationsEnabled;
                            _notificationThreshold = threshold;
                          });
                        }

                        if (context.mounted) {
                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                notificationsEnabled
                                    ? 'Canteen alerts enabled'
                                    : 'Canteen alerts disabled',
                              ),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      child: const Text('SAVE'),
                    ),
                  ],
                ),
          ),
    );
  }
}
