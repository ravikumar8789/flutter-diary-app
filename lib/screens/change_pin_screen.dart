import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/privacy_lock_provider.dart';
import '../widgets/pin_number_pad.dart';
import '../services/error_logging_service.dart';
import '../models/error_models.dart';
import '../ui/responsive/responsive_body.dart';
import '../ui/responsive/responsive_info.dart';
import '../ui/responsive/responsive_tokens.dart';

class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  String _currentPin = '';
  String _newPin = '';
  String _confirmPin = '';
  bool _isLoading = false;
  int _currentStep = 1; // 1: Current PIN, 2: New PIN, 3: Confirm PIN

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Change PIN'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleBackPress,
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate adaptive spacing based on available height
            final availableHeight = constraints.maxHeight;
            final isSmallScreen = availableHeight < 500;
            final isVerySmallScreen = availableHeight < 400;
            final info = ResponsiveInfo.of(context);
            final padding = EdgeInsets.all(
              isSmallScreen
                  ? ResponsiveTokens.spacingM(info)
                  : ResponsiveTokens.spacingL(info),
            );

            // More aggressive spacing for very small screens
            final topSpacing = isVerySmallScreen
                ? 8.0
                : (isSmallScreen ? 12.0 : 20.0);
            final sectionSpacing = isVerySmallScreen
                ? 16.0
                : (isSmallScreen ? 20.0 : 32.0);
            final bottomSpacing = isVerySmallScreen
                ? 8.0
                : (isSmallScreen ? 12.0 : 16.0);
            final keypadMaxWidth = info.value(
              compact: 320.0,
              medium: 360.0,
              expanded: 420.0,
            );
            final colorScheme = Theme.of(context).colorScheme;

            return ResponsiveBody(
              useSafeArea: false,
              padding: padding,
              alignment: Alignment.topCenter,
              child: Column(
                children: [
                  SizedBox(height: topSpacing),

                  // Progress indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index < _currentStep
                              ? Theme.of(context).colorScheme.primary
                              : colorScheme.outlineVariant,
                        ),
                      );
                    }),
                  ),

                  SizedBox(height: sectionSpacing),

                  // App Logo/Icon
                  Container(
                    width: isVerySmallScreen ? 50 : (isSmallScreen ? 60 : 70),
                    height: isVerySmallScreen ? 50 : (isSmallScreen ? 60 : 70),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(
                        isVerySmallScreen ? 12 : (isSmallScreen ? 15 : 18),
                      ),
                    ),
                    child: Icon(
                      Icons.lock_outline,
                      size: isVerySmallScreen ? 24 : (isSmallScreen ? 28 : 32),
                      color: colorScheme.onPrimary,
                    ),
                  ),

                  SizedBox(
                    height: isVerySmallScreen ? 16 : (isSmallScreen ? 20 : 24),
                  ),

                  // Title based on current step
                  Text(
                    _getTitle(),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: isVerySmallScreen
                          ? 18
                          : (isSmallScreen ? 20 : 24),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: isVerySmallScreen ? 4 : 6),

                  // Subtitle
                  Text(
                    _getSubtitle(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: isVerySmallScreen
                          ? 12
                          : (isSmallScreen ? 13 : 14),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: sectionSpacing),

                  // PIN Display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      String currentPin;
                      if (_currentStep == 1) {
                        currentPin = _currentPin;
                      } else if (_currentStep == 2) {
                        currentPin = _newPin;
                      } else {
                        currentPin = _confirmPin;
                      }

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index < currentPin.length
                              ? Theme.of(context).colorScheme.primary
                              : colorScheme.outlineVariant,
                        ),
                      );
                    }),
                  ),

                  SizedBox(height: sectionSpacing),

                  // Loading indicator
                  if (_isLoading)
                    Padding(
                      padding: EdgeInsets.only(bottom: bottomSpacing),
                      child: const CircularProgressIndicator(),
                    ),

                  // Number Pad
                  Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: keypadMaxWidth),
                      child: PinNumberPad(
                        onNumberPressed: _onNumberPressed,
                        onBackspacePressed: _onBackspacePressed,
                        onEnterPressed: _canEnter() ? _onEnterPressed : null,
                        isLoading: _isLoading,
                      ),
                    ),
                  ),

                  // Minimal spacing
                  SizedBox(
                    height: isVerySmallScreen ? 8 : (isSmallScreen ? 12 : 16),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _getTitle() {
    switch (_currentStep) {
      case 1:
        return 'Enter Current PIN';
      case 2:
        return 'Enter New PIN';
      case 3:
        return 'Confirm New PIN';
      default:
        return 'Change PIN';
    }
  }

  String _getSubtitle() {
    switch (_currentStep) {
      case 1:
        return 'Enter your current PIN to continue';
      case 2:
        return 'Enter a new 4-digit PIN';
      case 3:
        return 'Re-enter your new PIN to confirm';
      default:
        return '';
    }
  }

  bool _canEnter() {
    if (_isLoading) return false;

    if (_currentStep == 1) {
      return _currentPin.length == 4;
    } else if (_currentStep == 2) {
      return _newPin.length == 4;
    } else if (_currentStep == 3) {
      return _confirmPin.length == 4;
    }

    return false;
  }

  void _onNumberPressed(String number) {
    if (_isLoading) return;

    setState(() {
      if (_currentStep == 1) {
        if (_currentPin.length < 4) {
          _currentPin += number;
        }
      } else if (_currentStep == 2) {
        if (_newPin.length < 4) {
          _newPin += number;
        }
      } else if (_currentStep == 3) {
        if (_confirmPin.length < 4) {
          _confirmPin += number;
        }
      }
    });

    // Auto-validate when 4 digits are entered
    if (_currentStep == 1 && _currentPin.length == 4) {
      _validateCurrentPin();
    } else if (_currentStep == 2 && _newPin.length == 4) {
      _proceedToConfirmStep();
    } else if (_currentStep == 3 && _confirmPin.length == 4) {
      _validatePinChange();
    }
  }

  void _onBackspacePressed() {
    if (_isLoading) return;

    setState(() {
      if (_currentStep == 1 && _currentPin.isNotEmpty) {
        _currentPin = _currentPin.substring(0, _currentPin.length - 1);
      } else if (_currentStep == 2 && _newPin.isNotEmpty) {
        _newPin = _newPin.substring(0, _newPin.length - 1);
      } else if (_currentStep == 3 && _confirmPin.isNotEmpty) {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
      }
    });
  }

  void _onEnterPressed() {
    if (_currentStep == 1 && _currentPin.length == 4) {
      _validateCurrentPin();
    } else if (_currentStep == 2 && _newPin.length == 4) {
      _proceedToConfirmStep();
    } else if (_currentStep == 3 && _confirmPin.length == 4) {
      _validatePinChange();
    }
  }

  Future<void> _validateCurrentPin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final isValid = await ref
          .read(privacyLockProvider.notifier)
          .validatePin(_currentPin);

      if (isValid) {
        setState(() {
          _currentStep = 2;
          _isLoading = false;
        });
      } else {
        _showError('Incorrect PIN. Please try again.');
        _resetCurrentPin();
      }
    } catch (e) {
      _showError('Error validating PIN: $e');
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS093',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'validation_time': DateTime.now().toIso8601String(),
            'screen': 'ChangePinScreen',
            'step': _currentStep,
          },
        ),
      );
      _resetCurrentPin();
    }
  }

  void _proceedToConfirmStep() {
    setState(() {
      _currentStep = 3;
    });
  }

  Future<void> _validatePinChange() async {
    if (_newPin != _confirmPin) {
      _showError('PINs do not match. Please try again.');
      _resetNewPin();
      return;
    }

    if (_currentPin == _newPin) {
      _showError('New PIN must be different from current PIN.');
      _resetNewPin();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await ref
          .read(privacyLockProvider.notifier)
          .changePin(_currentPin, _newPin, _confirmPin);

      if (success) {
        _showSuccess();
        // Navigate back after short delay
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      } else {
        final errorMessage = ref.read(privacyLockProvider).errorMessage;
        _showError(errorMessage ?? 'Failed to change PIN. Please try again.');
        _resetAllSteps();
      }
    } catch (e) {
      _showError('Error: $e');
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS094',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'change_time': DateTime.now().toIso8601String(),
            'screen': 'ChangePinScreen',
          },
        ),
      );
      _resetAllSteps();
    }
  }

  void _handleBackPress() {
    if (_currentStep == 1) {
      // If on first step, just go back
      Navigator.of(context).pop();
    } else {
      // If on later steps, go back to previous step
      setState(() {
        if (_currentStep == 2) {
          _currentStep = 1;
          _currentPin = '';
        } else if (_currentStep == 3) {
          _currentStep = 2;
          _confirmPin = '';
        }
      });
    }
  }

  void _resetCurrentPin() {
    setState(() {
      _currentPin = '';
      _isLoading = false;
    });
  }

  void _resetNewPin() {
    setState(() {
      _newPin = '';
      _confirmPin = '';
      _currentStep = 2;
      _isLoading = false;
    });
  }

  void _resetAllSteps() {
    setState(() {
      _currentPin = '';
      _newPin = '';
      _confirmPin = '';
      _currentStep = 1;
      _isLoading = false;
    });
  }

  void _showError(String message) {
    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess() {
    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PIN changed successfully!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }
}

