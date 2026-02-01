import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-client@2"

serve(async (req) => {
  try {
    const body = await req.json()
    const { event } = body
    
    console.log(`Webhook recibido: ${event.type} para usuario: ${event.app_user_id}`)

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? ''
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const userId = event.app_user_id
    let isPremium = false

    const activeEvents = ['INITIAL_PURCHASE', 'RENEWAL', 'RESTORE']
    const inactiveEvents = ['CANCELLATION', 'EXPIRATION', 'BILLING_ERROR']

    if (activeEvents.includes(event.type)) {
      isPremium = true
    } else if (inactiveEvents.includes(event.type)) {
      isPremium = false
    } else {
      return new Response(JSON.stringify({ message: "Evento ignorado" }), { status: 200 })
    }

    const { error } = await supabase
      .from('profiles')
      .update({ is_premium: isPremium })
      .eq('id', userId)

    if (error) throw error

    return new Response(JSON.stringify({ success: true, status: isPremium }), { status: 200 })
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 400 })
  }
})