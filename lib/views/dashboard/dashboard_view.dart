import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orator_teleprompter/core/theme.dart';
import 'package:orator_teleprompter/views/editor/script_editor_view.dart';
import 'package:orator_teleprompter/views/prompter/camera_view.dart';
import 'package:orator_teleprompter/widgets/smart_ad_banner.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  late Stream<List<Map<String, dynamic>>> _scriptsStream;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    final user = Supabase.instance.client.auth.currentUser;
    _scriptsStream = Supabase.instance.client
        .from('scripts')
        .stream(primaryKey: ['id'])
        .eq('user_id', user?.id ?? '')
        .order('created_at', ascending: false);
  }

  void _refreshScripts() {
    setState(() {
      _initStream();
    });
  }

  // --- FUNCIÓN: ELIMINAR DE SUPABASE ---
  Future<void> _deleteScript(String id) async {
    try {
      await Supabase.instance.client.from('scripts').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Script deleted'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      debugPrint("Error deleting: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blackBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'MY SCRIPTS',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined,
                color: Colors.white, size: 28),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
          const SizedBox(width: 10),
        ],
      ),
      // --- ACTUALIZACIÓN: Column + Expanded para el Banner de Anuncios ---
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _scriptsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white)));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: redOrator));
                }

                final scripts = snapshot.data ?? [];
                if (scripts.isEmpty) return _buildEmptyState(context);

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: scripts.length,
                  itemBuilder: (context, index) {
                    final script = scripts[index];
                    final String id = script['id'].toString();
                    final String content = script['content'] ?? '';
                    final String title = script['title'] ?? 'Untitled Script';
                    final wordCount = content.isEmpty
                        ? 0
                        : content.split(RegExp(r'\s+')).length;
                    final readTime = (wordCount / 150).ceil();

                    // --- WIDGET DESLIZABLE ---
                    return Dismissible(
                      key: Key(id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: graySurface,
                            title: const Text("Delete Script?",
                                style: TextStyle(color: Colors.white)),
                            content: const Text("This action cannot be undone.",
                                style: TextStyle(color: Colors.white70)),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text("CANCEL",
                                      style: TextStyle(color: Colors.white38))),
                              TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text("DELETE",
                                      style: TextStyle(color: redOrator))),
                            ],
                          ),
                        );
                      },
                      onDismissed: (direction) => _deleteScript(id),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.delete_outline,
                            color: Colors.white, size: 30),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(
                          color: graySurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          title: Text(title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                                '$readTime min read • Swipe to delete',
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 12)),
                          ),
                          trailing: InkWell(
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => CameraView(
                                          scriptTitle: title,
                                          scriptContent: content)));
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: redOrator.withValues(alpha: 0.1),
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.videocam_rounded,
                                  color: redOrator, size: 28),
                            ),
                          ),
                          onTap: () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        ScriptEditorView(script: script)));
                            _refreshScripts();
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // --- ESTE ES EL COMPONENTE QUE GESTIONA EL PAGO DE $499 MXN ---
          const SmartAdBanner(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: redOrator,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('NEW SCRIPT',
            style:
                TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        onPressed: () async {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ScriptEditorView()));
          _refreshScripts();
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_stories_outlined,
              size: 100, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 20),
          const Text('YOUR STAGE IS READY',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          OutlinedButton.icon(
            onPressed: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ScriptEditorView()));
              _refreshScripts();
            },
            icon: const Icon(Icons.add, color: redOrator),
            label:
                const Text('WRITE NOW', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}