import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PurchaseService {
  // Inicialización del SDK
  static Future<void> init() async {
    try {
      await Purchases.setLogLevel(LogLevel.debug);

      // Usamos la llave del archivo .env de forma segura
      String? apiKey = dotenv.env['REVENUECAT_GOOGLE_KEY'];
      
      if (apiKey == null || apiKey.isEmpty) {
        debugPrint("Error: No se encontró la API Key en el archivo .env");
        return;
      }

      PurchasesConfiguration configuration = PurchasesConfiguration(apiKey);
      await Purchases.configure(configuration);
      
      // Configuramos el listener para cambios de estado globales
      _setupCustomerInfoListener();
      
      debugPrint("RevenueCat inicializado con éxito");
    } catch (e) {
      debugPrint("Error inicializando RevenueCat: $e");
    }
  }

  // Escucha cambios en la suscripción (ej: si el usuario cancela o restaura)
  static void _setupCustomerInfoListener() {
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      // Cambiado a 'pro' para coincidir con tu Dashboard
      final isPremium = customerInfo.entitlements.all['pro']?.isActive ?? false;
      debugPrint("Listener de RevenueCat: Premium activo = $isPremium");
    });
  }

  // --- FUNCIÓN PARA OBTENER PRECIO LOCALIZADO ---
  static Future<String?> getAnnualPrice() async {
    try {
      Offerings offerings = await Purchases.getOfferings();
      // Esto traerá el precio que configuraste en Google Play Console
      return offerings.current?.annual?.storeProduct.priceString;
    } catch (e) {
      debugPrint("Error obteniendo precio: $e");
      return null;
    }
  }

  // --- FUNCIÓN PARA COMPRAR ---
  static Future<bool> purchaseSubscription() async {
    try {
      Offerings offerings = await Purchases.getOfferings();
      
      if (offerings.current != null && offerings.current!.annual != null) {
        final PurchaseResult result = await Purchases.purchasePackage(
          offerings.current!.annual!,
        );
        
        // Verificamos el entitlement 'pro'
        return result.customerInfo.entitlements.all['pro']?.isActive ?? false;
      } else {
        debugPrint("No se encontraron ofertas configuradas en el dashboard");
      }
      return false;
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        debugPrint("Error de compra: ${e.message}");
      }
      return false;
    } catch (e) {
      debugPrint("Error inesperado: $e");
      return false;
    }
  }

  // --- FUNCIÓN PARA RESTAURAR COMPRAS ---
  static Future<bool> restorePurchases() async {
    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      return customerInfo.entitlements.all['pro']?.isActive ?? false;
    } on PlatformException catch (e) {
      debugPrint("Error restaurando compras: ${e.message}");
      return false;
    }
  }

  // --- VERIFICAR ESTADO ACTUAL ---
  static Future<bool> isUserPremium() async {
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all['pro']?.isActive ?? false;
    } catch (e) {
      debugPrint("Error verificando estado: $e");
      return false;
    }
  }
}