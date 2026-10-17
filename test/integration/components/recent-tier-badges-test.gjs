import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import RecentTierBadges from "../../../discourse/components/recent-tier-badges";

const USERS = {
  alice: {
    id: 1,
    username: "alice",
    avatar_template: "/user_avatar/localhost/alice/{size}/1.png",
  },
  bob: {
    id: 2,
    username: "bob",
    avatar_template: "/user_avatar/localhost/bob/{size}/2.png",
  },
};

// granted_at is what orders the list, so every grant here has a distinct one.
const GRANTS = {
  10: [{ user: "bob", granted_at: "2026-09-01T10:00:00.000Z" }],
  11: [{ user: "alice", granted_at: "2026-09-02T10:00:00.000Z" }],
  // Second grant for bob: he must still appear once, on his newest badge.
  20: [{ user: "bob", granted_at: "2026-09-03T10:00:00.000Z" }],
  21: [],
  22: [],
};

function badgeResponse(badgeId) {
  const grants = GRANTS[badgeId] ?? [];

  // Core's shape: users and badges are root keys beside user_badge_info.
  return response({
    badges: [
      {
        id: Number(badgeId),
        name: `Badge ${badgeId}`,
        slug: `badge-${badgeId}`,
      },
    ],
    users: grants.map((grant) => USERS[grant.user]),
    user_badge_info: {
      user_badges: grants.map((grant, index) => ({
        id: Number(badgeId) * 100 + index,
        badge_id: Number(badgeId),
        user_id: USERS[grant.user].id,
        granted_at: grant.granted_at,
      })),
    },
  });
}

module("User Tier Badge | recent tier badges", function (hooks) {
  setupRenderingTest(hooks);

  let originalTiers;

  hooks.beforeEach(function () {
    localStorage.clear();
    originalTiers = settings.tiers;
    pretender.get("/user_badges.json", (request) =>
      badgeResponse(request.queryParams.badge_id)
    );
  });

  hooks.afterEach(function () {
    settings.tiers = originalTiers;
  });

  test("lists one row per member, newest grant first", async function (assert) {
    settings.tiers = [
      { name: "user_badge.tiers.tier_1", badge_ids: "10,11", group: [] },
      { name: "user_badge.tiers.tier_2", badge_ids: "20,21,22", group: [] },
    ];

    await render(<template><RecentTierBadges /></template>);

    assert
      .dom(".recent-tier-badges__row")
      .exists({ count: 2 }, "bob's two grants collapse to one row");
    assert
      .dom(".recent-tier-badges__row:first-child .recent-tier-badges__username")
      .hasText("bob", "bob's badge 20 is the most recent grant");
    assert
      .dom(".recent-tier-badges__row:first-child .recent-tier-badges__badge")
      .hasAttribute("href", "/badges/20/badge-20");
  });

  test("renders nothing when no tier has badge ids", async function (assert) {
    settings.tiers = [
      { name: "user_badge.tiers.tier_1", badge_ids: "", group: [] },
    ];

    await render(<template><RecentTierBadges /></template>);

    assert.dom(".recent-tier-badges__layout").doesNotExist();
  });
});
