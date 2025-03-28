import 'package:flutter/material.dart';
import 'package:stattrak/SharedLocationPage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// -----------------------------------------------------------------------------
// 1) NotificationItem Model
//    - Just stores data and returns a text message via displayMessage
//    - NO navigation or BuildContext references here.
// -----------------------------------------------------------------------------
class NotificationItem {
  final String id;
  final String type; // e.g., 'friend_request_received', 'location_shared'
  final String? actorId;
  final String? actorUsername;
  final String? actorAvatarUrl;
  final String? relatedEntityId;   // e.g., the shared_routes row ID
  final String? relatedEntityType; // e.g., 'shared_route'
  final bool isRead;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.type,
    this.actorId,
    this.actorUsername,
    this.actorAvatarUrl,
    this.relatedEntityId,
    this.relatedEntityType,
    required this.isRead,
    required this.createdAt,
  });

  // Generates a user-friendly message based on notification type
  String get displayMessage {
    final actorName = actorUsername ?? 'Someone';
    switch (type) {
      case 'friend_request_received':
        return '$actorName sent you a friend request.';
      case 'friend_request_accepted':
        return '$actorName accepted your friend request.';
      case 'location_shared':
        return '$actorName shared a location with you.';
      case 'post_liked':
        return '$actorName liked your post.';
      case 'comment_added':
        return '$actorName commented on your post.';
      default:
        return 'New notification from $actorName.';
    }
  }

  // Formats the creation date into a relative string (e.g., "5m ago", "Yesterday")
  String get displayDate {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 1) {
      return DateFormat('MMM d, yyyy').format(createdAt); // e.g., Mar 28, 2025
    } else if (difference.inDays == 1 ||
        (difference.inHours >= 24 && now.day != createdAt.day)) {
      return 'Yesterday';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // Convert a Supabase response map into a NotificationItem
  factory NotificationItem.fromMap(Map<String, dynamic> map) {
    final actorData = map['actor'] as Map<String, dynamic>?;
    return NotificationItem(
      id: map['id'] as String,
      type: map['type'] as String? ?? 'unknown',
      actorId: map['actor_user_id'] as String?,
      actorUsername: actorData?['username'] as String?,
      actorAvatarUrl: actorData?['avatar_url'] as String?,
      relatedEntityId: map['related_entity_id'] as String?,
      relatedEntityType: map['related_entity_type'] as String?,
      isRead: map['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

// -----------------------------------------------------------------------------
// 2) NotificationSidebar Widget
//    - Fetches notifications from Supabase
//    - Displays them in a list
//    - Handles tapping (navigation) inside _handleNotificationTap()
// -----------------------------------------------------------------------------
class NotificationSidebar extends StatefulWidget {
  const NotificationSidebar({Key? key}) : super(key: key);

  @override
  State<NotificationSidebar> createState() => _NotificationSidebarState();
}

class _NotificationSidebarState extends State<NotificationSidebar> {
  final _supabase = Supabase.instance.client;
  late Future<List<NotificationItem>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _fetchNotifications();
  }

  // Fetch notifications for the logged-in user
  Future<List<NotificationItem>> _fetchNotifications() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not logged in.');
    }
    print("Fetching notifications for user: $userId");

    try {
      final response = await _supabase
          .from('notifications')
          .select('*, actor:profiles!notifications_actor_user_id_fkey(username, avatar_url)')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      if (response is List) {
        final notifications = response
            .map((item) => NotificationItem.fromMap(item as Map<String, dynamic>))
            .toList();
        print("Fetched ${notifications.length} notifications.");
        return notifications;
      } else {
        print("Supabase notifications response was not a list: $response");
        throw Exception('Unexpected data format received.');
      }
    } catch (error) {
      print('Error fetching notifications: $error');
      throw Exception('Failed to load notifications.');
    }
  }

  // Mark a notification as read in the DB
  Future<void> _markAsRead(NotificationItem notif) async {
    if (notif.isRead) return; // Already read
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notif.id);
      if (mounted) {
        setState(() {
          _notificationsFuture = _fetchNotifications();
        });
      }
    } catch (e) {
      print("Error marking notification as read: $e");
    }
  }

  // Handle user tapping a notification
  void _handleNotificationTap(NotificationItem notif) {
    print("Tapped notification: ${notif.id} - Type: ${notif.type}");
    // 1) Mark as read
    _markAsRead(notif);

    // 2) Navigate based on type
    switch (notif.type) {
      case 'location_shared':
        if (notif.relatedEntityId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SharedRoutePage(routeId: notif.relatedEntityId!),
            ),
          );
        }
        break;
    // Other cases...
      default:
        print("No specific action defined for type: ${notif.type}");
    }
  }

  @override
  Widget build(BuildContext context) {
    final sidebarColor = Theme.of(context).primaryColorDark;
    final textColor = Colors.white;

    return Container(
      width: 300,
      color: sidebarColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
            child: Text(
              "Notifications",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
            ),
          ),
          Divider(color: textColor.withOpacity(0.2), height: 1),

          // Main list area
          Expanded(
            child: FutureBuilder<List<NotificationItem>>(
              future: _notificationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: textColor));
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading notifications.\n${snapshot.error}',
                      style: TextStyle(color: textColor.withOpacity(0.8)),
                      textAlign: TextAlign.center,
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      'No new notifications',
                      style: TextStyle(color: textColor.withOpacity(0.8)),
                    ),
                  );
                }

                final notifications = snapshot.data!;
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _notificationsFuture = _fetchNotifications();
                    });
                  },
                  color: textColor,
                  backgroundColor: sidebarColor,
                  child: ListView.builder(
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notif = notifications[index];
                      return InkWell(
                        onTap: () => _handleNotificationTap(notif),
                        child: _buildNotificationTile(notif),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile(NotificationItem notif) {
    final tileColor = notif.isRead
        ? Colors.transparent
        : Theme.of(context).primaryColor.withOpacity(0.1);
    final titleColor = Colors.white;
    final subtitleColor = Colors.white70;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: tileColor,
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Actor avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white.withOpacity(0.3),
            backgroundImage: (notif.actorAvatarUrl != null && notif.actorAvatarUrl!.isNotEmpty)
                ? NetworkImage(notif.actorAvatarUrl!)
                : null,
            child: (notif.actorAvatarUrl == null || notif.actorAvatarUrl!.isEmpty)
                ? Icon(Icons.person, color: Colors.white.withOpacity(0.7), size: 22)
                : null,
          ),
          const SizedBox(width: 12),

          // Message & date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notif.displayMessage,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: notif.isRead ? FontWeight.normal : FontWeight.w600,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(
                  notif.displayDate,
                  style: TextStyle(color: subtitleColor, fontSize: 12),
                ),
              ],
            ),
          ),

          // Unread indicator
          if (!notif.isRead)
            Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 4),
              child: CircleAvatar(radius: 4, backgroundColor: Colors.blueAccent),
            ),
        ],
      ),
    );
  }
}
