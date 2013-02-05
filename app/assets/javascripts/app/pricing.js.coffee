$(document).ready () ->  
  
  $("#sedan").click () ->
    handler = (stripe_data) ->
      stripe_data.plan = 'regular'
      $.post '/register-card', stripe_data, (data) ->
        console.log data
   
    StripeCheckout.open {
      key:         STRIPE_PUBLISH_TOKEN
      address:     true
      name:        'CSS:Markupwand'
      description: 'Regular ($15/month) '
      panelLabel:  'Register for payment'
      token:       handler
      image:       '/assets/wand.png'
    }
    Analytical.event 'Pricing: Regular plan', {user: stripe_data.id}
    return false

  $("#suv").click () ->
    handler = (stripe_data) ->
      stripe_data.plan = 'plus'
      $.post '/register-card', stripe_data, (data) ->
        console.log data

    StripeCheckout.open {
      key:         STRIPE_PUBLISH_TOKEN
      address:     true
      name:        'CSS:Markupwand'
      description: 'Plus ($20/month)'
      panelLabel:  'Register for payment'
      token:        handler
      image:       '/assets/wand.png'
    }
    Analytical.event 'Pricing: Plus plan', {user: stripe_data.id}
    return false


  return
