import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// Shows the approved design's one toast style: an ink card positioned
/// 110px from the bottom, self-clearing after [PGMotion.toast].
///
/// This is a thin wrapper around [ScaffoldMessenger]/[SnackBar] rather
/// than a bespoke overlay, so it inherits standard accessibility and
/// queuing behaviour; the visual is styled to match the approved token.
void showPGToast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message,
          style: PGTextStyles.body.copyWith(color: PGColors.paper)),
      backgroundColor: PGColors.ink,
      duration: PGMotion.toast,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PGRadius.insetNote)),
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 110),
    ),
  );
}
