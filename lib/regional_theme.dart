import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

// ============================================================
// 1. NE THEME DATA MODEL
// ============================================================

class NETheme {
  final String id;
  final String stateName;
  final String tagline;
  final Color primary;
  final Color primaryDark;
  final Color accent;
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color appBarColor;
  final Color cardBorder;
  final Color dividerColor;
  final List<Color> patternColors;
  final NEStateMotif motif;
  final String fontFamily;

  const NETheme({
    required this.id,
    required this.stateName,
    required this.tagline,
    required this.primary,
    required this.primaryDark,
    required this.accent,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.appBarColor,
    required this.cardBorder,
    required this.dividerColor,
    this.patternColors = const [],
    this.motif = NEStateMotif.none,
    this.fontFamily = 'Roboto',
  });

  /// Apply a Google Font to a base TextTheme.
  TextTheme _applyFont(TextTheme base) {
    switch (fontFamily) {
      case 'Lora': return GoogleFonts.loraTextTheme(base);
      case 'Open Sans': return GoogleFonts.openSansTextTheme(base);
      case 'Lato': return GoogleFonts.latoTextTheme(base);
      case 'PT Sans': return GoogleFonts.ptSansTextTheme(base);
      case 'Fira Sans': return GoogleFonts.firaSansTextTheme(base);
      case 'Mukta': return GoogleFonts.muktaTextTheme(base);
      case 'Noto Sans': return GoogleFonts.notoSansTextTheme(base);
      default: return base;
    }
  }

  ThemeData toThemeData() {
    final baseTextTheme = TextTheme().copyWith(
      headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: textPrimary),
      bodyMedium: TextStyle(color: textSecondary),
    );
    final themedTextTheme = _applyFont(baseTextTheme);
    final appBarTextStyle = GoogleFonts.getFont(
      fontFamily,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    );
    return ThemeData(
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: appBarColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: appBarTextStyle,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cardBorder.withValues(alpha: 0.4), width: 1.5),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: dividerColor.withValues(alpha: 0.3),
        thickness: 1,
      ),
      iconTheme: IconThemeData(color: primary),
      textTheme: themedTextTheme,
      colorScheme: ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        secondary: accent,
        surface: surface,
        onSurface: textPrimary,
      ),
    );
  }
}

enum NEStateMotif { none, assam, meghalaya, manipur, mizoram, nagaland, tripura, arunachal, sikkim }

// ============================================================
// 2. ALL 7 STATE THEMES
// ============================================================

class NEThemes {
  NEThemes._();

  static const assam = NETheme(
    id: 'assam',
    stateName: 'Assam',
    tagline: 'Land of Red Rivers & Blue Hills',
    primary: Color(0xFF1B4332),
    primaryDark: Color(0xFF0D2818),
    accent: Color(0xFFC1440E),
    background: Color(0xFFFDF8F0),
    surface: Color(0xFFFFFBF5),
    textPrimary: Color(0xFF2B2D42),
    textSecondary: Color(0xFF5C5C6D),
    appBarColor: Color(0xFF1B4332),
    cardBorder: Color(0xFFC1440E),
    dividerColor: Color(0xFF1B4332),
    patternColors: [Color(0xFFF5E6CA), Color(0xFFC1440E), Color(0xFF1B4332)],
    motif: NEStateMotif.assam,
    fontFamily: 'Lora',
  );

  static const meghalaya = NETheme(
    id: 'meghalaya',
    stateName: 'Meghalaya',
    tagline: 'Abode of Clouds',
    primary: Color(0xFF2D6A4F),
    primaryDark: Color(0xFF1B4332),
    accent: Color(0xFF40916C),
    background: Color(0xFFF0F5F1),
    surface: Color(0xFFF8FBF9),
    textPrimary: Color(0xFF1B3A2D),
    textSecondary: Color(0xFF4A6B5D),
    appBarColor: Color(0xFF2D6A4F),
    cardBorder: Color(0xFF40916C),
    dividerColor: Color(0xFF2D6A4F),
    patternColors: [Color(0xFFE8EFE9), Color(0xFF40916C), Color(0xFF2D6A4F)],
    motif: NEStateMotif.meghalaya,
    fontFamily: 'PT Sans',
  );

  static const manipur = NETheme(
    id: 'manipur',
    stateName: 'Manipur',
    tagline: 'Jewel of India',
    primary: Color(0xFF0077B6),
    primaryDark: Color(0xFF023E8A),
    accent: Color(0xFFFF70A6),
    background: Color(0xFFF4F8FB),
    surface: Color(0xFFFAFCFE),
    textPrimary: Color(0xFF0D1B2A),
    textSecondary: Color(0xFF3A5A7C),
    appBarColor: Color(0xFF0077B6),
    cardBorder: Color(0xFFFF70A6),
    dividerColor: Color(0xFF0077B6),
    patternColors: [Color(0xFFD4EAF7), Color(0xFFFF70A6), Color(0xFF0077B6)],
    motif: NEStateMotif.manipur,
    fontFamily: 'Fira Sans',
  );

  static const nagaland = NETheme(
    id: 'nagaland',
    stateName: 'Nagaland',
    tagline: 'Land of Festivals',
    primary: Color(0xFF9E2A2B),
    primaryDark: Color(0xFF6A1B1C),
    accent: Color(0xFFF4A261),
    background: Color(0xFFFBF6F0),
    surface: Color(0xFFFFFDFB),
    textPrimary: Color(0xFF14213D),
    textSecondary: Color(0xFF5A4A42),
    appBarColor: Color(0xFF9E2A2B),
    cardBorder: Color(0xFFF4A261),
    dividerColor: Color(0xFF9E2A2B),
    patternColors: [Color(0xFFFFF0E0), Color(0xFFF4A261), Color(0xFF9E2A2B)],
    motif: NEStateMotif.nagaland,
    fontFamily: 'Fira Sans',
  );

  static const sikkim = NETheme(
    id: 'sikkim',
    stateName: 'Sikkim',
    tagline: 'Mystical Mountain Kingdom',
    primary: Color(0xFF003566),
    primaryDark: Color(0xFF001845),
    accent: Color(0xFF780000),
    background: Color(0xFFF5F7FA),
    surface: Color(0xFFFCFDFE),
    textPrimary: Color(0xFF0D1B2A),
    textSecondary: Color(0xFF3A506B),
    appBarColor: Color(0xFF003566),
    cardBorder: Color(0xFFC9A959),
    dividerColor: Color(0xFF003566),
    patternColors: [Color(0xFFE8EDF4), Color(0xFF780000), Color(0xFFC9A959)],
    motif: NEStateMotif.sikkim,
    fontFamily: 'Lato',
  );

  static const tripura = NETheme(
    id: 'tripura',
    stateName: 'Tripura',
    tagline: 'Land of Fourteen Gods',
    primary: Color(0xFF2D6A4F),
    primaryDark: Color(0xFF1B4332),
    accent: Color(0xFFBA181B),
    background: Color(0xFFF2F7F0),
    surface: Color(0xFFF9FCF8),
    textPrimary: Color(0xFF1A2E1A),
    textSecondary: Color(0xFF4A6B4A),
    appBarColor: Color(0xFF2D6A4F),
    cardBorder: Color(0xFFA3B18A),
    dividerColor: Color(0xFF2D6A4F),
    patternColors: [Color(0xFFDDE8D4), Color(0xFFBA181B), Color(0xFFA3B18A)],
    motif: NEStateMotif.tripura,
    fontFamily: 'Carlito',
  );

