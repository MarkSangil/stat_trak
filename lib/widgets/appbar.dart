import 'package:flutter/material.dart';

class MyCustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final double height;

  const MyCustomAppBar({Key? key, this.height = kToolbarHeight})
      : super(key: key);

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.blue,
      elevation: 0,
      leading: IconButton(
        icon: Image.asset("assets/icons/Home.png"),
        onPressed: () {
        },
      ),
      actions: [
        IconButton(
          icon: Image.asset("assets/icons/Map.png"),
          onPressed: () {
          },
        ),
        IconButton(
          icon: Image.asset("assets/icons/Friends.png"),
          onPressed: () {
          },
        ),
        IconButton(
          icon: Image.asset("assets/icons/Group.png"),
          onPressed: () {
          },
        ),
        IconButton(
          icon: Image.asset("assets/icons/Notification.png"),
          onPressed: () {
          },
        ),
        IconButton(
          icon: Image.asset("assets/icons/Profile.png"),
          onPressed: () {
          },
        ),
      ],
    );
  }
}
