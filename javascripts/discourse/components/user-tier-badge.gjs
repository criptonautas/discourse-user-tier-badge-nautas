import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AsyncContent from "discourse/components/async-content";
import dIcon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import I18n, { i18n } from "discourse-i18n";
import { parseBadgeIds } from "../lib/tiers";
import { cachedFetch } from "../lib/user-badges-cache";

// The user menu is ~15.5rem wide: past this many rows the list is cut, unearned
// badges first, and "see all" links to /badges.
const MAX_QUESTS = 5;

export default class UserTierBadge extends Component {
  @service currentUser;
  @service nautasKarma; // nautalist theme only; undefined elsewhere
  @service site;

  badgesUrl = getURL("/badges");

  // Following a link inside a dropdown must also close it. Enter on a focused
  // link fires click too, so this covers the keyboard.
  @action
  closeOnLinkClick(event) {
    if (event.target.closest("a[href]")) {
      this.args.closeMenu?.();
    }
  }

  async earnedBadgeIds() {
    return cachedFetch("earned-badges", this.currentUser.id, async () => {
      const json = await ajax(`/user-badges/${this.currentUser.username}.json`);
      return (json.badges || []).map((badge) => badge.id);
    });
  }

  // Name and slug for every badge on the site. The user's own payload only
  // carries badges they already hold, and the checklist has to name the ones
  // they don't.
  async allBadges() {
    return cachedFetch("badges", null, async () => {
      const json = await ajax("/badges.json");
      return (json.badges || []).map(({ id, name, slug }) => ({
        id,
        name,
        slug,
      }));
    });
  }

  // Karma comes from discourse-gamification, which may not be installed: a
  // failed lookup leaves it null. Only the last tier's "almost there" nudge
  // reads it. It is the user card's gamification_score, the total the plugin
  // shows on cards and profiles; the nautalist theme's karma service already
  // loads it for the avatar menu, so the menu asks once.
  async karma() {
    if (this.nautasKarma) {
      return this.nautasKarma.currentUserTotal();
    }
    return cachedFetch("karma", this.currentUser.id, async () => {
      const json = await ajax(
        `/u/${this.currentUser.username}/card.json`
      ).catch(() => null);
      return json?.user?.gamification_score ?? null;
    });
  }

  // The tier setting stores a group id picked from the live site. Resolve its
  // name so the tier can link to /g/, and fall back to plain text: groups the
  // viewer can't see are not serialized, so an unresolved id must not become a
  // broken link.
  groupUrl(group) {
    const id = [].concat(group ?? [])[0];
    const name = id ? this.site.groupsById?.[id]?.name : null;
    return name ? getURL(`/g/${name}`) : null;
  }

  // Optional one-line description, keyed beside the tier's name
  // (user_badge.tiers.x -> user_badge.descriptions.x). lookup() and not i18n():
  // it gives "" for a key left blank and undefined for an absent one, where
  // i18n() on Discourse 2026.3 renders both as a "[missing ...]" marker.
  descriptionFor(name) {
    const key = name.replace(
      /^user_badge\.tiers\./,
      "user_badge.descriptions."
    );
    return key === name ? null : I18n.lookup(themePrefix(key)) || null;
  }

  tierView(tier, position, total) {
    return {
      name: tier.name,
      groupUrl: tier.groupUrl,
      description: this.descriptionFor(tier.name),
      position,
      total,
    };
  }

  // A tier's group can be granted without the badges — by subscription or by
  // hand — so holding it satisfies the tier on its own. visibleGroups, not the
  // deprecated groups alias: a group the server does not serialize is simply
  // not counted, which fails towards showing the tier as still open.
  hasGroup(group) {
    const id = [].concat(group ?? [])[0];
    if (!id) {
      return false;
    }
    return this.currentUser.visibleGroups?.some((g) => g.id === id) ?? false;
  }