  static const mizoram = NETheme(
    id: 'mizoram',
    stateName: 'Mizoram',
    tagline: 'Land of the Hill People',
    primary: Color(0xFF2A9D8F),
    primaryDark: Color(0xFF1A6B60),
    accent: Color(0xFFB7094C),
    background: Color(0xFFF0F7F6),
    surface: Color(0xFFF8FCFB),
    textPrimary: Color(0xFF101010),
    textSecondary: Color(0xFF3A5A54),
    appBarColor: Color(0xFF2A9D8F),
    cardBorder: Color(0xFFB7094C),
    dividerColor: Color(0xFF2A9D8F),
    patternColors: [Color(0xFFD4EDE9), Color(0xFFB7094C), Color(0xFF2A9D8F)],
    motif: NEStateMotif.mizoram,
    fontFamily: 'Mukta',
  );

  static const arunachal = NETheme(
    id: 'arunachal',
    stateName: 'Arunachal Pradesh',
    tagline: 'Land of the Dawn-Lit Mountains',
    primary: Color(0xFF2D5A27),
    primaryDark: Color(0xFF1A3A18),
    accent: Color(0xFFE07A5F),
    background: Color(0xFFF3F7F4),
    surface: Color(0xFFFAFCFA),
    textPrimary: Color(0xFF1A2E1A),
    textSecondary: Color(0xFF4A6048),
    appBarColor: Color(0xFF2D5A27),
    cardBorder: Color(0xFFE07A5F),
    dividerColor: Color(0xFF2D5A27),
    patternColors: [Color(0xFFDDE8D4), Color(0xFFE07A5F), Color(0xFF2D5A27)],
    motif: NEStateMotif.arunachal,
    fontFamily: 'Noto Sans',
  );

  static const List<NETheme> all = [
    assam, meghalaya, manipur, nagaland,
    sikkim, tripura, mizoram, arunachal,
  ];

  static NETheme getById(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => assam);
}

// ============================================================
// 3. THEME PROVIDER (InheritedNotifier)
// ============================================================

class NEThemeNotifier extends ChangeNotifier {
  NETheme _current;
  NETheme _previous;

  NEThemeNotifier({NETheme initial = NEThemes.assam})
      : _current = initial,
        _previous = initial;

  NETheme get current => _current;
  NETheme get previous => _previous;

  void setTheme(NETheme theme) {
    if (_current.id != theme.id) {
      _previous = _current;
      _current = theme;
      notifyListeners();
    }
  }

  void setThemeById(String id) {
    setTheme(NEThemes.getById(id));
  }
}

class NEThemeScope extends InheritedNotifier<NEThemeNotifier> {
  const NEThemeScope({
    super.key,
    required NEThemeNotifier notifier,
    required super.child,
  }) : super(notifier: notifier);

  static NETheme of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<NEThemeScope>()!
        .notifier!
        .current;
  }

  static NEThemeNotifier ofNotifier(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<NEThemeScope>()!
        .notifier!;
  }
}

// ============================================================
// 4. CULTURAL MOTIF PAINTERS (CustomPainter)
// ============================================================

/// Draws delicate geometric border patterns inspired by NE textiles
class WeaveBorderPainter extends CustomPainter {
  final Color color;
  final double borderWidth;
  final NEStateMotif motif;

  WeaveBorderPainter({
    required this.color,
    this.borderWidth = 3.0,
    this.motif = NEStateMotif.none,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    // Draw weave-inspired geometric border
    final double step = 12.0;
    final double inset = borderWidth;

    // Top border - zigzag weave
    for (double x = inset; x < size.width - inset; x += step) {
      final double y = inset;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + step / 2, y + step / 3),
        paint,
      );
      canvas.drawLine(
        Offset(x + step / 2, y + step / 3),
        Offset(x + step, y),
        paint,
      );
    }

    // Bottom border
    for (double x = inset; x < size.width - inset; x += step) {
      final double y = size.height - inset;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + step / 2, y - step / 3),
        paint,
      );
      canvas.drawLine(
        Offset(x + step / 2, y - step / 3),
        Offset(x + step, y),
        paint,
      );
    }

    // Left border - vertical weave
    for (double y = inset; y < size.height - inset; y += step) {
      final double x = inset;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + step / 3, y + step / 2),
        paint,
      );
      canvas.drawLine(
        Offset(x + step / 3, y + step / 2),
        Offset(x, y + step),
        paint,
      );
    }

    // Right border
    for (double y = inset; y < size.height - inset; y += step) {
      final double x = size.width - inset;
      canvas.drawLine(
        Offset(x, y),
        Offset(x - step / 3, y + step / 2),
        paint,
      );
      canvas.drawLine(
        Offset(x - step / 3, y + step / 2),
        Offset(x, y + step),
        paint,
      );
    }

    // Corner accents
    _drawCornerMotif(canvas, Offset(inset + 4, inset + 4), color, size: 16);
    _drawCornerMotif(canvas, Offset(size.width - inset - 20, inset + 4), color, size: 16);
    _drawCornerMotif(canvas, Offset(inset + 4, size.height - inset - 20), color, size: 16);
    _drawCornerMotif(canvas, Offset(size.width - inset - 20, size.height - inset - 20), color, size: 16);
  }

  void _drawCornerMotif(Canvas canvas, Offset offset, Color color, {double size = 16}) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Small diamond motif at corners
    final path = Path()
      ..moveTo(offset.dx + size / 2, offset.dy)
      ..lineTo(offset.dx + size, offset.dy + size / 2)
      ..lineTo(offset.dx + size / 2, offset.dy + size)
      ..lineTo(offset.dx, offset.dy + size / 2)
      ..close();
    canvas.drawPath(path, paint);

    // Inner dot
    final dotPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(offset + Offset(size / 2, size / 2), 2, dotPaint);
  }

  @override
  bool shouldRepaint(covariant WeaveBorderPainter oldDelegate) =>
      color != oldDelegate.color || motif != oldDelegate.motif;
}

/// Draws watermark cultural motifs in corners/margins
class CulturalWatermarkPainter extends CustomPainter {
  final NEStateMotif motif;
  final Color color;
  final Color accentColor;
  final double opacity;

