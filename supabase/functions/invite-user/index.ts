import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-tressia-token',
}

serve(async (req) => {
  // Handle CORS Pre-flight
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
      console.error(`TRESSIA_DEBUG_ERROR: Auth failure: ${userError?.message}`);
      return new Response(JSON.stringify({ error: 'Unauthorized user token' }), { status: 401, headers: corsHeaders })
    }

    console.log(`TRESSIA_DEBUG: Inviting ${fullName} (${email}) as ${role} for clinic ${clinicId}`);

    // Create Admin Client (Uses service role to bypass RLS)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 1. Generate the invite link directly
    const { data: linkData, error: linkError } = await supabaseAdmin.auth.admin.generateLink({
      type: 'invite',
      email: email,
      options: {
        redirectTo: redirectTo ?? 'https://tressia.pages.dev/',
        data: { 
          role: role,
          clinic_id: clinicId,
          full_name: fullName,
          needs_password_setup: true
        }
      }
    });

    if (linkError) {
      console.error(`TRESSIA_DEBUG_ERROR: Failed to generate link for ${email}:`, linkError);
      throw linkError;
    }

    const actionLink = linkData.properties?.action_link;
    console.log(`TRESSIA_DEBUG: Invite link generated: ${actionLink}`);

    // 2. Fetch the Resend API Key (we will rely on a Supabase Secret)
    const resendApiKey = Deno.env.get('RESEND_API_KEY');

    if (resendApiKey) {
      // 3. Send the email manually via Resend REST API
      const resendResponse = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${resendApiKey}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          from: 'Silvana Nossiter <sil@createtherapy.com.au>',
          to: email,
          subject: 'You have been invited to Tressia',
          html: `
            <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto;">
              <h2 style="color: #2D3748;">Welcome to Tressia!</h2>
              <p style="color: #4A5568; font-size: 16px;">You have been invited to join the clinic team as a <strong>${role}</strong>.</p>
              <p style="color: #4A5568; font-size: 16px;">Click the button below to set up your account and get started:</p>
              <div style="margin: 30px 0;">
                <a href="${actionLink}" style="background-color: #3182CE; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; font-weight: bold; display: inline-block;">Accept Invitation</a>
              </div>
              <p style="color: #718096; font-size: 14px; margin-top: 40px;">If the button doesn't work, copy and paste this link into your browser:<br><br>${actionLink}</p>
            </div>
          `
        })
      });

      if (!resendResponse.ok) {
        const resendErr = await resendResponse.text();
        console.error(`TRESSIA_DEBUG_ERROR: Resend API failed with status ${resendResponse.status}: ${resendErr}`);
      } else {
        const resendData = await resendResponse.json();
        console.log(`TRESSIA_DEBUG_SUCCESS: Email ID ${resendData.id} sent via Resend API to ${email}`);
      }
    } else {
      console.warn(`TRESSIA_DEBUG_WARNING: No RESEND_API_KEY found in Edge Function Environment. Skipping email delivery.`);
    }

    // 4. Update the public.invites table securely
    await supabaseAdmin
      .from('invites')
      .update({ action_link: actionLink })
      .ilike('email', email)
      .eq('clinic_id', clinicId);

    return new Response(JSON.stringify({ success: true, action_link: actionLink }), {
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
