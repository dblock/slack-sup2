S'Up v2 for Slack Channels
==========================

[![Tests](https://github.com/dblock/slack-sup2/actions/workflows/test.yml/badge.svg)](https://github.com/dblock/slack-sup2/actions/workflows/test.yml)

### What's This?

The most valuable relationships are not made of two people, they're made of three. A third person will always stabilize and grow the relationship between the other two. It's called a [triad](http://www.culturesync.net/toolbox/intro-to-triads), and the more you create, the stronger your network.

This bot passively generates fresh triads of channel members to meet for coffee every week in an informal standup, or S'Up.

### Install

We host the bot at [sup2.playplay.io](https://sup2.playplay.io).

<a href="http://sup2.playplay.io"><img alt="Add to Slack" height="40" width="139" src="https://platform.slack-edge.com/img/add_to_slack.png" srcset="https://platform.slack-edge.com/img/add_to_slack.png 1x, https://platform.slack-edge.com/img/add_to_slack@2x.png 2x" /></a>

### History

S'Up for Slack is made possible with the generous support of team [Artsy](https://www.artsy.net). This is a fresh rewrite of [artsy/sup](https://github.com/artsy/sup) for Slack teams during [ArtsyOpenSource](http://artsy.github.io) Hackathon 5.0. This is a [fork, or v2 of S'Up](https://github.com/dblock/slack-sup) that allows for multiple S'Ups, one per channel.

### Website artwork

The website follows the shared Slava, Strata, Strada, and Shell layout with a purple palette inspired by the existing Slack conversation preview (base `#4a154b`). A high-contrast purple hero gives the main message, installation button, and original Slack screenshot priority; quieter sections explain the workflow and triads approach, show the follow-up and participation reporting, and separate pricing from technical details. The triads screenshot `public/img/sup-triad.png` is cropped from the introduction message in `public/img/sup-dm.png`. Screenshots in the supporting sections display at half their source dimensions, shrinking further when needed to fit their containers without scrolling. The editable `public/img/screenshot-background.svg` keeps `preserveAspectRatio="none"` and is painted on a fixed viewport-sized layer so opening help topics does not resize the ribbons. Preserve the original transparent `public/img/icon.png` logo, matching favicons, and product demonstration images.

### Website asset caching

Local stylesheets, scripts, images, and favicons use content-hashed `asset_path` URLs from rack-server-pages 0.3.0. The stylesheet is an ERB template served at `/styles.css`, so its background artwork URL is versioned too. The custom API middleware applies the slack-ruby-bot-server 2.3.0 `config.server_pages` callback; HTML and generated CSS use `Cache-Control: private, no-cache` so browsers revalidate and discover updated asset URLs, including when only a nested image changes. Static assets retain the middleware's content ETags and timestamp validation defaults without a long-lived or immutable cache policy. Versioned query strings are cache keys, not archived copies: old URLs still serve the current file.

### Copyright & License

Copyright [Daniel Doubrovkine, Vestris LLC](https://www.vestris.com), 2017-2025

[MIT License](LICENSE)
