import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:orator_teleprompter/core/theme.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _nameController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false; 
  String? _avatarUrl;

  final User? _user = Supabase.instance.client.auth.currentUser;

  @override
  void initState() {
    super.initState();
    _getInitialProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  // --- LOGOUT LOGIC ---
  Future<void> _signOut() async {
  try {
    setState(() => _isLoading = true);

    // 1. Cerramos la sesión en el servidor
    await Supabase.instance.client.auth.signOut();

    if (mounted) {
      // 2. Usamos el rootNavigator para salir de cualquier menú anidado
      // El nombre '/login' debe ser idéntico al de main.dart
      Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
        '/login',
        (route) => false, // Esto borra el historial (Dashboard y Profile)
      );
    }
  } catch (e) {
    debugPrint("Logout error: $e");
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  Future<void> _getInitialProfile() async {
    if (_user == null) return;
    final data = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', _user!.id)
        .maybeSingle();

    if (data != null) {
      setState(() {
        _nameController.text = data['display_name'] ?? '';
        _avatarUrl = data['avatar_url'];
      });
    }
  }

  // --- PRIVACY POLICY ---
  void _showPrivacyPolicy() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: graySurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(25),
            child: ListView(
              controller: scrollController,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const Text(
                  'Privacy Policy',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                _policySection('1. Data Collection', 'We collect your email and name to manage your teleprompter scripts.'),
                _policySection('2. Data Security', 'Your data is managed through Supabase with industry-standard encryption.'),
                _policySection('3. Account Deletion', 'You can delete your account and all associated data permanently from this screen.'),
                _policySection('4. Permissions', 'Storage access is only used to update your profile image.'),
                const SizedBox(height: 30),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: redOrator),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CLOSE'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _policySection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: redOrator, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }

  // --- LOGIC: UPLOAD & UPDATE ---
  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image == null || _user == null) return;

    setState(() => _isLoading = true);
    try {
      final imageBytes = await image.readAsBytes();
      final fileName = '${_user!.id}.${image.path.split('.').last}';

      await Supabase.instance.client.storage.from('avatars').uploadBinary(
            fileName,
            imageBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final String publicUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(fileName);
      setState(() => _avatarUrl = publicUrl);
      _updateProfile(newAvatarUrl: publicUrl);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload Error: $e'), backgroundColor: redOrator));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile({String? newAvatarUrl}) async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.from('profiles').upsert({
        'id': _user!.id,
        'display_name': _nameController.text.trim(),
        'avatar_url': newAvatarUrl ?? _avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ACCOUNT DELETION ---
  Future<void> _deleteAccountPermanently() async {
    try {
      setState(() => _isLoading = true);
      await Supabase.instance.client.auth.signInWithPassword(
        email: _user!.email!,
        password: _passwordConfirmController.text.trim(),
      );
      await Supabase.instance.client.rpc('delete_user');
      await Supabase.instance.client.auth.signOut();
      if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Incorrect password"), backgroundColor: redOrator));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDeleteDialog() {
    _passwordConfirmController.clear();
    _isPasswordVisible = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: graySurface,
            title: const Text('⚠️ IRREVERSIBLE ACTION', style: TextStyle(color: redOrator, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('To delete your account and all data permanently, please enter your password.', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordConfirmController,
                  obscureText: !_isPasswordVisible,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.white54),
                      onPressed: () => setDialogState(() => _isPasswordVisible = !_isPasswordVisible),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: redOrator),
                onPressed: () {
                  if (_passwordConfirmController.text.isNotEmpty) {
                    Navigator.pop(context);
                    _deleteAccountPermanently();
                  }
                },
                child: const Text('DELETE EVERYTHING'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blackBackground,
      appBar: AppBar(
        title: const Text('Profile Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: redOrator),
            onPressed: _signOut,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickAndUploadImage,
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: graySurface,
                  backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                  child: _avatarUrl == null ? const Icon(Icons.camera_alt, size: 40, color: Colors.white24) : null,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text('Tap to change photo', style: TextStyle(color: Colors.white24, fontSize: 12)),
            const SizedBox(height: 40),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Full Name',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: graySurface,
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: redOrator)),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              enabled: false,
              controller: TextEditingController(text: _user?.email ?? ''),
              style: const TextStyle(color: Colors.white54),
              decoration: InputDecoration(
                labelText: 'Email Address',
                labelStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: graySurface.withValues(alpha: 0.5),
                disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.white10)),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _updateProfile(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: redOrator,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 30),
            ListTile(
              onTap: _showPrivacyPolicy,
              leading: const Icon(Icons.privacy_tip_outlined, color: Colors.white70),
              title: const Text('Privacy Policy', style: TextStyle(color: Colors.white70)),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
              tileColor: graySurface.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            const SizedBox(height: 40),
            const Divider(color: Colors.white10),
            TextButton(
              onPressed: _showDeleteDialog,
              child: const Text('Delete Account Forever', style: TextStyle(color: Colors.white24, decoration: TextDecoration.underline)),
            ),
          ],
        ),
      ),
    );
  }
}