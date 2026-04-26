import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // CORS Pre-flight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { userId, email } = await req.json()
    
    // Create Admin Client (Bypass RLS)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    let targetId = userId;

    // Fallback: If no ID but we have an email, look them up in auth
    if (!targetId && email) {
      console.log(`TRESSIA_DEBUG: No ID provided, searching for user by email: ${email}`);
      const { data, error: listError } = await supabaseAdmin.auth.admin.listUsers();
      if (!listError && data?.users) {
        const found = data.users.find(u => u.email?.toLowerCase() === email.toLowerCase());
        if (found) {
          targetId = found.id;
          console.log(`TRESSIA_DEBUG: Found user ID ${targetId} for email ${email}`);
        }
      } else if (listError) {
        console.error('TRESSIA_DEBUG_ERROR: listUsers failed:', listError);
      }
    }

    if (!targetId) {
      console.log('TRESSIA_DEBUG: No user ID identified for deletion. This might be because the user was already purged or never created. Proceeding with success.');
      return new Response(JSON.stringify({ success: true, message: 'Nothing to delete' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    console.log(`TRESSIA_DEBUG: Attempting to delete user ${targetId}`);

    // Deleting from auth.users securely wipes them from the system and cascades to public.users!
    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(targetId)

    if (deleteError) {
      // If user doesn't exist (404), that is a success for us!
      if (deleteError.status === 404 || deleteError.message?.toLowerCase().includes('not found')) {
        console.log(`TRESSIA_DEBUG: User ${targetId} already purged.`);
        return new Response(JSON.stringify({ success: true, message: 'Already purged' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        })
      }
      
      console.error(`TRESSIA_DEBUG_ERROR: Failed to delete user ${targetId}:`, deleteError);
      throw deleteError;
    }

    console.log(`TRESSIA_DEBUG_SUCCESS: User ${targetId} fully purged from system.`);

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
