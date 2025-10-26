import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/privacy_lock_provider.dart';
import '../widgets/pin_number_pad.dart';
import '../services/error_logging_service.dart';
import 'home_screen.dart';

class PinLockScreen extends ConsumerStatefulWidget {
  const PinLockScreen({super.key});

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen> {
  String _enteredPin = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Check if we need to show lockout message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLockoutStatus();
    });
  }

  void _checkLockoutStatus() {
    final privacyLockData = ref.read(privacyLockProvider);
    if (privacyLockData.isLockedOut) {
      _showLockoutDialog();
    }
  }

  void _showLockoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Account Locked'),
        content: Text(
          'Too many failed attempts. Please try again in ${ref.read(privacyLockProvider).remainingLockoutTime} minutes.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showRecoveryOptions();
            },
            child: const Text('Forgot PIN?'),
          ),
        ],
      ),
    );
  }

  void _showRecoveryOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recover PIN'),
        content: const Text(
          'You can reset your PIN using your security questions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startRecoveryProcess();
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _startRecoveryProcess() {
    // TODO: Navigate to recovery screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recovery feature coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _onNumberPressed(String number) {
    if (_isLoading) return;

    setState(() {
      if (_enteredPin.length < 4) {
        _enteredPin += number;
      }
    });

    // Auto-validate when 4 digits are entered
    if (_enteredPin.length == 4) {
      _validatePin();
    }
  }

  void _onBackspacePressed() {
    if (_isLoading) return;

    setState(() {
      if (_enteredPin.isNotEmpty) {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      }
    });
  }

  Future<void> _validatePin() async {
    if (_enteredPin.length != 4) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await ref
          .read(privacyLockProvider.notifier)
          .validatePin(_enteredPin);

      if (success) {
        // Navigate to home screen
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } else {
        // Show error and reset PIN
        setState(() {
          _enteredPin = '';
          _isLoading = false;
        });

        // Show error message
        final errorMessage = ref.read(privacyLockProvider).errorMessage;
        if (errorMessage != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _enteredPin = '';
        _isLoading = false;
      });
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRSYS091',
        errorMessage: 'PIN entry processing failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'entry_time': DateTime.now().toIso8601String(),
          'screen': 'PinLockScreen',
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate adaptive spacing based on screen height
            final screenHeight = constraints.maxHeight;
            final isSmallScreen = screenHeight < 500;
            final isVerySmallScreen = screenHeight < 400;

            // More aggressive spacing for very small screens
            final topSpacing = isVerySmallScreen
                ? 12.0
                : (isSmallScreen ? 16.0 : 24.0);
            final sectionSpacing = isVerySmallScreen
                ? 16.0
                : (isSmallScreen ? 20.0 : 28.0);
            final bottomSpacing = isVerySmallScreen
                ? 12.0
                : (isSmallScreen ? 16.0 : 20.0);

            return Padding(
              padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
              child: Column(
                children: [
                  SizedBox(height: topSpacing),

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

                  // Title
                  Text(
                    'Enter PIN',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: isVerySmallScreen
                          ? 18
                          : (isSmallScreen ? 20 : 24),
                    ),
                  ),

                  SizedBox(height: isVerySmallScreen ? 4 : 6),

                  // Subtitle
                  Text(
                    'Enter your 4-digit PIN to access your diary',
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
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index < _enteredPin.length
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
                    onEnterPressed: _enteredPin.length == 4
                        ? _validatePin
                        : null,
                    isLoading: _isLoading,
                  ),

                  SizedBox(
                    height: isVerySmallScreen ? 8 : (isSmallScreen ? 12 : 16),
                  ),

                  // Forgot PIN button
                  TextButton(
                    onPressed: _isLoading ? null : _showRecoveryOptions,
                    child: Text(
                      'Forgot PIN?',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: isVerySmallScreen
                            ? 12
                            : (isSmallScreen ? 13 : 14),
                      ),
                    ),
                  ),

                  SizedBox(height: bottomSpacing),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
