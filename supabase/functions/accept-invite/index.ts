import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) throw new Error('Missing Authorization header')

    // Create Admin Client to query invites without RLS blocking us
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Verify the caller's JWT safely
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error: userError } = await supabase.auth.getUser()
    if (userError || !user) throw new Error('Invalid user token')

    console.log(`TRESSIA_DEBUG: User ${user.id} (${user.email}) accepting invite.`);

    // Check if they are already in users table
    const { data: existingUser } = await supabaseAdmin.from('users').select('id').eq('id', user.id).single();
    if (existingUser) {
      return new Response(JSON.stringify({ success: true, message: 'Already a user' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    // Find their invite natively using Admin
    const { data: invite, error: inviteError } = await supabaseAdmin
      .from('invites')
      .select('*')
      .eq('email', user.email)
      .single()

    if (inviteError || !invite) {
      throw new Error('No valid invitation found for this email address.');
    }

    // They found an invite. Map them to public.users!
    const { error: insertError } = await supabaseAdmin.from('users').insert({
      id: user.id,
      clinic_id: invite.clinic_id,
      full_name: invite.full_name || 'Staff Member',
      role: invite.role,
      setup_complete: false // They must complete their profile!
    });

    if (insertError) throw insertError;

    // Destroy the used invite securely
    await supabaseAdmin.from('invites').delete().eq('id', invite.id);

    console.log(`TRESSIA_DEBUG: Successfully migrated ${user.email} from invites to public.users!`);

    return new Response(JSON.stringify({ success: true }), {
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
