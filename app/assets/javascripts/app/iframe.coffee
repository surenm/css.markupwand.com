focus_bar_template = '''
<div class='right'> 
  <button id='done' class='btn btn-success'> Done </button>
</div>
'''

loading_template = '''
<div class="content">
  <div> <img src="/assets/loading-ninja.gif">  </div>
</div>
'''

focus_overlay_div = document.createElement 'div'
focus_overlay_div.id = 'focus-overlay'
$(focus_overlay_div).hide()
app.editor_iframe.append focus_overlay_div

overlay_div = document.createElement 'div'
overlay_div.id = 'overlay'
$(overlay_div).hide()
app.editor_iframe.append overlay_div


on_focus_div = document.createElement 'div'
on_focus_div.id = 'on-focus-bar'
content = focus_bar_template
$(on_focus_div).html content
$(on_focus_div).hide()
app.editor_iframe.append on_focus_div


loading_div = document.createElement 'div'
loading_div.id = 'loading'
content = loading_template
$(loading_div).html content
$(loading_div).hide()
app.editor_iframe.append loading_div
