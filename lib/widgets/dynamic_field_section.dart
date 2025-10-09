import 'package:flutter/material.dart';

class DynamicFieldSection extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final List<TextEditingController> controllers;
  final VoidCallback onAddField;
  final Function(int) onRemoveField;
  final String fieldHint;
  final String addButtonText;
  final int maxFields;
  final String fieldLabelPrefix;
  final VoidCallback? onSave;
  final bool showSaveButton;
  final bool showProgressCounter;

  const DynamicFieldSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.controllers,
    required this.onAddField,
    required this.onRemoveField,
    required this.fieldHint,
    required this.addButtonText,
    this.maxFields = 10,
    this.fieldLabelPrefix = 'Item',
    this.onSave,
    this.showSaveButton = true,
    this.showProgressCounter = true,
  });

  @override
  State<DynamicFieldSection> createState() => _DynamicFieldSectionState();
}

class _DynamicFieldSectionState extends State<DynamicFieldSection>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              widget.accentColor.withOpacity(0.1),
              widget.accentColor.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(widget.icon, color: widget.accentColor, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: widget.accentColor,
                      ),
                    ),
                  ),
                  // Progress indicator
                  if (widget.showProgressCounter &&
                      widget.controllers.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget.accentColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${widget.controllers.where((c) => c.text.isNotEmpty).length}/${widget.controllers.length}',
                        style: TextStyle(
                          color: widget.accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (widget.showProgressCounter) const SizedBox(width: 8),
                  // Save button
                  if (widget.showSaveButton && widget.onSave != null)
                    _buildSaveButton(context),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),

              // Dynamic Fields
              AnimatedList(
                key: _listKey,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                initialItemCount: widget.controllers.length,
                itemBuilder: (context, index, animation) {
                  return SlideTransition(
                    position: animation.drive(
                      Tween(
                        begin: const Offset(1, 0),
                        end: Offset.zero,
                      ).chain(CurveTween(curve: Curves.easeOutCubic)),
                    ),
                    child: _buildFieldItem(
                      context: context,
                      controller: widget.controllers[index],
                      index: index,
                      accentColor: widget.accentColor,
                      fieldHint: widget.fieldHint,
                      onRemove: widget.controllers.length > 2
                          ? () => _removeFieldWithAnimation(index)
                          : null,
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              // Add More Button
              if (widget.controllers.length < widget.maxFields)
                _buildAddMoreButton(
                  context: context,
                  accentColor: widget.accentColor,
                  buttonText: widget.addButtonText,
                  onTap: _addFieldWithAnimation,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldItem({
    required BuildContext context,
    required TextEditingController controller,
    required int index,
    required Color accentColor,
    required String fieldHint,
    VoidCallback? onRemove,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: '${widget.fieldLabelPrefix} ${index + 1}',
            hintText: index == 0 ? fieldHint : null,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            labelStyle: TextStyle(
              color: accentColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            floatingLabelStyle: TextStyle(
              color: accentColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
            suffixIcon: onRemove != null
                ? IconButton(
                    icon: Icon(Icons.close, color: Colors.grey[400], size: 18),
                    onPressed: onRemove,
                    tooltip: 'Remove field',
                  )
                : null,
          ),
          maxLines: 2,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    final hasContent = widget.controllers.any(
      (controller) => controller.text.isNotEmpty,
    );

    return Container(
      decoration: BoxDecoration(
        color: hasContent
            ? widget.accentColor.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasContent
              ? widget.accentColor.withOpacity(0.3)
              : Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: hasContent ? widget.onSave : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.save_outlined,
                  color: hasContent ? widget.accentColor : Colors.grey,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  'Save',
                  style: TextStyle(
                    color: hasContent ? widget.accentColor : Colors.grey,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddMoreButton({
    required BuildContext context,
    required Color accentColor,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accentColor.withOpacity(0.1), accentColor.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline, color: accentColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  buttonText,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addFieldWithAnimation() {
    // Call the parent's add field method
    widget.onAddField();

    // Insert the new item with animation
    _listKey.currentState?.insertItem(
      widget.controllers.length - 1,
      duration: const Duration(milliseconds: 300),
    );
  }

  void _removeFieldWithAnimation(int index) async {
    final shouldRemove = await _showDeleteConfirmation(context);
    if (shouldRemove) {
      // Remove the item with animation
      _listKey.currentState?.removeItem(
        index,
        (context, animation) => SlideTransition(
          position: animation.drive(
            Tween(
              begin: Offset.zero,
              end: const Offset(-1, 0),
            ).chain(CurveTween(curve: Curves.easeInCubic)),
          ),
          child: _buildFieldItem(
            context: context,
            controller: widget.controllers[index],
            index: index,
            accentColor: widget.accentColor,
            fieldHint: widget.fieldHint,
            onRemove: null,
          ),
        ),
        duration: const Duration(milliseconds: 250),
      );

      // Call the parent's remove field method after animation
      Future.delayed(const Duration(milliseconds: 250), () {
        widget.onRemoveField(index);
      });
    }
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Field'),
            content: const Text('Are you sure you want to delete this field?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }
}