  CulturalWatermarkPainter({
    required this.motif,
    required this.color,
    this.accentColor = const Color(0xFF000000),
    this.opacity = 0.30,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: opacity * 0.5)
      ..style = PaintingStyle.fill;

    final accentFill = Paint()
      ..color = accentColor.withValues(alpha: opacity * 0.6)
      ..style = PaintingStyle.fill;

    final accentStroke = Paint()
      ..color = accentColor.withValues(alpha: opacity * 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final thinPaint = Paint()
      ..color = color.withValues(alpha: opacity * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // All motifs placed bottom-right with -15px bleed
    final anchor = Offset(size.width - 15, size.height - 15);

    switch (motif) {
      case NEStateMotif.assam:
        _drawAssamRhino(canvas, anchor, paint, fillPaint, thinPaint, accentFill, accentStroke);
        break;
      case NEStateMotif.meghalaya:
        _drawMeghalayaRootBridge(canvas, anchor, paint, fillPaint, thinPaint, accentFill, accentStroke);
        break;
      case NEStateMotif.manipur:
        _drawManipurDancer(canvas, anchor, paint, fillPaint, thinPaint, accentFill, accentStroke);
        break;
      case NEStateMotif.nagaland:
        _drawNagalandHornbill(canvas, anchor, paint, fillPaint, thinPaint, accentFill, accentStroke);
        break;
      case NEStateMotif.sikkim:
        _drawSikkimBuddha(canvas, anchor, paint, fillPaint, thinPaint, accentFill, accentStroke);
        break;
      case NEStateMotif.tripura:
        _drawTripuraPalace(canvas, anchor, paint, fillPaint, thinPaint, accentFill, accentStroke);
        break;
      case NEStateMotif.mizoram:
        _drawMizoramHills(canvas, anchor, paint, fillPaint, thinPaint, accentFill, accentStroke);
        break;
      case NEStateMotif.arunachal:
        _drawArunachalMonastery(canvas, anchor, paint, fillPaint, thinPaint, accentFill, accentStroke);
        break;
      case NEStateMotif.none:
        break;
    }
  }

  // ==== ASSAM: One-horned Rhinoceros + tea leaves + Jaapi hat ====
  void _drawAssamRhino(Canvas canvas, Offset a, Paint p, Paint f, Paint t, Paint af, Paint as2) {
    // Scale up for vibrancy
    canvas.save();
    canvas.translate(a.dx - 80, a.dy - 60);
    canvas.scale(1.3);
    final ox = a.dx - 160;
    final oy = a.dy - 120;
    // Rhino body — organic curved silhouette
    final rhino = Path()
      ..moveTo(ox, oy + 50) // chin
      ..lineTo(ox + 6, oy + 30) // horn tip
      ..lineTo(ox + 12, oy + 38)
      ..lineTo(ox + 18, oy + 25) // forehead
      ..quadraticBezierTo(ox + 28, oy + 18, ox + 38, oy + 20) // head back
      ..quadraticBezierTo(ox + 50, oy + 15, ox + 60, oy + 10) // neck
      ..quadraticBezierTo(ox + 80, oy, ox + 100, oy + 5) // back hump
      ..quadraticBezierTo(ox + 120, oy + 2, ox + 135, oy + 10) // rear hump
      ..lineTo(ox + 140, oy + 25) // rump
      ..lineTo(ox + 135, oy + 45) // back leg top
      ..lineTo(ox + 125, oy + 50) // back leg bottom
      ..lineTo(ox + 115, oy + 45)
      ..lineTo(ox + 110, oy + 50) // belly
      ..lineTo(ox + 65, oy + 50) // belly
      ..lineTo(ox + 58, oy + 45)
      ..lineTo(ox + 50, oy + 50) // front leg bottom
      ..lineTo(ox + 42, oy + 45)
      ..lineTo(ox + 38, oy + 50)
      ..lineTo(ox + 15, oy + 50) // chest
      ..close();
    canvas.drawPath(rhino, f);
    canvas.drawPath(rhino, p);
    // Eye
    canvas.drawCircle(Offset(ox + 22, oy + 30), 2, p);
    // Ear
    canvas.drawArc(
      Rect.fromCenter(center: Offset(ox + 30, oy + 20), width: 6, height: 8),
      0, math.pi * 1.5, false, p);

    // Jaapi hat outline above rhino
    final jaapiCx = ox + 70;
    final jaapiCy = oy - 15;
    final jaapi = Path()
      ..moveTo(jaapiCx - 22, jaapiCy + 8)
      ..quadraticBezierTo(jaapiCx - 10, jaapiCy - 12, jaapiCx, jaapiCy - 16)
      ..quadraticBezierTo(jaapiCx + 10, jaapiCy - 12, jaapiCx + 22, jaapiCy + 8)
      ..lineTo(jaapiCx + 18, jaapiCy + 10)
      ..quadraticBezierTo(jaapiCx, jaapiCy - 4, jaapiCx - 18, jaapiCy + 10)
      ..close();
    canvas.drawPath(jaapi, t);
    // Jaapi geometric cross pattern
    canvas.drawLine(Offset(jaapiCx, jaapiCy - 14), Offset(jaapiCx, jaapiCy + 6), t);
    canvas.drawLine(Offset(jaapiCx - 12, jaapiCy), Offset(jaapiCx + 12, jaapiCy), t);

    // Tea leaf accents scattered
    for (int i = 0; i < 4; i++) {
      final lx = ox + 150 + i * 12;
      final ly = oy + 35 + (i.isEven ? 0 : 8);
      final leaf = Path()
        ..moveTo(lx, ly)
        ..quadraticBezierTo(lx + 6, ly - 8, lx + 10, ly)
        ..quadraticBezierTo(lx + 6, ly + 3, lx, ly);
      canvas.drawPath(leaf, af);
      canvas.drawPath(leaf, as2);
    }
    // Accent ground line
    canvas.drawLine(Offset(ox - 10, oy + 55), Offset(ox + 180, oy + 55), as2);
    canvas.restore();
  }

  // ==== MEGHALAYA: Living Root Bridge + waterfall + clouds ====
  void _drawMeghalayaRootBridge(Canvas canvas, Offset a, Paint p, Paint f, Paint t, Paint af, Paint as2) {
    canvas.save();
    canvas.translate(a.dx - 70, a.dy - 55);
    canvas.scale(1.3);
    final ox = a.dx - 150;
    final oy = a.dy - 110;

    // Living root bridge — two tree trunks with arching roots
    // Left trunk
    canvas.drawLine(Offset(ox, oy + 60), Offset(ox, oy), t);
    canvas.drawLine(Offset(ox + 5, oy + 60), Offset(ox + 5, oy + 5), t);
    // Right trunk
    canvas.drawLine(Offset(ox + 100, oy + 60), Offset(ox + 100, oy + 5), t);
    canvas.drawLine(Offset(ox + 105, oy + 60), Offset(ox + 105, oy + 5), t);
    // Root bridge arch
    final rootPath = Path()
      ..moveTo(ox + 2, oy + 15)
      ..quadraticBezierTo(ox + 30, oy + 30, ox + 52, oy + 25)
      ..quadraticBezierTo(ox + 75, oy + 20, ox + 102, oy + 15);
    canvas.drawPath(rootPath, p);
    // Hanging root tendrils
    for (int i = 0; i < 5; i++) {
      final rx = ox + 15 + i * 18;
      final ry = oy + 22 + (i % 2) * 5;
      canvas.drawLine(Offset(rx, ry), Offset(rx + 2, ry + 12), t);
    }
    // Bridge planks
    for (int i = 0; i < 5; i++) {
      final px = ox + 10 + i * 20;
      canvas.drawRect(Rect.fromLTWH(px, oy + 26, 14, 3), t);
    }

    // Waterfall lines cascading down left side
    for (int i = 0; i < 4; i++) {
      final wx = ox - 20 - i * 6;
      final waterfall = Path()
        ..moveTo(wx, oy)
        ..quadraticBezierTo(wx + 5, oy + 20, wx, oy + 40)
        ..quadraticBezierTo(wx - 5, oy + 55, wx, oy + 70)
        ..quadraticBezierTo(wx + 4, oy + 80, wx, oy + 90);
      canvas.drawPath(waterfall, t);
    }

    // Cloud outlines top-right — filled for vibrancy
    final cloudOx = ox + 110;
    final cloudOy = oy - 10;
    final cloud = Path()
      ..moveTo(cloudOx, cloudOy + 15)
      ..quadraticBezierTo(cloudOx - 5, cloudOy + 5, cloudOx + 5, cloudOy)
      ..quadraticBezierTo(cloudOx + 15, cloudOy - 5, cloudOx + 25, cloudOy + 2)
      ..quadraticBezierTo(cloudOx + 35, cloudOy - 3, cloudOx + 40, cloudOy + 8)
      ..quadraticBezierTo(cloudOx + 48, cloudOy + 5, cloudOx + 45, cloudOy + 15)
      ..close();
    canvas.drawPath(cloud, af);
    canvas.drawPath(cloud, as2);
    canvas.restore();
  }

  // ==== MANIPUR: Raas Leela dancer + Loktak Lake ripples ====
  void _drawManipurDancer(Canvas canvas, Offset a, Paint p, Paint f, Paint t, Paint af, Paint as2) {
    canvas.save();
    canvas.translate(a.dx - 50, a.dy - 65);
    canvas.scale(1.3);
    final ox = a.dx - 100;
    final oy = a.dy - 130;

    // Dancer silhouette — graceful standing pose
    // Head
    canvas.drawCircle(Offset(ox + 50, oy + 10), 8, t);
    // Crown / headpiece
    final crown = Path()
      ..moveTo(ox + 44, oy + 5)
      ..lineTo(ox + 50, oy - 5)
      ..lineTo(ox + 56, oy + 5);
    canvas.drawPath(crown, t);
    // Neck
    canvas.drawLine(Offset(ox + 50, oy + 18), Offset(ox + 50, oy + 24), t);
    // Torso — flowing dress
    final torso = Path()
      ..moveTo(ox + 44, oy + 24)
      ..lineTo(ox + 42, oy + 50)
      ..quadraticBezierTo(ox + 35, oy + 80, ox + 30, oy + 95) // flowing skirt left
      ..lineTo(ox + 70, oy + 95) // skirt bottom
      ..quadraticBezierTo(ox + 65, oy + 80, ox + 58, oy + 50) // skirt right
      ..lineTo(ox + 56, oy + 24)
      ..close();
    canvas.drawPath(torso, t);
    // Arms extended in dance
    canvas.drawLine(Offset(ox + 44, oy + 30), Offset(ox + 22, oy + 22), t);
    canvas.drawLine(Offset(ox + 56, oy + 30), Offset(ox + 78, oy + 22), t);
    // Hands with graceful mudra
    canvas.drawCircle(Offset(ox + 22, oy + 22), 3, t);
    canvas.drawCircle(Offset(ox + 78, oy + 22), 3, t);
    // Skirt pleats
    for (int i = 0; i < 5; i++) {
      final sx = ox + 36 + i * 7;
      canvas.drawLine(Offset(sx, oy + 50), Offset(sx - 2 + i * 0.5, oy + 93), t);
    }

    // Loktak Lake water ripples below
    for (int i = 0; i < 4; i++) {
      final ry = oy + 105 + i * 10;
      final ripple = Path()
        ..moveTo(ox + 20, ry)
        ..quadraticBezierTo(ox + 50, ry + (i.isEven ? 6 : -4), ox + 80, ry)
        ..quadraticBezierTo(ox + 50, ry + (i.isEven ? -3 : 5), ox + 20, ry);
      canvas.drawPath(ripple, t);
    }
    // Phumdi (floating vegetation island) — accent colored for vibrancy
    final phumdi = Path()
      ..moveTo(ox + 35, oy + 110)
      ..quadraticBezierTo(ox + 50, oy + 104, ox + 65, oy + 110)
      ..quadraticBezierTo(ox + 50, oy + 114, ox + 35, oy + 110);
    canvas.drawPath(phumdi, af);
    canvas.drawPath(phumdi, as2);
    canvas.restore();
  }

  // ==== NAGALAND: Great Hornbill in flight + spear accents ====
  void _drawNagalandHornbill(Canvas canvas, Offset a, Paint p, Paint f, Paint t, Paint af, Paint as2) {
    canvas.save();
    canvas.translate(a.dx - 70, a.dy - 50);
    canvas.scale(1.3);
    final ox = a.dx - 140;
    final oy = a.dy - 100;

    // Hornbill body
    final body = Path()
      ..moveTo(ox + 20, oy + 30) // beak tip
      ..lineTo(ox + 5, oy + 25) // lower beak
      ..lineTo(ox + 10, oy + 35) // throat
      ..quadraticBezierTo(ox + 25, oy + 50, ox + 55, oy + 45) // belly
      ..quadraticBezierTo(ox + 80, oy + 42, ox + 100, oy + 35) // tail
      ..lineTo(ox + 105, oy + 30) // tail tip
      ..lineTo(ox + 100, oy + 25)
      ..quadraticBezierTo(ox + 75, oy + 18, ox + 50, oy + 15) // back
      ..quadraticBezierTo(ox + 35, oy + 12, ox + 20, oy + 20) // head
      ..close();
    canvas.drawPath(body, f);
    canvas.drawPath(body, p);

    // Casque (hornbill helmet) on head
    final casque = Path()
      ..moveTo(ox + 18, oy + 20)
      ..quadraticBezierTo(ox + 22, oy + 5, ox + 35, oy + 10)
      ..quadraticBezierTo(ox + 28, oy + 12, ox + 18, oy + 20);
    canvas.drawPath(casque, f);
    canvas.drawPath(casque, p);

    // Eye
    canvas.drawCircle(Offset(ox + 22, oy + 26), 2, p);

    // Wings spread — left wing up, right wing down
    final leftWing = Path()
      ..moveTo(ox + 45, oy + 18)
      ..quadraticBezierTo(ox + 30, oy - 10, ox + 15, oy - 15)
      ..lineTo(ox + 20, oy - 5)
      ..quadraticBezierTo(ox + 35, oy + 5, ox + 50, oy + 15);
    canvas.drawPath(leftWing, p);
    // Wing feather lines
    for (int i = 0; i < 4; i++) {
      final fx = ox + 20 + i * 8;
      final fy = oy - 10 + i * 5;
      canvas.drawLine(Offset(fx, fy), Offset(fx - 3, fy + 8), t);
    }

    // Traditional spear accent lines
    final spearX = ox + 120;
    canvas.drawLine(Offset(spearX, oy + 5), Offset(spearX, oy + 55), p);
    // Spear tip
    final spearTip = Path()
      ..moveTo(spearX - 4, oy + 5)
      ..lineTo(spearX, oy - 5)
      ..lineTo(spearX + 4, oy + 5)
      ..close();
    canvas.drawPath(spearTip, f);
    // Spear shaft decoration
    canvas.drawLine(Offset(spearX - 3, oy + 15), Offset(spearX + 3, oy + 15), t);
    canvas.drawLine(Offset(spearX - 3, oy + 20), Offset(spearX + 3, oy + 20), t);

    // Tribal geometric diamond border at bottom — accent colored
    for (int i = 0; i < 6; i++) {
      final dx = ox + i * 20;
      final dy = oy + 65;
      final diamond = Path()
        ..moveTo(dx, dy)
        ..lineTo(dx + 6, dy + 6)
        ..lineTo(dx, dy + 12)
        ..lineTo(dx - 6, dy + 6)
        ..close();
      canvas.drawPath(diamond, af);
      canvas.drawPath(diamond, as2);
    }
    canvas.restore();
  }

  // ==== SIKKIM: Meditating Buddha + Himalayan peaks ====
  void _drawSikkimBuddha(Canvas canvas, Offset a, Paint p, Paint f, Paint t, Paint af, Paint as2) {
    canvas.save();
    canvas.translate(a.dx - 55, a.dy - 60);
    canvas.scale(1.3);
    final ox = a.dx - 110;
    final oy = a.dy - 120;

    // Buddha seated in lotus position — elegant silhouette
    // Head
    canvas.drawCircle(Offset(ox + 50, oy + 15), 10, t);
    // Ushnisha (crown bump)
    canvas.drawCircle(Offset(ox + 50, oy + 4), 5, t);
    // Halo
    canvas.drawCircle(Offset(ox + 50, oy + 15), 18, t);
    // Neck
    canvas.drawLine(Offset(ox + 50, oy + 25), Offset(ox + 50, oy + 32), t);
    // Shoulders
    canvas.drawLine(Offset(ox + 50, oy + 32), Offset(ox + 30, oy + 40), t);
    canvas.drawLine(Offset(ox + 50, oy + 32), Offset(ox + 70, oy + 40), t);
    // Torso
    final torso = Path()
      ..moveTo(ox + 30, oy + 40)
      ..lineTo(ox + 28, oy + 55)
      ..quadraticBezierTo(ox + 35, oy + 70, ox + 50, oy + 72)
      ..quadraticBezierTo(ox + 65, oy + 70, ox + 72, oy + 55)
      ..lineTo(ox + 70, oy + 40)
      ..close();
    canvas.drawPath(torso, t);
    // Crossed legs (lotus)
    final legs = Path()
      ..moveTo(ox + 25, oy + 68)
      ..quadraticBezierTo(ox + 40, oy + 80, ox + 50, oy + 78)
      ..quadraticBezierTo(ox + 60, oy + 80, ox + 75, oy + 68)
      ..lineTo(ox + 70, oy + 72)
      ..quadraticBezierTo(ox + 55, oy + 82, ox + 50, oy + 82)
      ..quadraticBezierTo(ox + 45, oy + 82, ox + 30, oy + 72)
      ..close();
    canvas.drawPath(legs, t);
    // Hands in dhyana mudra
    canvas.drawCircle(Offset(ox + 50, oy + 62), 5, t);

    // Himalayan mountain peaks in background
    final mtn = Path()
      ..moveTo(ox - 10, oy + 85)
      ..lineTo(ox + 15, oy + 45)
      ..lineTo(ox + 30, oy + 60)
      ..lineTo(ox + 50, oy + 30)
      ..lineTo(ox + 70, oy + 55)
      ..lineTo(ox + 85, oy + 40)
      ..lineTo(ox + 110, oy + 85)
      ..close();
    canvas.drawPath(mtn, t);
    // Snow caps on tallest peaks
    canvas.drawLine(Offset(ox + 46, oy + 38), Offset(ox + 50, oy + 30), t);
    canvas.drawLine(Offset(ox + 54, oy + 38), Offset(ox + 50, oy + 30), t);
    canvas.drawLine(Offset(ox + 81, oy + 48), Offset(ox + 85, oy + 40), t);
    canvas.drawLine(Offset(ox + 89, oy + 48), Offset(ox + 85, oy + 40), t);
    // Accent snow caps
    canvas.drawLine(Offset(ox + 46, oy + 38), Offset(ox + 50, oy + 30), as2);
    canvas.drawLine(Offset(ox + 54, oy + 38), Offset(ox + 50, oy + 30), as2);
    canvas.restore();
  }

  // ==== TRIPURA: Neermahal Water Palace + bamboo weave ====
  void _drawTripuraPalace(Canvas canvas, Offset a, Paint p, Paint f, Paint t, Paint af, Paint as2) {
    canvas.save();
    canvas.translate(a.dx - 70, a.dy - 55);
    canvas.scale(1.3);
    final ox = a.dx - 140;
    final oy = a.dy - 110;

    // Palace main body
    canvas.drawRect(Rect.fromLTWH(ox + 15, oy + 30, 80, 40), t);
    // Central dome
    canvas.drawArc(
      Rect.fromCenter(center: Offset(ox + 55, oy + 30), width: 40, height: 30),
      math.pi, math.pi, false, p);
    // Dome spire
    canvas.drawLine(Offset(ox + 55, oy + 15), Offset(ox + 55, oy + 5), t);
    canvas.drawCircle(Offset(ox + 55, oy + 3), 3, f);
    // Side towers
    canvas.drawRect(Rect.fromLTWH(ox + 10, oy + 20, 15, 50), t);
    canvas.drawRect(Rect.fromLTWH(ox + 85, oy + 20, 15, 50), t);
    // Tower tops
    canvas.drawArc(
      Rect.fromCenter(center: Offset(ox + 17, oy + 20), width: 14, height: 10),
      math.pi, math.pi, false, t);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(ox + 92, oy + 20), width: 14, height: 10),
      math.pi, math.pi, false, t);
    // Arched windows
    for (int i = 0; i < 3; i++) {
      final wx = ox + 30 + i * 22;
      canvas.drawArc(
        Rect.fromCenter(center: Offset(wx, oy + 42), width: 12, height: 10),
        math.pi, math.pi, false, t);
      canvas.drawLine(Offset(wx - 6, oy + 42), Offset(wx - 6, oy + 52), t);
      canvas.drawLine(Offset(wx + 6, oy + 42), Offset(wx + 6, oy + 52), t);
    }
    // Water reflection lines
    for (int i = 0; i < 3; i++) {
      final ry = oy + 75 + i * 8;
      final ripple = Path()
        ..moveTo(ox + 10, ry)
        ..quadraticBezierTo(ox + 55, ry + (i.isEven ? 4 : -3), ox + 100, ry);
      canvas.drawPath(ripple, t);
    }
    // Bamboo weave pattern border at bottom-right
    final bwX = ox + 105;
    final bwY = oy + 50;
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 3; j++) {
        canvas.drawRect(Rect.fromLTWH(bwX + i * 8, bwY + j * 8, 6, 6), af);
      }
    }
    canvas.restore();
  }

  // ==== MIZORAM: Hill contours + Cheraw bamboo sticks ====
  void _drawMizoramHills(Canvas canvas, Offset a, Paint p, Paint f, Paint t, Paint af, Paint as2) {
    canvas.save();
    canvas.translate(a.dx - 70, a.dy - 50);
    canvas.scale(1.3);
    final ox = a.dx - 140;
    final oy = a.dy - 100;

    // Rolling hill contour lines
    for (int h = 0; h < 3; h++) {
      final hillY = oy + 30 + h * 20;
      final hill = Path()
        ..moveTo(ox, hillY + 15)
        ..quadraticBezierTo(ox + 30, hillY - 5, ox + 60, hillY + 5)
        ..quadraticBezierTo(ox + 90, hillY + 15, ox + 120, hillY)
        ..quadraticBezierTo(ox + 140, hillY - 8, ox + 160, hillY + 10);
      canvas.drawPath(hill, t);
    }

    // Cheraw bamboo dance sticks — two pairs of crossed sticks
    final cx = ox + 55;
    final cy = oy + 80;
    // Horizontal sticks
    canvas.drawLine(Offset(cx - 30, cy), Offset(cx + 30, cy), p);
    canvas.drawLine(Offset(cx - 30, cy + 10), Offset(cx + 30, cy + 10), p);
    // Vertical sticks being held
    canvas.drawLine(Offset(cx - 10, cy - 15), Offset(cx - 10, cy + 25), p);
    canvas.drawLine(Offset(cx + 10, cy - 15), Offset(cx + 10, cy + 25), p);
    // Stick grip marks
    canvas.drawCircle(Offset(cx - 10, cy - 12), 2, f);
    canvas.drawCircle(Offset(cx + 10, cy - 12), 2, f);
    canvas.drawCircle(Offset(cx - 10, cy + 22), 2, f);
    canvas.drawCircle(Offset(cx + 10, cy + 22), 2, f);

    // Puan fabric geometric border at very bottom
    for (int i = 0; i < 8; i++) {
      final px = ox + i * 18;
      final py = oy + 100;
      final diamond = Path()
        ..moveTo(px, py)
        ..lineTo(px + 7, py + 5)
        ..lineTo(px, py + 10)
        ..lineTo(px - 7, py + 5)
        ..close();
      canvas.drawPath(diamond, i.isEven ? af : t);
    }
    canvas.restore();
  }

  // ==== ARUNACHAL: Monastery pagoda + sunrise + mountains ====
  void _drawArunachalMonastery(Canvas canvas, Offset a, Paint p, Paint f, Paint t, Paint af, Paint as2) {
    canvas.save();
    canvas.translate(a.dx - 65, a.dy - 60);
    canvas.scale(1.3);
    final ox = a.dx - 130;
    final oy = a.dy - 120;

    // Mountain silhouette background
    final mtn = Path()
      ..moveTo(ox, oy + 80)
      ..lineTo(ox + 20, oy + 40)
      ..lineTo(ox + 40, oy + 55)
      ..lineTo(ox + 60, oy + 25)
      ..lineTo(ox + 80, oy + 50)
      ..lineTo(ox + 100, oy + 35)
      ..lineTo(ox + 130, oy + 80)
      ..close();
    canvas.drawPath(mtn, t);

    // Sun rays rising behind mountains
    final sunCenter = Offset(ox + 60, oy + 35);
    canvas.drawCircle(sunCenter, 10, t);
    for (int i = 0; i < 8; i++) {
      final angle = -math.pi / 2 + (i - 3.5) * 0.25;
      final startR = 14;
      final endR = 28;
      canvas.drawLine(
        Offset(sunCenter.dx + math.cos(angle) * startR, sunCenter.dy + math.sin(angle) * startR),
        Offset(sunCenter.dx + math.cos(angle) * endR, sunCenter.dy + math.sin(angle) * endR),
        t);
    }

    // Tawang Monastery pagoda — multi-tiered roof
    final mx = ox + 55;
    final my = oy + 85;
    // Base building
    canvas.drawRect(Rect.fromLTWH(mx - 18, my, 36, 20), t);
    // First roof tier
    final roof1 = Path()
      ..moveTo(mx - 25, my)
      ..lineTo(mx, my - 12)
      ..lineTo(mx + 25, my)
      ..close();
    canvas.drawPath(roof1, t);
    // Second roof tier
    final roof2 = Path()
      ..moveTo(mx - 18, my - 12)
      ..lineTo(mx, my - 22)
      ..lineTo(mx + 18, my - 12)
      ..close();
    canvas.drawPath(roof2, t);
    // Top spire
    canvas.drawLine(Offset(mx, my - 22), Offset(mx, my - 32), t);
    canvas.drawCircle(Offset(mx, my - 34), 3, f);
    // Windows
    canvas.drawRect(Rect.fromLTWH(mx - 10, my + 5, 7, 10), af);
    canvas.drawRect(Rect.fromLTWH(mx + 3, my + 5, 7, 10), af);
    // Accent sun rays
    canvas.drawCircle(sunCenter, 6, af);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CulturalWatermarkPainter oldDelegate) =>
      motif != oldDelegate.motif || color != oldDelegate.color || accentColor != oldDelegate.accentColor;
}

