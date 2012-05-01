window.iframeLoaded =->
  console.log "Frame loaded"
  document.getElementById("editor-iframe").contentWindow.document.body.onclick = (el)->
    debugger
