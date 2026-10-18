// Run: QT_QPA_PLATFORM=offscreen qmltestrunner -input packages/plasma-widelaunchers/tests
import QtQuick
import QtTest
import "../package/contents/ui/logic.js" as Logic

TestCase {
    name: "Logic"

    function test_hasWideScreen_data() {
        return [
            { tag: "rowlett: landscape + portrait", widths: [2560, 1080], want: true },
            { tag: "celebi undocked", widths: [1504], want: false },
            { tag: "celebi docked: panel on narrow screen", widths: [1504, 2560], want: true },
            { tag: "no screens", widths: [], want: false },
            { tag: "exactly the threshold", widths: [1600], want: true },
        ];
    }
    function test_hasWideScreen(data) {
        compare(Logic.hasWideScreen(data.widths, 1600), data.want);
    }

    function test_displayMode_data() {
        return [
            { tag: "no wide screen", wide: false, alloc: 200, slot: 44, count: 2, want: "hidden" },
            { tag: "full width", wide: true, alloc: 88, slot: 44, count: 2, want: "full" },
            { tag: "sub-pixel short", wide: true, alloc: 87.7, slot: 44, count: 2, want: "full" },
            { tag: "squeezed", wide: true, alloc: 60, slot: 44, count: 2, want: "collapsed" },
            { tag: "no launchers", wide: true, alloc: 44, slot: 44, count: 0, want: "hidden" },
        ];
    }
    function test_displayMode(data) {
        compare(Logic.displayMode(data.wide, data.alloc, data.slot, data.count), data.want);
    }

    function test_appState_data() {
        const rows = [
            { AppId: "chatgpt", IsLauncher: true },
            { AppId: "com.anthropic.Claude", IsLauncher: false },
        ];
        const suffixed = [
            { AppId: "chatgpt.desktop", IsLauncher: true },
            { AppId: "com.anthropic.Claude.desktop", IsLauncher: false },
        ];
        return [
            { tag: "running app", rows: rows, id: "com.anthropic.Claude", want: { row: 1, running: true } },
            { tag: "launcher only", rows: rows, id: "chatgpt", want: { row: 0, running: false } },
            { tag: "absent", rows: [], id: "chatgpt", want: { row: -1, running: false } },
            // Plasma 6.6's TasksModel reports AppId as the desktop file's
            // storage id, .desktop suffix included (seen live on rowlett).
            { tag: "launcher, .desktop AppId", rows: suffixed, id: "chatgpt", want: { row: 0, running: false } },
            { tag: "running, .desktop AppId", rows: suffixed, id: "com.anthropic.Claude", want: { row: 1, running: true } },
            { tag: "no prefix match", rows: [{ AppId: "chatgpt-beta.desktop", IsLauncher: false }], id: "chatgpt", want: { row: -1, running: false } },
        ];
    }
    function test_appState(data) {
        compare(Logic.appState(data.rows, data.id), data.want);
    }

    function test_anyRunning() {
        compare(Logic.anyRunning([{ running: false }, { running: true }]), true);
        compare(Logic.anyRunning([{ running: false }]), false);
    }
}
