# Marquee

A title or subtitle wider than the block scrolls instead of ending in an ellipsis. The text slides left until its end shows, then back, at about 30 px per second with eased turns. Text that fits stays still. The narrow rail shows no text, so it has no marquee.

## Sub-features

- `marquee-scroll` a title or subtitle wider than its box swings between its start and its end.
- `marquee-still` text that fits is drawn plainly and never moves.
- `marquee-clip` scrolling text stays inside its box and never draws over the artwork.
- `marquee-follow` a new track that fits stops the scroll; one that doesn't starts it with a period set by its own overflow.

## How to get to it (user POV)

- Play a track with a long title or a long `artist — album`, such as a soundtrack album, and look at the block.

## Driving it with np-verify

Preconditions:

- `$NP doctor` exits 0.
- The shown session has a subtitle or title longer than about 30 characters. `$NP sessions` prints the titles; `$NP do cycle` shows the next session.

- **See it move.** Run `$NP shot marquee1`, wait 1 s, run `$NP shot marquee2`. Open both `.block.png`. The long line shows a different slice of its text in each, cut at the box edge on both sides.
- **See it still.** In the same two shots, a line that fits (often the title) sits at the same x in both.
- **Follow.** `$NP do cycle` to a session whose text fits, wait 2 s, take two shots 1 s apart. Nothing moves.

## Gotchas

- There is no text measuring API. The widths come from `on_size_change` on the clip box and on the unwrapped text, so the first frame after a change is drawn unscrolled.
- The loop is native (`.loop("left", …)`). It runs while drawn and never calls render, so a still block costs nothing.
- Shots 1 s apart can land on the same offset at a turn. Take a third shot if two look the same.
