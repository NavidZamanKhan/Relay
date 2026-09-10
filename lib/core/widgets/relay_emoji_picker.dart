import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';

import '../motion/relay_motion.dart';
import '../theme/relay_colors.dart';

/// A production-grade, Cupertino-styled native emoji picker for Relay.
///
/// Provides the complete Unicode 15 emoji library (1,600+ emojis across 8 categories)
/// in an instantaneous, zero-latency drawer with authentic Apple iOS styling.
/// Operates completely in-memory with pure Dart to ensure zero platform-channel
/// overhead, zero loading delays, and zero dependency on native storage plugins.
class RelayEmojiPicker extends StatefulWidget {
  const RelayEmojiPicker({
    super.key,
    required this.textEditingController,
    this.onEmojiSelected,
    this.onBackspacePressed,
    this.height = 270,
  });

  final TextEditingController textEditingController;
  final void Function(Category? category, Emoji emoji)? onEmojiSelected;
  final VoidCallback? onBackspacePressed;
  final double height;

  /// Session-level recents cache preserved in-memory across drawer toggles.
  static final List<Emoji> _sessionRecents = [];

  @override
  State<RelayEmojiPicker> createState() => _RelayEmojiPickerState();
}

class _RelayEmojiPickerState extends State<RelayEmojiPicker> {
  late final PageController _pageController;
  late final TextEditingController _searchController;
  int _selectedCategoryIndex = 0;
  bool _isSearchOpen = false;
  List<Emoji> _searchResults = const [];

  static const List<(Category, IconData, String)> _categoryDefinitions = [
    (Category.SMILEYS, CupertinoIcons.smiley, 'Smileys'),
    (Category.ANIMALS, CupertinoIcons.paw, 'Animals'),
    (Category.FOODS, CupertinoIcons.cart, 'Food'),
    (Category.ACTIVITIES, CupertinoIcons.sportscourt, 'Activities'),
    (Category.TRAVEL, CupertinoIcons.car_detailed, 'Travel'),
    (Category.OBJECTS, CupertinoIcons.lightbulb, 'Objects'),
    (Category.SYMBOLS, CupertinoIcons.number, 'Symbols'),
    (Category.FLAGS, CupertinoIcons.flag, 'Flags'),
  ];

  static final List<Emoji> _allEmojis = [
    for (final category in defaultEmojiSet) ...category.emoji,
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<(Category, IconData, String)> get _activeCategories {
    if (RelayEmojiPicker._sessionRecents.isNotEmpty) {
      return [
        (Category.RECENT, CupertinoIcons.clock, 'Recents'),
        ..._categoryDefinitions,
      ];
    }
    return _categoryDefinitions;
  }

  List<Emoji> _emojisForCategory(Category category) {
    if (category == Category.RECENT) {
      return RelayEmojiPicker._sessionRecents;
    }
    for (final cat in defaultEmojiSet) {
      if (cat.category == category) {
        return cat.emoji;
      }
    }
    return const [];
  }

  void _handleEmojiTap(Category? category, Emoji emoji) {
    // Record into session recents
    RelayEmojiPicker._sessionRecents.removeWhere((e) => e.emoji == emoji.emoji);
    RelayEmojiPicker._sessionRecents.insert(0, emoji);
    if (RelayEmojiPicker._sessionRecents.length > 35) {
      RelayEmojiPicker._sessionRecents.removeLast();
    }

    final controller = widget.textEditingController;
    final text = controller.text;
    final selection = controller.selection;

    if (selection.baseOffset < 0) {
      controller.text += emoji.emoji;
    } else {
      final newText = text.replaceRange(selection.start, selection.end, emoji.emoji);
      final newOffset = selection.start + emoji.emoji.length;
      controller.value = controller.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: newOffset),
        composing: TextRange.empty,
      );
    }

