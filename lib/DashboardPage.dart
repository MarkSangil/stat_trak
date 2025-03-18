import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:stattrak/widgets/appbar.dart';
import 'package:stattrak/providers/weather_provider.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
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
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    context.read<WeatherProvider>().fetchWeather(position.latitude, position.longitude);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WeatherProvider>();
    return Scaffold(
      appBar: MyCustomAppBar(),
      body: Stack(
        children: [
          if (provider.isLoading)
            const Positioned(
              top: 20,
              right: 20,
              child: CircularProgressIndicator(),
            )
          else if (provider.error != null)
            Positioned(
              top: 20,
              right: 20,
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
                right: 20,
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
                      const SizedBox(height: 4),
                      const Text('(Current Location) Example: Caloocan City'),
                    ],
                  ),
                ),
              )
        ],
      ),
    );
  }
}
