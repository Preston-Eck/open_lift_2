import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/social_service.dart';

class UserPickerDialog extends StatefulWidget {
  final String title;
  const UserPickerDialog({super.key, this.title = "Select Friend"});

  @override
  State<UserPickerDialog> createState() => _UserPickerDialogState();
}

class _UserPickerDialogState extends State<UserPickerDialog> {
  List<Map<String, dynamic>> _friends = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    try {
      final friends = await context.read<SocialService>().getFriends();
      if (mounted) {
        setState(() {
          _friends = friends;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : _friends.isEmpty 
            ? const Text("No friends found. Add friends first!") 
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _friends.length,
                itemBuilder: (ctx, i) {
                  final f = _friends[i];
                  return ListTile(
                    leading: CircleAvatar(child: Text(f['username'][0].toUpperCase())),
                    title: Text(f['username']),
                    onTap: () => Navigator.pop(context, f['friend_id']),
                  );
                },
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
      ],
    );
  }
}
