import 'package:flutter/material.dart';

/// Shown instead of a blank screen when the build-time configuration is
/// invalid (bad APP_FLAVOR / API_BASE_URL). Deliberately localisation-free
/// and detail-free: it must work before any service exists and must not leak
/// configuration to whoever holds the device.
Widget buildStartupErrorApp() => const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                startupErrorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
        ),
      ),
    );

const startupErrorMessage = 'App configuration error — please reinstall or contact support';
