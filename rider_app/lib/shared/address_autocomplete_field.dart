
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;


class AddressSuggestion {
  final String description;
  final String placeId;
  AddressSuggestion({required this.description, required this.placeId});
}

class PlaceLatLng {
  final double lat;
  final double lng;
  PlaceLatLng(this.lat, this.lng);
}


class AddressAutocompleteField extends StatefulWidget {
  final String label;
  final String hint;
  final void Function(String text, String? placeId, PlaceLatLng? latLng) onChangedOrSelected;
  const AddressAutocompleteField({
    super.key,
    required this.label,
    required this.hint,
    required this.onChangedOrSelected,
  });
  @override
  State<AddressAutocompleteField> createState() => _AddressAutocompleteFieldState();
}


class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  String? _inlineError;
  String? _inlineProof;
  static const _minLen = 3;

  // === ENDPOINTS (from Firebase Functions console, v2 run.app) ===
  static const PLACES_AUTOCOMPLETE_URL = 'https://placesautocomplete-pbe56gqazq-uc.a.run.app';
  static const PLACE_DETAILS_URL = 'https://placedetails-pbe56gqazq-uc.a.run.app';

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<List<AddressSuggestion>> _fetchSuggestions(String q) async {
    if (q.length < _minLen) return [];
    final uri = Uri.parse(PLACES_AUTOCOMPLETE_URL).replace(queryParameters: {
      'input': q,
    });
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      final status = res.statusCode;
      final body = res.body;
      final data = jsonDecode(body) as Map<String, dynamic>;
      final predictions = (data['predictions'] as List?) ?? [];
      // Inline proof: show URL, status, and sample predictions
      String proof = 'URL: ${uri.toString()}\nHTTP $status';
      if (status == 200) {
        proof += ' • predictions: ${predictions.length}';
        if (predictions.isNotEmpty) {
          proof += '\n1: ${(predictions[0]['description'] ?? '')}';
          if (predictions.length > 1) {
            proof += '\n2: ${(predictions[1]['description'] ?? '')}';
          }
        }
      } else {
        proof += '\nBody: $body';
      }
      setState(() {
        _inlineProof = proof;
        _inlineError = null;
      });
      if (status != 200) {
        setState(() => _inlineError = 'HTTP $status • Autocomplete unavailable');
        return [];
      }
      return predictions.map((item) {
        return AddressSuggestion(
          description: item['description'] ?? '',
          placeId: item['place_id'] ?? '',
        );
      }).where((s) => s.description.isNotEmpty && s.placeId.isNotEmpty).toList();
    } catch (e) {
      setState(() {
        _inlineProof = null;
        _inlineError = 'HTTP ERROR • $e';
      });
      return [];
    }
  }

  Future<PlaceLatLng?> _fetchDetails(String placeId) async {
    final uri = Uri.parse(PLACE_DETAILS_URL).replace(queryParameters: {
      'place_id': placeId,
      'fields': 'geometry/location',
    });
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      final status = res.statusCode;
      final body = res.body;
      if (status != 200) {
        setState(() => _inlineError = 'HTTP $status • Details unavailable');
        return null;
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final loc = (((data['result'] ?? {})['geometry'] ?? {})['location'] ?? {}) as Map<String, dynamic>;
      final lat = (loc['lat'] as num?)?.toDouble();
      final lng = (loc['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        return PlaceLatLng(lat, lng);
      }
      setState(() => _inlineError = 'No lat/lng in response');
      return null;
    } catch (e) {
      setState(() => _inlineError = 'HTTP ERROR • $e');
      return null;
    }
  }

  void _select(AddressSuggestion s) async {
    _ctrl.text = s.description;
    _ctrl.selection = TextSelection.fromPosition(TextPosition(offset: s.description.length));
    _focus.unfocus();
    setState(() {
      _inlineError = null;
      _inlineProof = 'Selected: ${s.description}';
    });
    widget.onChangedOrSelected(s.description, s.placeId, null);
    final latLng = await _fetchDetails(s.placeId);
    if (latLng != null) {
      setState(() {
        _inlineProof = 'Selected: ${s.description}\nlat: ${latLng.lat}, lng: ${latLng.lng}';
      });
    }
    widget.onChangedOrSelected(s.description, s.placeId, latLng);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TypeAheadField<AddressSuggestion>(
          controller: _ctrl,
          focusNode: _focus,
          debounceDuration: const Duration(milliseconds: 150),
          suggestionsCallback: (query) async {
            if (query.trim().length < _minLen) {
              return [];
            }
            final results = await _fetchSuggestions(query.trim());
            debugPrint('Autocomplete results: ${results.length}');
            return results;
          },
          itemBuilder: (context, suggestion) {
            return ListTile(
              dense: true,
              leading: const Icon(
                Icons.location_on,
                color: Color(0xFFE83E8C),
                size: 18,
              ),
              title: Text(
                suggestion.description,
                style: const TextStyle(fontSize: 14),
              ),
            );
          },
          onSelected: (suggestion) {
            _select(suggestion);
          },
          builder: (context, controller, focusNode) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: widget.label,
                hintText: widget.hint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                widget.onChangedOrSelected(value, null, null);
              },
            );
          },
          loadingBuilder: (context) => const Padding(
            padding: EdgeInsets.all(10),
            child: CircularProgressIndicator(),
          ),
          emptyBuilder: (context) => const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'No addresses found',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ), // Added comma here
        if (_inlineError != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Text(
              _inlineError!,
              style: const TextStyle(fontSize: 11, color: Colors.red),
            ),
          ),
        if (_inlineProof != null && _inlineProof!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Text(
              _inlineProof!,
              style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
            ),
          ),
      ],
    );
  }
}
