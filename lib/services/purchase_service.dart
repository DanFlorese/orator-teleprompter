import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ==========================================
// 1. LOGIC SERVICE (PurchaseService)
// ==========================================
class PurchaseService {
  static Future<void> init() async {
    try {
      // En producción usamos LogLevel.error para evitar ruido en la consola
      await Purchases.setLogLevel(LogLevel.error);
      
      String? apiKey = dotenv.env['REVENUECAT_GOOGLE_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        debugPrint("PurchaseService: API Key not found in .env");
        return;
      }

      PurchasesConfiguration configuration = PurchasesConfiguration(apiKey);
      await Purchases.configure(configuration);
      
      // Iniciamos el escuchador reactivo profesional
      _setupCustomerInfoListener();
      
      debugPrint("PurchaseService: Initialization successful");
    } catch (e) {
      debugPrint("PurchaseService: Initialization error: $e");
    }
  }

  /// Escuchador reactivo: Si el estado cambia en RevenueCat (compra, expiración, 
  /// reembolso), Supabase se actualiza automáticamente.
  static void _setupCustomerInfoListener() {
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      final isPremium = customerInfo.entitlements.all['Pro']?.isActive ?? false;
      debugPrint("PurchaseService: Syncing reactive status -> Premium: $isPremium");
      
      // Sincronización automática en ambos sentidos
      _updateSupabasePremiumStatus(isPremium);
    });
  }

  /// Método centralizado para actualizar el estatus en la base de datos
  static Future<void> _updateSupabasePremiumStatus(bool status) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({'is_premium': status})
            .eq('id', user.id);
        debugPrint("Supabase: Profile synced (is_premium: $status)");
      }
    } catch (e) {
      debugPrint("Supabase Sync Error: $e");
    }
  }

  static Future<String?> getAnnualPrice() async {
    try {
      Offerings offerings = await Purchases.getOfferings();
      return offerings.current?.annual?.storeProduct.priceString;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> purchaseSubscription() async {
    try {
      Offerings offerings = await Purchases.getOfferings();
      Package? packageToBuy = offerings.current?.annual;
      
      if (packageToBuy != null) {
        final PurchaseResult result = await Purchases.purchasePackage(packageToBuy);
        bool isActive = result.customerInfo.entitlements.all['Pro']?.isActive ?? false;

        // Sincronizamos inmediatamente tras la compra
        await _updateSupabasePremiumStatus(isActive);
        return isActive;
      }
      return false;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        debugPrint("PurchaseService Error: ${e.message}");
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> restorePurchases() async {
    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      bool isActive = customerInfo.entitlements.all['Pro']?.isActive ?? false;
      
      await _updateSupabasePremiumStatus(isActive);
      return isActive;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> isUserPremium() async {
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all['Pro']?.isActive ?? false;
    } catch (e) {
      return false;
    }
  }
}

// ==========================================
// 2. INTERFACE WIDGET (SubscriptionWidget)
// ==========================================
class SubscriptionWidget extends StatefulWidget {
  const SubscriptionWidget({super.key});

  @override
  State<SubscriptionWidget> createState() => _SubscriptionWidgetState();
}

class _SubscriptionWidgetState extends State<SubscriptionWidget> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      // Usamos la fuente de verdad de RevenueCat para la UI
      future: PurchaseService.isUserPremium(),
      builder: (context, premiumSnapshot) {
        if (premiumSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // VISTA PARA USUARIOS PREMIUM
        if (premiumSnapshot.data == true) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded, color: Colors.amber, size: 60),
                const SizedBox(height: 12),
                const Text("You are a Premium User!", 
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const Text("All Pro features are unlocked."),
                const SizedBox(height: 20),
                // Botón de seguridad para restaurar si algo falla
                TextButton(
                  onPressed: () => PurchaseService.restorePurchases(), 
                  child: const Text("Refresh subscription status")
                )
              ],
            ),
          );
        }

        // VISTA PARA USUARIOS GRATUITOS (PAYWALL)
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FutureBuilder<String?>(
                future: PurchaseService.getAnnualPrice(),
                builder: (context, priceSnapshot) {
                  final price = priceSnapshot.data ?? "---";
                  return Text(
                    "Upgrade to Pro - $price/yr",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  );
                },
              ),
              const SizedBox(height: 24),
              
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isProcessing ? null : () async {
                  setState(() => _isProcessing = true);
                  bool success = await PurchaseService.purchaseSubscription();
                  if (!context.mounted) return;
                  setState(() => _isProcessing = false);

                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Success! You are now Pro.")),
                    );
                  }
                },
                child: _isProcessing 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("SUBSCRIBE NOW", style: TextStyle(color: Colors.white, fontSize: 18)),
              ),

              TextButton(
                onPressed: _isProcessing ? null : () async {
                  setState(() => _isProcessing = true);
                  bool restored = await PurchaseService.restorePurchases();
                  if (!context.mounted) return;
                  setState(() => _isProcessing = false);

                  if (restored) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Subscription restored successfully.")),
                    );
                  }
                },
                child: const Text("Already Pro? Restore purchase"),
              ),
            ],
          ),
        );
      },
    );
  }
}