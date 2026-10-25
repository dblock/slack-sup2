$(document).ready(function() {

  // Legacy stats from sup.playplay.io (an earlier version of this app) are added in
  // so real historical totals are shown. The tagline starts hidden (see
  // index.html.erb) and is only revealed once, with a fade-in, either with the
  // combined live stats (if both requests succeed) or with the static default text
  // (on failure), so users never see it change/flash from one to the other.
  var $tagline = $('#tagline');

  $.when(
    $.ajax({ type: "GET", url: "https://sup.playplay.io/api/stats" }),
    $.ajax({ type: "GET", url: "/api/stats" })
  ).done(function(legacyResponse, currentResponse) {
    var legacy = legacyResponse[0];
    var current = currentResponse[0];

    $tagline.text(
      (current.sups_count + legacy.sups_count).toLocaleString('en-US') + " S'Ups facilitated \u00b7 " +
      current.unique_pairs_count.toLocaleString('en-US') + " unique connections"
    );
  }).always(function() {
    $tagline.fadeIn('slow');
  });

});
