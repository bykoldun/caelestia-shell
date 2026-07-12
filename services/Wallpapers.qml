pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.Models
import qs.services
import qs.utils

Searcher {
    id: root

    readonly property string currentNamePath: `${Paths.state}/wallpaper/path.txt`
    readonly property list<string> smartArg: GlobalConfig.services.smartScheme ? [] : ["--no-smart"]
    readonly property string fallback: Quickshell.shellPath("assets/wallpaper.webp")

    property bool showPreview: false
    readonly property string current: showPreview ? previewPath : actualCurrent
    property string previewPath
    property string actualCurrent
    property bool previewColourLock
    property bool pendingPreviewClear

    property list<string> favorites: []

    FileView {
        path: `${Paths.state}/wallpaper/favorites.txt`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.favorites = text().split('\n').filter(p => p.length > 0);
        }
    }

    function toggleFavorite(path: string): void {
        Quickshell.execDetached(["bash", "-c", `
            FILE="$1"
            PATH_STR="$2"
            mkdir -p "$(dirname "$FILE")"
            touch "$FILE"
            if grep -Fxq "$PATH_STR" "$FILE"; then
                grep -Fxv "$PATH_STR" "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"
            else
                echo "$PATH_STR" >> "$FILE"
            fi
        `, "dummy", `${Paths.state}/wallpaper/favorites.txt`, path]);
    }

    function getCategoryFor(w: var): string {
        if (!w || !w.parentDir) return "";
        if (w.parentDir.includes("steamapps/workshop/content/431960"))
            return "Wallpaper Engine";
        if (!w.parentDir.startsWith(Paths.wallsdir))
            return "";
        let category = w.parentDir.slice(Paths.wallsdir.length + 1);
        if (category.includes("/"))
            category = category.slice(0, category.indexOf("/"));
        return category || "Pictures";
    }

    function getPreviewFor(path: string): string {
        if (!path) return "";
        const ext = path.split('.').pop().toLowerCase();
        let resultPath = path;
        if (["mp4", "webm", "mkv", "avi"].includes(ext)) {
            if (wpEnginePreviews[path]) resultPath = wpEnginePreviews[path];
            else {
                const parentDir = path.substring(0, path.lastIndexOf('/'));
                const preview = allWallpapers.find(e => e && e.parentDir === parentDir && (e.name.startsWith("preview.") || e.name.startsWith("thumbnail.")));
                resultPath = preview ? preview.path : (parentDir + "/preview.jpg");
            }
        }
        return resultPath ? (resultPath.startsWith("file://") || resultPath.startsWith("qs://") ? resultPath : "file://" + resultPath) : "";
    }

    function setRandom(): void {
        Quickshell.execDetached(["caelestia", "wallpaper", "-r", ...smartArg]);
    }

    function setWallpaper(path: string): void {
        actualCurrent = path;
        Quickshell.execDetached(["caelestia", "wallpaper", "-f", path, ...smartArg]);
    }

    function preview(path: string): void {
        previewPath = path;
        showPreview = true;

        if (Colours.scheme === "dynamic")
            getPreviewColoursProc.running = true;
    }

    function stopPreview(): void {
        showPreview = false;
        if (previewColourLock)
            pendingPreviewClear = true;
        else
            Colours.showPreview = false;
    }

    onPreviewColourLockChanged: {
        if (!previewColourLock && pendingPreviewClear)
            Colours.showPreview = false;
    }

    property var allWallpapers: [...(wallpapers.entries || []), ...(wpEngine.entries || [])]
    list: {
        const _deps = root.wpEnginePaths; // Force QML to track dependency
        return allWallpapers.filter(e => {
            if (!e || !e.path || !e.name) return false;
            
            if (e.parentDir && e.parentDir.includes("steamapps/workshop/content/431960")) {
                if (!root.wpEnginePaths.includes(e.path)) return false;
                const ext = e.path.split('.').pop().toLowerCase();
                return ["mp4", "webm", "mkv", "avi"].includes(ext);
            }

        if (e.name.startsWith("preview.") || e.name.startsWith("thumbnail.")) return false;
        const ext = e.path.split('.').pop().toLowerCase();
        return ["jpg", "jpeg", "png", "webp", "gif", "mp4", "webm", "mkv", "avi"].includes(ext);
    })
    }
    key: "relativePath"
    useFuzzy: GlobalConfig.launcher.useFuzzy.wallpapers
    extraOpts: useFuzzy ? ({}) : ({
            forward: false
        })

    function searchQuery(q: string): list<var> {
        q = q.trim();
        let onlyFavs = false;
        
        const favFlag = GlobalConfig.launcher.specialPrefix + "f";
        if (q.startsWith(favFlag)) {
            onlyFavs = true;
            q = q.substring(favFlag.length).trim();
        }
        
        let results = root.query(q); // Call MiniSearch's native query
        
        if (onlyFavs) {
            results = results.filter(w => favorites.includes(w.path));
        }
        return results;
    }

    IpcHandler {
        function get(): string {
            return root.actualCurrent;
        }

        function query(q: string): list<var> {
            if (q.trim().length === 0)
                return root.list;
            return root.list.filter(w => {
                const name = (root.wpEngineTitles[w.path] || w.name).toLowerCase();
                return name.includes(q.toLowerCase());
            });
        }

        function set(path: string): void {
            root.setWallpaper(path);
        }

        function list(): string {
            return root.list.map(w => w.path).join("\n");
        }

        target: "wallpaper"
    }

    FileView {
        path: root.currentNamePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()

        onLoaded: {
            let wall = text().trim();
            if (!wall) {
                wall = root.fallback;
                Quickshell.execDetached(["caelestia", "wallpaper", "-f", root.fallback, ...root.smartArg]);
            }
            root.actualCurrent = wall;
            root.previewColourLock = false;
        }
        onLoadFailed: {
            root.actualCurrent = root.fallback;
            root.previewColourLock = false;
            Quickshell.execDetached(["caelestia", "wallpaper", "-f", root.fallback, ...root.smartArg]);
        }
    }

    FileSystemModel {
        id: wallpapers

        recursive: true
        path: Paths.wallsdir
        filter: FileSystemModel.Files
    }

    FileSystemModel {
        id: wpEngine

        recursive: true
        path: Paths.home + "/.local/share/Steam/steamapps/workshop/content/431960"
        filter: FileSystemModel.Files
        onEntriesChanged: getWPEngineWallpapers.running = true
    }

    property var wpEnginePaths: []
    property var wpEngineTitles: ({})
    property var wpEnginePreviews: ({})

    Process {
        id: getWPEngineWallpapers
        running: true
        command: ["python", "-c", `
import os, json
path = os.path.expanduser('~/.local/share/Steam/steamapps/workshop/content/431960')
result = {"paths": [], "titles": {}, "previews": {}}
if os.path.exists(path):
    for d in os.listdir(path):
        d_path = os.path.join(path, d)
        p = os.path.join(d_path, 'project.json')
        if os.path.exists(p):
            try:
                with open(p) as f:
                    data = json.load(f)
                file_name = data.get('file')
                if file_name:
                    full_path = os.path.join(d_path, file_name)
                    result["paths"].append(full_path)
                    result["titles"][full_path] = data.get('title', file_name)
                    
                    preview = data.get('preview')
                    if preview and os.path.exists(os.path.join(d_path, preview)):
                        result["previews"][full_path] = os.path.join(d_path, preview)
                    else:
                        found_preview = None
                        for p_name in ['preview.jpg', 'preview.gif', 'preview.png', 'thumbnail.jpg']:
                            if os.path.exists(os.path.join(d_path, p_name)):
                                found_preview = os.path.join(d_path, p_name)
                                break
                        if found_preview:
                            result["previews"][full_path] = found_preview
                        else:
                            result["previews"][full_path] = os.path.join(d_path, 'preview.jpg')
            except:
                pass
print(json.dumps(result))
`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const res = JSON.parse(text);
                    root.wpEnginePaths = res.paths || [];
                    root.wpEngineTitles = res.titles || {};
                    root.wpEnginePreviews = res.previews || {};
                } catch(e) {
                    root.wpEnginePaths = [];
                    root.wpEngineTitles = {};
                    root.wpEnginePreviews = {};
                }
            }
        }
    }

    Process {
        id: getPreviewColoursProc

        command: ["caelestia", "wallpaper", "-p", root.previewPath, ...root.smartArg]
        stdout: StdioCollector {
            onStreamFinished: {
                Colours.load(text, true);
                Colours.showPreview = true;
            }
        }
    }
}
