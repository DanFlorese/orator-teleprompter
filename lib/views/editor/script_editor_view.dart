import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orator_teleprompter/core/theme.dart';

class ScriptEditorView extends StatefulWidget {
  final Map<String, dynamic>? script; // Null si es nuevo, datos si es edición

  const ScriptEditorView({super.key, this.script});

  @override
  State<ScriptEditorView> createState() => _ScriptEditorViewState();
}

class _ScriptEditorViewState extends State<ScriptEditorView> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isSaving = false;
  int _wordCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.script != null) {
      _titleController.text = widget.script!['title'] ?? '';
      _contentController.text = widget.script!['content'] ?? '';
      _updateStats();
    }
    _contentController.addListener(_updateStats);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _updateStats() {
    final text = _contentController.text.trim();
    setState(() {
      _wordCount = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
    });
  }

  String _getEstimatedTime() {
    double minutes = _wordCount / 150;
    if (minutes < 1) {
      return "${(minutes * 60).toInt()} seconds";
    }
    return "${minutes.toStringAsFixed(1)} minutes";
  }

  // --- LÓGICA: ASEGURAR SESIÓN (Prevención de InvalidJWTToken) ---
  Future<void> _ensureActiveSession() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null || session.isExpired) {
      await Supabase.instance.client.auth.refreshSession();
    }
  }

  // --- FUNCIÓN PARA ELIMINAR SCRIPT ---
  Future<void> _deleteScript() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: graySurface,
        title: const Text("Delete Script?", style: TextStyle(color: Colors.white)),
        content: const Text("This action cannot be undone.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL", style: TextStyle(color: Colors.white38))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("DELETE", style: TextStyle(color: redOrator))),
        ],
      ),
    );

    if (confirm == true && widget.script != null) {
      setState(() => _isSaving = true);
      try {
        await _ensureActiveSession(); // Refresco preventivo
        await Supabase.instance.client
            .from('scripts')
            .delete()
            .eq('id', widget.script!['id']);
        
        if (mounted) Navigator.pop(context, true); 
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error deleting: $e"), backgroundColor: redOrator));
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  // --- FUNCIÓN PARA GUARDAR SCRIPT ---
  Future<void> _saveScript() async {
    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Title and content are required")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _ensureActiveSession(); // Refresco preventivo para evitar el error de la foto
      
      final user = Supabase.instance.client.auth.currentUser;
      final data = {
        'user_id': user?.id,
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (widget.script == null) {
        await Supabase.instance.client.from('scripts').insert(data);
      } else {
        await Supabase.instance.client
            .from('scripts')
            .update(data)
            .eq('id', widget.script!['id']);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: redOrator),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blackBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.script == null ? 'NEW SCRIPT' : 'EDIT SCRIPT',
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        actions: [
          if (widget.script != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white38),
              onPressed: _isSaving ? null : _deleteScript,
            ),
          _isSaving 
            ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: redOrator, strokeWidth: 2)))
            : TextButton(
                onPressed: _saveScript,
                child: const Text('SAVE', style: TextStyle(color: redOrator, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
        ],
      ),
      body: Column(
        children: [
          // Stats Bar (Top)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: graySurface.withValues(alpha: 0.5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem(Icons.text_fields, "$_wordCount Words"),
                _statItem(Icons.timer_outlined, _getEstimatedTime()),
              ],
            ),
          ),
          
          // Title Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: TextField(
              controller: _titleController,
              autofocus: widget.script == null,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: "Enter title...",
                hintStyle: TextStyle(color: Colors.white10),
                border: InputBorder.none,
              ),
            ),
          ),
          
          const Divider(color: Colors.white10, thickness: 1, indent: 20, endIndent: 20),

          // Main Editor
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _contentController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(color: Colors.white70, fontSize: 18, height: 1.6),
                decoration: const InputDecoration(
                  hintText: "Start writing your masterpiece...",
                  hintStyle: TextStyle(color: Colors.white10),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: redOrator),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
      ],
    );
  }
}