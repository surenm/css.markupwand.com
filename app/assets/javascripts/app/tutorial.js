$(function () {

    var $tabs = $('#tabs').tabs();
    $('.ui-tabs-nav').removeClass('ui-widget-header');

    $(".ui-tabs-panel").each(function (i) {

        var totalSize = $(".ui-tabs-panel").size() - 1;

        if (i != 0) {
            prev = i;
            $(this).prepend("<a href='#' class='prev-tab mover' rel='" + prev + "'>&#171; Previous</a>");
        }

        if (i != totalSize) {
            next = i + 2;
            $(this).prepend("<a href='#' class='next-tab mover' rel='" + next + "'>Next &#187;</a>");
        }

    });

    $('.next-tab, .prev-tab').click(function () {
        $tabs.tabs('select', $(this).attr("rel"));
        return false;
    });


});

$(function() {
    var viewport_width = $('body').innerWidth();
    var modal_width = $('.modal').width();
    var hmargin = (viewport_width - modal_width)/2;
    var modal_width_changed = false;

    if (hmargin <= 0) {
        hmargin = 10;
        modal_width = viewport_width-20;
        modal_width_changed = true;
    }

    $('.modal').css('left', hmargin+'px')
    if(modal_width_changed) {
        $('.modal').css('width', modal_width+'px')
    }
});