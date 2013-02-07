$(document).ready () ->  
  $("#regular").click () ->
    handler = (stripe_data) ->
      stripe_data.plan = 'regular'
      $("#pricing-update-popup").dialog 
          modal: true
          draggable: false
          resizable: false
          buttons: [
            {
              text: 'Ok'
              click: () -> $(this).dialog('close')
              class: 'btn btn-success'
            }
          ]
      $.post '/register-card', stripe_data, (data) ->
        $.doTimeout 1000, () ->
          if data.status == "OK"
            $("#pricing-update-popup").dialog 'close'

   
    StripeCheckout.open {
      key:         STRIPE_PUBLISH_TOKEN
      address:     true
      name:        'CSS:Markupwand'
      description: 'Regular ($15/month) '
      panelLabel:  'Register for payment'
      token:       handler
      image:       '/assets/wand.png'
    }
    
    return false

  $("#plus").click () ->
    handler = (stripe_data) ->
      stripe_data.plan = 'plus'
      $("#pricing-update-popup").dialog 
          modal: true
          draggable: false
          resizable: false
          buttons: [
            {
              text: 'Ok'
              click: () -> $(this).dialog('close')
              class: 'btn btn-success'
            }
          ]
      $.post '/register-card', stripe_data, (data) ->
        $.doTimeout 1000, () ->
          if data.status == "OK"
            $("#pricing-update-popup").dialog 'close'

    StripeCheckout.open {
      key:         STRIPE_PUBLISH_TOKEN
      address:     true
      name:        'CSS:Markupwand'
      description: 'Plus ($20/month)'
      panelLabel:  'Register for payment'
      token:        handler
      image:       '/assets/wand.png'
    }
    
    return false


  return