// ============================================================
// 4b. TEXTILE / SAREE WEAVE BACKGROUND PAINTER
// ============================================================

class TextileWeavePainter extends CustomPainter {
  final NEStateMotif motif;
  final Color color;
  final double opacity;

  TextileWeavePainter({
    required this.motif,
    required this.color,
    this.opacity = 0.09,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: opacity * 0.7)
      ..style = PaintingStyle.fill;

    switch (motif) {
      case NEStateMotif.assam:
        _drawAssamGamucha(canvas, size, paint, fillPaint);
        break;
      case NEStateMotif.meghalaya:
        _drawMeghalayaWeave(canvas, size, paint, fillPaint);
        break;
      case NEStateMotif.manipur:
        _drawManipurShaphee(canvas, size, paint, fillPaint);
        break;
      case NEStateMotif.nagaland:
        _drawNagalandShawl(canvas, size, paint, fillPaint);
        break;
      case NEStateMotif.sikkim:
        _drawSikkimPrayer(canvas, size, paint, fillPaint);
        break;
      case NEStateMotif.tripura:
        _drawTripuraRisa(canvas, size, paint, fillPaint);
        break;
      case NEStateMotif.mizoram:
        _drawMizoramPuan(canvas, size, paint, fillPaint);
        break;
      case NEStateMotif.arunachal:
        _drawArunachalHandloom(canvas, size, paint, fillPaint);
        break;
      case NEStateMotif.none:
        break;
    }
  }

