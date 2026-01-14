import 'package:flutter/material.dart';
import 'package:orator_teleprompter/core/theme.dart';

class PrivacyPolicyView extends StatelessWidget {
  const PrivacyPolicyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blackBackground,
      appBar: AppBar(
        title: const Text('Privacy Policy', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Data Protection & Privacy',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _policySection(
              '1. Data Collection', 
              'We collect your email address for authentication and your display name for profile personalization. Your password is encrypted via Supabase Auth and is never visible to us.'
            ),
            _policySection(
              '2. Third-Party Infrastructure', 
              'We use Supabase (hosted on secure AWS/Google Cloud infrastructure) as our primary database provider. By using this app, you acknowledge that your data will be stored and processed through their secure systems.'
            ),
            _policySection(
              '3. Local vs. Cloud Storage', 
              'Your scripts are stored in our cloud database to allow multi-device sync. Videos recorded are stored locally on your device unless you explicitly choose to upload them to your allocated storage bucket.'
            ),
            _policySection(
              '4. Permissions', 
              'Orator Teleprompter requires access to your Camera and Microphone solely for the purpose of recording your videos. We do not record or transmit any data in the background.'
            ),
            _policySection(
              '5. Data Deletion (Right to be Forgotten)', 
              'In compliance with GDPR and CCPA, you have the right to permanent deletion. Using the "Delete Account" feature in your profile will trigger an irreversible process that wipes all your records from our servers.'
            ),
            const SizedBox(height: 30),
            const Divider(color: Colors.white10),
            const SizedBox(height: 20),
            const Center(
              child: Column(
                children: [
                  Text(
                    'Contact: support@yourdomain.com', // REEMPLAZA CON TU EMAIL REAL
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Version 1.0 - Last updated: January 2026',
                    style: TextStyle(color: Colors.white24, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _policySection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title, 
            style: const TextStyle(color: redOrator, fontWeight: FontWeight.bold, fontSize: 16)
          ),
          const SizedBox(height: 8),
          Text(
            content, 
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)
          ),
        ],
      ),
    );
  }
}