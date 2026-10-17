# User Tier Badge

**ENGLISH** | [ESPAÑOL](README.es.md)

Maintained by Criptonautas. Not affiliated with or endorsed by Discourse (Civilized Discourse Construction Kit, Inc.).

Discourse theme component showing a member's progress through custom badge
tiers — not trust levels. Each tier is a set of badges; completing the set
unlocks a group.

## Features

- **Tier progress in the avatar menu** — the current tier, how many of its
  badges are earned, a progress bar and a checklist of the badges still
  missing. Long tiers show five rows (unearned first) and a "see all" link to
  `/badges`. Following any link in the box closes the menu.
- **Tiers defined by badge ids** in an `objects` setting, one row per tier with
  the group it unlocks. Holding the group also satisfies the tier, so a
  subscription or a manual grant counts.
- **Recent tier badges** — who most recently earned one, newest first, one row
  per member. Not placed anywhere by default; see
  [Recent tier badges in the right sidebar](#recent-tier-badges-in-the-right-sidebar).
- **Browser cache** with a configurable TTL, so badge lookups don't repeat on
  every page view.

## Requirements

The box renders into the `custom-user-menu-after-user-info` outlet, which only
[discourse-custom-user-menu-nautas](https://github.com/somos-criptonautas/discourse-custom-user-menu-nautas)
provides (a fork of Manuel Kostka's Custom User Menu). Without it the box simply
doesn't show; nothing breaks. The block `theme:user-tier-badge:badge` is still
registered for themes that want to place the box in a block outlet themselves.

## Recent tier badges in the right sidebar

[Right Sidebar Blocks](https://github.com/discourse/discourse-right-sidebar-blocks)
renders any component by its name, so no extra setup is needed here. Add this
row to its `blocks` setting:

```json
{ "name": "recent-tier-badges" }
```

That component shows the sidebar on desktop topic lists only (it lives in the
`before-list-area` outlet), never on topic pages or phones. The row count is
this component's `recent_badges_count`. A theme can also place the same list
in a block outlet by its block name, `theme:user-tier-badge:recent-badges`.

## Install

Install discourse-custom-user-menu-nautas first (it replaces the upstream
Custom User Menu). Then upload this component in **Admin > Customize > Themes**,
attach both to your active theme, and fill the `tiers` setting with each tier's
badge ids and group.

## License

MIT. See [LICENSE](LICENSE).

Text of this README under [CC BY-NC-SA 4.0](CC-BY-NC-SA-4.0.txt).
