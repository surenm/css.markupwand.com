loading_template = '''
<div class="content">
  <div> <img src="/assets/loading-ninja.gif">  </div>
</div>
'''

overlay_div = document.createElement 'div'
overlay_div.id = 'overlay'
$(overlay_div).hide()
app.editor_iframe.append overlay_div

loading_div = document.createElement 'div'
loading_div.id = 'loading'
content = loading_template
$(loading_div).html content
$(loading_div).hide()
app.editor_iframe.append loading_div


mouseover_div = document.createElement 'div'
$(mouseover_div).addClass 'mouseoverlay'
app.editor_iframe.append mouseover_div

focus_overlay_div = document.createElement 'div'
$(focus_overlay_div).addClass 'focus-overlay'
app.editor_iframe.append focus_overlay_div