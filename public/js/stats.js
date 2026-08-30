$(document).ready(function() {

  // The tagline starts hidden (see index.html.erb) and is only revealed once, with a
  // fade-in, either with live stats from /api/stats (if the request succeeds) or with
  // the static default text (on failure), so users never see it change/flash.
  var $tagline = $('#tagline');

  $.ajax({
    type: "GET",
    url: "/api/stats"
  }).done(function(data) {
    $tagline.text(
      "Bringing teams together, one coffee at a time: " +
      data.sups_count + " S'Ups facilitated, and " +
      data.unique_pairs_count + " unique connections made."
    );
  }).always(function() {
    $tagline.fadeIn('slow');
  });

});
