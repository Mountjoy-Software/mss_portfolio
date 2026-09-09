import 'package:flutter/widgets.dart';

const compactBreakpoint = 600.0;

bool isCompact(BuildContext context) =>
    MediaQuery.sizeOf(context).width < compactBreakpoint;

bool keyboardOpen(BuildContext context) =>
    MediaQuery.viewInsetsOf(context).bottom > 0;
