# Marquee

A title or subtitle wider than the block scrolls instead of ending in an ellipsis. The text rests 1.5 s at its start, slides left at a constant 30 px per second until its end shows, rests 1.5 s, and slides back. Text that fits stays still. The narrow rail shows no text, so it has no marquee.

## Sub-features

- `marquee-scroll` a title or subtitle wider than its box rests at its start, glides at a constant speed to its end, rests, and glides back.
- `marquee-still` text that fits is drawn plainly and never moves.
- `marquee-clip` scrolling text stays inside its box and never draws over the artwork.
- `marquee-follow` a new track that fits stops the scroll; one that doesn't starts it with a period set by its own overflow.

## How to get to it (user POV)

- Play a track with a long title or a long `artist — album`, such as a soundtrack album, and look at the block.

## Driving it with mr-verify

Preconditions:

- `$MR doctor` exits 0.
- The shown session has a subtitle or title longer than about 30 characters. `$MR sessions` prints the titles; `$MR do cycle` shows the next session.

- **See it move.** Run `$MR shot marquee1`, wait 1 s, run `$MR shot marquee2`. Open both `.block.png`. The long line shows a different slice of its text in each, cut at the box edge on both sides.
- **See it still.** In the same two shots, a line that fits (often the title) sits at the same x in both.
- **Follow.** `$MR do cycle` to a session whose text fits, wait 2 s, take two shots 1 s apart. Nothing moves.
- **Motion.** Run `.claude/skills/verify-music-remote/scripts/marquee-motion` while a long subtitle shows (needs `ffmpeg`; its crop assumes a 2x display and the default footer, override with `CROP=`). `step(px)` stays an even 3 to 4 per ~55 ms during a leg, 0 for about 1.5 s at each end, and never jumps back to 0 mid-leg.

## Gotchas

- There is no text measuring API. The widths come from `on_size_change` on the clip box and on the unwrapped text, so the first frame after a change is drawn unscrolled.
- The glide is a native `.transition("left")`; a timer flips its target once per leg. Don't go back to `.loop`: its ease-in-out ran at about 30 fps with a peak three times the average speed, and it stuttered.
- Shots 1 s apart can land on the same offset at a turn. Take a third shot if two look the same.
