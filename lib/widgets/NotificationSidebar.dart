import 'package:flutter/material.dart';
import 'package:stattrak/SharedLocationPage.dart';
import 'package:stattrak/widgets/friends_sidebar.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide ChannelFilter;
import 'package:intl/intl.dart';

// -----------------------------------------------------------------------------
// 1) NotificationItem Model
// -----------------------------------------------------------------------------
class NotificationItem {
  final String id;
  final String type;
  final String? actorId;
  final String? actorUsername;
  final String? actorAvatarUrl;
  final String? relatedEntityId;
  final String? relatedEntityType;
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

  String get displayDate {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 1) {
      return DateFormat('MMM d, yyyy').format(createdAt);
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
// 2) NotificationSidebar Widget with Latest Realtime Subscriptions
// -----------------------------------------------------------------------------
class NotificationSidebar extends StatefulWidget {
  const NotificationSidebar({Key? key}) : super(key: key);

  @override
  State<NotificationSidebar> createState() => _NotificationSidebarState();
}

class _NotificationSidebarState extends State<NotificationSidebar> {
  final _supabase = Supabase.instance.client;

  // Use RealtimeChannel (not SupabaseChannel)
  late RealtimeChannel _notificationsChannel;

  List<NotificationItem> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    _subscribeToNotifications();
  }

  // Fetch initial notifications for the logged-in user
  Future<void> _fetchNotifications() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _error = 'User not logged in.';
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await _supabase
          .from('notifications')
          .select(
          '*, actor:profiles!notifications_actor_user_id_fkey(username, avatar_url)')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      if (response is List) {
        setState(() {
          _notifications = response
              .map((item) =>
              NotificationItem.fromMap(item as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Unexpected data format received.';
          _isLoading = false;
        });
      }
    } catch (error) {
      setState(() {
        _error = 'Failed to load notifications: $error';
        _isLoading = false;
      });
    }
  }

  // Subscribe to realtime notifications for the current user using channels
  void _subscribeToNotifications() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _notificationsChannel = _supabase.channel('notifications-channel')
        .onPostgresChanges(
      // Corrected parameter name: 'event'
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notifications',
      // Corrected filter syntax
      filter: PostgresChangeFilter(
        column: 'user_id',
        // Corrected parameter name: 'type'
        // Corrected enum: 'PostgresFilterOperator'
        type: PostgresFilterOperator.eq, // Use 'type' and ensure 'PostgresFilterOperator' is recognized
        value: userId,
      ),
      callback: (payload) {
        try {
          if (payload.newRecord is Map<String, dynamic>) {
            final newNotification = NotificationItem.fromMap(payload.newRecord as Map<String, dynamic>);
            if (mounted) {
              setState(() => _notifications.insert(0, newNotification));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(newNotification.displayMessage),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } else {
            print("Received unexpected payload format: ${payload.newRecord}");
          }
        } catch (e) {
          print("Error processing notification payload: $e");
        }
      },
    ).subscribe((status, [error]) {
      if (error != null) {
        print("Error subscribing to notifications: $error");
        if (mounted) {
          setState(() {
            _error = 'Failed to subscribe to notifications: $error';
          });
        }
      } else {
        print("Notification subscription status: $status");
      }
    });
  }

  @override
  void dispose() {
    // Remove the realtime channel when disposing
    _supabase.removeChannel(_notificationsChannel);
    super.dispose();
  }

  // Mark a notification as read in the DB
  Future<void> _markAsRead(NotificationItem notif) async {
    if (notif.isRead) return;
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notif.id);
      // Update the UI after marking as read
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notif.id);
        if (index != -1) {
          _notifications[index] = NotificationItem(
            id: notif.id,
            type: notif.type,
            actorId: notif.actorId,
            actorUsername: notif.actorUsername,
            actorAvatarUrl: notif.actorAvatarUrl,
            relatedEntityId: notif.relatedEntityId,
            relatedEntityType: notif.relatedEntityType,
            isRead: true,
            createdAt: notif.createdAt,
          );
        }
      });
    } catch (e) {
      print("Error marking notification as read: $e");
    }
  }

  // Handle user tapping a notification
  void _handleNotificationTap(NotificationItem notif) {
    print("Tapped notification: ${notif.id} - Type: ${notif.type}");
    _markAsRead(notif);

    switch (notif.type) {
      case 'friend_request_received':
        final currentUserId = _supabase.auth.currentUser?.id;
        if (currentUserId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FriendsModal(currentUserId: currentUserId),
            ),
          );
        }
        break;
      case 'friend_request_accepted':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Your friend request was accepted!")),
        );
        break;
      case 'location_shared':
        if (notif.relatedEntityId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  SharedRoutePage(routeId: notif.relatedEntityId!),
            ),
          );
        }
        break;
      case 'post_liked':
        if (notif.relatedEntityId != null) {
          print("Navigate to PostDetailPage with ID: ${notif.relatedEntityId}");
          // TODO: Implement navigation to the actual post detail page
        }
        break;
      default:
        print("No specific action defined for type: ${notif.type}");
    }
  }

  // Build the Notification Sidebar UI
  @override
  Widget build(BuildContext context) {
    final sidebarColor = Theme.of(context).primaryColorDark;
    final textColor = Colors.white;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: textColor));
    }

    if (_error != null) {
      return Center(
        child: Text(
          'Error loading notifications.\n$_error',
          style: TextStyle(color: textColor.withOpacity(0.8)),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      width: 300,
      color: sidebarColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
            child: Text(
              "Notifications",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchNotifications,
              color: textColor,
              backgroundColor: sidebarColor,
              child: ListView.builder(
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final notif = _notifications[index];
                  return InkWell(
                    onTap: () => _handleNotificationTap(notif),
                    child: _buildNotificationTile(notif),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build a single notification tile
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
        border:
        Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Actor's avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white.withOpacity(0.3),
            backgroundImage: (notif.actorAvatarUrl != null &&
                notif.actorAvatarUrl!.isNotEmpty)
                ? NetworkImage(notif.actorAvatarUrl!)
                : null,
            child: (notif.actorAvatarUrl == null ||
                notif.actorAvatarUrl!.isEmpty)
                ? Icon(Icons.person,
                color: Colors.white.withOpacity(0.7), size: 22)
                : null,
          ),
          const SizedBox(width: 12),
          // Notification text + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notif.displayMessage,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight:
                    notif.isRead ? FontWeight.normal : FontWeight.w600,
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
              child: CircleAvatar(
                radius: 4,
                backgroundColor: Colors.blueAccent,
              ),
            ),
        ],
      ),
    );
  }
}
