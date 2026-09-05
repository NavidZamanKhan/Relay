# Relay visual system

The accepted direction is balanced inbox density, a neutral conversation
canvas, restrained colored outgoing bubbles, and voice notes as the signature
interaction.

| Role | Light | Dark |
| --- | --- | --- |
| Canvas | `#F8F8F5` | `#141B20` |
| Incoming/surface | `#FFFFFF` | `#202A30` |
| Primary text | `#202A30` | `#F4F5F2` |
| Secondary text | `#68747A` | `#ACB7BD` |
| Outgoing message | `#F9DFD8` | `#593D38` |
| Signal coral | `#F17D6C` | `#F17D6C` |
| Hairline | `#E7EAE7` | `#354148` |
| Online indicator | `#329877` | `#329877` |

Manrope is bundled, so typography does not depend on an online font service.
Inbox names are 15.5 logical pixels; message text is 15 with 1.42 line height.
The Relay wordmark is 27. Timestamps stay quiet and use consistent formatting.

The inbox has a 54-pixel brand/header area, a 46-pixel search field, three compact
filters, and conversation rows with an 83-pixel minimum height. Avatars are 54
pixels. The profile is opposite the Relay mark. New messages and groups share
one compose action. There is no duplicate active-people carousel.

The chat header is 64 pixels. Message widths follow their content, capped at
79% of the viewport; photo cards use 72%. Main composer controls are 48 pixels.
Incoming messages are paper-like; outgoing bubbles use a restrained coral wash.
Photo previews preserve a 4:3 crop for the bundled 4:3 image and open fullscreen.

Cupertino vector glyphs form the icon system. Custom vector paths draw the
Relay mark, country flags, read receipts, and waveforms. Emoji glyphs are not
used as interface symbols. Avatars have a small online dot without a competing
colored ring.

The Relay mark is a compact handoff R: a pale continuous stem/bowl hands its
lower stroke to coral. Its Flutter painter, SVG, and launcher icons are bundled.
