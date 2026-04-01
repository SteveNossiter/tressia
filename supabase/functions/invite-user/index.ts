import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS Pre-flight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { email, role, clinicId } = await req.json()
    console.log(`TRESSIA_DEBUG: Inviting ${email} as ${role} for clinic ${clinicId}`);

    // Create Admin Client (Uses service role to bypass RLS)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Trigger the official Supabase Auth Invitation
    const { data, error } = await supabaseAdmin.auth.admin.inviteUserByEmail(email, {
      data: { 
        role: role,
        clinic_id: clinicId
      },
    })

    if (error) {
      console.error(`TRESSIA_DEBUG_ERROR: Failed to invite ${email}:`, error);
      throw error;
    }

    console.log(`TRESSIA_DEBUG_SUCCESS: Invite sent to ${email}. ID: ${data.user.id}`);

    return new Response(JSON.stringify({ success: true, data }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error: any) {
    console.error(`TRESSIA_DEBUG_CATCH: ${error.message}`);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
