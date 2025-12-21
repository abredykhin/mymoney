import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'jsr:@supabase/supabase-js@2'
import { Configuration, PlaidApi, PlaidEnvironments } from 'npm:plaid@31.1.0'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get authenticated user
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! }
        }
      }
    )

    const { data: { user }, error: userError } = await supabase.auth.getUser()
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Parse request body
    const { public_token, institution_id } = await req.json()

    if (!public_token || !institution_id) {
      return new Response(
        JSON.stringify({ error: 'Missing public_token or institution_id' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`Saving new item for user ${user.id}, institution: ${institution_id}`)

    // Initialize Plaid client
    const plaidConfig = new Configuration({
      basePath: PlaidEnvironments[Deno.env.get('PLAID_ENV') || 'sandbox'],
      baseOptions: {
        headers: {
          'PLAID-CLIENT-ID': Deno.env.get('PLAID_CLIENT_ID'),
          'PLAID-SECRET': Deno.env.get('PLAID_SECRET'),
        },
      },
    })
    const plaidClient = new PlaidApi(plaidConfig)

    // Check for duplicate item
    const { data: existingItems } = await supabase
      .from('items_table')
      .select('id')
      .eq('user_id', user.id)
      .eq('plaid_institution_id', institution_id)
      .eq('is_active', true)
      .limit(1)

    if (existingItems && existingItems.length > 0) {
      return new Response(
        JSON.stringify({ error: 'Item already exists for this institution' }),
        { status: 409, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get institution details from Plaid
    console.log('Fetching institution details from Plaid...')
    const institutionResponse = await plaidClient.institutionsGetById({
      institution_id: institution_id,
      country_codes: ['US'],
      options: {
        include_optional_metadata: true,
      },
    })

    const institution = institutionResponse.data.institution
    console.log(`Got institution: ${institution.name}`)

    // Use service role to insert institution (bypasses RLS)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // Upsert institution (insert or update if exists)
    await supabaseAdmin
      .from('institutions_table')
      .upsert({
        institution_id: institution.institution_id,
        name: institution.name,
        primary_color: institution.primary_color || null,
        url: institution.url || null,
        logo: institution.logo || null,
      }, {
        onConflict: 'institution_id'
      })

    console.log('Institution saved to database')

    // Exchange public token for access token
    console.log('Exchanging public token for access token...')
    const tokenResponse = await plaidClient.itemPublicTokenExchange({
      public_token: public_token,
    })

    const accessToken = tokenResponse.data.access_token
    const itemId = tokenResponse.data.item_id

    console.log(`Got access token for item ${itemId}`)

    // Get accounts for this item
    console.log('Fetching accounts from Plaid...')
    const accountsResponse = await plaidClient.accountsGet({
      access_token: accessToken,
    })

    const accounts = accountsResponse.data.accounts

    // Save item to database
    console.log('Saving item to database...')
    const { data: newItem, error: itemError } = await supabase
      .from('items_table')
      .insert({
        user_id: user.id,
        bank_name: institution.name,
        plaid_access_token: accessToken,
        plaid_item_id: itemId,
        plaid_institution_id: institution_id,
        status: 'good',
        is_active: true,
        transactions_cursor: null,
      })
      .select()
      .single()

    if (itemError) {
      console.error('Error saving item:', itemError)
      throw itemError
    }

    console.log(`Item saved with id ${newItem.id}`)

    // Save accounts to database
    console.log(`Saving ${accounts.length} accounts...`)
    const accountsToInsert = accounts.map(account => ({
      item_id: newItem.id,
      plaid_account_id: account.account_id,
      name: account.name,
      mask: account.mask || '',
      official_name: account.official_name || null,
      current_balance: account.balances.current || 0,
      available_balance: account.balances.available || null,
      iso_currency_code: account.balances.iso_currency_code || null,
      unofficial_currency_code: account.balances.unofficial_currency_code || null,
      type: account.type,
      subtype: account.subtype || '',
      hidden: false,
    }))

    const { error: accountsError } = await supabase
      .from('accounts_table')
      .insert(accountsToInsert)

    if (accountsError) {
      console.error('Error saving accounts:', accountsError)
      throw accountsError
    }

    console.log('Accounts saved successfully')

    // Trigger initial transaction sync
    console.log('Triggering initial transaction sync...')
    try {
      const syncResponse = await fetch(
        `${Deno.env.get('SUPABASE_URL')}/functions/v1/sync-transactions`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
          },
          body: JSON.stringify({ plaid_item_id: itemId }),
        }
      )

      if (!syncResponse.ok) {
        console.warn('Initial sync failed, but item was saved. Webhook will handle sync.')
      } else {
        console.log('Initial sync completed successfully')
      }
    } catch (syncError) {
      console.warn('Initial sync error (non-fatal):', syncError)
    }

    // Return success
    return new Response(
      JSON.stringify({
        success: true,
        item: {
          id: newItem.id,
          institution_name: institution.name,
          accounts_count: accounts.length,
        }
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.error('Error in save-item function:', error)
    return new Response(
      JSON.stringify({
        error: error.message || 'Internal server error',
        details: error.toString()
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
