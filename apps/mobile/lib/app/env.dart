/// Compile-time environment configuration.
///
/// Values are injected via `--dart-define` (or `--dart-define-from-file`)
/// at build/run time — never hardcoded, never read from a bundled `.env`
/// file. Flutter has no built-in dotenv support; adding an unverified
/// new pub dependency to read one felt riskier in this environment (no
/// network to actually fetch/verify a package) than using Dart's
/// built-in compile-time environment mechanism, which needs nothing
/// extra installed.
///
/// Example:
/// ```bash
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xyz.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJ...
/// ```
///
/// Or via a git-ignored JSON file (`--dart-define-from-file=env.json`)
/// for anything beyond a couple of values — see Flutter's own docs for
/// the exact flag, this project doesn't commit an env.json.
class Env {
  Env._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
