import 'package:flutter/material.dart';
import 'package:stattrak/DashboardPage.dart';
import 'package:stattrak/map_page.dart';
import 'package:stattrak/ProfilePage.dart';
import 'package:stattrak/widgets/friends_sidebar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyCustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final double height;
  final VoidCallback onNotificationPressed;
  final VoidCallback onGroupPressed;

  final String? avatarUrl; // The user’s avatar
  final double? lat;
  final double? long;

  const MyCustomAppBar({
    Key? key,
    this.height = kToolbarHeight,
    required this.onNotificationPressed,
    required this.onGroupPressed,
    this.lat,
    this.long,
    this.avatarUrl, required bool isLoading,
  }) : super(key: key);

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E6091),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              // Left side icons
              IconButton(
                icon: Image.asset(
                  "assets/icons/Home.png",
                  color: Colors.lightBlue[200],
                ),
                onPressed: () {
                  Navigator.push(context,
                  MaterialPageRoute(builder: (context) => DashboardPage()),
                );},
              ),
              IconButton(
                icon: Image.asset(
                  "assets/icons/Map.png",
                  color: Colors.black,
                ),
                onPressed: () {
                  Navigator.push(context,
                    MaterialPageRoute(builder: (context) => MapPage()),
                  );
                },
              ),
              IconButton(
                icon: Image.asset(
                  "assets/icons/Events.png",
                  color: Colors.black,
                ),
                onPressed: () {},
              ),
              const Spacer(),

              // Right side icons
              IconButton(
                icon: Image.asset("assets/icons/Friends.png", color: Colors.black),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: SizedBox(
                        width: 400,  // set fixed width
                        height: 500, // or use MediaQuery
                        child: FriendsModal(
                          currentUserId: Supabase.instance.client.auth.currentUser!.id,
                          lat: lat,
                          long: long,
                        ),
                      ),
                    ),
                  );

                },
              ),

              IconButton(
                icon: Image.asset(
                  "assets/icons/Group.png",
                  color: Colors.white,
                ),
                onPressed: onGroupPressed,
              ),

              IconButton(
                icon: Image.asset(
                  "assets/icons/Notification.png",
                  color: Colors.white,
                ),
                onPressed: onNotificationPressed,
              ),
              (avatarUrl != null && avatarUrl!.isNotEmpty)
                  ? GestureDetector(
                onTap: () {
                  // Navigate to ProfilePage
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfilePage(
                        initialLat: lat,
                        initialLong: long,
                      ),
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage: NetworkImage(avatarUrl!),
                  backgroundColor: Colors.grey[200],
                ),
              )
                  : IconButton(
                icon: Image.asset(
                  "assets/icons/Profile.png",
                  color: Colors.white,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfilePage(
                        initialLat: lat,
                        initialLong: long,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
