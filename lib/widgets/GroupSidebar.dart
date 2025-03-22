import 'package:flutter/material.dart';

// Simple data model for a group
class GroupItem {
  final String id;
  final String groupName;
  final String groupImageUrl;  // e.g. a logo
  final bool isMember;         // if the user is already a member

  GroupItem({
    required this.id,
    required this.groupName,
    required this.groupImageUrl,
    required this.isMember,
  });
}

class GroupSidebar extends StatefulWidget {
  const GroupSidebar({Key? key}) : super(key: key);

  @override
  State<GroupSidebar> createState() => _GroupSidebarState();
}

class _GroupSidebarState extends State<GroupSidebar> {
  late Future<List<GroupItem>> _groupsFuture;

  @override
  void initState() {
    super.initState();
    // On init, trigger a fetch from Supabase (placeholder function for now)
    _groupsFuture = _fetchGroups();
  }

  // TODO: Replace this mock function with a real Supabase query
  Future<List<GroupItem>> _fetchGroups() async {
    await Future.delayed(const Duration(seconds: 1)); // simulate network delay

    // Return mock data for now
    return [
      GroupItem(
        id: 'g1',
        groupName: 'Pedal Matatag Bikers',
        groupImageUrl: 'https://via.placeholder.com/80x80.png?text=Just+Ride+Logo',
        isMember: false,
      ),
      GroupItem(
        id: 'g2',
        groupName: 'Weekend Warriors',
        groupImageUrl: 'https://via.placeholder.com/80x80.png?text=WW+Logo',
        isMember: true,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300, // or any width you prefer for the sidebar
      color: const Color(0xFF1565C0), // Blue-ish background
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ======= TOP BAR: "Community" + Search Icon =======
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Text(
                  "Community",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    // TODO: search logic
                  },
                  icon: const Icon(Icons.search, color: Colors.white),
                ),
              ],
            ),
          ),

          // ======= CREATE GROUP BUTTON (centered) =======
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.group_add),
                label: const Text("Create Group"),
                onPressed: () {
                  // TODO: implement create group logic
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,         // White fill
                  foregroundColor: const Color(0xFF1565C0), // Blue text/icon
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20), // pill shape
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ======= GROUPS LIST =======
          Expanded(
            child: FutureBuilder<List<GroupItem>>(
              future: _groupsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                } else if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No groups found',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }

                final groups = snapshot.data!;
                return ListView.builder(
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return _buildGroupTile(group);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupTile(GroupItem group) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey[300],
            backgroundImage: NetworkImage(group.groupImageUrl),
            radius: 24,
          ),
          const SizedBox(width: 16),

          // Put name + button in a column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.groupName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    // membership logic
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: Colors.black12),
                    ),
                  ),
                  child: Text(group.isMember ? 'Leave Group' : 'Join Group'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
