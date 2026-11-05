import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const MaterialApp(
    home: MainScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

// Layar utama yang menampung navigasi bawah
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  // Menyimpan daftar lagu yang di-like
  List<dynamic> _likedSongs = [];

  // Fungsi untuk menambah atau menghapus lagu dari daftar like
  void _toggleLike(dynamic song) {
    setState(() {
      // Menggunakan trackId untuk mengecek apakah lagu sudah ada di daftar
      bool isAlreadyLiked = _likedSongs.any((s) => s['trackId'] == song['trackId']);

      if (isAlreadyLiked) {
        _likedSongs.removeWhere((s) => s['trackId'] == song['trackId']);
      } else {
        _likedSongs.add(song);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Daftar halaman yang akan ditampilkan berdasarkan tab yang dipilih
    final List<Widget> pages = [
      HomeScreen(likedSongs: _likedSongs, toggleLike: _toggleLike),
      ProfileScreen(likedSongs: _likedSongs),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note),
            label: 'Cari Lagu',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

// Halaman pencarian lagu
class HomeScreen extends StatefulWidget {
  final List<dynamic> likedSongs;
  final Function(dynamic) toggleLike;

  const HomeScreen({super.key, required this.likedSongs, required this.toggleLike});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  List<dynamic> _songs = [];
  bool _isLoading = false;

  Future<void> _carilagu() async {
    if (_controller.text.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.https('itunes.apple.com', '/search', {
        'term': _controller.text,
        'entity': 'song',
        'limit': '15',
      });

      final response = await http.get(url);
      final data = jsonDecode(response.body);

      setState(() {
        _songs = data['results'];
      });
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Player'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Cari Lagu atau Artis',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _carilagu,
                ),
              ),
              onSubmitted: (_) => _carilagu(),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _songs.length,
                  itemBuilder: (context, index) {
                    final song = _songs[index];
                    // Cek apakah lagu ini ada di daftar like
                    bool isLiked = widget.likedSongs.any((s) => s['trackId'] == song['trackId']);

                    return ListTile(
                      leading: song['artworkUrl60'] != null
                          ? Image.network(song['artworkUrl60'])
                          : const Icon(Icons.music_note),
                      title: Text(song['trackName'] ?? 'Unknown Track'),
                      subtitle: Text(song['artistName'] ?? 'Unknown Artist'),
                      trailing: IconButton(
                        icon: Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.red : null,
                        ),
                        onPressed: () => widget.toggleLike(song),
                      ),
                      onTap: () {
                        if (song['previewUrl'] != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PlayerScreen(song: song),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Preview lagu tidak tersedia')),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Halaman baru untuk memutar lagu
class PlayerScreen extends StatefulWidget {
  final dynamic song;
  const PlayerScreen({super.key, required this.song});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _playSong();
  }

  Future<void> _playSong() async {
    await _audioPlayer.play(UrlSource(widget.song['previewUrl']));

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String artworkUrl = widget.song['artworkUrl100'] ?? '';
    artworkUrl = artworkUrl.replaceAll('100x100bb', '300x300bb');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Now Playing'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (artworkUrl.isNotEmpty)
              Image.network(artworkUrl, height: 250, width: 250, fit: BoxFit.cover)
            else
              const Icon(Icons.music_note, size: 250),
            const SizedBox(height: 32),
            Text(
              widget.song['trackName'] ?? 'Unknown Track',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.song['artistName'] ?? 'Unknown Artist',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            IconButton(
              iconSize: 72,
              color: Colors.blue,
              icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
              onPressed: () async {
                if (_isPlaying) {
                  await _audioPlayer.pause();
                } else {
                  await _audioPlayer.resume();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Halaman Profil Sederhana
class ProfileScreen extends StatelessWidget {
  final List<dynamic> likedSongs;

  const ProfileScreen({super.key, required this.likedSongs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Saya'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.account_circle, size: 100, color: Colors.blueGrey),
          const SizedBox(height: 16),
          const Text(
            'Lemuel Yosia Nikodemus',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Email: lemuelomazio@gmail.com',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'Lagu yang Disukai',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: likedSongs.isEmpty
                ? const Center(child: Text('Belum ada lagu yang disukai'))
                : ListView.builder(
              itemCount: likedSongs.length,
              itemBuilder: (context, index) {
                final song = likedSongs[index];
                return ListTile(
                  leading: const Icon(Icons.favorite, color: Colors.red),
                  title: Text(song['trackName'] ?? 'Unknown'),
                  subtitle: Text(song['artistName'] ?? 'Unknown'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}