focus_bar_template = '''
<div class='right'> 
  <button id='done' class='btn btn-success'> Done </button>
</div>
'''
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
