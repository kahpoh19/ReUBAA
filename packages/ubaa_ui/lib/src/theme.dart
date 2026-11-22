import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'shared/monday_first_localizations.dart';

/// 用户可选的主题色预设；持久化时只保存 [name]，色值可随版本调整。
///
/// 色相避开成功（绿）、警告（橙）和错误（红）的语义色，石墨为低饱和中性预设。
enum UbaaAccent {
  blue('默认蓝', Color(0xFF1976D2)),
  indigo('靛蓝', Color(0xFF3F51B5)),
  teal('青碧', Color(0xFF00838F)),
  purple('紫罗兰', Color(0xFF7B4FC2)),
  rose('玫红', Color(0xFFB82E8A)),
  graphite('石墨', Color(0xFF5B6B78));

  const UbaaAccent(this.label, this.seed);
  final String label;

  /// 色块展示色，也是重新着色时的色相与饱和度来源。
  final Color seed;

  static UbaaAccent parse(String? name) =>
      values.asNameMap()[name] ?? UbaaAccent.blue;

  /// 把默认蓝里手调的颜色换成本预设的色相，并保持相对亮度不变；
  /// 对比度只取决于相对亮度，因此各预设沿用默认蓝已核对过的对比度。
  Color retint(Color color) {
    if (this == UbaaAccent.blue) return color;
    final source = HSLColor.fromColor(color);
    if (source.saturation == 0) return color;
    final from = HSLColor.fromColor(UbaaAccent.blue.seed);
    final to = HSLColor.fromColor(seed);
    // 只降不升：低饱和预设（石墨）随之变灰，高饱和预设不把浅底调得刺眼。
    final saturation =
        source.saturation * math.min(1.0, to.saturation / from.saturation);
    return UbaaTheme.atLuminance(
      source.withHue(to.hue).withSaturation(saturation).toColor(),
      color.computeLuminance(),
    );
  }
}

/// 界面风格。Material 是原来的样子；Miuix 仿小米 HyperOS：浅灰页面、白色无边框卡片、
/// 大圆角和不带指示条的底部导航。只换配色和组件主题，页面结构不变。
enum UbaaUiStyle {
  material('Material'),
  miuix('Miuix');

  const UbaaUiStyle(this.label);
  final String label;

  static UbaaUiStyle parse(String? name) =>
      values.asNameMap()[name] ?? UbaaUiStyle.material;
}

/// 挂在主题上的界面风格，组件据此决定是否换成 Miuix 的写法。
@immutable
class UbaaStyleTheme extends ThemeExtension<UbaaStyleTheme> {
  const UbaaStyleTheme(this.style);
  final UbaaUiStyle style;
  @override
  UbaaStyleTheme copyWith({UbaaUiStyle? style}) =>
      UbaaStyleTheme(style ?? this.style);
  @override
  UbaaStyleTheme lerp(UbaaStyleTheme? other, double t) =>
      t < .5 ? this : other ?? this;
}

/// 设备外观偏好与修改回调：宿主持有并保存，设置页只展示和回调。
@immutable
class UiAppearanceSettings {
  const UiAppearanceSettings({
    this.themeMode = ThemeMode.system,
    this.onThemeModeChanged,
    this.accent = UbaaAccent.blue,
    this.onAccentChanged,
    this.style = UbaaUiStyle.material,
    this.onStyleChanged,
  });
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final UbaaAccent accent;
  final ValueChanged<UbaaAccent>? onAccentChanged;
  final UbaaUiStyle style;
  final ValueChanged<UbaaUiStyle>? onStyleChanged;
}

/// 共享 Material 3 设计变量；宿主选择亮度与主题色，不在此持久化偏好。
class UbaaTheme {
  const UbaaTheme._();

