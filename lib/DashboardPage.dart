import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:stattrak/PostWidget.dart';
import 'package:stattrak/providers/post_provider.dart';
import 'package:stattrak/providers/weather_provider.dart';
import 'package:stattrak/widgets/CreatePostWidget.dart';
import 'package:stattrak/widgets/appbar.dart';
import 'package:stattrak/widgets/NotificationSidebar.dart';
import 'package:stattrak/widgets/GroupSidebar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum SidebarType { none, notification, group }

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  SidebarType _activeSidebar = SidebarType.none;
  double? _latitude;
  double? _longitude;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _requestLocationAndFetchWeather();
    _fetchUserAvatar();

    Future.microtask(() {
      context.read<PostProvider>().fetchInitialPosts();
    });
  }

  Future<void> _fetchUserAvatar() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Just select the avatar_url column
      final response = await supabase
          .from('profiles')
          .select('avatar_url')
          .eq('id', user.id)
          .single();

      if (response != null && response['avatar_url'] != null) {
        setState(() {
          _avatarUrl = response['avatar_url'] as String;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user avatar: $e');
    }
  }

  Future<void> _requestLocationAndFetchWeather() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // 1) Store the lat/long in your state:
    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;
    });

    // 2) Fetch weather
    context.read<WeatherProvider>().fetchWeather(
      position.latitude,
      position.longitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WeatherProvider>();
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: MyCustomAppBar(
        avatarUrl: _avatarUrl,
        onNotificationPressed: () {
          setState(() {
            _activeSidebar = (_activeSidebar == SidebarType.notification)
                ? SidebarType.none
                : SidebarType.notification;
          });
        },
        onGroupPressed: () {
          setState(() {
            _activeSidebar = (_activeSidebar == SidebarType.group)
                ? SidebarType.none
                : SidebarType.group;
          });
        },
      ),
      body:
      // Use a LayoutBuilder to determine the screen width.
      LayoutBuilder(
        builder: (context, constraints) {
          if (screenWidth > 900) {
            // For larger screens (desktops, tablets in landscape), use a side-by-side layout.
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column (posts) takes up most of the width.
                Expanded(
                  child: _buildPostFeed(),
                ),
                // Right column (weather and sidebars) has a fixed width.
                SizedBox(
                  width: 300,
                  child: _buildSidebarAndWeather(constraints), // Pass constraints
                ),
              ],
            );
          } else {
            // For smaller screens (phones, tablets in portrait), stack the columns.
            return Column(
              children: [
                // Posts feed takes up the full width.
                Expanded(
                  child: _buildPostFeed(),
                ),
                //  Weather and sidebars.
                SizedBox(
                  width: double.infinity, // Make it take the full width.
                  child: _buildSidebarAndWeather(constraints), // Pass constraints
                ),
              ],
            );
          }
        },
      ),
    );
  }
  // Extract the Post Feed Widget
  Widget _buildPostFeed() {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CreatePostWidget(),
            const SizedBox(height: 16),
            Consumer<PostProvider>(
              builder: (context, postProvider, _) {
                final posts = postProvider.posts;

                if (postProvider.isLoading && posts.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                return Column(
                  children: [
                    ...posts.map((post) => PostWidget(post: post)).toList(),
                    if (postProvider.hasMore && !postProvider.isLoading)
                      ElevatedButton(
                        onPressed: () {
                          postProvider.loadMorePosts();
                        },
                        child: const Text("Load More"),
                      ),
                    if (postProvider.isLoading && posts.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Extract the Sidebar and Weather Widget
  Widget _buildSidebarAndWeather(BoxConstraints constraints) { // Add BoxConstraints
    final provider = context.watch<WeatherProvider>();
    final isSmallScreen = constraints.maxWidth < 900; // Use the breakpoint

    return Container(
      color: Colors.grey.shade100,
      // Constrain the height of the Stack.
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: isSmallScreen ? 0.0 : constraints.maxHeight, // 0 on small, max on large
          maxHeight: constraints.maxHeight,
        ),
        child: Stack(
          children: [
            // Weather logic, sidebars, etc.
            if (provider.isLoading)
              const Positioned(
                top: 20,
                left: 20,
                child: CircularProgressIndicator(),
              )
            else if (provider.error != null)
              Positioned(
                top: 20,
                left: 20,
                child: Container(
                  width: 250,
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Text('Error: ${provider.error}'),
                ),
              )
            else if (provider.weatherData != null)
                Positioned(
                  top: 20,
                  left: 20,
                  child: Container(
                    width: 250,
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Weather for Today',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.wb_sunny),
                            const SizedBox(width: 8),
                            Text(
                              '${provider.weatherData!.temperature.toStringAsFixed(1)} °C',
                              style: const TextStyle(fontSize: 24),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            // Ensure the sidebars have a size.  Positioned.fill ensures they expand to fill available space
            if (_activeSidebar == SidebarType.notification)
              const Positioned.fill(
                child: NotificationSidebar(),
              ),
            if (_activeSidebar == SidebarType.group)
              const Positioned.fill(
                child: GroupSidebar(),
              ),
          ],
        ),
      ),
    );
  }
}
