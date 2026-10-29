import 'package:flutter/material.dart';

const double kFloatingNavClearance = 88;

double shellBottomContentPadding(BuildContext context, {double overlap = 0}) {
  final mq = MediaQuery.of(context);
  final keyboardOpen = mq.viewInsets.bottom > 0 ||
      (mq.viewPadding.bottom - mq.padding.bottom) > 0;
  if (keyboardOpen) return 12 + overlap;
  return overlap + kFloatingNavClearance + mq.viewPadding.bottom;
}