  // ---- ASSAM: Gamucha red-white checkered border weave ----
  void _drawAssamGamucha(Canvas canvas, Size size, Paint paint, Paint fill) {
    final double cell = 24.0;
    // Top edge gamucha strip
    for (double x = 0; x < size.width; x += cell) {
      final int col = (x / cell).floor();
      if (col % 2 == 0) {
        canvas.drawRect(Rect.fromLTWH(x, 0, cell, 4), fill);
      } else {
        canvas.drawRect(Rect.fromLTWH(x, 0, cell, 4), paint);
      }
    }
    // Bottom edge gamucha strip
    for (double x = 0; x < size.width; x += cell) {
      final int col = (x / cell).floor();
      if (col % 2 == 0) {
        canvas.drawRect(Rect.fromLTWH(x, size.height - 4, cell, 4), fill);
      } else {
        canvas.drawRect(Rect.fromLTWH(x, size.height - 4, cell, 4), paint);
      }
    }
    // Subtle diagonal tea garden slope lines across background
    for (double y = -size.height; y < size.height * 2; y += 48) {
      final path = Path()
        ..moveTo(0, y)
        ..quadraticBezierTo(size.width * 0.3, y + 12, size.width * 0.6, y)
        ..quadraticBezierTo(size.width * 0.8, y - 8, size.width, y + 4);
      canvas.drawPath(path, paint);
    }
  }

