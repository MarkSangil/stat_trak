import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stattrak/widgets/appbar.dart';
import 'package:stattrak/providers/weather_provider.dart';

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


  @override
  void initState() {
    super.initState();
    _checkMembership();
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Leave")),
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
    final weather = context.watch<WeatherProvider>();

    if (!_checkedAccess) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: MyCustomAppBar(
        onNotificationPressed: () {},
        onGroupPressed: () {},
        avatarUrl: null,
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== Left Sidebar (Group Info) =====
          Container(
            width: 250,
            color: Colors.grey[100],
            padding: const EdgeInsets.all(16),
            child: Column(
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
            ),
          ),

          // ===== Center Feed / Content =====
          Expanded(
            child: SingleChildScrollView(
              child: Column(
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
                  const SizedBox(height: 16),
                  if (_isMember)
                    Padding(
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
                    ),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _fetchGroupPosts(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const CircularProgressIndicator();
                      final posts = snapshot.data!;
                      if (posts.isEmpty) return const Text("No posts yet.");
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

                          return ListTile(
                            leading: CircleAvatar(backgroundImage: NetworkImage(avatarUrl)),
                            title: Text(fullName),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (username.isNotEmpty) Text('@$username', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                Text(content),
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
                          );
                        }).toList(),
                      );
                    },
                  )
                ],
              ),
            ),
          ),

          // ===== Right Sidebar (Weather + Members) =====
          Container(
            width: 300,
            color: Colors.grey[100],
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (weather.isLoading)
                  const CircularProgressIndicator()
                else if (weather.error != null)
                  Text('Weather error: \${weather.error}')
                else if (weather.weatherData != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const SizedBox(width: 8),
                            if (weather.weatherData != null)
                              Column(
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
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                const SizedBox(height: 24),
                const Text("MEMBERS", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Expanded(
                  child: FutureBuilder<List<Member>>(
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
                                  Text('@\${member.username}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                Text(member.role),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
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
