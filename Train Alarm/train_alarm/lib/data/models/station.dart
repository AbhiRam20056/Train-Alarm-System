class Station {
  final String code;
  final String name;
  final double lat;
  final double lng;
  final String? state;
  final String? zone;
  final String? address;

  const Station({
    required this.code,
    required this.name,
    required this.lat,
    required this.lng,
    this.state,
    this.zone,
    this.address,
  });

  factory Station.fromMap(Map<String, dynamic> map) => Station(
        code: map['code'] as String,
        name: map['name'] as String,
        lat: (map['lat'] as num).toDouble(),
        lng: (map['lng'] as num).toDouble(),
        state: map['state'] as String?,
        zone: map['zone'] as String?,
        address: map['address'] as String?,
      );

  @override
  String toString() => '$name ($code)';
}
