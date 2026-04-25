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

    // 1. Initialize client with user token to verify permissions
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: `Bearer ${userToken}` } } }
    )

    // Verify user identity
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    if (userError || !user) {
      console.error(`TRESSIA_DEBUG_ERROR: Auth failure: ${userError?.message}`);
      return new Response(JSON.stringify({ error: 'Unauthorized user token' }), { status: 401, headers: corsHeaders })
    }

    // 2. Verify user has permission (Admin/Administrator role)
    const { data: profile, error: profileError } = await supabaseClient
      .from('users')
      .select('role')
      .eq('id', user.id)
      .single()

    if (profileError || !profile || !['admin', 'administrator'].includes(profile.role.toLowerCase())) {
      console.warn(`TRESSIA_DEBUG_WARNING: User ${user.id} attempted to invite without admin rights.`);
      return new Response(JSON.stringify({ error: 'Insufficient permissions to invite users' }), { status: 403, headers: corsHeaders })
    }

    console.log(`TRESSIA_DEBUG: Admin ${user.id} inviting ${fullName} (${email}) as ${role} for clinic ${clinicId}`);

    // 3. Create Admin Client (Uses service role to perform admin actions)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 4. Generate the invite link directly
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
    if (!actionLink) {
      throw new Error('Supabase failed to return an action link');
    }

    console.log(`TRESSIA_DEBUG: Invite link generated successfully`);

    // 5. Send the email via Resend
    const resendApiKey = Deno.env.get('RESEND_API_KEY');
    if (resendApiKey) {
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
            <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; color: #2D3748;">
              <h2 style="color: #4A5568;">Welcome to Tressia!</h2>
              <p style="font-size: 16px;">You have been invited to join the clinic team as a <strong>${role}</strong>.</p>
              <p style="font-size: 16px;">Click the button below to set up your professional profile and password:</p>
              <div style="margin: 32px 0;">
                <a href="${actionLink}" style="background-color: #38BDF8; color: white; padding: 14px 28px; text-decoration: none; border-radius: 12px; font-weight: bold; display: inline-block;">Join Tressia Team</a>
              </div>
              <p style="color: #718096; font-size: 14px; margin-top: 40px;">If the button above doesn't work, copy and paste this link into your browser:<br><br>${actionLink}</p>
              <div style="border-top: 1px solid #E2E8F0; margin-top: 40px; padding-top: 20px;">
                 <p style="font-size: 12px; color: #A0AEC0;">This invite was sent from Tressia on behalf of your clinic administrator.</p>
              </div>
            </div>
          `
        })
      });

      if (!resendResponse.ok) {
        const resendErr = await resendResponse.text();
        console.error(`TRESSIA_DEBUG_ERROR: Resend API failed: ${resendErr}`);
      }
    }

    // 6. Final Update: Persist the link in our public.invites table
    // We use upsert here to be absolutely sure the record exists with the link
    const { error: dbError } = await supabaseAdmin
      .from('invites')
      .upsert({ 
        clinic_id: clinicId,
        email: email,
        role: role,
        full_name: fullName,
        action_link: actionLink,
        created_by: user.id
      }, { onConflict: 'clinic_id,email' });

    if (dbError) {
      console.error(`TRESSIA_DEBUG_ERROR: DB update failed: ${dbError.message}`);
      // We don't throw here because the link was generated and email sent, 
      // we still want to return the link to the client.
    }

    return new Response(JSON.stringify({ 
      success: true, 
      action_link: actionLink,
      inviteLink: actionLink // Providing both for compatibility
    }), {
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

