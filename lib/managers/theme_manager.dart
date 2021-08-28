import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/cupertino.dart';

class ThemeManager {
  factory ThemeManager() {
    return _manager;
  }

  static final ThemeManager _manager = ThemeManager._internal();

  ThemeManager._internal();

  /// Get the iOS style or Material style scroll physics
  ScrollPhysics get scrollPhysics {
    if (SettingsManager().settings.skin.value == Skins.iOS) {
      return AlwaysScrollableScrollPhysics(
        parent: CustomBouncingScrollPhysics(),
      );
    }
    return AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
    );
  }
}
