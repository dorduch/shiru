# Storytime Design System

## Scene

A child uses Storytime on a shared phone or tablet in a calm living room or
bedroom. The interface must remain readable in daylight and quiet at bedtime.

## Visual language

- Warm parchment background `#F7F3EC`, tinted white surface `#FFFDFC`.
- Violet action color `#6657D9` with soft selected surface `#EAE7FF`.
- Child tiles use named pastel roles: yellow `#FFD66B`, mint `#7FD1C4`, coral
  `#FF9B8A`, and lilac `#B59BFF`.
- Primary ink is `#292638`; secondary copy is `#716D7E`.
- Existing 16×16 `PixelSprite` artwork supplies identity and state feedback.

## Interaction

- Child controls have a minimum 64px target; parent controls use at least 48px.
- Choice cards select and speak their label. A separate Continue action avoids
  accidental navigation and supports non-readers.
- Motion lasts 150–220ms, communicates state, and never bounces.
- Icons supplement spoken and written labels; color is never the only signal.

## Components

- Home actions are large asymmetric tiles, not repeated nested cards.
- Wizard progress uses five compact dots and a two- or three-column choice grid.
- Playback keeps one dominant artwork surface, one progress control, and one
  play/pause action.
- Parent screens use familiar app bars, list rows, forms, and confirmation
  dialogs rather than child-facing tile patterns.
