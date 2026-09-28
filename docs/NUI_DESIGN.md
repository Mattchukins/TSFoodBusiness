# TwilightStore NUI design inventory

Inspected 2026-09-28: [TSFamilyGenealogy App](https://github.com/Mattchukins/TSFamilyGenealogy/blob/main/web/App.tsx), [tokens](https://github.com/Mattchukins/TSFamilyGenealogy/blob/main/web/shared/tokens.css), [TSAnimalServices shell](https://github.com/Mattchukins/TSAnimalServices/blob/main/web/src/main.tsx), [style](https://github.com/Mattchukins/TSAnimalServices/blob/main/web/src/style.css), and [NUI transport](https://github.com/Mattchukins/TSAnimalServices/blob/main/web/src/nui.ts).

| Design route | Observed pattern | Food Business mapping |
| --- | --- | --- |
| Family player routes | `home`, `myfamilies`, `families`, `profiles`, `requests` and further view keys in a labelled dialog; compact navigation, active view and close button | Overview, Businesses, Kitchen, Orders, Finance route keys inside a single labelled dialog |
| Family admin | Distinct privileged view, with access checked before rendering | Future separate admin view; no admin access exposed in bootstrap |
| Family tokens | Dark surfaces `#090c17` / `#121729`, purple accent `#9956ed`, visible focus ring, 8–18 px radii | Initial shell uses matching color values and focus treatment |
| Animal tablet | Header, searchable left navigation, workspace and responsive narrow layout | Header, left route navigation and responsive workspace; search deferred until route count grows |
| Animal NUI | Explicit `open`/`close` messages and POST callback, Escape close, initial focus and Tab containment | Bootstrap implements these for the close-only callback |

The present UI is a navigation preview. Screen contents are placeholders until v0.1+ contracts exist. Do not copy sibling business data or treat a hidden route as an authorization check. Future common components should be extracted under an agreed shared package with versioned ownership; the bootstrap follows observed conventions without introducing a cross-resource dependency.