  static const locale = Locale('zh', 'CN');
  static const supportedLocales = [locale];
  static const localizationsDelegates = [
    // 排在官方委托前面：同类型委托取第一个，中文日期选择器改为周一开头。
    UiMondayFirstLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  /// 无头渲染（如商店截图）注入的字体族；测试字体环境不解析未指定字体族的文本。
  /// 生产始终为空，沿用各平台系统字体。
  @visibleForTesting
  static String? debugFontFamily;

  static const Color seedColor = Color(0xFF1976D2);
  static const Color _darkPrimary = Color(0xFF83BEF7);

  /// 预设在指定明暗下的主色，供色块预览，与主题实际主色一致。
  static Color accentPrimary(UbaaAccent accent, Brightness brightness) =>
      accent.retint(brightness == Brightness.dark ? _darkPrimary : seedColor);
  static const double pageMaxWidth = 1040;
  static const double cardRadius = 16;
  static const double controlRadius = 12;

  /// 成功与临近截止的语义色；Material 配色没有这两类，统一在此定义。
  static Color success(ColorScheme colors) =>
      colors.brightness == Brightness.dark
      ? const Color(0xFF8BD5A8)
      : const Color(0xFF2E7D4F);

  static Color warning(ColorScheme colors) =>
      colors.brightness == Brightness.dark
      ? const Color(0xFFFFBD75)
      : const Color(0xFF9A4D00);

  /// 保持色相与饱和度，把颜色调到指定的相对亮度；不同色相由此看起来一样亮。
  static Color atLuminance(Color color, double luminance) {
    final hsl = HSLColor.fromColor(color);
    var low = 0.0, high = 1.0;
    for (var i = 0; i < 16; i++) {
      final mid = (low + high) / 2;
      if (hsl.withLightness(mid).toColor().computeLuminance() < luminance) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return hsl.withLightness((low + high) / 2).toColor();
  }

  /// 固定的类别色（文件类型、日程来源）：深色主题下过暗的提亮到能看清。
  static Color category(Color color, ColorScheme colors) =>
      colors.brightness == Brightness.dark && color.computeLuminance() < .25
      ? atLuminance(color, .25)
      : color;

  /// 面板、对话框内的分组底色：半透明叠色，在页面、底部面板和对话框上都看得出边界。
  static Color insetFill(ColorScheme colors) =>
      colors.onSurface.withValues(alpha: .05);

  /// 当前主题是不是 Miuix 风格。
  static bool miuix(BuildContext context) =>
      Theme.of(context).extension<UbaaStyleTheme>()?.style == UbaaUiStyle.miuix;

  static double pagePadding(double width) => width < 600
      ? 16
      : width < 1000
      ? 24
      : 32;

  static EdgeInsets pageInsets(
    BuildContext context, {
    double? top,
    double? bottom,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    // Miuix 的卡片离屏幕边 12，比 Material 窄一点。
    final gutter = miuix(context) && width < 600 ? 12.0 : pagePadding(width);
    return EdgeInsets.fromLTRB(gutter, top ?? gutter, gutter, bottom ?? gutter);
  }

  static ThemeData light({
    UbaaAccent accent = UbaaAccent.blue,
    UbaaUiStyle style = UbaaUiStyle.material,
  }) => style == UbaaUiStyle.miuix
      ? _miuix(Brightness.light, accent)
      : _build(Brightness.light, accent);
  static ThemeData dark({
    UbaaAccent accent = UbaaAccent.blue,
    UbaaUiStyle style = UbaaUiStyle.material,
  }) => style == UbaaUiStyle.miuix
      ? _miuix(Brightness.dark, accent)
      : _build(Brightness.dark, accent);

  static ThemeData _build(Brightness brightness, UbaaAccent accent) {
    final dark = brightness == Brightness.dark;
    final tint = accent.retint;
    // 浅底与正文建立层次，图标蓝串联导航、来源和操作。
    // 明暗主题按角色配对，区分品牌强调与普通状态。
    final accentContainer = tint(
      dark ? const Color(0xFF183F64) : const Color(0xFFE3F0FC),
    );
    final onAccentContainer = tint(
      dark ? const Color(0xFFB8DAFC) : const Color(0xFF125EA7),
    );
    final colors =
        ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: brightness,
          dynamicSchemeVariant: DynamicSchemeVariant.neutral,
        ).copyWith(
          primary: accentPrimary(accent, brightness),
          onPrimary: tint(dark ? const Color(0xFF082F49) : Colors.white),
          primaryContainer: accentContainer,
          onPrimaryContainer: onAccentContainer,
          secondary: dark ? const Color(0xFFBEC5CD) : const Color(0xFF596B7E),
          onSecondary: dark ? const Color(0xFF24282D) : Colors.white,
          secondaryContainer: accentContainer,
          onSecondaryContainer: onAccentContainer,
          // 深色表面是略带冷调的中性灰，由低到高逐级变亮；蓝色只留给强调。
          surface: dark ? const Color(0xFF0E1114) : const Color(0xFFFCFDFF),
          surfaceDim: dark ? const Color(0xFF0E1114) : null,
          surfaceBright: dark ? const Color(0xFF3F444A) : null,
          surfaceContainerLowest: dark ? const Color(0xFF07080B) : Colors.white,
          surfaceContainerLow: dark ? const Color(0xFF1F2226) : Colors.white,
          // 浅色导航底带一点主题色，深色保持中性灰。
          surfaceContainer: dark
              ? const Color(0xFF24282D)
              : tint(const Color(0xFFEAF3FC)),
          surfaceContainerHigh: dark
              ? const Color(0xFF2D3136)
              : const Color(0xFFF1F4F7),
          surfaceContainerHighest: dark
              ? const Color(0xFF363B41)
              : const Color(0xFFE5EBF2),
          onSurface: dark ? const Color(0xFFE7EAED) : const Color(0xFF242424),
          onSurfaceVariant: dark
              ? const Color(0xFFB7BEC8)
              : const Color(0xFF596B7E),
          outline: dark ? const Color(0xFF858D97) : const Color(0xFF757575),
          outlineVariant: dark
              ? const Color(0xFF3F444B)
              : tint(const Color(0xFFDBE5EF)),
          inverseSurface: dark
              ? const Color(0xFFE7EAED)
              : const Color(0xFF303030),
          onInverseSurface: dark
              ? const Color(0xFF24282D)
              : const Color(0xFFF5F5F5),
          inversePrimary: tint(dark ? seedColor : _darkPrimary),
          surfaceTint: accentPrimary(accent, brightness),
        );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(controlRadius),
    );
    return ThemeData(
      adaptations: [_AppleSwitchAdaptation(colors.primary)],
      useMaterial3: true,
      fontFamily: debugFontFamily,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      visualDensity: VisualDensity.standard,
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        thickness: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surfaceContainer,
        indicatorColor: colors.secondaryContainer,
        indicatorShape: const StadiumBorder(),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w500
                : FontWeight.w400,
            color: states.contains(WidgetState.selected)
                ? colors.onSurface
                : colors.onSurfaceVariant,
          ),
        ),
      ),
      // 选中标签已有底色区分，不再加对钩，宽度也不随选中跳动。
      chipTheme: const ChipThemeData(showCheckmark: false),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surfaceContainer,
        indicatorColor: colors.secondaryContainer,
        useIndicator: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      // 日期选择与其他对话框同一底色。
      datePickerTheme: DatePickerThemeData(
        backgroundColor: colors.surfaceContainerLow,
        rangePickerBackgroundColor: colors.surfaceContainerLow,
      ),
      // 菜单从按钮下方展开，不盖住触发它的按钮。
      popupMenuTheme: PopupMenuThemeData(
        position: PopupMenuPosition.under,
        color: colors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      hoverColor: colors.primary.withValues(alpha: 0.04),
      focusColor: colors.primary.withValues(alpha: 0.10),
      // 当前复选框、开关均属于整行选项；反馈由外层选项行统一绘制。
      checkboxTheme: const CheckboxThemeData(
        overlayColor: WidgetStatePropertyAll(Colors.transparent),
        splashRadius: 0,
      ),
      switchTheme: const SwitchThemeData(
        overlayColor: WidgetStatePropertyAll(Colors.transparent),
        splashRadius: 0,
      ),
      listTileTheme: ListTileThemeData(shape: controlShape),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: controlShape,
          foregroundColor: colors.onPrimaryContainer,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: debugFontFamily,
          color: colors.onSurface,
          fontSize: 26,
          fontWeight: FontWeight.w500,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
        ),
        filled: true,
        fillColor: colors.surfaceContainerLow,
      ),
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        elevation: 0,
        color: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.65),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: controlShape,
          minimumSize: const Size(48, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: controlShape,
          foregroundColor: colors.onPrimaryContainer,
          minimumSize: const Size(48, 48),
        ),
      ),
    );
  }

  /// Miuix 风格：配色参考 HyperOS，页面浅灰（深色纯黑）、卡片白色（深色 #242424）、
  /// 强调色默认 HyperOS 蓝，选了别的主题色时按同样方式换色相。
  static ThemeData _miuix(Brightness brightness, UbaaAccent accent) {
    final dark = brightness == Brightness.dark;
    final primary = accent.retint(
      dark ? const Color(0xFF277AF7) : const Color(0xFF3482FF),
    );
    final page = dark ? Colors.black : const Color(0xFFF7F7F7);
    final card = dark ? const Color(0xFF242424) : Colors.white;
    final text = dark ? Colors.white : Colors.black;
    final summary = dark ? const Color(0xFF8C8C8C) : const Color(0xFF8A8A8A);
    final fill = dark ? const Color(0xFF2E2E2E) : const Color(0xFFF0F0F0);
    final line = dark ? const Color(0xFF2B2B2B) : const Color(0xFFEDEDED);
    final tinted = Color.alphaBlend(
      primary.withValues(alpha: dark ? .24 : .12),
      card,
    );
    final colors =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
          dynamicSchemeVariant: DynamicSchemeVariant.neutral,
        ).copyWith(
          primary: primary,
          onPrimary: Colors.white,
          primaryContainer: tinted,
          onPrimaryContainer: primary,
          secondary: summary,
          onSecondary: Colors.white,
          secondaryContainer: tinted,
          onSecondaryContainer: primary,
          surface: page,
          surfaceDim: page,
          surfaceBright: card,
          surfaceContainerLowest: card,
          surfaceContainerLow: card,
          surfaceContainer: card,
          surfaceContainerHigh: fill,
          surfaceContainerHighest: dark
              ? const Color(0xFF383838)
              : const Color(0xFFE6E6E6),
          onSurface: text,
          onSurfaceVariant: summary,
          outline: dark ? const Color(0xFF5C5C5C) : const Color(0xFFBDBDBD),
          outlineVariant: line,
          inverseSurface: dark ? Colors.white : const Color(0xFF303030),
          onInverseSurface: dark ? Colors.black : Colors.white,
          inversePrimary: primary,
          surfaceTint: Colors.transparent,
        );
    final radius = BorderRadius.circular(16);
    final controlShape = RoundedRectangleBorder(borderRadius: radius);
    WidgetStateProperty<Color> pick(Color on, Color off) =>
        WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? on : off,
        );
    return ThemeData(
      adaptations: [_AppleSwitchAdaptation(primary)],
      extensions: const [UbaaStyleTheme(UbaaUiStyle.miuix)],
      useMaterial3: true,
      fontFamily: debugFontFamily,
      colorScheme: colors,
      scaffoldBackgroundColor: page,
      visualDensity: VisualDensity.standard,
      // HyperOS 点按没有水波纹，只把按下的区域压暗一点。
      splashFactory: NoSplash.splashFactory,
      highlightColor: text.withValues(alpha: dark ? .10 : .06),
      // 卡片里的列表项之间不画分隔线，靠留白区分。
      dividerTheme: const DividerThemeData(
        color: Colors.transparent,
        thickness: 0,
      ),
      // 底栏和页面同色，选中项只加深颜色，没有指示条。
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: page,
        surfaceTintColor: Colors.transparent,
        height: 64,
        indicatorColor: Colors.transparent,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? text : summary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
            color: states.contains(WidgetState.selected) ? text : summary,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: page,
        indicatorColor: tinted,
        useIndicator: true,
      ),
      chipTheme: ChipThemeData(
        showCheckmark: false,
        backgroundColor: fill,
        selectedColor: tinted,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      // HyperOS 的对话框贴在屏幕下方，四周留 12，标题居中加粗。
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        alignment: Alignment.bottomCenter,
        insetPadding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        titleTextStyle: TextStyle(
          fontFamily: debugFontFamily,
          color: text,
          fontSize: 19,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          fontFamily: debugFontFamily,
          color: text,
          fontSize: 16,
          height: 1.4,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        focusElevation: 3,
        hoverElevation: 4,
        highlightElevation: 2,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: fill,
        circularTrackColor: Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark
            ? const Color(0xFF333333)
            : const Color(0xFF303030),
        contentTextStyle: TextStyle(
          fontFamily: debugFontFamily,
          color: Colors.white,
          fontSize: 14,
        ),
        shape: controlShape,
      ),
      // 页内切换做成药丸：选中项浅色强调底，没有下划线。
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: tinted,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: primary,
        unselectedLabelColor: summary,
        labelStyle: TextStyle(
          fontFamily: debugFontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: debugFontFamily,
          fontSize: 15,
        ),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      radioTheme: RadioThemeData(fillColor: pick(primary, summary)),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        modalBackgroundColor: card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: card,
        rangePickerBackgroundColor: card,
      ),
      popupMenuTheme: PopupMenuThemeData(
        position: PopupMenuPosition.under,
        color: card,
        shape: controlShape,
      ),
      hoverColor: primary.withValues(alpha: 0.04),
      focusColor: primary.withValues(alpha: 0.10),
      checkboxTheme: CheckboxThemeData(
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        splashRadius: 0,
        shape: const CircleBorder(),
        fillColor: pick(primary, Colors.transparent),
      ),
      // HyperOS 的开关：白色圆钮，开时轨道是强调色，关时浅灰，没有描边。
      switchTheme: SwitchThemeData(
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        splashRadius: 0,
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        // 带了图标的开关圆钮开关时一样大，不像 Material 关着时缩小。
        thumbIcon: const WidgetStatePropertyAll(Icon(null)),
        trackColor: pick(
          primary,
          dark ? const Color(0xFF4A4A4A) : const Color(0xFFE6E6E6),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      listTileTheme: ListTileThemeData(
        shape: controlShape,
        titleTextStyle: TextStyle(
          fontFamily: debugFontFamily,
          color: text,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: debugFontFamily,
          color: summary,
          fontSize: 14,
        ),
        iconColor: summary,
        minVerticalPadding: 12,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: controlShape,
          foregroundColor: primary,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: page,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: debugFontFamily,
          color: text,
          fontSize: 28,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fill,
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        elevation: 0,
        color: card,
        shape: controlShape,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: controlShape,
          minimumSize: const Size(48, 48),
        ),
      ),
      // HyperOS 没有描边按钮，次要按钮用浅灰底。
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: controlShape,
          backgroundColor: fill,
          foregroundColor: text,
          side: BorderSide.none,
          minimumSize: const Size(48, 48),
        ),
      ),
      // 分段选择：浅灰底，选中项浅色强调底、强调色字。
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: fill,
          foregroundColor: text,
          selectedBackgroundColor: tinted,
          selectedForegroundColor: primary,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// Apple 平台的自适应开关默认是系统绿色且忽略 [SwitchThemeData]；改为主色，
/// 与 macOS 跟随强调色的原生开关一致。
class _AppleSwitchAdaptation extends Adaptation<SwitchThemeData> {
  const _AppleSwitchAdaptation(this.primary);
  final Color primary;
  @override
  SwitchThemeData adapt(ThemeData theme, SwitchThemeData defaultValue) =>
      switch (theme.platform) {
        TargetPlatform.iOS || TargetPlatform.macOS => SwitchThemeData(
          trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? primary : null,
          ),
        ),
        _ => defaultValue,
      };
}
