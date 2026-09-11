import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/relay_colors.dart';
import '../../../core/widgets/relay_avatar.dart';
import '../../../core/widgets/relay_button.dart';
import '../chat_models.dart';
import '../repositories/i_chat_repository.dart';

/// Modal bottom sheet for searching and adding new members to an existing group.
class AddGroupMembersSheet extends StatefulWidget {
  const AddGroupMembersSheet({
    super.key,
    required this.existingMemberIds,
  });

  final List<String> existingMemberIds;

  static Future<List<RelayContact>?> show(
    BuildContext context, {
    required List<String> existingMemberIds,
  }) {
    return showModalBottomSheet<List<RelayContact>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddGroupMembersSheet(
        existingMemberIds: existingMemberIds,
      ),
    );
  }

  @override
  State<AddGroupMembersSheet> createState() => _AddGroupMembersSheetState();
}

class _AddGroupMembersSheetState extends State<AddGroupMembersSheet> {
  final TextEditingController _searchController = TextEditingController();
  final Set<RelayContact> _selectedContacts = {};
  List<RelayContact> _allContacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts([String query = '']) async {
    IChatRepository? repo;
    try {
      repo = context.read<IChatRepository>();
    } catch (_) {}

    if (repo == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final contacts = await repo.searchUsers(query);
      if (mounted) {
        setState(() {
          // Filter out users who are already members
          _allContacts = contacts
              .where((c) => !widget.existingMemberIds.contains(c.id))
              .toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final theme = Theme.of(context);

    return Container(
      height: mediaQuery.size.height * 0.75,
      padding: EdgeInsets.only(
        bottom: mediaQuery.viewInsets.bottom + 16,
        left: 16,
        right: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Add Members',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.xmark, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            onChanged: (val) => _loadContacts(val),
            decoration: InputDecoration(
              hintText: 'Search contacts...',
              prefixIcon: const Icon(CupertinoIcons.search, size: 20),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .5),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(child: CupertinoActivityIndicator())
                : _allContacts.isEmpty
                    ? Center(
                        child: Text(
                          'No new contacts to add',
                          style: TextStyle(
                            color: theme.textTheme.bodySmall?.color,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _allContacts.length,
                        itemBuilder: (context, index) {
                          final contact = _allContacts[index];
                          final isSelected = _selectedContacts.contains(contact);

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            leading: RelayAvatar(
                              name: contact.displayName,
                              asset: contact.avatarUrl,
                              size: 40,
                            ),
                            title: Text(
                              contact.displayName,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              contact.phoneNumber,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.textTheme.bodySmall?.color,
                              ),
                            ),
                            trailing: Checkbox(
                              value: isSelected,
                              activeColor: RelayColors.mint,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedContacts.add(contact);
                                  } else {
                                    _selectedContacts.remove(contact);
                                  }
                                });
                              },
                            ),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedContacts.remove(contact);
                                } else {
                                  _selectedContacts.add(contact);
                                }
                              });
                            },
                          );
                        },
                      ),
          ),
          const SizedBox(height: 12),
          RelayButton(
            label: _selectedContacts.isEmpty
                ? 'Select contacts'
                : 'Add (${_selectedContacts.length})',
            onPressed: _selectedContacts.isEmpty
                ? null
                : () => Navigator.pop(context, _selectedContacts.toList()),
          ),
        ],
      ),
    );
  }
}
