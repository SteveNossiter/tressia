import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-tressia-token',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const url = new URL(req.url)
    const userToken = url.searchParams.get('token') || req.headers.get('X-Tressia-Token') || req.headers.get('Authorization')?.split(' ')[1]
    const body = await req.json()
    const { email, role, clinicId, fullName, redirectTo } = body

    if (!userToken) {
      return new Response(JSON.stringify({ error: 'Missing authentication token' }), { status: 401, headers: corsHeaders })
    }

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: `Bearer ${userToken}` } } }
    )

    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized user token' }), { status: 401, headers: corsHeaders })
    }

    // Verify Admin permission
    const { data: profile } = await supabaseClient.from('users').select('role').eq('id', user.id).single()
    if (!profile || !['admin', 'administrator'].includes(profile.role.toLowerCase())) {
      return new Response(JSON.stringify({ error: 'Insufficient permissions' }), { status: 403, headers: corsHeaders })
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    console.log(`TRESSIA_DEBUG: Admin ${user.id} inviting ${email}`);

    // Try 'invite' link generation
    let { data: linkData, error: linkError } = await supabaseAdmin.auth.admin.generateLink({
      type: 'invite',
      email: email,
      options: {
        redirectTo: redirectTo ?? 'https://tressia.pages.dev/',
        data: { role, clinic_id: clinicId, full_name: fullName }
      }
    });

    // Fallback if user already exists
    if (linkError && (linkError.status === 422 || linkError.message.toLowerCase().includes('already') || linkError.message.toLowerCase().includes('registered'))) {
      console.log(`TRESSIA_DEBUG: User ${email} exists. Generating login link instead.`);
      const { data: magicData, error: magicError } = await supabaseAdmin.auth.admin.generateLink({
        type: 'magiclink',
        email: email,
        options: { redirectTo: redirectTo ?? 'https://tressia.pages.dev/' }
      });
      
      if (!magicError) {
        linkData = magicData;
        linkError = null;
      } else {
        throw magicError;
      }
    }

    if (linkError) throw linkError;

    const actionLink = linkData.properties?.action_link;
    const invitedUserId = linkData.user?.id; // Capture the actual user ID created/updated in Auth
    
    if (!actionLink) throw new Error('Supabase failed to return a link');

    // Send Email via Resend
    // ... (rest of fetch logic)
    const resendApiKey = Deno.env.get('RESEND_API_KEY');
    if (resendApiKey) {
      await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${resendApiKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          from: 'Silvana Nossiter <sil@createtherapy.com.au>',
          to: email,
          subject: 'You have been invited to Tressia',
          html: `
            <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; color: #2D3748;">
              <h2 style="color: #4A5568;">Welcome to Tressia!</h2>
              <p>You have been invited to join the clinic team as a <strong>${role}</strong>.</p>
              <div style="margin: 32px 0;">
                <a href="${actionLink}" style="background-color: #38BDF8; color: white; padding: 14px 28px; text-decoration: none; border-radius: 12px; font-weight: bold; display: inline-block;">Click To Join</a>
              </div>
              <p style="color: #718096; font-size: 12px;">Link: ${actionLink}</p>
            </div>
          `
        })
      });
    }

    // Persist in invites table
    await supabaseAdmin.from('invites').upsert({ 
      clinic_id: clinicId,
      email: email,
      role: role,
      full_name: fullName,
      action_link: actionLink,
      auth_user_id: invitedUserId, // Store the ID for future total deletion
      created_by: user.id
    }, { onConflict: 'clinic_id,email' });

    return new Response(JSON.stringify({ success: true, action_link: actionLink, inviteLink: actionLink }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error: any) {
    console.error(`TRESSIA_DEBUG_ERROR: ${error.message}`);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})

