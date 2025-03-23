import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stattrak/ProfilePage.dart';

class FriendsModal extends StatefulWidget {
  final String currentUserId;
  final double? lat;
  final double? long;

  const FriendsModal({
    super.key,
    required this.currentUserId,
    this.lat,
    this.long,
  });

  @override
  State<FriendsModal> createState() => _FriendsModalState();
}

class _FriendsModalState extends State<FriendsModal> {
  final _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  List<dynamic>? _pendingRequests;
  List<dynamic>? _friendsList;

  // Flags to prevent re-fetching
  bool _pendingFetched = false;
  bool _friendsFetched = false;

  Future<void> _searchUsers(String query) async {
    final response = await Supabase.instance.client
        .from('profiles')
        .select()
        .ilike('full_name', '%$query%')
        .neq('id', widget.currentUserId);

    setState(() {
      _searchResults = response;
    });
  }

  Future<void> _loadPendingRequests() async {
    final response = await Supabase.instance.client.rpc('get_pending_requests', params: {
      'current_user_id': widget.currentUserId
    });

    debugPrint("Pending requests: $response");

    setState(() {
      _pendingRequests = response;
      _pendingFetched = true;
    });
  }

  Future<void> _loadFriends() async {
    if (_friendsFetched) return;
    final response = await Supabase.instance.client.rpc('get_friends_list', params: {
      'current_user_id': widget.currentUserId
    });
    setState(() {
      _friendsList = response;
      _friendsFetched = true;
    });
  }

  Future<void> _acceptRequest(String userId) async {
    await Supabase.instance.client
        .from('user_friendships')
        .update({'status': 'accepted'})
        .match({'user_id': userId, 'friend_id': widget.currentUserId});

    await _loadPendingRequests();
    setState(() {
      _friendsFetched = false;
    });
  }

  Future<void> _rejectRequest(String userId) async {
    await Supabase.instance.client
        .from('user_friendships')
        .delete()
        .or('user_id.eq.${widget.currentUserId},friend_id.eq.${widget.currentUserId}')
        .filter('user_id', 'in', '(${widget.currentUserId},"$userId")')
        .filter('friend_id', 'in', '(${widget.currentUserId},"$userId")');

    await _loadPendingRequests();
  }

  void _openProfile(String id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfilePage(
          userId: id,
          initialLat: widget.lat,
          initialLong: widget.long,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).canvasColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text("Friends", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          // Search
          TextField(
            controller: _searchController,
            onChanged: _searchUsers,
            decoration: const InputDecoration(
              hintText: 'Search users...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // List area
          Expanded(
            child: _searchController.text.isNotEmpty
                ? ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final user = _searchResults[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(user['avatar_url'] ?? ''),
                  ),
                  title: Text(user['full_name']),
                  subtitle: Text('@${user['username']}'),
                  onTap: () => _openProfile(user['id']),
                );
              },
            )
                : ListView(
              children: [
                ListTile(
                  title: const Text("Pending Requests"),
                  onTap: _loadPendingRequests,
                ),
                if (_pendingRequests != null)
                  ..._pendingRequests!.map((user) {
                    final direction = user['direction']; // 'sent' or 'received'
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(user['avatar_url'] ?? ''),
                      ),
                      title: Text(user['full_name']),
                      subtitle: Text('@${user['username']}'),
                      trailing: direction == 'received'
                          ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check),
                            onPressed: () => _acceptRequest(user['id']),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => _rejectRequest(user['id']),
                          ),
                        ],
                      )
                          : IconButton(
                        icon: const Icon(Icons.cancel),
                        onPressed: () => _rejectRequest(user['id']), // cancel sent request
                      ),
                      onTap: () => _openProfile(user['id']),
                    );
                  }),
                const Divider(),
                ListTile(
                  title: const Text("My Friends"),
                  onTap: _loadFriends,
                ),
                if (_friendsList != null)
                  ..._friendsList!.map((user) => ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(user['avatar_url'] ?? ''),
                    ),
                    title: Text(user['full_name']),
                    subtitle: Text('@${user['username']}'),
                    onTap: () => _openProfile(user['id']),
                  )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
