Save your ENOSIS logo PNG in this folder as exactly:

    enosis_logo.png

(i.e. this file should end up living at assets/branding/enosis_logo.png)

The app looks for it at that exact path (see lib/features/auth/presentation/screens/splash_screen.dart
and login_screen.dart). If it's missing, the app still runs — it just shows a
fallback icon instead of your logo, and prints a note in the debug console.

You can delete this .txt file once the real logo.png is in place.
