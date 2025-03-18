import 'package:flutter/material.dart';

class MyCustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final double height;

  const MyCustomAppBar({Key? key, this.height = kToolbarHeight}) : super(key: key);

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFF1E6091), // Blue background color
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              // Left side icons - using black color for icons
              IconButton(
                icon: Image.asset(
                  "assets/icons/Home.png",
                  color: Colors.lightBlue[200], // Light blue color for home icon
                ),
                onPressed: () {},
              ),
              IconButton(
                icon: Image.asset(
                  "assets/icons/Map.png",
                  color: Colors.black, // Black color for map icon
                ),
                onPressed: () {},
              ),
              IconButton(
                icon: Image.asset(
                  "assets/icons/Events.png",
                  color: Colors.black, // Black color for events icon
                ),
                onPressed: () {},
              ),

              // Spacer to push the right icons to the end
              Spacer(),

              // Right side icons
              IconButton(
                icon: Image.asset(
                  "assets/icons/Friends.png",
                  color: Colors.black, // Black color
                ),
                onPressed: () {},
              ),
              IconButton(
                icon: Image.asset(
                  "assets/icons/Group.png",
                  color: Colors.white, // White color
                ),
                onPressed: () {},
              ),
              IconButton(
                icon: Image.asset(
                  "assets/icons/Notification.png",
                  color: Colors.white, // White color
                ),
                onPressed: () {},
              ),
              IconButton(
                icon: Image.asset(
                  "assets/icons/Profile.png",
                  color: Colors.white, // White color
                ),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}