import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:stattrak/providers/weather_provider.dart';
import 'package:stattrak/widgets/CreatePostWidget.dart';
import 'package:stattrak/widgets/appbar.dart';
import 'package:stattrak/widgets/NotificationSidebar.dart';
import 'package:stattrak/widgets/GroupSidebar.dart';

enum SidebarType { none, notification, group }

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  SidebarType _activeSidebar = SidebarType.none;

  @override
  void initState() {
    super.initState();
    _requestLocationAndFetchWeather();
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

    Position position =
    await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    context.read<WeatherProvider>().fetchWeather(position.latitude, position.longitude);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WeatherProvider>();

    return Scaffold(
      appBar: MyCustomAppBar(
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
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ========== LEFT COLUMN (Main Feed) ==========
          Expanded(
            child: Container(
              color: Colors.white,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CreatePostWidget(),
                    const SizedBox(height: 16),
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      color: Colors.grey.shade200,
                      padding: const EdgeInsets.all(16),
                      child: const Text(
                        'Your feed items go here...',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),

                    // Add more feed content below...
                  ],
                ),
              ),
            ),
          ),

          // ========== RIGHT COLUMN (Weather + Sidebars) ==========
          Container(
            width: 300,
            color: Colors.grey.shade100,
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

                if (_activeSidebar == SidebarType.notification)
                  Positioned.fill(
                    child: NotificationSidebar(),
                  ),
                if (_activeSidebar == SidebarType.group)
                  Positioned.fill(
                    child: GroupSidebar(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
