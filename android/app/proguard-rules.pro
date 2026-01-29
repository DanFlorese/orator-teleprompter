# Reglas básicas para Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Solución para el error de Google Play Core (tu fallo de R8)
-keep class com.google.android.play.core.** { *; }

# Mantener AdMob y Google Play Services
-keep public class com.google.android.gms.ads.** { public *; }
-keep public class com.google.android.gms.common.internal.safeparcel.SafeParcelable { public *; }

# Evitar advertencias que detienen la compilación
-dontwarn com.google.android.play.core.**