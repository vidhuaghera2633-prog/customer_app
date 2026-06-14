import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class SelectLocationMapScreen extends StatefulWidget {
  const SelectLocationMapScreen({super.key});

  @override
  State<SelectLocationMapScreen> createState() => _SelectLocationMapScreenState();
}

class _SelectLocationMapScreenState extends State<SelectLocationMapScreen> {
  LatLng _selectedLocation = const LatLng(23.0225, 72.5714); // Default Ahmedabad
  GoogleMapController? _mapController;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      final loc = Location();
      bool serviceEnabled = await loc.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await loc.requestService();
        if (!serviceEnabled) return;
      }

      PermissionStatus permissionGranted = await loc.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await loc.requestPermission();
        if (permissionGranted != PermissionStatus.granted) return;
      }

      final data = await loc.getLocation();
      if (data.latitude != null && data.longitude != null) {
        setState(() {
          _selectedLocation = LatLng(data.latitude!, data.longitude!);
          _loading = false;
        });
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _selectedLocation, zoom: 16),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error fetching location: $e");
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Select Location",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedLocation,
              zoom: 15,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              if (!_loading) {
                controller.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: _selectedLocation, zoom: 16),
                  ),
                );
              }
            },
            onTap: (latLng) {
              setState(() {
                _selectedLocation = latLng;
              });
            },
            markers: {
              Marker(
                markerId: const MarkerId("selected"),
                position: _selectedLocation,
                draggable: true,
                onDragEnd: (newPosition) {
                  setState(() {
                    _selectedLocation = newPosition;
                  });
                },
              ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0D47A1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 4,
              ),
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
              label: const Text(
                "Confirm Selected Location",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              onPressed: () {
                Navigator.pop(context, _selectedLocation);
              },
            ),
          ),
        ],
      ),
    );
  }
}
