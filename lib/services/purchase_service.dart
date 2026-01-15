import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PurchaseService {
  // --- LLAVES DE REVENUECAT ---
  // He colocado tu llave real aquí para que la app pueda inicializar correctamente
  static const _apiKey = 'test_tTSbOOROmMVkZjVrnVBgHyhOzcM';

  static Future<void> init() async {
    // LogLevel.debug nos permite ver en la consola si la llave funciona o si hay errores de red
    await Purchases.setLogLevel(LogLevel.debug);

    PurchasesConfiguration configuration;
    
    // Por ahora usamos la misma llave para Android e iOS ya que es una Public SDK Key
    configuration = PurchasesConfiguration(_apiKey);
    
    await Purchases.configure(configuration);
    debugPrint("RevenueCat inicializado con éxito");
  }

  // --- FUNCIÓN PARA COMPRAR ---
  static Future<bool> purchaseSubscription() async {
    try {
      // Busca los productos configurados en el panel de RevenueCat
      Offerings offerings = await Purchases.getOfferings();
      
      if (offerings.current != null && offerings.current!.annual != null) {
        // Usamos el constructor nombrado corregido para evitar errores de compilación
        final PurchaseResult result = await Purchases.purchase(
          PurchaseParams.package(offerings.current!.annual!),
        );
        
        // Extraemos la información del cliente del resultado de la compra
        final CustomerInfo customerInfo = result.customerInfo;
        
        // Verifica si el derecho (entitlement) "premium" está activo
        return customerInfo.entitlements.all['premium']?.isActive ?? false;
      } else {
        debugPrint("No se encontraron ofertas actuales o paquete anual");
      }
      return false;
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      // No imprimimos error si el usuario simplemente cerró la ventana de pago
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        debugPrint("Error de compra: ${e.message}");
      }
      return false;
    } catch (e) {
      debugPrint("Error inesperado en la compra: $e");
      return false;
    }
  }

  // --- FUNCIÓN PARA VERIFICAR ESTADO (USADA EN EL TELEPROMPTER) ---
  static Future<bool> isUserPremium() async {
    try {
      // Consulta el estado actual del usuario directamente en RevenueCat
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all['premium']?.isActive ?? false;
    } catch (e) {
      debugPrint("Error verificando estado premium: $e");
      return false;
    }
  }
}