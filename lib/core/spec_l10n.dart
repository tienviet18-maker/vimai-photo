import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'capture/capture_checks.dart';
import 'specs/photo_spec.dart';

/// Localized labels for spec enums, kept out of the data model.
extension PhotoRuleL10n on PhotoRule {
  String label(AppLocalizations l) => switch (this) {
        PhotoRule.onlyYou => l.ruleOnlyYou,
        PhotoRule.noHat => l.ruleNoHat,
        PhotoRule.frontFacing => l.ruleFrontFacing,
        PhotoRule.noShadow => l.ruleNoShadow,
        PhotoRule.upperBody => l.ruleUpperBody,
        PhotoRule.noEdit => l.ruleNoEdit,
        PhotoRule.nameOnBack => l.ruleNameOnBack,
        PhotoRule.eyesVisible => l.ruleEyesVisible,
      };
}

extension PhotoBackgroundL10n on PhotoBackground {
  String label(AppLocalizations l) => switch (this) {
        PhotoBackground.white => l.bgWhite,
        PhotoBackground.lightBlue => l.bgLightBlue,
        PhotoBackground.plain => l.bgPlain,
      };

  Color get swatch => switch (this) {
        PhotoBackground.white => Colors.white,
        PhotoBackground.lightBlue => const Color(0xFFCFE3F5),
        PhotoBackground.plain => const Color(0xFFF1F1EE),
      };
}

/// Maps the JSON icon name to a Material icon.
IconData specIcon(String name) => switch (name) {
      'badge' => Icons.badge_outlined,
      'work' => Icons.work_outline,
      'credit_card' => Icons.credit_card,
      'flight' => Icons.flight_takeoff,
      'directions_car' => Icons.directions_car_outlined,
      'public' => Icons.public,
      _ => Icons.portrait_outlined,
    };

/// Formats 40.0 as "40" and 35.5 as "35.5".
String formatMm(double mm) =>
    mm == mm.roundToDouble() ? mm.toStringAsFixed(0) : mm.toStringAsFixed(1);

extension CaptureCheckL10n on CaptureCheck {
  String label(AppLocalizations l) => switch (this) {
        CaptureCheck.face => l.checkFace,
        CaptureCheck.distance => l.checkDistance,
        CaptureCheck.straight => l.checkStraight,
        CaptureCheck.level => l.checkLevel,
        CaptureCheck.eyes => l.checkEyes,
        CaptureCheck.light => l.checkLight,
      };
}

extension CaptureHintL10n on CaptureHint {
  String label(AppLocalizations l) => switch (this) {
        CaptureHint.noFace => l.hintNoFace,
        CaptureHint.manyFaces => l.hintManyFaces,
        CaptureHint.moveCloser => l.hintMoveCloser,
        CaptureHint.moveBack => l.hintMoveBack,
        CaptureHint.moveLeft => l.hintMoveLeft,
        CaptureHint.moveRight => l.hintMoveRight,
        CaptureHint.moveUp => l.hintMoveUp,
        CaptureHint.moveDown => l.hintMoveDown,
        CaptureHint.lookStraight => l.hintLookStraight,
        CaptureHint.levelHead => l.hintLevelHead,
        CaptureHint.openEyes => l.hintOpenEyes,
        CaptureHint.needLight => l.hintNeedLight,
        CaptureHint.tooBright => l.hintTooBright,
        CaptureHint.holdStill => l.hintHoldStill,
      };
}
