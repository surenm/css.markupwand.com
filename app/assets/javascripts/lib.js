// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
// WARNING: THE FIRST BLANK LINE MARKS THE END OF WHAT'S TO BE PROCESSED, ANY BLANK LINE SHOULD
// GO AFTER THE REQUIRES BELOW.
//
//= require jquery
//= require jquery_ujs
//= require lib/jquery.cookie
//= require lib/jquery-ui-1.9.2.custom.min

//= require lib/underscore
//= require lib/backbone
//= require twitter/bootstrap

//= require lib/bootstrap-editable.min
//= require lib/bootstrap-tour
//= require lib/codemirror
//= require lib/codemirror-modes/css/css
//= require lib/codemirror-modes/htmlembedded/htmlembedded
//= require lib/codemirror-modes/htmlmixed/htmlmixed
//= require lib/jcanvas
//= require lib/jquery.ba-dotimeout
//= require lib/jquery.client
//= require lib/jquery.formdefaults
//= require lib/jquery.imagesloaded
//= require lib/jquery.Jcrop.min
//= require lib/ZeroClipboard

$(document).ajaxSend(function(event, request, settings) {
  if (typeof(AUTH_TOKEN) == "undefined") return;
  settings.data = settings.data || "";
  settings.data += (settings.data ? "&" : "") + "authenticity_token=" + encodeURIComponent(AUTH_TOKEN);
});

_.templateSettings = {
  interpolate : /\{\{(.+?)\}\}/g
};

$('.dropdown-toggle').dropdown()