pragma Singleton

import Quickshell
import Caelestia
import Caelestia.Config
import qs.utils

Searcher {
    id: root

    function launch(entry: DesktopEntry): void {
        appDb.incrementFrequency(entry.id);

        if (entry.runInTerminal)
            Quickshell.execDetached({
                command: [...GlobalConfig.general.apps.terminal, `${Quickshell.shellDir}/assets/wrap_term_launch.sh`, ...entry.command],
                workingDirectory: entry.workingDirectory
            });
        else
            entry.execute();
    }

    function search(searchString: string): list<var> {
        const prefix = GlobalConfig.launcher.specialPrefix;
        
        let flag = "";
        let q = searchString.trim();
        
        if (q.startsWith(prefix) && q.length >= prefix.length + 1) {
            const potentialFlag = q.substring(prefix.length, prefix.length + 1);
            if (["i", "c", "d", "e", "w", "g", "k", "t"].includes(potentialFlag)) {
                if (q.length === prefix.length + 1 || q[prefix.length + 1] === " ") {
                    flag = potentialFlag;
                    q = q.substring(prefix.length + 1).trim();
                }
            }
        }

        if (flag === "i") {
            keys = ["id", "name"];
            weights = [0.9, 0.1];
        } else if (flag === "c") {
            keys = ["categories", "name"];
            weights = [0.9, 0.1];
        } else if (flag === "d") {
            keys = ["comment", "name"];
            weights = [0.9, 0.1];
        } else if (flag === "e") {
            keys = ["execString", "name"];
            weights = [0.9, 0.1];
        } else if (flag === "w") {
            keys = ["startupClass", "name"];
            weights = [0.9, 0.1];
        } else if (flag === "g") {
            keys = ["name"];
            weights = [1];
        } else if (flag === "k") {
            keys = ["keywords", "name"];
            weights = [0.9, 0.1];
        } else {
            keys = ["name"];
            weights = [1];
        }

        const results = query(q).map(e => e.entry);
        if (flag === "t")
            return results.filter(a => a.runInTerminal);
        if (flag === "g") {
            const excludeCats = ["utility", "network", "filetransfer", "emulator", "settings", "system"];
            return results.filter(a => {
                const cats = a.categories;
                if (!cats) return false;
                const catArray = Array.isArray(cats) ? cats : String(cats).split(";");
                const isGame = catArray.some(c => c.toLowerCase().includes("game"));
                const isLauncher = catArray.some(c => excludeCats.some(e => c.toLowerCase().includes(e)));
                return isGame && !isLauncher;
            });
        }
        return results;
    }

    function selector(item: var): string {
        return keys.map(k => item[k]).join(" ");
    }

    list: appDb.apps
    useFuzzy: GlobalConfig.launcher.useFuzzy.apps

    AppDb {
        id: appDb

        path: `${Paths.state}/apps.sqlite`
        favouriteApps: GlobalConfig.launcher.favouriteApps
        entries: DesktopEntries.applications.values.filter(a => !Strings.testRegexList(GlobalConfig.launcher.hiddenApps, a.id))
    }
}
