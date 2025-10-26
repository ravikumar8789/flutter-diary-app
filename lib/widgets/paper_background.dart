import 'package:flutter/material.dart';
import '../providers/paper_style_provider.dart';

class PaperBackground extends StatelessWidget {
  final Widget child;
  final PaperStyle paperStyle;
  final double lineHeight;
  final Color lineColor;
  final Color backgroundColor;

  const PaperBackground({
    super.key,
    required this.child,
    required this.paperStyle,
    this.lineHeight = 24.0,
    this.lineColor = const Color(0xFFE0E0E0),
    this.backgroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: CustomPaint(
        painter: PaperPainter(
          paperStyle: paperStyle,
          lineHeight: lineHeight,
          lineColor: lineColor,
        ),
        child: child,
      ),
    );
  }
}

class PaperPainter extends CustomPainter {
  final PaperStyle paperStyle;
  final double lineHeight;
  final Color lineColor;

  PaperPainter({
    required this.paperStyle,
    required this.lineHeight,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (paperStyle == PaperStyle.plain) {
      return; // No background for plain paper
    }

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    if (paperStyle == PaperStyle.ruled) {
      _drawRuledLines(canvas, size, paint);
    } else if (paperStyle == PaperStyle.grid) {
      _drawGridLines(canvas, size, paint);
    }
  }

  void _drawRuledLines(Canvas canvas, Size size, Paint paint) {
    // Draw horizontal ruled lines - start from lineHeight/2 to center between lines
    double y = lineHeight / 2;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      y += lineHeight;
    }

    // Draw left margin line (red line)
    final marginPaint = Paint()
      ..color = const Color(0xFFFF6B6B)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(20, 0), Offset(20, size.height), marginPaint);
  }

  void _drawGridLines(Canvas canvas, Size size, Paint paint) {
    // Draw vertical lines - start from lineHeight/2 to center between lines
    double x = lineHeight / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      x += lineHeight;
    }

    // Draw horizontal lines - start from lineHeight/2 to center between lines
    double y = lineHeight / 2;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      y += lineHeight;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is PaperPainter &&
        (oldDelegate.paperStyle != paperStyle ||
            oldDelegate.lineHeight != lineHeight ||
            oldDelegate.lineColor != lineColor);
  }
}
