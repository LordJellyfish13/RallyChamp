enum StaffRole { marshal, judge }

extension StaffRoleX on StaffRole {
  String get firestoreValue => switch (this) {
    StaffRole.marshal => 'marshal',
    StaffRole.judge => 'judge',
  };

  String get label => switch (this) {
    StaffRole.marshal => 'Marshal / Volunteer',
    StaffRole.judge => 'Judge',
  };
}
