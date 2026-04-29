import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../widgets/animated_heading.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const _kApiUrl = 'https://display.sriher.com/Dashboardview';
const _kApiKey =
    '933cdb13cb54e31e694f82bf7f75f0144a9495036db0243b85dd855be53c06f2';
const _kBaseUrl = 'https://display.sriher.com/uploads/';

// ─── Models ───────────────────────────────────────────────────────────────────

class _DashboardData {
  final int totalDevice;
  final int activeDevice;
  final int totTemp;
  final int totScheTemp;
  final int totLocation;
  final int activeLoc;
  final int imgFile;
  final int vidFile;
  final List<String> imageUrls;
  final List<String> videoUrls;
  final List<Map<String, dynamic>> deviceList;
  final List<Map<String, dynamic>> tempList;
  final List<Map<String, dynamic>> locationList;
  final List<Map<String, dynamic>> overview;

  _DashboardData({
    required this.totalDevice,
    required this.activeDevice,
    required this.totTemp,
    required this.totScheTemp,
    required this.totLocation,
    required this.activeLoc,
    required this.imgFile,
    required this.vidFile,
    required this.imageUrls,
    required this.videoUrls,
    required this.deviceList,
    required this.tempList,
    required this.locationList,
    required this.overview,
  });

  factory _DashboardData.fromJson(Map<String, dynamic> json) {
    final imgs = (json['img'] as List? ?? [])
        .map((e) => '$_kBaseUrl${e['file_name']}')
        .toList();

    final vids = json['vid'] as List?;
    final vidUrls = (vids ?? [])
        .map((e) => '$_kBaseUrl${e['file_name']}')
        .toList();

    // Add vinci videos if any (fallback/additional)
    if (json['vinci'] != null && (json['vinci'] as List).isNotEmpty) {
      vidUrls.addAll(
        (json['vinci'] as List).map((e) => '$_kBaseUrl${e['file_name']}'),
      );
    }

    return _DashboardData(
      totalDevice: json['totaldevice'] ?? 0,
      activeDevice: json['active_device'] ?? 0,
      totTemp: json['tot_temp'] ?? 0,
      totScheTemp: json['tot_sche_temp'] ?? 0,
      totLocation: json['tot_location'] ?? 0,
      activeLoc: json['active_loc'] ?? 0,
      imgFile: json['img_file'] ?? 0,
      vidFile: json['vid_file'] ?? 0,
      imageUrls: imgs,
      videoUrls: vidUrls,
      deviceList: _maps(json['deviceList']),
      tempList: _maps(json['templist']),
      locationList: _maps(json['locationlist']),
      overview: _maps(json['overview']),
    );
  }