    widget.onEmojiSelected?.call(category, emoji);
  }

  void _handleBackspace() {
    final controller = widget.textEditingController;
    final text = controller.text;
    if (text.isEmpty) {
      widget.onBackspacePressed?.call();
      return;
    }

    final selection = controller.selection;
    final cursor = selection.baseOffset >= 0 ? selection.baseOffset : text.length;

    if (cursor > 0) {
      final beforeCursor = selection.baseOffset >= 0
          ? selection.textBefore(text)
          : text;
      final afterCursor = selection.baseOffset >= 0
          ? selection.textAfter(text)
          : '';

      final newBeforeCursor = beforeCursor.characters.skipLast(1).toString();
      final newOffset = newBeforeCursor.length;

      controller.value = controller.value.copyWith(
        text: newBeforeCursor + afterCursor,
        selection: TextSelection.collapsed(offset: newOffset),
        composing: TextRange.empty,
      );
    }

    widget.onBackspacePressed?.call();
  }

  void _onCategoryTapped(int index) {
    setState(() {
      _selectedCategoryIndex = index;
      _isSearchOpen = false;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(index);
    }
  }

  void _onSearchChanged(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) {
      setState(() => _searchResults = const []);
      return;
    }
    final matches = _allEmojis
        .where((e) => e.name.toLowerCase().contains(clean))
        .take(60)
        .toList();
    setState(() => _searchResults = matches);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? RelayColors.night : RelayColors.porcelain;
    final surfaceColor = isDark ? RelayColors.nightRaised : RelayColors.paper;
    final iconColor = isDark ? RelayColors.moonMuted : RelayColors.inkSoft;
    const activeColor = RelayColors.coral;
    final isIOS = foundation.defaultTargetPlatform == TargetPlatform.iOS ||
        foundation.defaultTargetPlatform == TargetPlatform.macOS;
    final columns = isIOS ? 7 : 8;

    final categories = _activeCategories;

    return Container(
      height: widget.height,
      color: backgroundColor,
      child: Column(
        children: [
          Expanded(
            child: _isSearchOpen
                ? _buildSearchBody(backgroundColor, surfaceColor, iconColor, columns)
                : _buildCategoryPageView(categories, backgroundColor, columns),
          ),
          _buildCategoryBar(categories, surfaceColor, iconColor, activeColor),
        ],
      ),
    );
  }

  Widget _buildCategoryPageView(
    List<(Category, IconData, String)> categories,
    Color backgroundColor,
    int columns,
  ) {
    return PageView.builder(
      controller: _pageController,
      itemCount: categories.length,
      onPageChanged: (index) {
        setState(() => _selectedCategoryIndex = index);
      },
      itemBuilder: (context, pageIndex) {
        final categoryDef = categories[pageIndex];
        final emojis = _emojisForCategory(categoryDef.$1);

        if (emojis.isEmpty && categoryDef.$1 == Category.RECENT) {
          return const Center(
            child: Text(
              'No Recent Emojis',
              style: TextStyle(
                color: RelayColors.inkSoft,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }

        return GridView.builder(
          key: PageStorageKey<String>('emoji-page-${categoryDef.$1.name}'),
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: emojis.length,
          itemBuilder: (context, emojiIndex) {
            final emoji = emojis[emojiIndex];
            return _buildEmojiButton(categoryDef.$1, emoji);
          },
        );
      },
    );
  }

  Widget _buildSearchBody(
    Color backgroundColor,
    Color surfaceColor,
    Color iconColor,
    int columns,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withValues(alpha: .5),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.search, size: 16, color: iconColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search emojis',
                            hintStyle: TextStyle(
                              color: iconColor,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: _onSearchChanged,
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                          child: Icon(
                            CupertinoIcons.clear_circled_solid,
                            size: 16,
                            color: iconColor,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 36),
                onPressed: () {
                  setState(() {
                    _isSearchOpen = false;
                    _searchController.clear();
                    _searchResults = const [];
                  });
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 14,
                    color: RelayColors.coral,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _searchResults.isEmpty
              ? Center(
                  child: Text(
                    _searchController.text.isEmpty
                        ? 'Type to search all 1,600+ emojis'
                        : 'No emojis found',
                    style: TextStyle(
                      color: iconColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              : GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                  ),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final emoji = _searchResults[index];
                    return _buildEmojiButton(null, emoji);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmojiButton(Category? category, Emoji emoji) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleEmojiTap(category, emoji),
      child: Center(
        child: Text(
          emoji.emoji,
          style: const TextStyle(
            fontSize: 27,
            height: 1.1,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBar(
    List<(Category, IconData, String)> categories,
    Color surfaceColor,
    Color iconColor,
    Color activeColor,
  ) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: .5),
            width: .7,
          ),
        ),
      ),
      child: Row(
        children: [
          // Search Icon Button
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                _isSearchOpen = !_isSearchOpen;
              });
            },
            child: SizedBox(
              width: 38,
              height: 44,
              child: Center(
                child: Icon(
                  CupertinoIcons.search,
                  size: 20,
                  color: _isSearchOpen ? activeColor : iconColor,
                ),
              ),
            ),
          ),
          // Category Icons
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (int i = 0; i < categories.length; i++)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _onCategoryTapped(i),
                    child: SizedBox(
                      width: 32,
                      height: 44,
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: RelayMotion.duration(context, RelayMotion.quick),
                          child: Icon(
                            categories[i].$2,
                            key: ValueKey('cat-$i-${_selectedCategoryIndex == i}'),
                            size: 20,
                            color: !_isSearchOpen && _selectedCategoryIndex == i
                                ? activeColor
                                : iconColor,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Backspace Button
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _handleBackspace,
            child: SizedBox(
              width: 42,
              height: 44,
              child: Center(
                child: Icon(
                  CupertinoIcons.delete_left,
                  size: 22,
                  color: activeColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
