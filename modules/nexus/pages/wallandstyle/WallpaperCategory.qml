pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Caelestia.Config
import Caelestia.Models
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: {
        const c = nState.selectedWallpaperCategory;
        return c.slice(0, 1).toUpperCase() + c.slice(1);
    }
    isSubPage: true

    Component.onCompleted: root.flickable.interactive = false

    ListView {
        id: listView
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.cappedWidth
        implicitHeight: root.flickable.height - root.flickable.topMargin - root.flickable.bottomMargin // Perfectly fit viewport without clipping

        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.vertical: ScrollBar {}

        WheelHandler {
            onWheel: (event) => {
                listView.contentY -= event.angleDelta.y;
                if (listView.contentY < 0) listView.contentY = 0;
                const maxContentY = Math.max(0, listView.contentHeight - listView.height);
                if (listView.contentY > maxContentY) listView.contentY = maxContentY;
            }
        }

        spacing: Tokens.spacing.medium

        model: {
            let walls = [];
            if (root.nState.selectedWallpaperCategory === "Favorites") {
                walls = Wallpapers.list.filter(w => Wallpapers.favorites.includes(w.path));
            } else {
                walls = Wallpapers.list.filter(w => Wallpapers.getCategoryFor(w) === root.nState.selectedWallpaperCategory);
            }
            walls = walls.sort((a, b) => a.name.localeCompare(b.name));
            
            const chunked = [];
            const rowSize = Config.nexus.wallpapersPerRow;
            for (let i = 0; i < walls.length; i += rowSize) {
                chunked.push(walls.slice(i, i + rowSize));
            }
            return chunked;
        }

        delegate: RowLayout {
            id: rowDelegate
            required property var modelData
            width: listView.width
            spacing: Tokens.spacing.large

            Repeater {
                model: rowDelegate.modelData

                WallItem {
                    required property var modelData
                    
                    Layout.fillWidth: true
                    
                    opacity: modelData ? 1 : 0
                    enabled: modelData

                    source: Wallpapers.getPreviewFor(modelData?.path ?? "")
                    text: (modelData && Wallpapers.wpEngineTitles[modelData.path]) ? Wallpapers.wpEngineTitles[modelData.path] : (modelData?.relativePath ?? modelData?.name ?? "")
                    onClicked: {
                        Wallpapers.setWallpaper(modelData.path);
                        root.nState.closeSubPage();
                        root.nState.closeSubPage();
                    }
                }
            }
            
            Repeater {
                model: Config.nexus.wallpapersPerRow - rowDelegate.modelData.length
                Item { Layout.fillWidth: true } // Empty placeholders
            }
        }
    }
}
