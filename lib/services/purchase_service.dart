import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PurchaseService {
  // --- LLAVES DE REVENUECAT ---
  static const _apiKey = 'goog_yMfiOIoyJKdOrRDVwyFYlYQuhRk';

  // Inicialización del SDK
  static Future<void> init() async {
    await Purchases.setLogLevel(LogLevel.debug);

    PurchasesConfiguration configuration = PurchasesConfiguration(_apiKey);
    await Purchases.configure(configuration);
    
    // Configuramos el listener para cambios de estado globales
    _setupCustomerInfoListener();
    
    debugPrint("RevenueCat inicializado con éxito");
  }

  // Escucha cambios en la suscripción (ej: si el usuario cancela o restaura)
  static void _setupCustomerInfoListener() {
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      final isPremium = customerInfo.entitlements.all['premium']?.isActive ?? false;
      debugPrint("Listener de RevenueCat: Premium activo = $isPremium");
    });
  }

  // --- FUNCIÓN PARA OBTENER PRECIO LOCALIZADO ---
  // Útil para poner "Upgrade - ${price}" en el botón sin escribirlo a mano
  static Future<String?> getAnnualPrice() async {
    try {
      Offerings offerings = await Purchases.getOfferings();
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
        final PurchaseResult result = await Purchases.purchase(
          PurchaseParams.package(offerings.current!.annual!),
        );
        
        return result.customerInfo.entitlements.all['premium']?.isActive ?? false;
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
  // Obligatorio para cumplir con las políticas de la App Store
  static Future<bool> restorePurchases() async {
    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      return customerInfo.entitlements.all['premium']?.isActive ?? false;
    } on PlatformException catch (e) {
      debugPrint("Error restaurando compras: ${e.message}");
      return false;
    }
  }

  // --- VERIFICAR ESTADO ACTUAL ---
  static Future<bool> isUserPremium() async {
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all['premium']?.isActive ?? false;
    } catch (e) {
      debugPrint("Error verificando estado: $e");
      return false;
    }
  }
}