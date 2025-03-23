import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:stattrak/login_page.dart';
import 'package:stattrak/providers/weather_provider.dart';
import 'package:stattrak/widgets/appbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePage extends StatefulWidget {
  final String? userId;
  final double? initialLat;
  final double? initialLong;

  const ProfilePage({
    Key? key,
    this.userId,
    this.initialLat,
    this.initialLong,
  }) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _avatarUrlController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isLoading = false;
  String? _friendshipStatus;
  double? _latitude;
  double? _longitude;
  List<Map<String, dynamic>> _userPosts = [];

  bool get _isOwnProfile {
    final currentUser = Supabase.instance.client.auth.currentUser;
    return widget.userId == null || widget.userId == currentUser?.id;
  }

  @override
  void initState() {
    super.initState();
    _latitude = widget.initialLat;
    _longitude = widget.initialLong;

    _initData();

    if (_latitude != null && _longitude != null) {
      Future.microtask(() {
        context.read<WeatherProvider>().fetchWeather(_latitude!, _longitude!);
      });
    }
  }

  Future<void> _initData() async {
    await _fetchProfile();
    await _fetchUserPosts();
    await _checkFriendshipStatus();
  }

  Future<void> _fetchProfile() async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    final targetUserId = widget.userId ?? currentUser?.id;

    if (targetUserId == null) return;

    setState(() => _isLoading = true);

    try {
      final row = await supabase
          .from('profiles')
          .select()
          .eq('id', targetUserId)
          .single();

      _usernameController.text = row['username'] ?? '';
      _fullNameController.text = row['full_name'] ?? '';
      _avatarUrlController.text = row['avatar_url'] ?? '';
      _bioController.text = row['bio'] ?? '';
      _latitude = row['lat'];
      _longitude = row['long'];
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchUserPosts() async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    final targetUserId = widget.userId ?? currentUser?.id;

    if (targetUserId == null) return;

    try {
      // Simplified query without the problematic array comparison
      final response = await supabase
          .from('posts')
          .select()
          .eq('user_id', targetUserId)
          .order('created_at', ascending: false);

      setState(() {
        _userPosts = List<Map<String, dynamic>>.from(response);
      });

      // Debug information
      print('Found ${_userPosts.length} posts for user $targetUserId');
    } catch (e) {
      debugPrint('Error fetching user posts: $e');
    }
  }

  Future<void> _checkFriendshipStatus() async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    final targetUserId = widget.userId;

    if (targetUserId == null || currentUser == null) return;

    try {
      final result = await supabase
          .from('user_friendships')
          .select('status')
          .or('and(user_id.eq.${currentUser.id},friend_id.eq.$targetUserId),and(user_id.eq.$targetUserId,friend_id.eq.${currentUser.id})')
          .maybeSingle();

      setState(() {
        _friendshipStatus = result?['status'] ?? 'none';
      });
    } catch (e) {
      debugPrint('Error checking friendship status: $e');
    }
  }

  Future<void> _sendFriendRequest() async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    final targetUserId = widget.userId;

    if (currentUser == null || targetUserId == null) return;

    try {
      await supabase.from('user_friendships').insert({
        'user_id': currentUser.id,
        'friend_id': targetUserId,
        'status': 'pending',
        'updated_at': DateTime.now().toIso8601String(),
      });

      setState(() {
        _friendshipStatus = 'pending';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request sent')),
      );
    } catch (e) {
      debugPrint('Error sending friend request: $e');
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isLoading = true);

    try {
      final fileBytes = await pickedFile.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';

      await supabase.storage
          .from('avatar-url')
          .uploadBinary(fileName, fileBytes, fileOptions: const FileOptions(upsert: false));

      final publicUrl = supabase.storage.from('avatar-url').getPublicUrl(fileName);

      await supabase
          .from('profiles')
          .update({
        'avatar_url': publicUrl,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', user.id);

      setState(() {
        _avatarUrlController.text = publicUrl;
      });
    } catch (e) {
      debugPrint('Error uploading avatar: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;
    });
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LoginPage()),
    );
  }

  Future<void> _updateProfile() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final updates = {
        'username': _usernameController.text,
        'full_name': _fullNameController.text,
        'avatar_url': _avatarUrlController.text,
        'bio': _bioController.text,
        'lat': _latitude,
        'long': _longitude,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await supabase.from('profiles').update(updates).eq('id', user.id);
    } catch (e) {
      debugPrint('Error updating profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyCustomAppBar(
        onGroupPressed: () {},
        onNotificationPressed: () {},
        lat: _latitude,
        long: _longitude,
        avatarUrl: _avatarUrlController.text,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LEFT SIDEBAR
            SizedBox(
              width: 250,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(_avatarUrlController.text),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _fullNameController.text,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (!_isOwnProfile)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.person),
                      label: Text(
                        _friendshipStatus == 'accepted'
                            ? 'Friends'
                            : _friendshipStatus == 'pending'
                            ? 'Request Sent'
                            : 'Add Friend',
                      ),
                      onPressed: _friendshipStatus == 'none' ? _sendFriendRequest : null,
                    ),
                  const SizedBox(height: 16),
                  Text(_bioController.text),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // POSTS SECTION
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Posts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_userPosts.isEmpty)
                    const Text('No posts to show.')
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: _userPosts.length,
                        itemBuilder: (context, index) {
                          final post = _userPosts[index];
                          final dynamic photosData = post['photos'];
                          final List<dynamic> photos = photosData != null ?
                          (photosData is List ? photosData : []) : [];
                          final String content = post['content'] ?? 'No description';
                          final DateTime createdAt = DateTime.parse(post['created_at']);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    content,
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${createdAt.toLocal()}'.split('.')[0],
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  if (photos.isNotEmpty)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 8),
                                        GridView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: photos.length,
                                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 2,
                                            mainAxisSpacing: 8,
                                            crossAxisSpacing: 8,
                                            childAspectRatio: 1.2,
                                          ),
                                          itemBuilder: (context, index) {
                                            return Image.network(photos[index], fit: BoxFit.cover);
                                          },
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // WEATHER
            SizedBox(
              width: 250,
              child: Consumer<WeatherProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (provider.error != null) {
                    return Text('Error: ${provider.error}');
                  } else if (provider.weatherData != null) {
                    final weather = provider.weatherData!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Weather for Today", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.blue.shade50,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.cloud, size: 32),
                              const SizedBox(width: 8),
                              Text('${weather.temperature.toStringAsFixed(1)}°C'),
                            ],
                          ),
                        ),
                      ],
                    );
                  } else {
                    return const Text('Weather data unavailable');
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