  // ---- MEGHALAYA: Horizontal cloud-layer weave ----
  void _drawMeghalayaWeave(Canvas canvas, Size size, Paint paint, Paint fill) {
    // Soft horizontal parallel lines like mist layers
    for (double y = 20; y < size.height; y += 36) {
      final path = Path();
      path.moveTo(0, y);
      for (double x = 0; x < size.width; x += 60) {
        path.quadraticBezierTo(x + 30, y + (y % 72 == 0 ? 6 : -6), x + 60, y);
      }
      canvas.drawPath(path, paint);
    }
    // Vertical rain-drop dashes
    for (double x = 30; x < size.width; x += 72) {
      for (double y = 10; y < size.height; y += 24) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 8), paint);
      }
    }
  }

  // ---- MANIPUR: Shaphee Lanphee zigzag tribal weave ----
  void _drawManipurShaphee(Canvas canvas, Size size, Paint paint, Paint fill) {
    final double step = 16.0;
    // Horizontal zigzag bands at top and bottom
    for (int band = 0; band < 3; band++) {
      final double yBase = band < 2 ? band * 12.0 : size.height - 12.0 - (band - 2) * 12.0;
      for (double x = 0; x < size.width; x += step) {
        final yOff = (x / step).floor().isEven ? 0.0 : 6.0;
        canvas.drawLine(
          Offset(x, yBase + yOff),
          Offset(x + step / 2, yBase + 6 - yOff),
          paint,
        );
        canvas.drawLine(
          Offset(x + step / 2, yBase + 6 - yOff),
          Offset(x + step, yBase + yOff),
          paint,
        );
      }
    }
    // Lotus ripple circles scattered
    for (double x = 80; x < size.width; x += 160) {
      for (double y = 80; y < size.height; y += 160) {
        canvas.drawCircle(Offset(x, y), 12, paint);
        canvas.drawCircle(Offset(x, y), 8, paint);
      }
    }
  }

  // ---- NAGALAND: Bold warrior shawl horizontal stripes ----
  void _drawNagalandShawl(Canvas canvas, Size size, Paint paint, Paint fill) {
    // Bold horizontal stripes (scarlet/yellow inspired)
    final stripeHeight = 6.0;
    final gap = 40.0;
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, stripeHeight), fill);
      canvas.drawRect(Rect.fromLTWH(0, y + stripeHeight + 4, size.width, 2), paint);
    }
    // Vertical spear-line accents
    for (double x = 0; x < size.width; x += 96) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      // Diamond spear tip
      final tip = Path()
        ..moveTo(x - 4, size.height * 0.08)
        ..lineTo(x, size.height * 0.05)
        ..lineTo(x + 4, size.height * 0.08)
        ..close();
      canvas.drawPath(tip, fill);
    }
  }

  // ---- SIKKIM: Prayer flag vertical stripes + cloud wisps ----
  void _drawSikkimPrayer(Canvas canvas, Size size, Paint paint, Paint fill) {
    // Vertical prayer flag stripes across full width
    final stripeW = 8.0;
    final gap = 40.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawRect(Rect.fromLTWH(x, 0, stripeW, size.height), fill);
    }
    // Tibetan cloud wisps
    for (double y = 40; y < size.height; y += 100) {
      final cloudPath = Path()
        ..moveTo(20, y)
        ..quadraticBezierTo(40, y - 10, 60, y)
        ..quadraticBezierTo(80, y + 5, 100, y)
        ..quadraticBezierTo(80, y + 12, 60, y + 8)
        ..quadraticBezierTo(40, y + 10, 20, y)
        ..close();
      canvas.drawPath(cloudPath, paint);
    }
  }

  // ---- TRIPURA: Risa bamboo matting grid ----
  void _drawTripuraRisa(Canvas canvas, Size size, Paint paint, Paint fill) {
    final double cell = 20.0;
    // Full bamboo matting grid
    for (double x = 0; x < size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Diagonal cross-weave accent lines every 4 cells
    for (double x = 0; x < size.width; x += cell * 4) {
      for (double y = 0; y < size.height; y += cell * 4) {
        canvas.drawLine(Offset(x, y), Offset(x + cell * 4, y + cell * 4), paint);
        canvas.drawLine(Offset(x + cell * 4, y), Offset(x, y + cell * 4), paint);
      }
    }
  }

  // ---- MIZORAM: Bold Puan fabric chevron + stripe ----
  void _drawMizoramPuan(Canvas canvas, Size size, Paint paint, Paint fill) {
    final double step = 20.0;
    // Horizontal bold stripes
    for (double y = 0; y < size.height; y += step * 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 3), fill);
      canvas.drawRect(Rect.fromLTWH(0, y + 6, size.width, 1), paint);
    }
    // Chevron / zigzag pattern in between
    for (double y = step; y < size.height; y += step * 3) {
      for (double x = 0; x < size.width; x += step) {
        final yOff = (x / step).floor().isEven ? 0.0 : step * 0.4;
        canvas.drawLine(
          Offset(x, y + yOff),
          Offset(x + step / 2, y + step * 0.4 - yOff),
          paint,
        );
        canvas.drawLine(
          Offset(x + step / 2, y + step * 0.4 - yOff),
          Offset(x + step, y + yOff),
          paint,
        );
      }
    }
  }

  // ---- ARUNACHAL: Vertical handloom stripes + bead dots ----
  void _drawArunachalHandloom(Canvas canvas, Size size, Paint paint, Paint fill) {
    // Vertical bamboo-gradient stripes
    final stripeW = 4.0;
    final gap = 28.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawRect(Rect.fromLTWH(x, 0, stripeW, size.height), fill);
      canvas.drawRect(Rect.fromLTWH(x + stripeW + 4, 0, 1, size.height), paint);
    }
    // Tribal bead dots in rows
    for (double y = 24; y < size.height; y += 48) {
      for (double x = 12; x < size.width; x += 28) {
        canvas.drawCircle(Offset(x, y), 2, fill);
      }
    }
  }

  @override
  bool shouldRepaint(covariant TextileWeavePainter oldDelegate) =>
      motif != oldDelegate.motif || color != oldDelegate.color;
}

