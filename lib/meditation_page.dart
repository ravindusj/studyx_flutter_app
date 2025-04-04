import 'package:flutter/material.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'services/audio_service.dart';
import 'dart:math' as math;
import 'breathing_exercise_page.dart';

class MeditationPage extends StatefulWidget {
  const MeditationPage({Key? key}) : super(key: key);

  @override
  State<MeditationPage> createState() => _MeditationPageState();
}

class _MeditationPageState extends State<MeditationPage> {
  final AudioService _audioService = AudioService();
  late final PageController _featuredPageController;
  Timer? _featuredSlideshowTimer;
  int _currentFeaturedIndex = 0;
  bool _isPageChanging = false;

  List<Map<String, dynamic>>? _cachedFeaturedMeditations;

  final List<Map<String, dynamic>> _meditations = [
    {
      'title': 'Quick Calm',
      'description': 'A short meditation to quickly calm your mind',
      'duration': '5 min',
      'seconds': 300,
      'image': 'assets/images/meditation1.jpg',
      'audio': 'meditation_calm.mp3',
      'category': 'Calm',
      'featured': true,
    },
    {
      'title': 'Mindful Focus',
      'description': 'Improve concentration and focus on your studies',
      'duration': '10 min',
      'seconds': 600,
      'image': 'assets/images/meditation2.jpg',
      'audio': 'meditation_focus.mp3',
      'category': 'Focus',
      'featured': false,
    },
    {
      'title': 'Deep Relaxation',
      'description': 'Release tension and fully relax your body and mind',
      'duration': '15 min',
      'seconds': 900,
      'image': 'assets/images/meditation3.jpg',
      'audio': 'meditation_relax.mp3',
      'category': 'Relax',
      'featured': false,
    },
    {
      'title': 'Sleep Well',
      'description': 'Prepare your mind for a restful night\'s sleep',
      'duration': '20 min',
      'seconds': 1200,
      'image': 'assets/images/meditation4.jpg',
      'audio': 'meditation_sleep.mp3',
      'category': 'Sleep',
      'featured': false,
    },
    {
      'title': 'Quick Energy',
      'description': 'Revitalize your energy levels between study sessions',
      'duration': '5 min',
      'seconds': 300,
      'image': 'assets/images/meditation5.jpg',
      'audio': 'meditation_energy.mp3',
      'category': 'Energy',
      'featured': false,
    },
    {
      'title': 'Exam Prep',
      'description': 'Calm your nerves before an exam',
      'duration': '7 min',
      'seconds': 420,
      'image': 'assets/images/meditation6.jpg',
      'audio': 'meditation_exam.mp3',
      'category': 'Calm',
      'featured': false,
    },
  ];

  List<String> get _categories {
    final categories =
        _meditations.map((m) => m['category'] as String).toSet().toList();
    categories.sort();
    return ['All', ...categories];
  }

  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();

    _featuredPageController = PageController(
      initialPage: 0,
      viewportFraction: 0.93,
    );

    _audioService.addListener(_updateState);

