import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/privacy_lock_provider.dart';
import '../services/error_logging_service.dart';
import 'home_screen.dart';

class SecurityQuestionsScreen extends ConsumerStatefulWidget {
  final bool isFromSetup;
  final VoidCallback? onComplete;

  const SecurityQuestionsScreen({
    super.key,
    this.isFromSetup = false,
    this.onComplete,
  });

  @override
  ConsumerState<SecurityQuestionsScreen> createState() =>
      _SecurityQuestionsScreenState();
}

class _SecurityQuestionsScreenState
    extends ConsumerState<SecurityQuestionsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _question1Controller = TextEditingController();
  final _answer1Controller = TextEditingController();
  final _question2Controller = TextEditingController();
  final _answer2Controller = TextEditingController();
  bool _isLoading = false;
  bool _hasLoadedExisting = false;

  @override
  void initState() {
    super.initState();
    _loadExistingQuestions();
  }

  Future<void> _loadExistingQuestions() async {
    if (_hasLoadedExisting) return;
    
    try {
      final questions = await ref.read(privacyLockProvider.notifier)
          .getSecurityQuestions();
      
      if (mounted && questions.isNotEmpty && questions['question1']?.isNotEmpty == true) {
        setState(() {
          _question1Controller.text = questions['question1'] ?? '';
          _question2Controller.text = questions['question2'] ?? '';
          _hasLoadedExisting = true;
        });
      }
    } catch (e) {
      // Ignore errors when loading existing questions
    }
  }

  @override
  void dispose() {
    _question1Controller.dispose();
    _answer1Controller.dispose();
    _question2Controller.dispose();
    _answer2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Security Questions'),
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
            final isSmallScreen = availableHeight < 600;
            final isVerySmallScreen = availableHeight < 500;

            final topSpacing = isVerySmallScreen
                ? 8.0
                : (isSmallScreen ? 12.0 : 20.0);
            final sectionSpacing = isVerySmallScreen
                ? 12.0
                : (isSmallScreen ? 16.0 : 24.0);

            return SingleChildScrollView(
              padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: topSpacing),

                    // Info text
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Set up security questions to recover your PIN if you forget it.',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 13 : 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: sectionSpacing),

                    // Question 1
                    Text(
                      'Question 1',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _question1Controller,
                      decoration: InputDecoration(
                        hintText: 'Enter your first security question',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a question';
                        }
                        if (value.trim().length < 10) {
                          return 'Question must be at least 10 characters';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: sectionSpacing),

                    // Answer 1
                    Text(
                      'Answer 1',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _answer1Controller,
                      decoration: InputDecoration(
                        hintText: 'Enter the answer to question 1',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an answer';
                        }
                        if (value.trim().length < 3) {
                          return 'Answer must be at least 3 characters';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: sectionSpacing),

                    // Question 2
                    Text(
                      'Question 2',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _question2Controller,
                      decoration: InputDecoration(
                        hintText: 'Enter your second security question',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a question';
                        }
                        if (value.trim().length < 10) {
                          return 'Question must be at least 10 characters';
                        }
                        if (value.trim().toLowerCase() ==
                            _question1Controller.text.trim().toLowerCase()) {
                          return 'Questions must be different';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: sectionSpacing),

                    // Answer 2
                    Text(
                      'Answer 2',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _answer2Controller,
                      decoration: InputDecoration(
                        hintText: 'Enter the answer to question 2',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an answer';
                        }
                        if (value.trim().length < 3) {
                          return 'Answer must be at least 3 characters';
                        }
                        if (value.trim().toLowerCase() ==
                            _answer1Controller.text.trim().toLowerCase()) {
                          return 'Answers must be different';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: sectionSpacing * 1.5),

                    // Save button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveQuestions,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Save Security Questions',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),

                    SizedBox(height: isSmallScreen ? 16 : 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleBackPress() {
    if (widget.isFromSetup) {
      // If from setup, just complete setup without questions
      if (widget.onComplete != null) {
        widget.onComplete!();
      } else {
        _completeSetup();
      }
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _saveQuestions() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await ref.read(privacyLockProvider.notifier)
          .setSecurityQuestions(
        question1: _question1Controller.text.trim(),
        answer1: _answer1Controller.text.trim(),
        question2: _question2Controller.text.trim(),
        answer2: _answer2Controller.text.trim(),
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Security questions saved successfully'),
              duration: Duration(seconds: 2),
            ),
          );

          if (widget.isFromSetup) {
            // Complete setup and navigate to home
            if (widget.onComplete != null) {
              widget.onComplete!();
            } else {
              _completeSetup();
            }
          } else {
            // Just go back to settings
            Navigator.of(context).pop();
          }
        } else {
          _showError('Failed to save security questions. Please try again.');
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Error: $e');
        await ErrorLoggingService.logHighError(
          errorCode: 'ERRSYS093',
          errorMessage: 'Security questions save failed: ${e.toString()}',
          stackTrace: StackTrace.current.toString(),
          errorContext: {
            'save_time': DateTime.now().toIso8601String(),
            'screen': 'SecurityQuestionsScreen',
            'is_from_setup': widget.isFromSetup.toString(),
          },
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _completeSetup() async {
    // Enable privacy lock now that PIN is successfully set
    final success = await ref
        .read(privacyLockProvider.notifier)
        .enablePrivacyLock();

    if (mounted) {
      if (success) {
        // Navigate to home screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        _showError('Failed to enable privacy lock. Please try again.');
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

