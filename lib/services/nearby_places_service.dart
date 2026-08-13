import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class NearbyPlaceSuggestion {
  const NearbyPlaceSuggestion({
    required this.name,
    required this.address,
    required this.typeLabel,
    required this.rating,
    required this.userRatingCount,
    required this.distanceKm,
    this.googleMapsUri,
    this.partnerDistanceKm,
    this.isHalfwayPick = false,
  });

  final String name;
  final String address;
  final String typeLabel;
  final double rating;
  final int userRatingCount;
  final double distanceKm;
  final String? googleMapsUri;
  final double? partnerDistanceKm;
  final bool isHalfwayPick;
}

class NearbyPlacesService {
  static const _placesApiKey = String.fromEnvironment('GOOGLE_PLACES_API_KEY');
  static const _mapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static const _endpoint =
      'https://places.googleapis.com/v1/places:searchNearby';

  String get _apiKey => _placesApiKey.isNotEmpty ? _placesApiKey : _mapsApiKey;

  bool get isConfigured => _apiKey.isNotEmpty;

  Future<NearbyPlaceSuggestion?> findBestSuggestion({
    required double latitude,
    required double longitude,
    double? partnerLatitude,
    double? partnerLongitude,
  }) async {
    try {
      final suggestions = await searchNearby(
        latitude: latitude,
        longitude: longitude,
        partnerLatitude: partnerLatitude,
        partnerLongitude: partnerLongitude,
      );
      if (suggestions.isEmpty) {
        return null;
      }
      return suggestions.first;
    } catch (error) {
      debugPrint('[Lovit/NearbyPlaces] $error');
      return null;
    }
  }

  Future<List<NearbyPlaceSuggestion>> searchNearby({
    required double latitude,
    required double longitude,
    double? partnerLatitude,
    double? partnerLongitude,
  }) async {
    if (!isConfigured) {
      return const [];
    }

    final partnerDistance = partnerLatitude != null && partnerLongitude != null
        ? _haversineKm(latitude, longitude, partnerLatitude, partnerLongitude)
        : null;
    final isHalfwayPick = partnerDistance != null && partnerDistance <= 12;
    final searchLatitude = isHalfwayPick
        ? (latitude + partnerLatitude!) / 2
        : latitude;
    final searchLongitude = isHalfwayPick
        ? (longitude + partnerLongitude!) / 2
        : longitude;
    final radiusMeters = isHalfwayPick
        ? ((partnerDistance * 1000 * 0.85).clamp(900.0, 3200.0))
        : 2200.0;

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask':
            'places.displayName,places.formattedAddress,places.primaryTypeDisplayName,places.rating,places.userRatingCount,places.location,places.googleMapsUri',
      },
      body: jsonEncode({
        'includedTypes': const [
          'cafe',
          'restaurant',
          'park',
          'tourist_attraction',
          'movie_theater',
        ],
        'maxResultCount': 12,
        'rankPreference': 'DISTANCE',
        'locationRestriction': {
          'circle': {
            'center': {
              'latitude': searchLatitude,
              'longitude': searchLongitude,
            },
            'radius': radiusMeters,
          },
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Nearby places lookup failed (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final rawPlaces = (json['places'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>();

    final suggestions = rawPlaces.map((place) {
      final location = (place['location'] as Map<String, dynamic>?) ?? const {};
      final placeLat = (location['latitude'] as num?)?.toDouble() ?? latitude;
      final placeLng = (location['longitude'] as num?)?.toDouble() ?? longitude;
      final distanceKm = _haversineKm(latitude, longitude, placeLat, placeLng);
      final partnerDistanceKm =
          partnerLatitude != null && partnerLongitude != null
          ? _haversineKm(partnerLatitude, partnerLongitude, placeLat, placeLng)
          : null;
      final displayName =
          (place['displayName'] as Map<String, dynamic>?)?['text'] as String? ??
          'Nearby place';
      final typeLabel =
          (place['primaryTypeDisplayName'] as Map<String, dynamic>?)?['text']
              as String? ??
          'Spot';

      return NearbyPlaceSuggestion(
        name: displayName,
        address: place['formattedAddress'] as String? ?? 'Nearby',
        typeLabel: typeLabel,
        rating: (place['rating'] as num?)?.toDouble() ?? 0,
        userRatingCount: (place['userRatingCount'] as num?)?.toInt() ?? 0,
        distanceKm: distanceKm,
        partnerDistanceKm: partnerDistanceKm,
        googleMapsUri: place['googleMapsUri'] as String?,
        isHalfwayPick: isHalfwayPick,
      );
    }).toList();

    final preferred = suggestions
        .where((item) => item.rating >= 4.2 && item.userRatingCount >= 30)
        .toList();
    final fallback = suggestions
        .where((item) => item.rating >= 4.0 && item.userRatingCount >= 10)
        .toList();
    final candidateList = preferred.isNotEmpty ? preferred : fallback;

    candidateList.sort(
      (a, b) => _scoreSuggestion(b).compareTo(_scoreSuggestion(a)),
    );
    return candidateList;
  }

  double _scoreSuggestion(NearbyPlaceSuggestion suggestion) {
    final ratingScore = suggestion.rating * 2.4;
    final reviewScore = math.log(suggestion.userRatingCount + 1);
    final distancePenalty = suggestion.distanceKm * 0.45;
    final partnerPenalty =
        (suggestion.partnerDistanceKm ?? suggestion.distanceKm) *
        (suggestion.isHalfwayPick ? 0.22 : 0.08);
    return ratingScore + reviewScore - distancePenalty - partnerPenalty;
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const radius = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return radius * c;
  }

  double _degToRad(double degrees) => degrees * (math.pi / 180);
}
