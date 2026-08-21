import 'package:flutter/material.dart';

abstract final class PearlColors {
  static const Color canvas = Color(0xFFEEF6FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF7FBFF);
  static const Color ink = Color(0xFF163451);
  static const Color inkMuted = Color(0xFF698098);
  static const Color pine = Color(0xFF247BD1);
  static const Color pineBright = Color(0xFF1E6FBC);
  static const Color mint = Color(0xFFE7F3FF);
  static const Color copper = Color(0xFFE98938);
  static const Color copperSoft = Color(0xFFFFF5DD);
  static const Color success = Color(0xFF278E67);
  static const Color successSoft = Color(0xFFE7F6EF);
  static const Color warning = Color(0xFFAA7114);
  static const Color danger = Color(0xFFBF414A);
  static const Color dangerSoft = Color(0xFFFFF0F1);
  static const Color line = Color(0xFFD7E6F3);
  static const Color cardShadow = Color(0x12305E8B);
  static const Color heroShadow = Color(0x1C26537F);
}

ThemeData workshopPearlTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: PearlColors.pine,
    brightness: Brightness.light,
    primary: PearlColors.pine,
    secondary: PearlColors.pineBright,
    surface: PearlColors.surface,
    error: PearlColors.danger,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: PearlColors.canvas,
    fontFamily: 'Roboto',
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
  final textTheme = base.textTheme.copyWith(
    displaySmall: base.textTheme.displaySmall?.copyWith(
      color: PearlColors.ink,
      fontWeight: FontWeight.w800,
      height: 1.04,
      letterSpacing: -1.1,
    ),
    headlineLarge: base.textTheme.headlineLarge?.copyWith(
      color: PearlColors.ink,
      fontWeight: FontWeight.w800,
      height: 1.08,
      letterSpacing: -0.7,
    ),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      color: PearlColors.ink,
      fontWeight: FontWeight.w800,
      height: 1.1,
      letterSpacing: -0.45,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      color: PearlColors.ink,
      fontWeight: FontWeight.w700,
      height: 1.15,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      color: PearlColors.ink,
      fontWeight: FontWeight.w700,
      height: 1.2,
    ),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(
      color: PearlColors.ink,
      height: 1.45,
    ),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(
      color: PearlColors.inkMuted,
      height: 1.42,
    ),
    labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      letterSpacing: 0.1,
    ),
  );
  return base.copyWith(
    textTheme: textTheme,
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: PearlColors.surface,
      selectedColor: PearlColors.mint,
      side: const BorderSide(color: PearlColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      labelStyle: textTheme.labelLarge,
    ),
    dividerColor: PearlColors.line,
    cardTheme: const CardThemeData(
      color: PearlColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: PearlColors.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PearlColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: PearlColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: PearlColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: PearlColors.pine, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: PearlColors.danger),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PearlColors.pine,
        foregroundColor: Colors.white,
      minimumSize: const Size(48, 62),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: PearlColors.pine,
      minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        side: const BorderSide(color: PearlColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: PearlColors.pine,
        minimumSize: const Size(48, 48),
        textStyle: textTheme.labelLarge,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 56,
      elevation: 0,
      backgroundColor: PearlColors.surface.withValues(alpha: 0.97),
      indicatorColor: PearlColors.mint,
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
        (states) => textTheme.labelMedium?.copyWith(
          color: states.contains(WidgetState.selected)
              ? PearlColors.pine
              : PearlColors.inkMuted,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w600,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? PearlColors.pine
              : PearlColors.inkMuted,
        ),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: PearlColors.canvas,
      modalBackgroundColor: PearlColors.canvas,
      showDragHandle: true,
      dragHandleColor: PearlColors.line,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: PearlColors.canvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: PearlColors.ink,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
  );
}

class PearlCard extends StatelessWidget {
  const PearlCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? PearlColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PearlColors.line),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: PearlColors.cardShadow,
            offset: const Offset(0, 8),
            blurRadius: 22,
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return card;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: card,
        ),
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          if (trailing != null) trailing!,
        ],
      );
}

class CylinderGlyph extends StatelessWidget {
  const CylinderGlyph({
    super.key,
    this.size = 52,
    this.color = PearlColors.pine,
    this.background = PearlColors.mint,
  });

  final double size;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(size * 0.34),
        ),
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _CylinderPainter(color),
          ),
        ),
      );
}

class _CylinderPainter extends CustomPainter {
  const _CylinderPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.34,
        size.height * 0.27,
        size.width * 0.32,
        size.height * 0.54,
      ),
      Radius.circular(size.width * 0.13),
    );
    canvas.drawRRect(body, paint);
    canvas.drawLine(
      Offset(size.width * 0.43, size.height * 0.27),
      Offset(size.width * 0.43, size.height * 0.18),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.57, size.height * 0.27),
      Offset(size.width * 0.57, size.height * 0.18),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.41, size.height * 0.18),
      Offset(size.width * 0.59, size.height * 0.18),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.50, size.height * 0.18),
      Offset(size.width * 0.50, size.height * 0.11),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.46, size.height * 0.11),
      Offset(size.width * 0.54, size.height * 0.11),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CylinderPainter oldDelegate) => oldDelegate.color != color;
}
