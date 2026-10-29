import 'attendance_shift.dart';
import 'dual_attendance_plan.dart';
import 'presence_info.dart';

class CheckResult {
  final AttendanceShift? shift;
  final PresenceInfo? presence;
  final DualAttendancePlan dualAttendance;

  const CheckResult({
    this.shift,
    this.presence,
    this.dualAttendance = const DualAttendancePlan(),
  });

  factory CheckResult.fromJson(Map<String, dynamic> json) {
    final shiftJson = json['shift'] as Map<String, dynamic>?;
    final presenceJson = json['presence'] as Map<String, dynamic>?;

    return CheckResult(
      shift: shiftJson == null
          ? null
          : AttendanceShift.fromJson({'shift': shiftJson}),
      presence: presenceJson == null
          ? null
          : PresenceInfo.fromJson(presenceJson),
      dualAttendance: DualAttendancePlan.fromJson(
        json['dual_attendance'] as Map<String, dynamic>?,
      ),
    );
  }
}
