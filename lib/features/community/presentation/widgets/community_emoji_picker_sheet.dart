import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

/// Shared bottom sheet for inserting emojis at the current cursor in [textController].
void showCommunityEmojiPickerSheet(
  BuildContext context, {
  required TextEditingController textController,
  ScrollController? scrollController,
}) {
  final effectiveScroll = scrollController ?? ScrollController();

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFFFF6E8),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: SafeArea(
          child: SizedBox(
            height: 320,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
                  child: Row(
                    children: [
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: EmojiPicker(
                    textEditingController: textController,
                    scrollController: effectiveScroll,
                    config: Config(
                      height: 256,
                      checkPlatformCompatibility: true,
                      emojiViewConfig: const EmojiViewConfig(
                        backgroundColor: Color(0xFFFFF3E0),
                        buttonMode: ButtonMode.MATERIAL,
                      ),
                      categoryViewConfig: const CategoryViewConfig(
                        backgroundColor: Color(0xFFFFE8C4),
                        indicatorColor: Color(0xFFE08B14),
                        iconColor: Color(0xFF888888),
                        iconColorSelected: Color(0xFFB87313),
                        backspaceColor: Color(0xFFB87313),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  ).whenComplete(() {
    if (scrollController == null) {
      effectiveScroll.dispose();
    }
  });
}

/// Small rounded icon-only control matching [CreatePostScreen] attachment chips.
class CommunityEmojiIconButton extends StatelessWidget {
  const CommunityEmojiIconButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 52,
          width: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outline),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.sentiment_satisfied_alt_rounded,
            color: AppColors.primaryDeep.withValues(alpha: 0.9),
            size: 24,
          ),
        ),
      ),
    );
  }
}