  static List<Map<String, dynamic>> _maps(dynamic raw) =>
      (raw as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
}

// ─── Widget ───────────────────────────────────────────────────────────────────

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});
  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _bgAnimController;
  final List<Animation<double>> _cardAnimations = [];

  // API state
  _DashboardData? _data;
  bool _loading = true;
  String? _error;

  // Slideshow
  int _slideIndex = 0;
  Timer? _slideTimer;
  late final PageController _pageCtrl;

  // Video (media_kit)
  late final Player _player = Player(
    configuration: const PlayerConfiguration(
      bufferSize: 1024 * 1024 * 32, // Increased to 32MB buffer
    ),
  );
  late final VideoController _videoController = VideoController(_player);
  bool _videoReady = false;
  bool _hasEverPlayed = true; // Autoplay by default
  bool _showControls = false; // Hide controls by default for signage
  String? _videoError; // non-null when init failed
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _bufferingSub;
  StreamSubscription? _errorSub;
  Timer? _videoReadyTimer;

  // Bottom table
  String _selectedCategory = 'Devices';
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  int _entriesPerPage = 10;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    for (int i = 0; i < 8; i++) {
      final s = i * 0.08;
      final e = (s + 0.4).clamp(0.0, 1.0);
      _cardAnimations.add(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(s, e, curve: Curves.easeOutBack),
        ),
      );
    }
    _controller.forward();
    _pageCtrl = PageController(initialPage: 5000);
    _fetchDashboard();
  }

  // ──────────────────── API ─────────────────────────────────────────────────

  Future<void> _fetchDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http.post(
        Uri.parse(_kApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'api_key': _kApiKey}),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['status'] == 'Success') {
          final d = _DashboardData.fromJson(body['data']);
          setState(() {
            _data = d;
            _loading = false;
          });
          _startSlideshow(d.imageUrls.length);
          _initVideo(d.videoUrls);
          return;
        }
      }
      setState(() {
        _loading = false;
        _error = 'Server error';
      });
    } catch (ex) {
      setState(() {
        _loading = false;
        _error = ex.toString();
      });
    }
  }

  void _startSlideshow(int count) {
    _slideTimer?.cancel();
    if (count == 0) return;
    _slideTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if (_pageCtrl.hasClients) {
        final next = _pageCtrl.page!.round() + 1;
        _pageCtrl.animateToPage(
          next,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        setState(() => _slideIndex = next % count);
      }
    });
  }

  void _initVideo(List<String> urls) {
    if (urls.isEmpty) return;
    setState(() {
      _videoReady = false;
      _hasEverPlayed = false;
      _videoError = null;
    });

    try {
      // Cancel any previous subscriptions / timers
      _durationSub?.cancel();
      _bufferingSub?.cancel();
      _videoReadyTimer?.cancel();
      _errorSub?.cancel();

      _errorSub = _player.stream.error.listen((err) {
        debugPrint('MediaKit Error: $err');
        if (mounted) {
          setState(() => _videoError = err.toString());
        }
      });

      // Open a playlist for the slideshow
      final playlist = Playlist(urls.map((u) => Media(u)).toList());

      // Set performance properties for smooth streaming and caching
      if (_player.platform is NativePlayer) {
        final platform = _player.platform as NativePlayer;
        platform.setProperty(
          'hwdec',
          'no',
        ); // Fallback to software decoding if CUDA fails
        platform.setProperty('cache', 'yes');
        platform.setProperty('demuxer-max-bytes', '32000000');
        platform.setProperty('demuxer-max-back-bytes', '32000000');
        platform.setProperty('cache-secs', '15');
      }

      _player.open(playlist, play: true);
      _hasEverPlayed = true;
      _player.setPlaylistMode(PlaylistMode.loop);
      _player.setVolume(0.0);

      // Mark ready immediately so the Video widget renders right away.
      // media_kit renders black until the first frame arrives — that is
      // fine; we no longer block behind a _videoReady flag which was
      // unreliable on Linux (stream events sometimes never fired).
      setState(() => _videoReady = true);
    } catch (err) {
      debugPrint('Video init error: $err');
      setState(() => _videoError = err.toString());
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _bufferingSub?.cancel();
    _errorSub?.cancel();
    _videoReadyTimer?.cancel();
    _searchController.dispose();
    _controller.dispose();
    _slideTimer?.cancel();
    _pageCtrl.dispose();
    _player.dispose();
    _bgAnimController.dispose();
    super.dispose();
  }

  // ──────────────────── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        color: Colors.white,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.orange),
              const SizedBox(height: 14),
              const Text(
                'Loading Dashboard…',
                style: TextStyle(
                  color: Color(0xFF9E9E9E),
                  fontSize: 14.0,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return Container(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, color: Colors.redAccent, size: 48),
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFF757575),
                  fontSize: 14.0,
                  fontWeight: FontWeight.normal,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchDashboard,
                icon: const Icon(Icons.refresh),
                label: const Text(
                  'Retry',
                  style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final d = _data!;
    return AnimatedBuilder(
      animation: _bgAnimController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            gradient: LinearGradient(
              begin: Alignment(
                0.0,
                -1.0 + (_bgAnimController.value * 0.1),
              ), // Moving subtle gradient
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFE3F2FD), // Light blue mix animated
                Colors.white,
              ],
              stops: const [0.0, 0.4],
            ),
          ),
          child: child,
        );
      },
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _topCards(d),
            const SizedBox(height: 16),
            _midSection(d),
            const SizedBox(height: 28),
            _bottomSection(d),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ──────────────────── Top cards ───────────────────────────────────────────

  Widget _topCards(_DashboardData d) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 950;
        final List<Widget> cards = [
          _menuCard(
            'DEVICE DETAILS',
            Icons.tv,
            '${d.activeDevice} / ${d.totalDevice}',
            const Color.fromARGB(255, 228, 210, 18),
            const Color.fromARGB(255, 245, 212, 48),
            _cardAnimations[0],
          ),
          _menuCard(
            'TEMPLATE DETAILS',
            Icons.dashboard_customize,
            '${d.totScheTemp} / ${d.totTemp}',
            const Color.fromARGB(255, 71, 148, 204), // Card background (Light-Medium Blue)
            const Color.fromARGB(255, 126, 184, 224), // Border accent
            _cardAnimations[1],
            iconContainerColor: const Color(0xFFE3F2FD), // Outer part of icon is light blue
            iconInnerColor: const Color(0xFF0D47A1), // Inside square icon is Dark Blue
          ),
          _menuCard(
            'LOCATION',
            Icons.location_on,
            '${d.activeLoc} / ${d.totLocation}',
            const Color.fromARGB(255, 42, 170, 53),
            const Color(0xFF43A047),
            _cardAnimations[2],
          ),
          _menuCard(
            'FILES',
            Icons.insert_drive_file,
            '${d.imgFile}',
            const Color(0xFFBA68C8),
            const Color(0xFFCE93D8),
            _cardAnimations[3],
          ),
        ];

        return Padding(
          padding: const EdgeInsets.all(12),
          child: isNarrow
              ? Column(
                  children: [
                    Row(children: [cards[0], cards[1]]),
                    const SizedBox(height: 10),
                    Row(children: [cards[2], cards[3]]),
                  ],
                )
              : Row(children: cards),
        );
      },
    );
  }

  Widget _menuCard(
    String title,
    IconData icon,
    String count,
    Color bgColor,
    Color accentColor,
    Animation<double> anim, {
    Color? iconContainerColor,
    Color? iconInnerColor,
  }) {
    return Expanded(
      child: ScaleTransition(
        scale: anim,
        child: Container(
          height: 85,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: bgColor, // Switched to specific light background
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accentColor.withOpacity(0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.0,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        count,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconContainerColor ?? Colors.white.withOpacity(0.8), // Bright container behind logo
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconInnerColor ?? accentColor, size: 24),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────── Mid section ─────────────────────────────────────────

  Widget _midSection(_DashboardData d) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 950;
        final left = ScaleTransition(
          scale: _cardAnimations[4],
          child: _card(child: _slideshow(d.imageUrls), height: 420),
        );
        final right = ScaleTransition(
          scale: _cardAnimations[5],
          child: _card(child: _videoPanel(d.videoUrls), height: 420),
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: isNarrow
              ? Column(children: [left, const SizedBox(height: 20), right])
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: left),
                    const SizedBox(width: 20),
                    Expanded(child: right),
                  ],
                ),
        );
      },
    );
  }

  // Bare white card container
  Widget _card({required Widget child, double? height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  // ── Slideshow ─────────────────────────────────────────────────────────────

  Widget _slideshow(List<String> urls) {
    if (urls.isEmpty) {
      return const Center(
        child: Text('No images', style: TextStyle(color: Colors.grey)),
      );
    }
    return Stack(
      children: [
        // Pages — 5 px padding on all sides
        PageView.builder(
          controller: _pageCtrl,
          onPageChanged: (i) => setState(() => _slideIndex = i % urls.length),
          itemCount: 10000,
          itemBuilder: (_, i) {
            final index = i % urls.length;
            return Padding(
              padding: const EdgeInsets.all(5),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  urls[index],
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: Colors.grey.shade100,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade100,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.grey.shade400,
                      size: 40,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        // Prev arrow
        Positioned(
          left: 6,
          top: 0,
          bottom: 0,
          child: Center(
            child: _arrowBtn(
              icon: Icons.chevron_left,
              onTap: () {
                final p = _pageCtrl.page!.round() - 1;
                _pageCtrl.animateToPage(
                  p,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              },
            ),
          ),
        ),
        // Next arrow
        Positioned(
          right: 6,
          top: 0,
          bottom: 0,
          child: Center(
            child: _arrowBtn(
              icon: Icons.chevron_right,
              onTap: () {
                final n = (_slideIndex + 1) % urls.length;
                _pageCtrl.animateToPage(
                  n,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              },
            ),
          ),
        ),
        // Dot indicators
        Positioned(
          bottom: 10,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              urls.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: i == _slideIndex ? 16 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: i == _slideIndex ? Colors.orange : Colors.white70,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _arrowBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black38,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  // ── Video panel ───────────────────────────────────────────────────────────

  Widget _videoPanel(List<String> urls) {
    if (urls.isEmpty) {
      return _videoPanelPlaceholder(null, 'No videos integrated');
    }

    // Error state — show message with retry button
    if (_videoError != null) {
      return _videoPanelPlaceholder(
        urls.isNotEmpty ? urls.first : null,
        'Video Error: $_videoError',
        showRetry: true,
        onRetry: () => _initVideo(urls),
      );
    }

    // Always show the Video widget — media_kit renders black until the
    // first frame arrives which is fine (no more blank-screen gate).
    // A thin buffering indicator is shown via StreamBuilder overlay.
    return StreamBuilder<bool>(
      stream: _player.stream.buffering,
      builder: (context, bufSnap) {
        final isBuffering = bufSnap.data ?? true;
        return StreamBuilder<bool>(
          stream: _player.stream.playing,
          builder: (context, playingSnap) {
            final isPlaying = playingSnap.data ?? false;
            return StreamBuilder<Duration>(
              stream: _player.stream.position,
              builder: (context, positionSnap) {
                final position = positionSnap.data ?? Duration.zero;

                return StreamBuilder<Duration>(
                  stream: _player.stream.duration,
                  builder: (context, durationSnap) {
                    final duration = durationSnap.data ?? Duration.zero;

                    return StreamBuilder<double>(
                      stream: _player.stream.volume,
                      builder: (context, volumeSnap) {
                        final volume = volumeSnap.data ?? 100.0;
                        final isMuted = volume == 0.0;
                        final progress = duration.inMilliseconds > 0
                            ? (position.inMilliseconds /
                                      duration.inMilliseconds)
                                  .clamp(0.0, 1.0)
                            : 0.0;

                        return GestureDetector(
                          onTap: () {
                            setState(() => _showControls = !_showControls);
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              children: [
                                // ── Video frame (rendered by media_kit) ──
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.black,
                                    child: Video(
                                      controller: _videoController,
                                      controls: NoVideoControls,
                                      fill: Colors.black,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),

                                // ── Buffering spinner overlay ──
                                if (isBuffering)
                                  const Positioned.fill(
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.orange,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),

                                // ── Gradient overlay (when controls visible) ──
                                if (_showControls)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.transparent,
                                            Colors.black54,
                                          ],
                                          stops: [0.0, 0.5, 1.0],
                                        ),
                                      ),
                                    ),
                                  ),

                                // ── Big centered Play/Pause (only while controls showing) ──
                                if (_showControls)
                                  Center(
                                    child: GestureDetector(
                                      onTap: () => _player.playOrPause(),
                                      child: Container(
                                        padding: const EdgeInsets.all(18),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.55),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white54,
                                            width: 2,
                                          ),
                                        ),
                                        child: Icon(
                                          isPlaying
                                              ? Icons.pause
                                              : Icons.play_arrow,
                                          color: Colors.white,
                                          size: 42,
                                        ),
                                      ),
                                    ),
                                  ),

                                // ── Bottom control bar (only while playing & controls showing) ──
                                if (_hasEverPlayed && _showControls)
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      color: Colors.black54,
                                      padding: const EdgeInsets.fromLTRB(
                                        8,
                                        4,
                                        8,
                                        6,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Scrub slider
                                          SliderTheme(
                                            data: SliderTheme.of(context).copyWith(
                                              trackHeight: 3,
                                              thumbShape:
                                                  const RoundSliderThumbShape(
                                                    enabledThumbRadius: 6,
                                                  ),
                                              overlayShape:
                                                  const RoundSliderOverlayShape(
                                                    overlayRadius: 10,
                                                  ),
                                              activeTrackColor: Colors.orange,
                                              inactiveTrackColor:
                                                  Colors.white30,
                                              thumbColor: Colors.orange,
                                            ),
                                            child: Slider(
                                              value: progress.toDouble(),
                                              onChanged: (v) {
                                                _player.seek(
                                                  Duration(
                                                    milliseconds:
                                                        (v *
                                                                duration
                                                                    .inMilliseconds)
                                                            .toInt(),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          // Time row
                                          Row(
                                            children: [
                                              GestureDetector(
                                                onTap: () =>
                                                    _player.playOrPause(),
                                                child: Icon(
                                                  isPlaying
                                                      ? Icons.pause
                                                      : Icons.play_arrow,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${_formatDuration(position)} / ${_formatDuration(duration)}',
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 10,
                                                ),
                                              ),
                                              const Spacer(),
                                              GestureDetector(
                                                onTap: () => _player.setVolume(
                                                  isMuted ? 100.0 : 0.0,
                                                ),
                                                child: Icon(
                                                  isMuted
                                                      ? Icons.volume_off
                                                      : Icons.volume_up,
                                                  color: Colors.white70,
                                                  size: 18,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _videoPanelPlaceholder(
    String? url,
    String message, {
    bool showRetry = false,
    VoidCallback? onRetry,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        color: Colors.black87,
        padding: const EdgeInsets.all(5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.ondemand_video_rounded,
              color: Colors.white54,
              size: 48,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            if (url != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  url.split('/').last,
                  style: const TextStyle(color: Colors.orange, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            if (showRetry && onRetry != null) ...[
              const SizedBox(height: 14),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry', style: TextStyle(fontSize: 12)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ──────────────────── Bottom section ──────────────────────────────────────

  Widget _bottomSection(_DashboardData d) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 950;
        final leftCol = Column(
          children: [
            ScaleTransition(
              scale: _cardAnimations[6],
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      const AnimatedHeading(
                        text: 'Progress Track',
                        style: TextStyle(
                          color: Color(0xFF2196F3),
                          fontWeight: FontWeight.bold,
                          fontSize: 16.0,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Divider(color: Colors.grey.shade100),
                      _categoryRow(
                        Icons.tv,
                        Colors.orange,
                        'Devices',
                        d.deviceList.length,
                      ),
                      _categoryRow(
                        Icons.dashboard_customize,
                        Colors.blue,
                        'Templates',
                        d.tempList.length,
                      ),
                      _categoryRow(
                        Icons.location_on,
                        Colors.green,
                        'Locations',
                        d.locationList.length,
                      ),
                      _categoryRow(
                        Icons.view_quilt,
                        Colors.purple,
                        'Over Views',
                        d.overview.length,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(top: 12, left: 4),
                child: Text(
                  '© 2026 SRIHER Display',
                  style: TextStyle(
                    color: Color(0x8AFFFFFF),
                    fontSize: 11.0,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
            ),
          ],
        );

        final rightCol = Column(
          children: [
            Row(
              children: [
                const Text(
                  "Show ",
                  style: TextStyle(
                    color: Color(0xDD000000),
                    fontSize: 13.0,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _entriesPerPage,
                      dropdownColor: Colors.white,
                      isDense: true,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 12,
                      ),
                      items: [5, 10, 20, 50].map((int value) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text(value.toString()),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _entriesPerPage = val;
                            _currentPage = 1;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const Text(
                  " entries",
                  style: TextStyle(
                    color: Color(0xDD000000),
                    fontSize: 13.0,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
            ScaleTransition(
              scale: _cardAnimations[7],
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [_tableHeader(), _tableBody(d), _tableFooter(d)],
                ),
              ),
            ),
          ],
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: isNarrow
              ? Column(
                  children: [leftCol, const SizedBox(height: 20), rightCol],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 1, child: leftCol),
                    const SizedBox(width: 20),
                    Expanded(flex: 4, child: rightCol),
                  ],
                ),
        );
      },
    );
  }

  Widget _categoryBtn(String label, IconData icon, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () {
          _searchController.clear();
          setState(() {
            _selectedCategory = label;
            _currentPage = 1; // Reset to page 1 on category change
            _searchQuery = "";
            _searchController.clear();
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.white10,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const Spacer(),
              if (isSelected)
                const Icon(Icons.check_circle, color: Colors.white, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryRow(IconData icon, Color color, String label, int count) {
    final bool sel = _selectedCategory == label;
    final double progress = count > 0 ? (count / 12).clamp(0.0, 1.0) : 0.0;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        _searchController.clear();
        setState(() {
          _selectedCategory = label;
          _searchQuery = "";
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: sel ? color.withValues(alpha: 0.07) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: color, size: 15),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.0,
                    color: const Color(0xDD000000),
                    fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 11.0,
                    color: Color(0x8A000000),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  color: sel ? color : Colors.grey.shade400,
                  size: 11,
                ),
              ],
            ),
            const SizedBox(height: 5),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: progress),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: LinearProgressIndicator(
                  value: v,
                  backgroundColor: color.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Table header / body ───────────────────────────────────────────────────

  List<String> get _headers {
    switch (_selectedCategory) {
      case 'Devices':
        return ['Device Name', 'Device Code', 'Model'];
      case 'Templates':
        return ['Template Name', 'Duration'];
      case 'Locations':
        return ['Location', 'Floor', 'Sub Location'];
      case 'Over Views':
        return ['Device', 'Schedule', 'Template', 'Duration', 'Location'];
      default:
        return [];
    }
  }

  List<List<String>> _rows(_DashboardData d) {
    List<List<String>> allRows = [];
    switch (_selectedCategory) {
      case 'Devices':
        allRows = d.deviceList
            .map(
              (e) => [
                (e['device_name'] ?? '-').toString(),
                (e['device_code'] ?? '-').toString(),
                (e['device_model'] ?? '-').toString(),
              ],
            )
            .toList();
        break;
      case 'Templates':
        allRows = d.tempList
            .map(
              (e) => [
                (e['temp_name'] ?? '-').toString(),
                (e['duration'] ?? '-').toString(),
              ],
            )
            .toList();
        break;
      case 'Locations':
        allRows = d.locationList
            .map(
              (e) => [
                (e['location_name'] ?? '-').toString(),
                (e['floor'] ?? '-').toString(),
                (e['sublocation'] ?? '-').toString(),
              ],
            )
            .toList();
        break;
      case 'Over Views':
        if (d.overview.isEmpty) break;
        allRows = d.overview
            .map(
              (e) => [
                (e['device_name'] ?? '-').toString(),
                (e['schedule_name'] ?? '-').toString(),
                (e['template_name'] ?? '-').toString(),
                (e['template_duration'] ?? '-').toString(),
                (e['location_name'] ?? '-').toString(),
              ],
            )
            .toList();
        break;
    }

    if (_searchQuery.isEmpty) return allRows;
    return allRows.where((row) {
      return row.any(
        (cell) => cell.toLowerCase().contains(_searchQuery.toLowerCase()),
      );
    }).toList();
  }

  Widget _tableHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(bottom: BorderSide(color: Colors.blue.shade100)),
      ),
      child: Row(
        children: _headers
            .map(
              (h) => Expanded(
                child: Text(
                  h,
                  style: TextStyle(
                    color: const Color(0xFF1565C0),
                    fontWeight: FontWeight.bold,
                    fontSize: 11.0,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _tableBody(_DashboardData d) {
    final allRows = _rows(d);
    if (allRows.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_rounded, color: Colors.grey.shade300, size: 40),
              const SizedBox(height: 10),
              Text(
                'No data for $_selectedCategory',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final startIndex = (_currentPage - 1) * _entriesPerPage;
    final endIndex = (startIndex + _entriesPerPage).clamp(0, allRows.length);
    final rows = allRows.sublist(startIndex, endIndex);

    return SizedBox(
      height: 350,
      child: SingleChildScrollView(
        child: Column(
          children: List.generate(rows.length, (i) {
            return Container(
              decoration: BoxDecoration(
                color: i.isEven ? Colors.grey.shade50 : Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                children: rows[i]
                    .map(
                      (cell) => Expanded(
                        child: Text(
                          cell,
                          style: const TextStyle(
                            color: Color(0xDD000000),
                            fontSize: 12.0,
                            fontWeight: FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _tableFooter(_DashboardData d) {
    final allRows = _rows(d);
    final total = allRows.length;
    final start = total == 0 ? 0 : (_currentPage - 1) * _entriesPerPage + 1;
    final end = (_currentPage * _entriesPerPage).clamp(0, total);
    final totalPages = (total / _entriesPerPage).ceil();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Showing $start to $end of $total entries",
            style: const TextStyle(
              color: Color(0x8A000000),
              fontSize: 12.0,
              fontWeight: FontWeight.normal,
            ),
          ),
          Row(
            children: [
              _pageBtn("Prev", _currentPage > 1, () {
                setState(() => _currentPage--);
              }),
              ...List.generate(totalPages, (i) {
                final page = i + 1;
                if (totalPages > 5) {
                  if (page == 1 ||
                      page == totalPages ||
                      (page >= _currentPage - 1 && page <= _currentPage + 1)) {
                    return _pageBtn(
                      page.toString(),
                      true,
                      () => setState(() => _currentPage = page),
                      active: page == _currentPage,
                    );
                  }
                  if (page == 2 || page == totalPages - 1) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        "...",
                        style: TextStyle(color: Colors.black38),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }
                return _pageBtn(
                  page.toString(),
                  true,
                  () => setState(() => _currentPage = page),
                  active: page == _currentPage,
                );
              }),
              _pageBtn("Next", _currentPage < totalPages, () {
                setState(() => _currentPage++);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pageBtn(
    String label,
    bool enabled,
    VoidCallback onTap, {
    bool active = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? Colors.blue
                : (enabled ? Colors.grey.shade100 : Colors.grey.shade50),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: active ? Colors.blue : Colors.grey.shade300,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active
                  ? Colors.white
                  : (enabled
                        ? const Color(0xDD000000)
                        : const Color(0x42000000)),
              fontSize: 12.0,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
