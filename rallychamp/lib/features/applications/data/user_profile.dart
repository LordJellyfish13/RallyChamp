import 'package:cloud_firestore/cloud_firestore.dart';

/// The contact details `users/{uid}` accumulates the first time someone
/// applies to any rally — as staff or as a team, both write the same
/// document (`ApplicationsRepository.submitStaffApplication` /
/// `submitTeamEntry`). Read back by both application forms to prefill
/// themselves: applying to a second rally shouldn't mean retyping a phone
/// number and OIB the app was already told once. See dev_notes.md §5 "Don't
/// retype what's already known".
class UserProfile {
  const UserProfile({this.name, this.phone, this.oib, this.licenseNumber});

  factory UserProfile.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return UserProfile(
      name: data['name'] as String?,
      phone: data['phone'] as String?,
      oib: data['oib'] as String?,
      licenseNumber: data['licenseNumber'] as String?,
    );
  }

  final String? name;
  final String? phone;
  final String? oib;
  final String? licenseNumber;
}
