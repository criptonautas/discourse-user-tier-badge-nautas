import UserTierBadge from "../../components/user-tier-badge";

// Outlet added by discourse-custom-user-menu-nautas. Without that component the
// outlet never exists and this connector never renders.
<template><UserTierBadge @closeMenu={{@outletArgs.closeMenu}} /></template>