// ============================================================
// 5. THEMED BACKGROUND WRAPPER WIDGET
// ============================================================

/// Maps state motifs to their hand-drawn SVG illustration assets.
String _getMotifSvgPath(NEStateMotif motif) {
  switch (motif) {
    case NEStateMotif.assam:
      return 'assets/images/regional/assam.svg';
    case NEStateMotif.sikkim:
      return 'assets/images/regional/sikkim.svg';
    case NEStateMotif.meghalaya:
      return 'assets/images/regional/meghalaya.svg';
    case NEStateMotif.nagaland:
      return 'assets/images/regional/nagaland.svg';
    case NEStateMotif.manipur:
      return 'assets/images/regional/manipur.svg';
    case NEStateMotif.tripura:
      return 'assets/images/regional/tripura.svg';
    case NEStateMotif.mizoram:
      return 'assets/images/regional/mizoram.svg';
    case NEStateMotif.arunachal:
      return 'assets/images/regional/arunachal.svg';
    case NEStateMotif.none:
      return 'assets/images/regional/assam.svg'; // fallback
  }
}

class RegionalThemeBackground extends StatelessWidget {
  final Widget child;
  final NETheme? themeOverride;

  const RegionalThemeBackground({
    super.key,
    required this.child,
    this.themeOverride,
  });

