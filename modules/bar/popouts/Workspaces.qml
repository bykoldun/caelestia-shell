import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    required property PopoutState popouts

    implicitWidth: child.implicitWidth
    implicitHeight: child.implicitHeight

    property var wsWindows: popouts.hoveredWs > 0 ? Hypr.toplevels.values.filter(c => c.workspace?.id === root.popouts.hoveredWs) : []
    property var wsInfo: popouts.hoveredWs > 0 ? Hypr.workspaces.values.find(w => w.id === root.popouts.hoveredWs) : null
    property var monitorInfo: wsInfo ? Hypr.monitors.values.find(m => m.lastIpcObject.id === wsInfo.lastIpcObject.monitorID) : Hypr.focusedMonitor
    
    property real monWidth: monitorInfo ? monitorInfo.lastIpcObject.width : 1920
    property real monHeight: monitorInfo ? monitorInfo.lastIpcObject.height : 1080
    property real monX: monitorInfo ? monitorInfo.lastIpcObject.x : 0
    property real monY: monitorInfo ? monitorInfo.lastIpcObject.y : 0

    // Set our preview target width
    property real previewWidth: Tokens.sizes.bar.windowPreviewSize * 2
    property real previewScale: previewWidth / monWidth
    property real previewHeight: monHeight * previewScale

    ColumnLayout {
        id: child

        spacing: Tokens.spacing.medium

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: "Workspace " + (root.popouts.hoveredWs > 0 ? root.popouts.hoveredWs : "")
            font: Tokens.font.body.large
            color: Colours.palette.m3onSurface
            visible: root.popouts.hoveredWs > 0
        }

        ClippingWrapperRectangle {
            visible: root.wsWindows.length > 0
            implicitWidth: root.previewWidth
            implicitHeight: root.previewHeight
            color: Colours.layer(Colours.palette.m3surfaceVariant, 1)
            radius: Tokens.rounding.medium

            Item {
                width: root.monWidth
                height: root.monHeight
                scale: root.previewScale
                transformOrigin: Item.TopLeft

                Repeater {
                    model: root.wsWindows
                    
                    Item {
                        property var ipcObj: modelData.lastIpcObject
                        x: ipcObj.at ? (ipcObj.at[0] - root.monX) : 0
                        y: ipcObj.at ? (ipcObj.at[1] - root.monY) : 0
                        width: ipcObj.size ? ipcObj.size[0] : 0
                        height: ipcObj.size ? ipcObj.size[1] : 0
                        
                        Rectangle {
                            anchors.fill: parent
                            color: Colours.layer(Colours.palette.m3surface, 2)
                            radius: Tokens.rounding.medium * (1 / root.previewScale)
                            
                            ScreencopyView {
                                anchors.fill: parent
                                anchors.margins: 4 * (1 / root.previewScale)
                                captureSource: modelData.wayland ?? null
                                live: visible
                            }
                        }
                    }
                }
            }
        }
        
        Item {
            visible: root.wsWindows.length === 0
            implicitWidth: root.previewWidth
            implicitHeight: root.previewHeight
            StyledText {
                anchors.centerIn: parent
                text: "Empty Workspace"
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }
}