    _startFeaturedSlideshow();
  }

  void _startFeaturedSlideshow() {
    _featuredSlideshowTimer = Timer.periodic(const Duration(seconds: 5), (
      timer,
    ) {
      if (!mounted || _isPageChanging) return;

      if (!_featuredPageController.hasClients) return;

      final featuredMeditations = _getFeaturedMeditations();
      if (featuredMeditations.length <= 1) return;

      setState(() {
        _isPageChanging = true;

        final nextPage =
            (_currentFeaturedIndex + 1) % featuredMeditations.length;
        _currentFeaturedIndex = nextPage;
      });

      if (_featuredPageController.hasClients) {
        _featuredPageController
            .animateToPage(
              _currentFeaturedIndex,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
            )
            .whenComplete(() {
              if (mounted) {
                setState(() {
                  _isPageChanging = false;
                });
              }
            });
      } else {
        if (mounted) {
          setState(() {
            _isPageChanging = false;
          });
        }
      }
    });
  }

  List<Map<String, dynamic>> _getFeaturedMeditations() {
    if (_audioService.currentMeditationData != null &&
        _cachedFeaturedMeditations != null) {
      return _cachedFeaturedMeditations!;
    }

    final explicitFeatured =
        _meditations.where((m) => m['featured'] == true).toList();

    if (explicitFeatured.length >= 3) {
      return explicitFeatured;
    }

    final result = List<Map<String, dynamic>>.from(explicitFeatured);
    final remainingMeditations =
        _meditations.where((m) => m['featured'] != true).toList();
    remainingMeditations.shuffle();

    while (result.length < 3 && remainingMeditations.isNotEmpty) {
      result.add(remainingMeditations.removeAt(0));
    }

    return result;
  }

  void _updateState() {
    if (mounted) {
      setState(() {});
    }
  }

  void _playMeditation(Map<String, dynamic> meditation) async {
    try {
      _cachedFeaturedMeditations = _getFeaturedMeditations();

      _featuredSlideshowTimer?.cancel();

      await _audioService.playMeditation(meditation);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not play meditation audio.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );

      _cachedFeaturedMeditations = null;

      _startFeaturedSlideshow();
    }
  }

  void _pauseResumeMeditation() async {
    await _audioService.pauseResume();
  }

  void _stopMeditation() async {
    await _audioService.stop();

    _cachedFeaturedMeditations = null;

    if (mounted) {
      _startFeaturedSlideshow();
    }
  }

  @override
  void dispose() {
    _audioService.removeListener(_updateState);
    _featuredPageController.dispose();
    _featuredSlideshowTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    final bool hasCurrentMeditation =
        _audioService.currentMeditationData != null;

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 16.0,
                  horizontal: 16.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Guided Meditation',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        _buildFeatureButtons(context, theme),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Take a moment to relax and focus with these guided sessions',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),

                    _buildCategoryFilters(theme, isDarkMode),
                  ],
                ),
              ),

              Expanded(
                child:
                    hasCurrentMeditation
                        ? Padding(
                          padding: const EdgeInsets.only(bottom: 76.0),
                          child: _buildMeditationList(theme, isDarkMode),
                        )
                        : _buildMeditationList(theme, isDarkMode),
              ),
            ],
          ),

          if (hasCurrentMeditation)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildMiniPlayer(theme, isDarkMode),
            ),
        ],
      ),
    );
  }

  Widget _buildFeatureButtons(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: () {
            if (_audioService.isPlaying) {
              _stopMeditation();
            }

            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const BreathingExercisePage(),
              ),
            );
          },
          icon: const Icon(Icons.air, size: 16),
          label: const Text('Breathing'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.secondary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniPlayer(ThemeData theme, bool isDarkMode) {
    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: Slider(
              value: _audioService.position.inSeconds.toDouble(),
              max:
                  _audioService.duration.inSeconds.toDouble() == 0
                      ? 1.0
                      : _audioService.duration.inSeconds.toDouble(),
              onChanged: (value) async {
                final position = Duration(seconds: value.toInt());
                await _audioService.seekTo(position);
              },
              activeColor: theme.colorScheme.primary,
              inactiveColor: theme.colorScheme.primary.withOpacity(0.3),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                if (_audioService.currentMeditationData != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      _audioService.currentMeditationData!['image'] as String,
                      width: 42,
                      height: 42,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) => Container(
                            width: 42,
                            height: 42,
                            color: theme.colorScheme.tertiary.withOpacity(0.3),
                            child: Icon(
                              Icons.spa,
                              color: theme.colorScheme.primary,
                              size: 24,
                            ),
                          ),
                    ),
                  ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _audioService.currentMeditationTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Remaining: ${_audioService.formatRemainingTime()}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(
                            0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                IconButton(
                  icon: Icon(
                    _audioService.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    size: 42,
                    color: theme.colorScheme.primary,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: _pauseResumeMeditation,
                ),

                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  padding: EdgeInsets.zero,
                  onPressed: _stopMeditation,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeditationList(ThemeData theme, bool isDarkMode) {
    final filteredMeditations =
        _selectedCategory == 'All'
            ? _meditations
            : _meditations
                .where((m) => m['category'] == _selectedCategory)
                .toList();

    final featuredMeditations = _getFeaturedMeditations();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (_selectedCategory == 'All')
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: _buildFeaturedSlideshow(
              featuredMeditations,
              theme,
              isDarkMode,
            ),
          ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child:
              filteredMeditations.isEmpty
                  ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        'No meditations found in this category.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ),
                  )
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_selectedCategory == 'All')
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: 8.0,
                            top: 16.0,
                          ),
                          child: Text(
                            'All Meditations',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ...filteredMeditations
                          .where(
                            (m) =>
                                !featuredMeditations.contains(m) ||
                                _selectedCategory != 'All',
                          )
                          .map(
                            (meditation) =>
                                _buildMeditationTile(meditation, theme),
                          )
                          .toList(),
                    ],
                  ),
        ),
      ],
    );
  }

  Widget _buildFeaturedSlideshow(
    List<Map<String, dynamic>> featuredMeditations,
    ThemeData theme,
    bool isDarkMode,
  ) {
    if (featuredMeditations.isEmpty) {
      return const SizedBox(height: 10);
    }

    if (_currentFeaturedIndex >= featuredMeditations.length) {
      _currentFeaturedIndex = 0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 230,
          child: PageView.builder(
            controller: _featuredPageController,
            itemCount: featuredMeditations.length,
            onPageChanged: (index) {
              setState(() {
                _currentFeaturedIndex = index;
              });
            },
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 20, left: 4, right: 4),
                child: _buildFeaturedMeditation(
                  featuredMeditations[index],
                  theme,
                  isDarkMode,
                ),
              );
            },
          ),
        ),
        if (featuredMeditations.length > 1)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(featuredMeditations.length, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: _currentFeaturedIndex == index ? 16 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color:
                          _currentFeaturedIndex == index
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primary.withOpacity(0.3),
                    ),
                  );
                }),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFeaturedMeditation(
    Map<String, dynamic> meditation,
    ThemeData theme,
    bool isDarkMode,
  ) {
    final baseGreen = Colors.green.shade700;
    final complementaryGreen = Color.fromARGB(
      baseGreen.alpha,
      (baseGreen.red + 20).clamp(0, 255),
      math.max(baseGreen.green - 40, 0),
      math.min(baseGreen.blue + 60, 255),
    );

    return Hero(
      tag: 'meditation-${meditation['title']}',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: GestureDetector(
          onTap: () => _playMeditation(meditation),
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [baseGreen, complementaryGreen],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              image: DecorationImage(
                image: AssetImage(meditation['image'] as String),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.green.withOpacity(0.4),
                  BlendMode.multiply,
                ),
                onError: (_, __) => const SizedBox(),
              ),
            ),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: RadialGradient(
                      center: const Alignment(-0.8, -0.8),
                      radius: 1.5,
                      colors: [
                        Colors.white.withOpacity(0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: const Text(
                          'Featured',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        meditation['title'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              blurRadius: 3.0,
                              color: Colors.black45,
                              offset: Offset(1.0, 1.0),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        meditation['description'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          shadows: [
                            Shadow(
                              blurRadius: 2.0,
                              color: Colors.black38,
                              offset: Offset(1.0, 1.0),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  meditation['duration'] as String,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              meditation['category'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 24,
                      child: IconButton(
                        icon: const Icon(
                          Icons.play_arrow,
                          color: Colors.green,
                          size: 32,
                        ),
                        onPressed: () => _playMeditation(meditation),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMeditationTile(
    Map<String, dynamic> meditation,
    ThemeData theme,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            meditation['image'] as String,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder:
                (context, error, stackTrace) => Container(
                  width: 60,
                  height: 60,
                  color: theme.colorScheme.tertiary.withOpacity(0.3),
                  child: Icon(Icons.spa, color: theme.colorScheme.primary),
                ),
          ),
        ),
        title: Text(
          meditation['title'] as String,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              meditation['description'] as String,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: theme.textTheme.bodySmall?.color,
                ),
                const SizedBox(width: 4),
                Text(
                  meditation['duration'] as String,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    meditation['category'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: Icon(
            Icons.play_circle_outline,
            color: theme.colorScheme.primary,
            size: 36,
          ),
          onPressed: () => _playMeditation(meditation),
        ),
        onTap: () => _playMeditation(meditation),
      ),
    );
  }

  Widget _buildCategoryFilters(ThemeData theme, bool isDarkMode) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _selectedCategory = category;
                });
              },
              backgroundColor: isDarkMode ? theme.cardColor : Colors.grey[100],
              selectedColor: theme.colorScheme.primary.withOpacity(0.3),
              labelStyle: TextStyle(
                color:
                    isSelected
                        ? (isDarkMode ? Colors.white : Colors.black)
                        : isDarkMode
                        ? theme.textTheme.bodyMedium?.color
                        : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color:
                    isSelected
                        ? theme.colorScheme.primary
                        : Colors.grey.withOpacity(0.3),
                width: 1.5,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              avatar:
                  isSelected
                      ? Icon(
                        Icons.check_circle,
                        size: 18,
                        color: theme.colorScheme.primary.withOpacity(0.9),
                      )
                      : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: isSelected ? 2 : 0,
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }
}
