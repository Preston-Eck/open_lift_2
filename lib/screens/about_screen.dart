import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("About OpenLift")),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final info = snapshot.data!;
          final version = "${info.version} (Build ${info.buildNumber})";

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo / Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.renewalTeal,
                    borderRadius: BorderRadius.circular(20),
                    image: const DecorationImage(
                      image: AssetImage('assets/icon/app_icon.png'),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // App Name
                Text(
                  "OpenLift 2.0",
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.foundationalSlate,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Version $version",
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 48),

                // Action Buttons
                SizedBox(
                  width: 200,
                  child: OutlinedButton(
                    onPressed: () {
                      showLicensePage(
                        context: context,
                        applicationName: "OpenLift 2.0",
                        applicationVersion: version,
                        applicationIcon: const Icon(Icons.fitness_center),
                      );
                    },
                    child: const Text("Open Source Licenses"),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Copyright
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "© 2025 Vitality Rise.\nDesigned for Strength.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}