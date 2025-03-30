import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stattrak/widgets/appbar.dart'; // Your custom MyCustomAppBar
import 'package:stattrak/providers/weather_provider.dart';
import 'package:stattrak/utils/responsive_layout.dart';

class GroupPage extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String groupImageUrl;

  const GroupPage({
    Key? key,
    required this.groupId,
    required this.groupName,
    required this.groupImageUrl,
  }) : super(key: key);

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  bool _isMember = false;
  bool _checkedAccess = false;
  final userId = Supabase.instance.client.auth.currentUser?.id;
  final TextEditingController _postController = TextEditingController();
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _checkMembership();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final result = await Supabase.instance.client
        .from('profiles')
        .select('avatar_url')
        .eq('id', userId!)
        .maybeSingle();

    if (result != null && mounted) {
      setState(() {
        _avatarUrl = result['avatar_url'];
      });
    }
  }

  Future<void> _createPost() async {
    final content = _postController.text.trim();
    if (content.isEmpty || userId == null) return;

    try {
      await Supabase.instance.client.from('posts').insert({
        'user_id': userId,
        'group_id': widget.groupId,
        'content': content,
      });

      _postController.clear();
      setState(() {}); // re-fetch posts
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to post: $e")),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _fetchGroupPosts() async {
    final response = await Supabase.instance.client
        .from('posts')
        .select('''
          id, content, created_at, user_id,
          profiles:profiles!user_id(id, full_name, avatar_url, username),
          post_likes(user_id)
        ''')
        .eq('group_id', widget.groupId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _checkMembership() async {
    if (userId == null) {
      _denyAccess("You must be logged in.");
      return;
    }

    final result = await Supabase.instance.client
        .from('group_members')
        .select('id')
        .eq('group_id', widget.groupId)
        .eq('user_id', userId!)
        .maybeSingle();

    if (result == null) {
      _denyAccess("You are not a member of this group.");
    } else {
      setState(() {
        _isMember = true;
        _checkedAccess = true;
      });
    }
  }

  void _denyAccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    Navigator.pop(context);
  }

  Future<void> _likePost(String postId) async {
    await Supabase.instance.client.from('post_likes').insert({
      'user_id': userId,
      'post_id': postId,
    });
    setState(() {});
  }

  Future<void> _unlikePost(String postId) async {
    await Supabase.instance.client
        .from('post_likes')
        .delete()
        .eq('user_id', userId!)
        .eq('post_id', postId);
    setState(() {});
  }

  void _toggleMembership() async {
    if (!_isMember) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Leave Group"),
        content: const Text("Are you sure you want to leave this group?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Leave")),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('group_members')
            .delete()
            .eq('group_id', widget.groupId)
            .eq('user_id', userId!);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have left the group.')),
        );
        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to leave group: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checkedAccess) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      // Keep your custom app bar
      appBar: MyCustomAppBar(
        onNotificationPressed: () {},
        onGroupPressed: () {},
        avatarUrl: _avatarUrl,
      ),
      body: ResponsiveLayout(
        mobileLayout: _buildMobileLayout(),
        tabletLayout: _buildTabletLayout(),
        desktopLayout: _buildDesktopLayout(),
      ),
    );
  }

  // ===================== LAYOUTS =====================

  // Desktop layout - full three-column layout
  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left sidebar with group info
        _buildLeftSidebar(),

        // Center feed
        Expanded(child: _buildContentFeed()),

        // Right sidebar with weather and members
        _buildRightSidebar(),
      ],
    );
  }

  // Tablet layout - two columns (feed and combined sidebar)
  Widget _buildTabletLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Feed takes most of the space
        Expanded(
          flex: 2,
          child: _buildContentFeed(),
        ),

        // Combined sidebar (group info + members + weather in one column)
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildGroupInfoSection(),
                _buildWeatherWidget(),
                _buildMembersSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Mobile layout - stacked vertically
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // We’ll leave the top image to the _buildContentFeed for consistency,
          // but you could also place the back button here if you wanted.

          // Actually build the feed (which has the back button on the image).
          _buildContentFeed(),

          // On mobile, let's place the members section at the bottom
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "MEMBERS",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _buildMembersList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===================== COMMON WIDGETS =====================

  // Main content feed
  Widget _buildContentFeed() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Wrap the group cover image in a Stack so we can position the back button on top
          Stack(
            children: [
              Container(
                height: 200,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(widget.groupImageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // Positioned back button on top of the group image
              Positioned(
                top: 16,
                left: 16,
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Post creation widget
          if (_isMember) _buildPostCreationWidget(),

          // Posts feed
          _buildPostsFeed(),
        ],
      ),
    );
  }

  // Post creation widget
  Widget _buildPostCreationWidget() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Create a post", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _postController,
            decoration: const InputDecoration(
              hintText: "What's on your mind?",
              border: OutlineInputBorder(),
            ),
            maxLines: null,
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _createPost,
            child: const Text("Post"),
          ),
        ],
      ),
    );
  }

  // Posts feed
  Widget _buildPostsFeed() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchGroupPosts(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final posts = snapshot.data!;
        if (posts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20.0),
            child: Center(child: Text("No posts yet.")),
          );
        }

        return Column(
          children: posts.map((post) {
            final profile = post['profiles'] ?? {};
            final fullName = profile['full_name'] ?? 'Unknown';
            final username = profile['username'] ?? '';
            final avatarUrl = profile['avatar_url'] ?? 'https://via.placeholder.com/80';
            final postId = post['id'];
            final content = post['content'];
            final createdAt = post['created_at'];
            final postUserId = post['user_id'];
            final likes = post['post_likes'] ?? [];
            final hasLiked = likes.any((like) => like['user_id'] == userId);

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: CircleAvatar(backgroundImage: NetworkImage(avatarUrl)),
                title: Text(fullName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (username.isNotEmpty)
                      Text('@$username',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(content),
                    ),
                    Text(createdAt, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Row(
                      children: [
                        if (postUserId != userId)
                          IconButton(
                            icon: Icon(
                              hasLiked ? Icons.favorite : Icons.favorite_border,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              if (hasLiked) {
                                _unlikePost(postId);
                              } else {
                                _likePost(postId);
                              }
                            },
                          ),
                        Text("${likes.length} likes")
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // Left sidebar with group info
  Widget _buildLeftSidebar() {
    return Container(
      width: 250,
      color: Colors.grey[100],
      padding: const EdgeInsets.all(16),
      child: _buildGroupInfoSection(),
    );
  }

  // Group info section (profile image, name, leave button)
  Widget _buildGroupInfoSection() {
    return Column(
      children: [
        CircleAvatar(
          radius: 48,
          backgroundImage: NetworkImage(widget.groupImageUrl),
          backgroundColor: Colors.grey[300],
        ),
        const SizedBox(height: 16),
        Text(
          widget.groupName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _toggleMembership,
          icon: const Icon(Icons.logout),
          label: const Text("Leave"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Colors.black12),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ],
    );
  }

  // Right sidebar with weather and members
  Widget _buildRightSidebar() {
    return Container(
      width: 300,
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Weather widget
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildWeatherWidget(),
          ),
          // Members section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildMembersSection(),
            ),
          ),
        ],
      ),
    );
  }

  // Weather widget for desktop/tablet
  Widget _buildWeatherWidget() {
    final weather = context.watch<WeatherProvider>();

    if (weather.isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (weather.error != null) {
      return Text('Weather error: ${weather.error}');
    } else if (weather.weatherData != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Weather for Today",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.wb_sunny),
                const SizedBox(width: 8),
                Text(
                  "${weather.weatherData!.temperature.toStringAsFixed(1)} °C",
                  style: const TextStyle(fontSize: 18),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  // Compact weather widget for mobile view
  Widget _buildCompactWeatherWidget() {
    final weather = context.watch<WeatherProvider>();

    if (!weather.isLoading && weather.error == null && weather.weatherData != null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.wb_sunny, size: 20),
            const SizedBox(width: 8),
            Text(
              "Today: ${weather.weatherData!.temperature.toStringAsFixed(1)} °C",
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  // Members section
  Widget _buildMembersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("MEMBERS", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Expanded(child: _buildMembersList()),
      ],
    );
  }

  // Members list
  Widget _buildMembersList() {
    return FutureBuilder<List<Member>>(
      future: _fetchGroupMembers(widget.groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text("No members yet");
        }
        final members = snapshot.data!;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundImage: NetworkImage(member.avatarUrl),
              ),
              title: Text(member.fullName),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (member.username.isNotEmpty)
                    Text('@${member.username}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(member.role),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

Future<List<Member>> _fetchGroupMembers(String groupId) async {
  final response = await Supabase.instance.client
      .from('group_members')
      .select('role, profiles(full_name, avatar_url, username)')
      .eq('group_id', groupId);

  final data = response as List;
  return data.map((e) {
    final profile = e['profiles'];
    return Member(
      fullName: profile['full_name'] ?? 'Unknown',
      avatarUrl: profile['avatar_url'] ?? 'https://via.placeholder.com/80',
      role: e['role'] ?? 'Member',
      username: profile['username'] ?? '',
    );
  }).toList();
}

class Member {
  final String fullName;
  final String avatarUrl;
  final String role;
  final String username;

  Member({
    required this.fullName,
    required this.avatarUrl,
    required this.role,
    required this.username,
  });
}
