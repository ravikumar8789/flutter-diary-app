import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PinNumberPad extends StatelessWidget {
  final Function(String) onNumberPressed;
  final VoidCallback? onBackspacePressed;
  final VoidCallback? onEnterPressed;
  final bool isLoading;

  const PinNumberPad({
    super.key,
    required this.onNumberPressed,
    this.onBackspacePressed,
    this.onEnterPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate adaptive sizing based on screen height
        final screenHeight = constraints.maxHeight;
        final isSmallScreen = screenHeight < 500;
        final isVerySmallScreen = screenHeight < 400;

        // More aggressive sizing for very small screens
        final buttonSize = isVerySmallScreen
            ? 50.0
            : (isSmallScreen ? 55.0 : 65.0);
        final spacing = isVerySmallScreen ? 8.0 : (isSmallScreen ? 10.0 : 12.0);
        final padding = isVerySmallScreen ? 4.0 : (isSmallScreen ? 6.0 : 8.0);

        return Container(
          padding: EdgeInsets.all(padding),
          child: Column(
            children: [
              // Row 1: 1, 2, 3
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNumberButton(context, '1', buttonSize),
                  _buildNumberButton(context, '2', buttonSize),
                  _buildNumberButton(context, '3', buttonSize),
                ],
              ),
              SizedBox(height: spacing),

              // Row 2: 4, 5, 6
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNumberButton(context, '4', buttonSize),
                  _buildNumberButton(context, '5', buttonSize),
                  _buildNumberButton(context, '6', buttonSize),
                ],
              ),
              SizedBox(height: spacing),

              // Row 3: 7, 8, 9
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNumberButton(context, '7', buttonSize),
                  _buildNumberButton(context, '8', buttonSize),
                  _buildNumberButton(context, '9', buttonSize),
                ],
              ),
              SizedBox(height: spacing),

              // Row 4: 0, Backspace, Enter
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNumberButton(context, '0', buttonSize),
                  _buildBackspaceButton(context, buttonSize),
                  _buildEnterButton(context, buttonSize),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNumberButton(
    BuildContext context,
    String number,
    double buttonSize,
  ) {
    return _buildButton(
      context: context,
      buttonSize: buttonSize,
      child: Text(
        number,
        style: TextStyle(
          fontSize: buttonSize * 0.35,
          fontWeight: FontWeight.w600,
        ),
      ),
      onPressed: isLoading
          ? null
          : () {
              HapticFeedback.lightImpact();
              onNumberPressed(number);
            },
    );
  }

  Widget _buildBackspaceButton(BuildContext context, double buttonSize) {
    return _buildButton(
      context: context,
      buttonSize: buttonSize,
      child: Icon(
        Icons.backspace_outlined,
        size: buttonSize * 0.35,
        color: isLoading ? Colors.grey : Theme.of(context).colorScheme.primary,
      ),
      onPressed: isLoading
          ? null
          : () {
              HapticFeedback.lightImpact();
              onBackspacePressed?.call();
            },
    );
  }

  Widget _buildEnterButton(BuildContext context, double buttonSize) {
    final canEnter = onEnterPressed != null && !isLoading;

    return _buildButton(
      context: context,
      buttonSize: buttonSize,
      child: Icon(
        Icons.check,
        size: buttonSize * 0.35,
        color: canEnter ? Colors.white : Colors.grey,
      ),
      backgroundColor: canEnter
          ? Theme.of(context).colorScheme.primary
          : Colors.grey[300],
      onPressed: canEnter
          ? () {
              HapticFeedback.lightImpact();
              onEnterPressed?.call();
            }
          : null,
    );
  }

  Widget _buildButton({
    required BuildContext context,
    required Widget child,
    required double buttonSize,
    VoidCallback? onPressed,
    Color? backgroundColor,
  }) {
    return Container(
      width: buttonSize,
      height: buttonSize,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey[100],
        borderRadius: BorderRadius.circular(buttonSize / 2),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(buttonSize / 2),
          onTap: onPressed,
          child: Center(child: child),
        ),
      ),
    );
  }
}
