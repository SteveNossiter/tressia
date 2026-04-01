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
    const { email, role, clinicId, fullName } = await req.json()
    console.log(`TRESSIA_DEBUG: Inviting ${fullName} (${email}) as ${role} for clinic ${clinicId}`);

    // Create Admin Client (Uses service role to bypass RLS)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Generate the invite link directly (bypassing native email delivery)
    const { data: linkData, error: linkError } = await supabaseAdmin.auth.admin.generateLink({
      type: 'invite',
      email: email,
      options: {
        redirectTo: 'https://tressia.pages.dev/',
        data: { 
          role: role,
          clinic_id: clinicId,
          full_name: fullName
        }
      }
    });

    if (linkError) {
      console.error(`TRESSIA_DEBUG_ERROR: Failed to generate link for ${email}:`, linkError);
      throw linkError;
    }

    const actionLink = linkData.properties?.action_link;
    console.log(`TRESSIA_DEBUG_SUCCESS: Invite link generated for ${email}. ID: ${linkData.user.id}`);

    // Update the public.invites table securely via service role
    await supabaseAdmin
      .from('invites')
      .update({ action_link: actionLink })
      .eq('email', email)
      .eq('clinic_id', clinicId);

    return new Response(JSON.stringify({ success: true, action_link: actionLink, data: linkData }), {
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
