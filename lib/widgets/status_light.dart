import 'package:flutter/material.dart';

import '../services/device_status_service.dart';

Color checkLevelColor(CheckLevel level) => switch (level) {
      CheckLevel.ok => Colors.green.shade600,
      CheckLevel.warn => Colors.amber.shade700,
      CheckLevel.error => Colors.red.shade600,
    };

IconData checkLevelIcon(CheckLevel level) => switch (level) {
      CheckLevel.ok => Icons.check_circle,
      CheckLevel.warn => Icons.error,
      CheckLevel.error => Icons.cancel,
    };

/// Colored traffic light icon for a check level.
class StatusLight extends StatelessWidget {
  const StatusLight(this.level, {super.key, this.size = 28});

  final CheckLevel level;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Icon(checkLevelIcon(level), color: checkLevelColor(level), size: size);
}
