# content/

This directory used to hold plain-text drafts of the Storytime starter
stories (`content/storytime/*.txt`). Those files were an early scratch copy
and had gone stale — nothing in `app/` or `functions/` ever read them.

**Source of truth for starter story text is
[`app/assets/storytime/starter_stories.json`](../app/assets/storytime/starter_stories.json).**
That JSON file is bundled with the app and is what the Storytime library
actually loads, alongside the matching narrated audio and
`.timing.json` read-along timing files in the same
`app/assets/storytime/` directory.

If you need to edit a starter story's text, edit `starter_stories.json`
directly — do not recreate files here.
