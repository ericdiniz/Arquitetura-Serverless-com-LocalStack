import 'package:flutter/material.dart';

import '../services/location_service.dart';

/// Modal content that lets the user either search for an address or
/// capture the current GPS position, returning the chosen coordinates.
class LocationPicker extends StatefulWidget {
  const LocationPicker({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
    required this.onLocationSelected,
  });

  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;
  final void Function(double latitude, double longitude, String? address)
      onLocationSelected;

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final _addressController = TextEditingController();
  bool _isLoading = false;
  double? _latitude;
  double? _longitude;
  String? _address;

  @override
  void initState() {
    super.initState();
    _latitude = widget.initialLatitude;
    _longitude = widget.initialLongitude;
    _address = widget.initialAddress;
    _addressController.text = widget.initialAddress ?? '';
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    final snapshot =
        await LocationService.instance.getCurrentLocationWithAddress();
    if (!mounted) {
      return;
    }

    if (snapshot == null) {
      _showMessage('Não foi possível obter a localização atual', Colors.red);
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _latitude = snapshot.latitude;
      _longitude = snapshot.longitude;
      _address = snapshot.address;
      _addressController.text = snapshot.address ?? '';
      _isLoading = false;
    });

    widget.onLocationSelected(
      snapshot.latitude,
      snapshot.longitude,
      snapshot.address,
    );
    _showMessage('Localização obtida com sucesso', Colors.green);
  }

  Future<void> _searchAddress() async {
    final query = _addressController.text.trim();
    if (query.isEmpty) {
      return;
    }

    setState(() => _isLoading = true);
    final position =
        await LocationService.instance.getPositionFromAddress(query);
    if (!mounted) {
      return;
    }

    if (position == null) {
      _showMessage('Endereço não encontrado', Colors.orange);
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;
      _address = query;
      _isLoading = false;
    });

    widget.onLocationSelected(position.latitude, position.longitude, query);
    _showMessage('Endereço localizado!', Colors.green);
  }

  void _showMessage(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_outlined),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Selecionar localização',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _addressController,
              enabled: !_isLoading,
              decoration: InputDecoration(
                labelText: 'Buscar endereço',
                hintText: 'Ex: Av. Afonso Pena, 1000, Belo Horizonte',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: _isLoading ? null : _searchAddress,
                  icon: const Icon(Icons.send),
                ),
              ),
              onSubmitted: (_) => _searchAddress(),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('ou'),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _getCurrentLocation,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: Text(_isLoading
                  ? 'Obtendo localização...'
                  : 'Usar localização atual'),
              style:
                  ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
            ),
            if (_latitude != null && _longitude != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.blueGrey.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.blueGrey),
                          SizedBox(width: 8),
                          Text(
                            'Localização selecionada',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_address != null && _address!.isNotEmpty)
                        Text(_address!),
                      Text(
                        LocationService.instance
                            .formatCoordinates(_latitude!, _longitude!),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
