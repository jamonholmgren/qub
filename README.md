# Qub -- QBasic Website Generator

Qub (pronounced "cube") is a CLI that generates a web server and framework for building websites in [QB64](https://qb64.com/) -- a more modern variant of QBasic.

<table><tr><td>
  <img alt="Screenshot of Qub running" src="./.github/images/screenshot-cli.png" width="350" />
</td><td>
  <img alt="Screenshot of Qub-powered website" src="./.github/images/screenshot-website.png" width="350" />
</td></tr></table>

## Getting started

_Windows Support_: Qub has only been tested on macOS and Linux. It might work on Windows WSL (Windows Subsystem for Linux) or Git Bash on Windows. If you want to help test and make it run on Windows, please open an issue or PR!

To get started, set up your `qub` alias first:

```
alias qub="source <(curl -sSL https://raw.githubusercontent.com/jamonholmgren/qub/main/src/cli.sh)"
```

Now, you should be able to run the CLI:

```
qub
qub --version
qub --help
qub create
qub update
```

## Creating a website

To create a website, run `qub create` and follow the prompts:

```
qub create
```

It'll ask you for your domain name (e.g. jamon.dev) which doubles as your project's folder name. It will also ask if you want to install QB64 (I recommend you do).

When done, you can CD into the new folder and run `./bin/build` to build the website. Then, run `./app` to start the web server. Visit [http://localhost:6464/](http://localhost:6464/) to view the website.

## Modifying your website

Your new website has the following folder structure:

```
bin
web
  pages
    home.html
    contact.html
  static
    scripts.js
    styles.css
  footer.html
  header.html
  head.html
app.bas
README.md
```

### app.bas

This is the Qub web server. You can modify it if you want to change the port or add more functionality.

However, if you don't modify it, you can periodically update it by running `qub update`. Note this will blow away any modifications you've made, so be careful!

Qub's web server is originally based on [Yacy](https://github.com/smokingwheels/Yacy_front_end) by SmokingWheels. It comes with a number of features:

- [x] Page routing (e.g. jamon.dev/links renders web/pages/links.html)
- [x] Individual header and footer and <head> support
- [x] Static file serving (css, js, etc)
- [x] Binary file serving (images, fonts, etc)
- [x] Custom 404 page support
- [x] Basic dynamic variable support (e.g. `${year}` in web/footer.html)
- [ ] 301 redirects support (coming soon)
- [ ] Custom 500 page support (coming soon)
- [ ] Custom port support (coming soon -- currently fixed at 6464)

It does not (and probably won't) support HTTPS or HTTP2. I recommend putting CloudFlare in front of it in production (more in the [deploy guide](#deploy-guide) below).

### Common files

In the `web` folder, you'll find three files that are included on every page -- head.html, header.html, and footer.html.

The header and footer are both directly within the `<body>` tag, while head is within the `<head>` tag, like so:

```html
<!DOCTYPE html>
<html>
  <head>
    <!-- head.html goes here -->
  </head>
  <body>
    <!-- header.html goes here -->
    <!-- routed page content goes here -->
    <!-- footer.html goes here -->
  </body>
</html>
```

### web/pages

This is where your website's pages go. Each page is an HTML file. You can add as many as you want, and they'll be routed automatically (minus the .html extension).

So, for example, if you add `web/pages/links.html`, it will be available at `example.com/links`. If you add a folder it'll route to that as well, so `web/pages/blog/2023.html` will be available at `example.com/blog/2023`.

### web/static

You'll put your static files here -- CSS, JS, images, fonts, etc. They'll be served at `example.com/static/` (e.g. `example.com/static/styles.css`). Any image files, fonts, PDFs, etc will be served as binary files (e.g. `example.com/static/logo.png`).

### 404.html

If you want to customize your 404 page, you can do so by editing `web/pages/404.html`. This is shown if the router is unable to find a page for the given URL. It'll also respond with the proper 404 status code.

## Deploy Guide

COMING SOON!

## History

When I was twelve, I built my first game in QBasic -- and kept building games and small apps (we called them "programs" in those days) for years. I have a lot of nostalgia and a special place in my heart for QBasic.

A few years ago, I was talking about rebuilding my website in something different, just for a fun challenge, and my friend Mark Villacampa said ["do it in BASIC you coward!"](https://twitter.com/MarkVillacampa/status/1594426506754801664). I took on the challenge and built [jamon.dev](https://jamon.dev) in QB64.

Once I had a working website, I realized that I wanted to make it easier for other people to build websites in QB64, so I started building Qub, aided by [@knewter](https://github.com/knewter) who is another QBasic fan from way back.

## TODO

- [ ] Fill out the README, documentation, screenshots
- [ ] Set up CI
- [ ] Add a Deployment doc
- [ ] Make the default template look nicer, better template README
- [ ] htmx version maybe
- [ ] YouTube video on Jamon's Code Quests

## License

MIT -- see [LICENSE](LICENSE) for details.

QB64 is licensed under the [MIT](https://github.com/QB64Official/qb64/blob/master/licenses/COPYING.TXT) license.