  // Tiers are evaluated top to bottom: the block shows the first unsatisfied
  // one. A tier is satisfied by earning every badge in it OR by holding its
  // group, since the group can also arrive via a subscription or by hand.
  @bind
  async loadData() {
    const [earnedIds, badges, karma] = await Promise.all([
      this.earnedBadgeIds(),
      this.allBadges(),
      this.karma(),
    ]);

    const earned = new Set(earnedIds);
    const byId = new Map(badges.map((badge) => [badge.id, badge]));

    const tiers = (settings.tiers || [])
      .map((tier) => ({
        name: tier.name,
        badgeIds: parseBadgeIds(tier.badge_ids),
        hasGroup: this.hasGroup(tier.group),
        groupUrl: this.groupUrl(tier.group),
      }))
      .filter((tier) => tier.badgeIds.length);

    // No tier has usable badge ids: nothing to show.
    if (!tiers.length) {
      return null;
    }

    const total = tiers.length;
    const nextIndex = tiers.findIndex(
      (tier) => !tier.hasGroup && !tier.badgeIds.every((id) => earned.has(id))
    );

    // Every tier satisfied: the last one stays on show, full, so the member
    // still sees which level they reached and what it means.
    if (nextIndex === -1) {
      return {
        isDone: true,
        tier: {
          ...this.tierView(tiers[total - 1], total, total),
          value: 1,
          max: 1,
        },
      };
    }

    const next = tiers[nextIndex];

    // Last tier special case: the first badge id is the one awarded at the
    // karma goal. Reaching the goal without the second (extraordinary
    // contribution) badge adds a nudge above the checklist, which stays so the
    // missing badge is still named.
    const [karmaBadgeId, secondBadgeId] = next.badgeIds;
    const isAlmost =
      nextIndex === total - 1 &&
      next.badgeIds.length >= 2 &&
      earned.has(karmaBadgeId) &&
      !earned.has(secondBadgeId) &&
      (karma ?? 0) >= (settings.karma_goal || 9999);

    // Class names are precomputed here: a strict-mode template cannot build one
    // from an inline conditional.
    const requirements = next.badgeIds.map((id) => {
      const badge = byId.get(id);
      const isEarned = earned.has(id);

      return {
        isEarned,
        name: badge?.name || `#${id}`,
        url: badge ? getURL(`/badges/${id}/${badge.slug}`) : null,
        className: isEarned
          ? "user-tier-badge__requirement --earned"
          : "user-tier-badge__requirement --missing",
      };
    });

    const value = requirements.filter((req) => req.isEarned).length;
    const shown =
      requirements.length > MAX_QUESTS
        ? [
            ...requirements.filter((req) => !req.isEarned),
            ...requirements.filter((req) => req.isEarned),
          ].slice(0, MAX_QUESTS)
        : requirements;

    return {
      isAlmost,
      tier: {
        ...this.tierView(next, nextIndex + 1, total),
        requirements: shown,
        isCapped: shown.length < requirements.length,
        value,
        max: requirements.length,
      },
    };
  }

  <template>
    {{#if this.currentUser}}
      <AsyncContent @asyncData={{this.loadData}}>
        <:content as |data|>
          {{#if data}}
            {{! Delegates clicks from the nested links, keyboard included. }}
            {{! template-lint-disable no-invalid-interactive }}
            <div
              class="user-tier-badge__layout"
              {{on "click" this.closeOnLinkClick}}
            >
              <div class="user-tier-badge__progress">
                <span class="user-tier-badge__progress-label">
                  {{#if data.tier.groupUrl}}
                    <a href={{data.tier.groupUrl}}>
                      {{i18n (themePrefix data.tier.name)}}
                    </a>
                  {{else}}
                    <span>{{i18n (themePrefix data.tier.name)}}</span>
                  {{/if}}
                  {{#unless data.isDone}}
                    <span class="user-tier-badge__progress-count">
                      {{data.tier.value}}
                      /
                      {{data.tier.max}}
                    </span>
                  {{/unless}}
                </span>
                <progress
                  value={{data.tier.value}}
                  max={{data.tier.max}}
                ></progress>
                <span class="user-tier-badge__position">
                  {{i18n
                    (themePrefix "user_badge.of_total")
                    current=data.tier.position
                    total=data.tier.total
                  }}
                </span>
                {{#if data.tier.description}}
                  <p class="user-tier-badge__description">
                    {{data.tier.description}}
                  </p>
                {{/if}}
              </div>

              {{#if data.isDone}}
                <div
                  class="user-tier-badge__message user-tier-badge__message--done"
                >
                  {{i18n (themePrefix "user_badge.completed")}}
                </div>
              {{else}}
                {{#if data.isAlmost}}
                  <div
                    class="user-tier-badge__message user-tier-badge__message--almost"
                  >
                    {{i18n (themePrefix "user_badge.almost_there")}}
                  </div>
                {{/if}}

                <ul class="user-tier-badge__requirements">
                  {{#each data.tier.requirements as |requirement|}}
                    <li class={{requirement.className}}>
                      {{#if requirement.isEarned}}
                        {{dIcon "check"}}
                      {{else}}
                        {{dIcon "xmark"}}
                      {{/if}}
                      {{#if requirement.url}}
                        <a href={{requirement.url}}>{{requirement.name}}</a>
                      {{else}}
                        <span>{{requirement.name}}</span>
                      {{/if}}
                    </li>
                  {{/each}}
                </ul>

                {{#if data.tier.isCapped}}
                  <a class="user-tier-badge__see-all" href={{this.badgesUrl}}>
                    {{i18n (themePrefix "user_badge.see_all")}}
                  </a>
                {{/if}}
              {{/if}}
            </div>
          {{/if}}
        </:content>
      </AsyncContent>
    {{/if}}
  </template>
}
