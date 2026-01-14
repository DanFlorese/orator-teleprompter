import 'package:flutter/material.dart';
import 'package:orator_teleprompter/core/theme.dart';

class TermsConditionsView extends StatelessWidget {
  const TermsConditionsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blackBackground,
      appBar: AppBar(
        title: const Text('Terms & Conditions', style: TextStyle(color: Colors.white)),
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
              'User Agreement',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _termSection(
              '1. Acceptance of Agreement', 
              'By creating an account and using Orator Teleprompter, you enter into a legally binding contract. If you do not agree to these terms, you must immediately cease use of the service and delete your account.'
            ),
            _termSection(
              '2. Limitation of Liability (The Shield)', 
              'Orator Teleprompter is provided "AS IS". Under no circumstances shall the developer be liable for any professional damages, loss of data, failed recordings, or economic losses resulting from technical interruptions or software errors during use.'
            ),
            _termSection(
              '3. Intellectual Property', 
              'All software code, interface designs, and brand assets are the exclusive property of the developer. Users are granted a limited, non-transferable license to use the app for content creation purposes.'
            ),
            _termSection(
              '4. Content Responsibility', 
              'You retain full ownership of your scripts. However, you are solely responsible for ensuring your content does not violate copyright laws, privacy rights, or local regulations. We do not monitor user-generated content.'
            ),
            _termSection(
              '5. Account Termination', 
              'We reserve the right to terminate or suspend access to our service (including Supabase database access) for users who attempt to reverse-engineer the app, bypass security measures, or engage in prohibited conduct.'
            ),
            _termSection(
              '6. Governing Law', 
              'This agreement shall be governed by and construed in accordance with the laws of your jurisdiction. Any disputes arising shall be subject to binding arbitration.'
            ),
            const SizedBox(height: 30),
            const Divider(color: Colors.white10),
            const SizedBox(height: 20),
            const Center(
              child: Column(
                children: [
                  Text(
                    'Contact: legal@yourdomain.com', // REEMPLAZA CON TU EMAIL
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

  Widget _termSection(String title, String content) {
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