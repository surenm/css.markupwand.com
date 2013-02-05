$(document).ready () ->  
  
  $("#sedan").click () ->
    SEDANHandler = (stripe_data) ->
      stripe_data.plan = 'sedan'
      $.post '/register-card', stripe_data, (data) ->
        console.log data
   
    StripeCheckout.open {
      key:         'pk_aRDAInglKtq2Y0w5zglZtRhkrqZkH'
      address:     true
      name:        'CSS:Markupwand'
      description: 'Regular ($15/month) '
      panelLabel:  'Register for payment'
      token:       SEDANHandler
      image:       '/assets/wand.png'
    }

    return false

  $("#suv").click () ->
    SUVHandler = (stripe) ->
      stripe_data.plan = 'suv'
      $.post '/register-card', stripe_data, (data) ->
        console.log data

    StripeCheckout.open {
      key:         'pk_aRDAInglKtq2Y0w5zglZtRhkrqZkH'
      address:     true
      name:        'CSS:Markupwand'
      description: 'Plus ($20/month)'
      panelLabel:  'Register for payment'
      token:        SUVHandler
      image:       '/assets/wand.png'
    }

    return false


  return
