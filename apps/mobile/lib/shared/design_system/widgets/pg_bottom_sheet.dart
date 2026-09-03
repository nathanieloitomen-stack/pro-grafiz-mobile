import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// Shows a modal bottom sheet using the approved shape: 32px/32px/0/0
/// top corners and the bottom-sheet shadow token. Sign-in, document
/// viewer, notifications, hold/cancel, and the accountant PIN gate all
/// use this shell in the approved design — build those as content passed
/// into [child], not as separate sheet implementations.
Future<T?> showPGBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    builder: (context) => DecoratedBox(
      decoration: BoxDecoration(
        color: PGColors.paper,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(PGRadius.bottomSheetTop),
          topRight: Radius.circular(PGRadius.bottomSheetTop),
        ),
        boxShadow: PGShadows.bottomSheet,
      ),
      child: SafeArea(
        top: false,
        child: builder(context),
      ),
    ),
  );
}
