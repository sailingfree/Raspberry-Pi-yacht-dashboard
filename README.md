# Raspberry-Pi-yacht-dashboard
Code for a Rpi based signalk dashboard with a 7 inch screen for use a repeater of the essential yacht data for use in the cabin.

I have a good N2K system on my yacht but I wanted a repeater in the cabin showing the essential details so when I'm down below navigating I can still see whats going on.

This uses a standard signalk setuip on a pi and that in turn gets its data from my Esp32 N2k gateway using the yacht data N2k format over UDP.

The Pi has a 7 inch screen from an older project so I wanted to use. I really wanted to avoid X, and many of the libraries to use the framebuffer are complicated to setup.
I cam across a neat Perl framebuffer project which fits my needs so the dashboard uses that.

The screen had a broken touch sensor so I added an overlay and an AR1100 USB driver. This will be incorported when I can think of a real use for it.


