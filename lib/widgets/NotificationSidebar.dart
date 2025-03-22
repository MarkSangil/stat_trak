import 'package:flutter/material.dart';

// Example data model for a notification item
class NotificationItem {
  final String id;
  final String userName;
  final String message;
  final DateTime date;

  NotificationItem({
    required this.id,
    required this.userName,
    required this.message,
    required this.date,
  });
}

class NotificationSidebar extends StatefulWidget {
  const NotificationSidebar({Key? key}) : super(key: key);

  @override
  State<NotificationSidebar> createState() => _NotificationSidebarState();
}

class _NotificationSidebarState extends State<NotificationSidebar> {
  late Future<List<NotificationItem>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    // On init, trigger a fetch from Supabase (placeholder function for now)
    _notificationsFuture = _fetchNotifications();
  }

  // TODO: Replace this mock function with a real Supabase query
  Future<List<NotificationItem>> _fetchNotifications() async {
    await Future.delayed(const Duration(seconds: 1)); // simulate network delay
    // Return mock data for now
    return [
      NotificationItem(
        id: '1',
        userName: 'John Doe II',
        message: 'commented on Morning Ride 08/21/2021',
        date: DateTime(2025, 3, 20),
      ),
      NotificationItem(
        id: '2',
        userName: 'Jane Doe',
        message: 'commented on Morning Ride 08/21/2021',
        date: DateTime(2025, 3, 19),
      ),
      NotificationItem(
        id: '3',
        userName: 'John Doe III',
        message: 'commented on Morning Ride 08/21/2021',
        date: DateTime(2025, 3, 18),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250, // or any width you prefer
      color: const Color(0xFF1565C0), // an example sidebar color
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "Notifications",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<NotificationItem>>(
              future: _notificationsFuture,
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
                      'No notifications',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }

                final notifications = snapshot.data!;
                return ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notif = notifications[index];
                    return _buildNotificationTile(notif);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile(NotificationItem notif) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(8),
      color: Colors.white,
      child: Row(
        children: [
          // Example avatar or icon for the user
          const CircleAvatar(
            backgroundColor: Colors.grey,
            child: Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 8),
          // Notification text
          Expanded(
            child: Text(
              '${notif.userName} ${notif.message}',
              style: const TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}
