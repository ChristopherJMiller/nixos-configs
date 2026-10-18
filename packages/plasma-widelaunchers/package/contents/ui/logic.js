.pragma library

// Pure decision logic for main.qml; tested by tests/tst_logic.qml.

// True when any connected screen is at least minWidth logical px wide. All
// screens count, not just the panel's: celebi's panel stays on the narrow
// laptop screen when docked to a wide monitor.
function hasWideScreen(screenWidths, minWidth) {
    return screenWidths.some(w => w >= minWidth);
}

// "hidden" without a wide screen or launchers; "full" when the panel gives
// us room for every icon; otherwise (panel squeezed us) "collapsed".
function displayMode(wide, allocatedWidth, slot, count) {
    if (!wide || count === 0)
        return "hidden";
    return allocatedWidth >= slot * count - 0.5 ? "full" : "collapsed";
}

// rows: [{AppId, IsLauncher}] read from the TasksModel. With
// launchInPlace/separateLaunchers off, a running app's launcher row turns
// into its window (group) row, so "running" = a non-launcher row exists.
// Plasma reports AppId as the desktop storage id ("chatgpt.desktop"); the
// config holds bare ids, so compare without the suffix.
function appState(rows, appId) {
    const matches = r => String(r.AppId).replace(/\.desktop$/, "") === appId;
    return {
        row: rows.findIndex(matches),
        running: rows.some(r => matches(r) && !r.IsLauncher),
    };
}

function anyRunning(states) {
    return states.some(s => s.running);
}
