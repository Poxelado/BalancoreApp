import 'package:flutter/material.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../../core/notifications/notification_preferences.dart';
part 'onboarding_identity_body.dart';
part 'onboarding_goal_reminders.dart';

String _hhmm(int m) =>
    '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

