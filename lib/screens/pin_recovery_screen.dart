import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/privacy_lock_provider.dart';
import '../services/error_logging_service.dart';
import 'home_screen.dart';

class PinRecoveryScreen extends ConsumerStatefulWidget {
  const PinRecoveryScreen({super.key});

  @override
  ConsumerState<PinRecoveryScreen> createState() => _PinRecoveryScreenState();
}

class _PinRecoveryScreenState extends ConsumerState<PinRecoveryScreen> {
  String _answer1 = '';
  String _answer2 = '';
  String _newPin = '';
  String _confirmPin = '';
  bool _isLoading = false;
  int _currentStep = 1; // 1: Show questions, 2: Enter answers, 3: New PIN, 4: Confirm PIN
  Map<String, String> _questions = {'question1': '', 'question2': ''};
  bool _questionsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final questions = await ref.read(privacyLockProvider.notifier)
          .getSecurityQuestions();
      
      if (mounted) {
        setState(() {
          _questions = questions;
          _questionsLoaded = true;
        });
        
        // Check if questions are set
        if (questions['question1']?.isEmpty ?? true) {
          _showError('Security questions are not set up. Cannot recover PIN.');
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) Navigator.of(context).pop();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to load security questions. Please try again.');
        await ErrorLoggingService.logHighError(
          errorCode: 'ERRSYS094',
          errorMessage: 'Failed to load security questions: ${e.toString()}',
          stackTrace: StackTrace.current.toString(),
          errorContext: {
            'load_time': DateTime.now().toIso8601String(),
            'screen': 'PinRecoveryScreen',
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Recover PIN'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleBackPress,
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;
            final isSmallScreen = availableHeight < 500;
            final isVerySmallScreen = availableHeight < 400;

            final topSpacing = isVerySmallScreen
                ? 8.0
                : (isSmallScreen ? 12.0 : 20.0);
            final sectionSpacing = isVerySmallScreen
                ? 16.0
                : (isSmallScreen ? 20.0 : 32.0);
            final bottomSpacing = isVerySmallScreen
                ? 8.0
                : (isSmallScreen ? 12.0 : 16.0);

            if (!_questionsLoaded) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Loading security questions...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: isSmallScreen ? 13 : 14,
                      ),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
              child: Column(
                children: [
                  SizedBox(height: topSpacing),

                  // Progress indicator (4 steps)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
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

                  // Icon
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
                      _currentStep <= 2 ? Icons.help_outline : Icons.lock_outline,
                      size: isVerySmallScreen ? 24 : (isSmallScreen ? 28 : 32),
                      color: Colors.white,
                    ),
                  ),

                  SizedBox(
                    height: isVerySmallScreen ? 16 : (isSmallScreen ? 20 : 24),
                  ),

                  // Title
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

                  // Content based on step
                  if (_currentStep == 1) _buildQuestionsView(isSmallScreen, isVerySmallScreen),
                  if (_currentStep == 2) _buildAnswersView(isSmallScreen, isVerySmallScreen),
                  if (_currentStep == 3) _buildNewPinView(isSmallScreen, isVerySmallScreen),
                  if (_currentStep == 4) _buildConfirmPinView(isSmallScreen, isVerySmallScreen),

                  SizedBox(height: sectionSpacing),

                  // Loading indicator
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: CircularProgressIndicator(),
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

  Widget _buildQuestionsView(bool isSmallScreen, bool isVerySmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Question 1
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Question 1:',
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _questions['question1'] ?? '',
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Question 2
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Question 2:',
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _questions['question2'] ?? '',
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: _isLoading ? null : () {
            setState(() {
              _currentStep = 2;
            });
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Continue',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnswersView(bool isSmallScreen, bool isVerySmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Answer 1
        Text(
          'Answer to Question 1:',
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          onChanged: (value) {
            setState(() {
              _answer1 = value;
            });
          },
          decoration: InputDecoration(
            hintText: 'Enter your answer',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),

        const SizedBox(height: 20),

        // Answer 2
        Text(
          'Answer to Question 2:',
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          onChanged: (value) {
            setState(() {
              _answer2 = value;
            });
          },
          decoration: InputDecoration(
            hintText: 'Enter your answer',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),

        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: (_isLoading || _answer1.trim().isEmpty || _answer2.trim().isEmpty)
              ? null
              : _verifyAnswers,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Verify Answers',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNewPinView(bool isSmallScreen, bool isVerySmallScreen) {
    return Column(
      children: [
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
                color: index < _newPin.length
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[300],
              ),
            );
          }),
        ),

        const SizedBox(height: 32),

        // Number pad would go here, but for simplicity using text input
        // In a real app, you'd use PinNumberPad widget
        TextField(
          onChanged: (value) {
            if (value.length <= 4 && RegExp(r'^\d*$').hasMatch(value)) {
              setState(() {
                _newPin = value;
              });
              if (_newPin.length == 4) {
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted) {
                    setState(() {
                      _currentStep = 4;
                    });
                  }
                });
              }
            }
          },
          keyboardType: TextInputType.number,
          maxLength: 4,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            letterSpacing: 8,
          ),
          decoration: InputDecoration(
            hintText: '0000',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          obscureText: true,
        ),
      ],
    );
  }

  Widget _buildConfirmPinView(bool isSmallScreen, bool isVerySmallScreen) {
    return Column(
      children: [
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
                color: index < _confirmPin.length
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[300],
              ),
            );
          }),
        ),

        const SizedBox(height: 32),

        TextField(
          onChanged: (value) {
            if (value.length <= 4 && RegExp(r'^\d*$').hasMatch(value)) {
              setState(() {
                _confirmPin = value;
              });
              if (_confirmPin.length == 4) {
                _saveNewPin();
              }
            }
          },
          keyboardType: TextInputType.number,
          maxLength: 4,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            letterSpacing: 8,
          ),
          decoration: InputDecoration(
            hintText: '0000',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          obscureText: true,
        ),
      ],
    );
  }

  String _getTitle() {
    switch (_currentStep) {
      case 1:
        return 'Security Questions';
      case 2:
        return 'Answer Questions';
      case 3:
        return 'Set New PIN';
      case 4:
        return 'Confirm New PIN';
      default:
        return 'Recover PIN';
    }
  }

  String _getSubtitle() {
    switch (_currentStep) {
      case 1:
        return 'Please review your security questions';
      case 2:
        return 'Enter the answers to verify your identity';
      case 3:
        return 'Enter your new 4-digit PIN';
      case 4:
        return 'Confirm your new PIN';
      default:
        return '';
    }
  }

  void _handleBackPress() {
    if (_currentStep > 1) {
      setState(() {
        _currentStep--;
        if (_currentStep == 2) {
          _answer1 = '';
          _answer2 = '';
        } else if (_currentStep == 3) {
          _newPin = '';
        } else if (_currentStep == 4) {
          _confirmPin = '';
        }
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _verifyAnswers() async {
    if (_answer1.trim().isEmpty || _answer2.trim().isEmpty) {
      _showError('Please enter both answers');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final isValid = await ref.read(privacyLockProvider.notifier)
          .verifySecurityAnswers(_answer1.trim(), _answer2.trim());

      if (mounted) {
        if (isValid) {
          setState(() {
            _currentStep = 3;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _answer1 = '';
            _answer2 = '';
          });
          _showError('Incorrect answers. Please try again.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError('Error verifying answers: $e');
        await ErrorLoggingService.logHighError(
          errorCode: 'ERRSYS095',
          errorMessage: 'Security answers verification failed: ${e.toString()}',
          stackTrace: StackTrace.current.toString(),
          errorContext: {
            'verify_time': DateTime.now().toIso8601String(),
            'screen': 'PinRecoveryScreen',
          },
        );
      }
    }
  }

  Future<void> _saveNewPin() async {
    if (_newPin != _confirmPin) {
      _showError('PINs do not match. Please try again.');
      setState(() {
        _confirmPin = '';
      });
      return;
    }

    if (_newPin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(_newPin)) {
      _showError('PIN must be exactly 4 digits');
      setState(() {
        _newPin = '';
        _confirmPin = '';
        _currentStep = 3;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await ref.read(privacyLockProvider.notifier)
          .setupPin(_newPin, _confirmPin);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PIN reset successfully!'),
              duration: Duration(seconds: 2),
            ),
          );

          // Navigate to home screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        } else {
          setState(() {
            _isLoading = false;
            _newPin = '';
            _confirmPin = '';
            _currentStep = 3;
          });
          _showError('Failed to reset PIN. Please try again.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _newPin = '';
          _confirmPin = '';
          _currentStep = 3;
        });
        _showError('Error: $e');
        await ErrorLoggingService.logHighError(
          errorCode: 'ERRSYS096',
          errorMessage: 'PIN reset failed: ${e.toString()}',
          stackTrace: StackTrace.current.toString(),
          errorContext: {
            'reset_time': DateTime.now().toIso8601String(),
            'screen': 'PinRecoveryScreen',
          },
        );
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