  @override
  Widget build(BuildContext context) {
    final theme = themeOverride ?? NEThemeScope.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      color: theme.background,
      child: Stack(
        children: [
          // Subtle gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.background,
                    theme.surface,
                    theme.background,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // Hand-drawn cultural illustration — bottom-right, blended with opacity
          Positioned(
            right: 0,
            bottom: 0,
            child: SizedBox(
              width: size.width * 0.45,
              height: size.width * 0.45 > 300 ? 300 : size.width * 0.45,
              child: Opacity(
                opacity: 0.18,
                child: SvgPicture.asset(
                  _getMotifSvgPath(theme.motif),
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomRight,
                  colorFilter: ColorFilter.mode(theme.primary, BlendMode.srcIn),
                ),
              ),
            ),
          ),
          // Accent overlay for vibrancy
          Positioned(
            right: 10,
            bottom: 10,
            child: SizedBox(
              width: size.width * 0.25,
              height: size.width * 0.25 > 180 ? 180 : size.width * 0.25,
              child: Opacity(
                opacity: 0.08,
                child: SvgPicture.asset(
                  _getMotifSvgPath(theme.motif),
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomRight,
                  colorFilter: ColorFilter.mode(theme.accent, BlendMode.srcIn),
                ),
              ),
            ),
          ),

          // Saree / textile weave background pattern
          Positioned.fill(
            child: CustomPaint(
              painter: TextileWeavePainter(
                motif: theme.motif,
                color: theme.primary,
                opacity: 0.09,
              ),
            ),
          ),

          // Weave border frame
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: CustomPaint(
                painter: WeaveBorderPainter(
                  color: theme.primary,
                  borderWidth: 2.5,
                  motif: theme.motif,
                ),
              ),
            ),
          ),

          // Content
          Positioned.fill(child: child),
        ],
      ),
    );
      }, // LayoutBuilder
    );
  }
}

// ============================================================
// 6. THEMED CARD WIDGET
// ============================================================

class RegionalCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const RegionalCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = NEThemeScope.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.cardBorder.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.primary.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          painter: WeaveBorderPainter(
            color: theme.primary,
            borderWidth: 1.0,
            motif: theme.motif,
          ),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 7. THEMED APP BAR
// ============================================================

class RegionalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;

  const RegionalAppBar({
    super.key,
    required this.title,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = NEThemeScope.of(context);

    return AppBar(
      title: Text(title),
      backgroundColor: theme.appBarColor,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      actions: actions,
    );
  }
}

// ============================================================
// 8. THEME SELECTION SCREEN
// ============================================================

class RegionalThemeScreen extends StatefulWidget {
  const RegionalThemeScreen({super.key});

  @override
  State<RegionalThemeScreen> createState() => _RegionalThemeScreenState();
}

class _RegionalThemeScreenState extends State<RegionalThemeScreen> {
  late String _selectedId;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _selectedId = NEThemeScope.of(context).id;
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = NEThemeScope.of(context);

    return Scaffold(
      appBar: RegionalAppBar(title: 'Choose Your Regional Theme'),
      body: RegionalThemeBackground(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: NEThemes.all.length,
          itemBuilder: (context, index) {
            final theme = NEThemes.all[index];
            final isSelected = _selectedId == theme.id;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedId = theme.id);
                  NEThemeScope.ofNotifier(context).setTheme(theme);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: isSelected ? theme.surface : theme.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? theme.primary
                          : theme.cardBorder.withValues(alpha: 0.25),
                      width: isSelected ? 3 : 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: theme.primary.withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
            child: CustomPaint(
              painter: CulturalWatermarkPainter(
                motif: theme.motif,
                color: theme.primary,
                accentColor: theme.accent,
                opacity: isSelected ? 0.15 : 0.07,
              ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            // Color palette preview
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    theme.primary,
                                    theme.accent,
                                  ],
                                ),
                                border: Border.all(
                                  color: isSelected
                                      ? theme.primary
                                      : theme.cardBorder.withValues(alpha: 0.2),
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: _buildMotifIcon(theme.motif, theme.primary),
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Theme info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    theme.stateName,
                                    style: GoogleFonts.getFont(
                                      theme.fontFamily,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: theme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    theme.tagline,
                                    style: GoogleFonts.getFont(
                                      theme.fontFamily,
                                      fontSize: 13,
                                      color: theme.textSecondary,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // Color dots preview
                                  Row(
                                    children: [
                                      _colorDot(theme.primary),
                                      const SizedBox(width: 4),
                                      _colorDot(theme.accent),
                                      const SizedBox(width: 4),
                                      _colorDot(theme.background),
                                      const SizedBox(width: 4),
                                      _colorDot(theme.surface),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Selection indicator
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: theme.primary,
                                size: 28,
                              )
                            else
                              Icon(
                                Icons.radio_button_unchecked,
                                color: theme.textSecondary.withValues(alpha: 0.4),
                                size: 28,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _colorDot(Color color) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildMotifIcon(NEStateMotif motif, Color color) {
    return SvgPicture.asset(
      _getMotifSvgPath(motif),
      width: 28,
      height: 28,
      colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
    );
  }
}

// ============================================================
// 9. STATE CHIP WIDGET (small inline indicator)
// ============================================================

class StateThemeChip extends StatelessWidget {
  final String stateId;
  final bool showLabel;

  const StateThemeChip({
    super.key,
    required this.stateId,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = NEThemes.getById(stateId);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: theme.primary,
              shape: BoxShape.circle,
            ),
          ),
          if (showLabel) ...[
            const SizedBox(width: 6),
            Text(
              theme.stateName,
              style: GoogleFonts.getFont(
                theme.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
