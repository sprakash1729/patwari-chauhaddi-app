class PatwariProfile {
  final String uid;
  final String name;
  final String district;
  final String tehsil;
  final String riCircle;
  final List<String> halkaNumbers;
  final List<String> villages;

  PatwariProfile({
    required this.uid,
    required this.name,
    this.district = 'Korba',
    this.tehsil = 'Korba',
    required this.riCircle,
    required this.halkaNumbers,
    required this.villages,
  });

  factory PatwariProfile.fromMap(Map<String, dynamic> data, String documentId) {
    return PatwariProfile(
      uid: documentId,
      name: data['name'] ?? '',
      district: data['district'] ?? 'Korba',
      tehsil: data['tehsil'] ?? 'Korba',
      riCircle: data['riCircle'] ?? '',
      halkaNumbers: List<String>.from(data['halkaNumbers'] ?? []),
      villages: List<String>.from(data['villages'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'district': district,
      'tehsil': tehsil,
      'riCircle': riCircle,
      'halkaNumbers': halkaNumbers,
      'villages': villages,
    };
  }
}
