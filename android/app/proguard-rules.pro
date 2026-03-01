# Pigio ProGuard / R8 rules

# ── Flutter ──────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── Firebase ─────────────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# ── AppAuth ───────────────────────────────────────────────────────────────────
-keep class net.openid.appauth.** { *; }

# ── Passkeys ─────────────────────────────────────────────────────────────────
-keep class androidx.credentials.** { *; }

# ── Kotlin coroutines ────────────────────────────────────────────────────────
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

# ── Keep annotations used by deserialization ─────────────────────────────────
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
