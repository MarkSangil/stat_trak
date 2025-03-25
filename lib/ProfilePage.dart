import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stattrak/EditProfilePage.dart';
import 'package:stattrak/login_page.dart';
import 'package:stattrak/providers/weather_provider.dart';
import 'package:stattrak/widgets/appbar.dart';
import 'package:stattrak/youtube_player_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';


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

  // New controllers for YouTube links
  final _youtubeLink1Controller = TextEditingController();
  final _youtubeLink2Controller = TextEditingController();
  final _youtubeLink3Controller = TextEditingController();

  bool _isLoading = false;
  String? _friendshipStatus;
  double? _latitude;
  double? _longitude;
  List<Map<String, dynamic>> _userPosts = [];

  // List to store featured photos
  List<String> _featuredPhotos = [];
  final int _maxFeaturedPhotos = 4;

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

      // Load YouTube links
      _youtubeLink1Controller.text = row['youtube_link1'] ?? '';
      _youtubeLink2Controller.text = row['youtube_link2'] ?? '';
      _youtubeLink3Controller.text = row['youtube_link3'] ?? '';

      // Load featured photos
      final featuredPhotosData = row['featured_photos'];
      if (featuredPhotosData != null && featuredPhotosData is List) {
        _featuredPhotos = List<String>.from(featuredPhotosData);
      }
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
      // Fetch posts with post_likes data
      final response = await supabase
          .from('posts')
          .select('''
            *,
            profiles:profiles!user_id(id, full_name, avatar_url, username),
            post_likes(user_id)
          ''')
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

  Future<void> _likePost(String postId) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    try {
      await Supabase.instance.client.from('post_likes').insert({
        'user_id': currentUser.id,
        'post_id': postId,
      });

      // Refresh posts to update the likes
      await _fetchUserPosts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to like post: $e")),
      );
    }
  }

  Future<void> _unlikePost(String postId) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    try {
      await Supabase.instance.client
          .from('post_likes')
          .delete()
          .eq('user_id', currentUser.id)
          .eq('post_id', postId);

      // Refresh posts to update the likes
      await _fetchUserPosts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to unlike post: $e")),
      );
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

  void _showEditProfileDialog() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfilePage(
          avatarUrl: _avatarUrlController.text,
          username: _usernameController.text,
          fullName: _fullNameController.text,
          bio: _bioController.text,
          youtubeLink1: _youtubeLink1Controller.text,
          youtubeLink2: _youtubeLink2Controller.text,
          youtubeLink3: _youtubeLink3Controller.text,
          featuredPhotos: _featuredPhotos,
          latitude: _latitude,
          longitude: _longitude,
        ),
      ),
    );

    // If result is not null, update the profile data
    if (result != null && mounted) {
      setState(() {
        _avatarUrlController.text = result['avatar_url'] ?? _avatarUrlController.text;
        _usernameController.text = result['username'] ?? _usernameController.text;
        _fullNameController.text = result['full_name'] ?? _fullNameController.text;
        _bioController.text = result['bio'] ?? _bioController.text;
        _youtubeLink1Controller.text = result['youtube_link1'] ?? _youtubeLink1Controller.text;
        _youtubeLink2Controller.text = result['youtube_link2'] ?? _youtubeLink2Controller.text;
        _youtubeLink3Controller.text = result['youtube_link3'] ?? _youtubeLink3Controller.text;

        if (result['featured_photos'] != null) {
          _featuredPhotos = List<String>.from(result['featured_photos']);
        }
      });
    }
  }

  Widget _buildFeaturedPhotosEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _featuredPhotos.length < _maxFeaturedPhotos
                ? _featuredPhotos.length + 1
                : _featuredPhotos.length,
            itemBuilder: (context, index) {
              if (index == _featuredPhotos.length && _featuredPhotos.length < _maxFeaturedPhotos) {
                // Add new photo tile
                return InkWell(
                  onTap: _pickAndUploadFeaturedPhoto,
                  child: Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(Icons.add_photo_alternate, size: 40),
                    ),
                  ),
                );
              } else {
                // Existing photo tile
                return Stack(
                  children: [
                    Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(_featuredPhotos[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _featuredPhotos.removeAt(index);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Future<void> _pickAndUploadFeaturedPhoto() async {
    if (_featuredPhotos.length >= _maxFeaturedPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 4 featured photos allowed')),
      );
      return;
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isLoading = true);

    try {
      final fileBytes = await pickedFile.readAsBytes();
      final fileName = 'featured_${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';

      await supabase.storage
          .from('featured-photos')
          .uploadBinary(fileName, fileBytes, fileOptions: const FileOptions(upsert: false));

      final publicUrl = supabase.storage.from('featured-photos').getPublicUrl(fileName);

      setState(() {
        _featuredPhotos.add(publicUrl);
      });
    } catch (e) {
      debugPrint('Error uploading featured photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading photo: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
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
        // Add YouTube links
        'youtube_link1': _youtubeLink1Controller.text,
        'youtube_link2': _youtubeLink2Controller.text,
        'youtube_link3': _youtubeLink3Controller.text,
        // Add featured photos
        'featured_photos': _featuredPhotos,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await supabase.from('profiles').update(updates).eq('id', user.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      debugPrint('Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Function to open YouTube links
  Future<void> _launchYouTubeUrl(String url) async {
    if (url.isEmpty) return;

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch URL')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;

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
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    if (_isOwnProfile) ...[
                      ElevatedButton.icon(
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Profile'),
                        onPressed: _showEditProfileDialog,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.logout),
                        label: const Text('Logout'),
                        onPressed: _logout,
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(_bioController.text),

                    if (_featuredPhotos.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Featured Photos',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _featuredPhotos.length,
                          itemBuilder: (context, index) {
                            return Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: NetworkImage(_featuredPhotos[index]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    if (_youtubeLink1Controller.text.isNotEmpty ||
                        _youtubeLink2Controller.text.isNotEmpty ||
                        _youtubeLink3Controller.text.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'YouTube Links',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (_youtubeLink1Controller.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: YouTubeVideoPlayer(url: _youtubeLink1Controller.text),
                        ),
                      if (_youtubeLink2Controller.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: YouTubeVideoPlayer(url: _youtubeLink2Controller.text),
                        ),
                      if (_youtubeLink3Controller.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: YouTubeVideoPlayer(url: _youtubeLink3Controller.text),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),

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
                          final String postId = post['id'];

                          // Get likes data
                          final List<dynamic> likes = post['post_likes'] ?? [];
                          final bool hasLiked = currentUser != null ?
                          likes.any((like) => like['user_id'] == currentUser.id) : false;

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
                                  const SizedBox(height: 8),
                                  // Like button and count
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          hasLiked ? Icons.favorite : Icons.favorite_border,
                                          color: _isOwnProfile ? Colors.grey : Colors.red,
                                        ),
                                        onPressed: (currentUser != null && !_isOwnProfile) ? () {
                                          if (hasLiked) {
                                            _unlikePost(postId);
                                          } else {
                                            _likePost(postId);
                                          }
                                        } : null,
                                      ),
                                      Text("${likes.length} likes")
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