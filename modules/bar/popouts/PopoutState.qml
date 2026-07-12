import QtQuick

QtObject {
    property string currentName
    property bool hasCurrent
    property int hoveredWs: -1

    signal detachRequested(mode: string)
}
