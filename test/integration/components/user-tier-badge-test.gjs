import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import UserTierBadge from "../../../discourse/components/user-tier-badge";

// Every badge referenced by the tiers below, so the checklist can name and
// link the ones the user has not earned.
const SITE_BADGES = [10, 11, 20, 21, 22, 23, 24, 25, 26, 30, 31].map((id) => ({
  id,
  name: `Badge ${id}`,
  slug: `badge-${id}`,
}));

// Core's AUTO_GROUPS ids, which Site#groupsById always resolves.
const TIERS = [
  { name: "user_badge.tiers.tier_1", badge_ids: "10,11", group: [11] },
  { name: "user_badge.tiers.tier_2", badge_ids: "20,21,22", group: [12] },
  { name: "user_badge.tiers.tier_3", badge_ids: "30,31", group: [13] },
];

function stub({ earned, karma = 0 }) {
  pretender.get("/badges.json", () => response({ badges: SITE_BADGES }));
  pretender.get("/user-badges/eviltrout.json", () =>
    response({ badges: earned.map((id) => ({ id })), user_badges: [] })
  );
  pretender.get("/u/eviltrout/card.json", () =>
    response({ user: { id: 1, gamification_score: karma } })
  );
}

module("User Tier Badge | menu box", function (hooks) {
  setupRenderingTest(hooks);

  let originalTiers;

  hooks.beforeEach(function () {
    localStorage.clear();
    originalTiers = settings.tiers;
    settings.tiers = TIERS;
    this.currentUser.id = 1;
    this.currentUser.visibleGroups = [];
  });

  hooks.afterEach(function () {
    settings.tiers = originalTiers;
  });

  test("leaves name and stats to the menu header", async function (assert) {
    stub({ earned: [10, 11, 20] });
    await render(<template><UserTierBadge /></template>);

    assert.dom(".user-tier-badge__layout").exists();
    assert.dom(".user-tier-badge__name").doesNotExist();
    assert.dom(".user-tier-badge__stats").doesNotExist();
  });

  test("advances to the first tier whose badges are not all earned", async function (assert) {
    stub({ earned: [10, 11, 20] });
    await render(<template><UserTierBadge /></template>);

    // Tier 1 (10, 11) is complete, so tier 2 (20, 21, 22) shows 1 of 3.
    assert
      .dom(".user-tier-badge__progress progress")
      .hasAttribute("value", "1");
    assert.dom(".user-tier-badge__progress progress").hasAttribute("max", "3");
    assert
      .dom(".user-tier-badge__progress-label a")
      .hasAttribute("href", "/g/trust_level_2");
  });

  test("ticks earned badges and links every row to the badge", async function (assert) {
    stub({ earned: [10, 11, 20] });
    await render(<template><UserTierBadge /></template>);

    assert.dom(".user-tier-badge__requirement").exists({ count: 3 });
    assert.dom(".user-tier-badge__requirement.--earned").exists({ count: 1 });
    assert.dom(".user-tier-badge__requirement.--missing").exists({ count: 2 });
    assert
      .dom(".user-tier-badge__requirement:first-child a")
      .hasAttribute("href", "/badges/20/badge-20");
    assert.dom(".user-tier-badge__see-all").doesNotExist();
  });

  test("caps a long tier, unearned first, with a link to all badges", async function (assert) {
    settings.tiers = [
      {
        name: "user_badge.tiers.tier_1",
        badge_ids: "20,21,22,23,24,25,26",
        group: [],
      },
    ];
    stub({ earned: [20, 21] });
    await render(<template><UserTierBadge /></template>);

    assert.dom(".user-tier-badge__requirement").exists({ count: 5 });
    assert
      .dom(".user-tier-badge__requirement.--missing")
      .exists({ count: 5 }, "the five unearned badges fill the cap");
    assert.dom(".user-tier-badge__progress-count").hasText("2 / 7");
    assert.dom(".user-tier-badge__see-all").hasAttribute("href", "/badges");
  });

  test("closes the menu when a link inside is followed", async function (assert) {
    stub({ earned: [10, 11, 20] });
    let closed = 0;
    const closeMenu = () => closed++;
    await render(
      <template><UserTierBadge @closeMenu={{closeMenu}} /></template>
    );

    // Plain clicks on the box itself must not close it.
    await click(".user-tier-badge__progress");
    assert.strictEqual(closed, 0);

    document
      .querySelector(".user-tier-badge__requirement a")
      .addEventListener("click", (event) => event.preventDefault());
    await click(".user-tier-badge__requirement a");
    assert.strictEqual(closed, 1);
  });

  test("renders the completion message when every tier is done", async function (assert) {
    stub({ earned: [10, 11, 20, 21, 22, 30, 31], karma: 12000 });
    await render(<template><UserTierBadge /></template>);

    assert
      .dom(".user-tier-badge__message--done")
      .hasText("every tier complete: thank you for being part of this.");
    assert.dom(".user-tier-badge__requirement").doesNotExist();
  });

  test("nudges instead of listing the last tier at the karma goal", async function (assert) {
    // Last tier: karma badge (30) earned, extraordinary badge (31) not.
    stub({ earned: [10, 11, 20, 21, 22, 30], karma: 9999 });
    await render(<template><UserTierBadge /></template>);

    assert
      .dom(".user-tier-badge__message--almost")
      .hasText("very close: time to think outside the box");
    assert.dom(".user-tier-badge__requirement").doesNotExist();
  });

  test("skips a tier whose group is held", async function (assert) {
    // Tier 2's group arrived by subscription: none of its badges are earned.
    this.currentUser.visibleGroups = [{ id: 12 }];
    stub({ earned: [10, 11], karma: 100 });
    await render(<template><UserTierBadge /></template>);

    assert.dom(".user-tier-badge__requirement").exists({ count: 2 });
    assert
      .dom(".user-tier-badge__requirement:first-child a")
      .hasAttribute("href", "/badges/30/badge-30");
  });

  test("renders nothing when no tier has badge ids", async function (assert) {
    settings.tiers = [{ name: "user_badge.tiers.tier_1", badge_ids: "" }];
    stub({ earned: [] });
    await render(<template><UserTierBadge /></template>);

    assert.dom(".user-tier-badge__layout").doesNotExist();
  });
});
