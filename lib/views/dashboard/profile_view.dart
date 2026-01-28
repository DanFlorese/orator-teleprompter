import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart'; // Nuevo: Para enlaces externos
import 'package:orator_teleprompter/core/theme.dart';
import 'package:orator_teleprompter/services/purchase_service.dart';

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

  // --- LOGIC: OPEN EXTERNAL LINKS ---
  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch $url");
    }
  }

  // --- LOGOUT LOGIC ---
  Future<void> _signOut() async {
    try {
      setState(() => _isLoading = true);
      await Supabase.instance.client.auth.signOut();

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
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

  // --- LOGIC: UPLOAD & UPDATE ---
  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final XFile? image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image == null || _user == null) return;

    setState(() => _isLoading = true);
    try {
      final imageBytes = await image.readAsBytes();
      final fileName = '${_user!.id}/avatar.${image.path.split('.').last}';

      await Supabase.instance.client.storage.from('avatars').uploadBinary(
            fileName,
            imageBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final String publicUrl =
          Supabase.instance.client.storage.from('avatars').getPublicUrl(fileName);
      setState(() => _avatarUrl = publicUrl);
      _updateProfile(newAvatarUrl: publicUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Upload Error: $e'), backgroundColor: redOrator));
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Update Error: $e')));
      }
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
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Error: Incorrect password"),
            backgroundColor: redOrator));
      }
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
            title: const Text('⚠️ IRREVERSIBLE ACTION',
                style: TextStyle(color: redOrator, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'To delete your account and all data permanently, please enter your password.',
                    style: TextStyle(color: Colors.white70)),
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
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.white54),
                      onPressed: () => setDialogState(
                          () => _isPasswordVisible = !_isPasswordVisible),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL',
                      style: TextStyle(color: Colors.white54))),
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
                  backgroundImage:
                      _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                  child: _avatarUrl == null
                      ? const Icon(Icons.camera_alt,
                          size: 40, color: Colors.white24)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text('Tap to change photo',
                style: TextStyle(color: Colors.white24, fontSize: 12)),
            const SizedBox(height: 40),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Full Name',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: graySurface,
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: redOrator)),
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
                disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Colors.white10)),
              ),
            ),
            
            // --- BOTÓN DORADO UPGRADE ---
            const SizedBox(height: 40),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: () async {
                    setState(() => _isLoading = true);
                    bool success = await PurchaseService.purchaseSubscription();
                    if (!context.mounted) return;
                    setState(() => _isLoading = false);
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('¡WELCOME TO PRO! All features unlocked.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.black, size: 22),
                        SizedBox(width: 12),
                        Text(
                          'UPGRADE TO PRO — \$499/YR',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // --- BOTÓN SAVE CHANGES ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _updateProfile(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: redOrator,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('SAVE CHANGES',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 30),

            // --- SECCIÓN LEGAL (AHORA EXTERNA) ---
            ListTile(
              onTap: () => _launchURL('https://oratorteleprompter.com/privacy-policy'),
              leading: const Icon(Icons.privacy_tip_outlined, color: Colors.white70),
              title: const Text('Privacy Policy', style: TextStyle(color: Colors.white70)),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
              tileColor: graySurface.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            const SizedBox(height: 12),
            ListTile(
              onTap: () => _launchURL('https://oratorteleprompter.com/terms-and-conditions'),
              leading: const Icon(Icons.description_outlined, color: Colors.white70),
              title: const Text('Terms & Conditions', style: TextStyle(color: Colors.white70)),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
              tileColor: graySurface.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),

            const SizedBox(height: 40),
            const Divider(color: Colors.white10),
            TextButton(
              onPressed: _showDeleteDialog,
              child: const Text('Delete Account Forever',
                  style: TextStyle(
                      color: Colors.white24,
                      decoration: TextDecoration.underline)),
            ),
          ],
        ),
      ),
    );
  }
}