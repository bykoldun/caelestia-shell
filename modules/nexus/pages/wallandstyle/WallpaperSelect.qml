pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.Components
import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Wallpapers")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.cappedWidth
        spacing: Tokens.spacing.small

        ButtonRow {
            Layout.bottomMargin: Tokens.spacing.medium
            Layout.alignment: Qt.AlignHCenter
            spacing: Tokens.spacing.small

            IconTextButton {
                icon: "photo_library"
                text: qsTr("Browse")
                font: Tokens.font.body.large
                isRound: true
                shapeMorph: true
                horizontalPadding: Tokens.padding.extraLarge
                verticalPadding: Tokens.padding.medium
                onClicked: browseDialog.open()

                FileDialog {
                    id: browseDialog

                    title: qsTr("Select an image")
                    filterLabel: qsTr("Image files")
                    filters: Images.validImageExtensions
                    onAccepted: path => {
                        Wallpapers.setWallpaper(path);
                        root.nState.closeSubPage();
                    }
                }
            }

            IconTextButton {
                icon: "shuffle"
                text: qsTr("Random")
                font: Tokens.font.body.large
                isRound: true
                shapeMorph: true
                horizontalPadding: Tokens.padding.extraLarge
                verticalPadding: Tokens.padding.medium
                type: IconTextButton.Tonal
                onClicked: {
                    Wallpapers.setRandom();
                    root.nState.closeSubPage();
                }
            }
        }

        WallItem {
            imgHeight: Math.round(width * 0.3)
            radius: Tokens.rounding.extraLarge
            source: Wallpapers.fallback
            text: qsTr("Featured wallpaper")
            fillLabel: false
            onClicked: {
                Wallpapers.setWallpaper(Wallpapers.fallback);
                root.nState.closeSubPage();
            }
        }

        StyledText {
            Layout.topMargin: Tokens.spacing.large
            Layout.bottomMargin: Tokens.spacing.medium
            text: qsTr("Local wallpapers")
            font: Tokens.font.title.small
            visible: categoriesGrid.count > 0
        }

        GridLayout {
            Layout.fillWidth: true
            visible: categoriesGrid.count > 0

            columns: Config.nexus.wallpapersPerRow
            rowSpacing: Tokens.spacing.medium
            columnSpacing: Tokens.spacing.large

            Repeater {
                id: categoriesGrid

                model: {
                    const walls = Wallpapers.list;
                    const categories = {};
                    for (const w of walls) {
                        if (Wallpapers.favorites.includes(w.path)) {
                            if (!("Favorites" in categories)) {
                                categories["Favorites"] = {
                                    isCategory: true,
                                    name: "Favorites",
                                    path: w.path,
                                    parentDir: w.parentDir
                                };
                            }
                        }

                        let categoryName = Wallpapers.getCategoryFor(w);
                        if (!categoryName) categoryName = "Pictures";
                        
                        if (!(categoryName in categories) || categories[categoryName].name.localeCompare(w.name) > 0) {
                            categories[categoryName] = {
                                isCategory: true,
                                name: categoryName,
                                path: w.path,
                                parentDir: w.parentDir
                            };
                        }
                    }
                    const list = Object.values(categories).sort((a, b) => a.name.localeCompare(b.name));
                    while (list.length < Config.nexus.wallpapersPerRow)
                        list.push(null);
                    return list;
                }

                WallItem {
                    required property var modelData

                    Layout.fillWidth: true
                    
                    opacity: modelData ? 1 : 0
                    enabled: modelData

                    source: Wallpapers.getPreviewFor(modelData?.path ?? "")
                    isCategory: modelData?.isCategory ?? false
                    categoryIcon: modelData?.name === "Favorites" ? "favorite" : "folder"
                    text: {
                        if (!modelData)
                            return "";
                        return modelData.name.slice(0, 1).toUpperCase() + modelData.name.slice(1);
                    }
                    onClicked: {
                        if (modelData) {
                            root.nState.selectedWallpaperCategory = modelData.name;
                            root.nState.openSubPage(2);
                        }
                    }
                }
            }
        }

        Loader {
            Layout.fillWidth: true
            asynchronous: true
            active: categoriesGrid.count === 0
            visible: active

            sourceComponent: StyledRect {
                color: Colours.tPalette.m3surfaceContainer
                radius: Tokens.rounding.extraLarge
                implicitHeight: noWallsLayout.implicitHeight + Tokens.padding.extraExtraLarge * 2

                ColumnLayout {
                    id: noWallsLayout
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.extraSmall

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: "hide_image"
                        color: Colours.palette.m3outline
                        fontStyle: Tokens.font.icon.extraLarge
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("No local wallpapers found")
                        color: Colours.palette.m3outline
                        font: Tokens.font.title.small
                    }
                }
            }
        }
    }
}
