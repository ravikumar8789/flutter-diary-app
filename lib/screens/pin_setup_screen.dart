import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/privacy_lock_provider.dart';
import '../widgets/pin_number_pad.dart';
import '../services/error_logging_service.dart';
import 'home_screen.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  String _enteredPin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _isLoading = false;
  int _currentStep = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Set Up PIN'),
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

            return Padding(
              padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
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
                              : Colors.grey[300],
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
                      color: Colors.white,
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
                      color: Colors.grey[600],
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
                      final currentPin = _isConfirming
                          ? _confirmPin
                          : _enteredPin;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index < currentPin.length
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[300],
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
                  PinNumberPad(
                    onNumberPressed: _onNumberPressed,
                    onBackspacePressed: _onBackspacePressed,
                    onEnterPressed: _canEnter() ? _onEnterPressed : null,
                    isLoading: _isLoading,
                  ),

                  // Minimal spacing
                  SizedBox(
                    height: isVerySmallScreen ? 8 : (isSmallScreen ? 12 : 16),
                  ),

                  // Skip button (only on first step)
                  if (_currentStep == 1)
                    TextButton(
                      onPressed: _isLoading ? null : _skipSetup,
                      child: Text(
                        'Skip for now',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: isVerySmallScreen
                              ? 12
                              : (isSmallScreen ? 13 : 14),
                        ),
                      ),
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
        return 'Create Your PIN';
      case 2:
        return 'Confirm Your PIN';
      case 3:
        return 'Set Security Questions';
      default:
        return 'Set Up PIN';
    }
  }

  String _getSubtitle() {
    switch (_currentStep) {
      case 1:
        return 'Enter a 4-digit PIN to secure your diary';
      case 2:
        return 'Re-enter your PIN to confirm';
      case 3:
        return 'Set up security questions for PIN recovery';
      default:
        return '';
    }
  }

  bool _canEnter() {
    if (_isLoading) return false;

    if (_currentStep == 1 || _currentStep == 2) {
      return (_isConfirming ? _confirmPin : _enteredPin).length == 4;
    }

    return false;
  }

  void _onNumberPressed(String number) {
    if (_isLoading) return;

    setState(() {
      if (_currentStep == 1) {
        if (_enteredPin.length < 4) {
          _enteredPin += number;
        }
      } else if (_currentStep == 2) {
        if (_confirmPin.length < 4) {
          _confirmPin += number;
        }
      }
    });

    // Auto-validate when 4 digits are entered
    if (_currentStep == 1 && _enteredPin.length == 4) {
      _proceedToNextStep();
    } else if (_currentStep == 2 && _confirmPin.length == 4) {
      _validatePinConfirmation();
    }
  }

  void _onBackspacePressed() {
    if (_isLoading) return;

    setState(() {
      if (_currentStep == 1 && _enteredPin.isNotEmpty) {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      } else if (_currentStep == 2 && _confirmPin.isNotEmpty) {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
      }
    });
  }

  void _onEnterPressed() {
    if (_currentStep == 1 && _enteredPin.length == 4) {
      _proceedToNextStep();
    } else if (_currentStep == 2 && _confirmPin.length == 4) {
      _validatePinConfirmation();
    }
  }

  void _proceedToNextStep() {
    setState(() {
      _currentStep = 2;
      _isConfirming = true;
    });
  }

  Future<void> _validatePinConfirmation() async {
    if (_enteredPin != _confirmPin) {
      _showError('PINs do not match. Please try again.');
      _resetToFirstStep();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await ref
          .read(privacyLockProvider.notifier)
          .setupPin(_enteredPin, _confirmPin);

      if (success) {
        setState(() {
          _currentStep = 3;
          _isLoading = false;
        });
        _showSecurityQuestionsDialog();
      } else {
        _showError('Failed to set up PIN. Please try again.');
        _resetToFirstStep();
      }
    } catch (e) {
      _showError('Error: $e');
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRSYS092',
        errorMessage: 'PIN confirmation validation failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'validation_time': DateTime.now().toIso8601String(),
          'screen': 'PinSetupScreen',
          'step': _currentStep,
        },
      );
      _resetToFirstStep();
    }
  }

  void _showSecurityQuestionsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Security Questions'),
        content: const Text(
          'Set up security questions to recover your PIN if you forget it.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _completeSetup();
            },
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showSecurityQuestionsForm();
            },
            child: const Text('Set Up'),
          ),
        ],
      ),
    );
  }

  void _showSecurityQuestionsForm() {
    // TODO: Implement security questions form
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Security questions feature coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
    _completeSetup();
  }

  void _completeSetup() async {
    // Enable privacy lock now that PIN is successfully set
    final success = await ref
        .read(privacyLockProvider.notifier)
        .enablePrivacyLock();

    if (success) {
      // Navigate to home screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      // Show error if enabling failed
      _showError('Failed to enable privacy lock. Please try again.');
    }
  }

  void _handleBackPress() {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel PIN Setup'),
        content: const Text(
          'Are you sure you want to cancel PIN setup? Privacy lock will not be enabled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue Setup'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _cancelSetup();
            },
            child: const Text('Cancel Setup'),
          ),
        ],
      ),
    );
  }

  void _cancelSetup() {
    // Navigate back to settings (privacy lock is not enabled yet)
    Navigator.of(context).pop();
  }

  void _skipSetup() {
    // Navigate back to settings (privacy lock is not enabled yet)
    Navigator.of(context).pop();
  }

  void _resetToFirstStep() {
    setState(() {
      _enteredPin = '';
      _confirmPin = '';
      _isConfirming = false;
      _isLoading = false;
      _currentStep = 1;
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
}
