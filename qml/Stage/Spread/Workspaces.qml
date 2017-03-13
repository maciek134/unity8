import QtQuick 2.4
import Ubuntu.Components 1.3
import WindowManager 1.0
import "MathUtils.js" as MathUtils
import "../../Components"

Item {
    id: root
    implicitWidth: listView.contentWidth

    property QtObject screen: null
    property alias workspaceModel: listView.model
    property var background // TODO: should be stored in the workspace data

    signal commitScreenSetup();

    DropArea {
        anchors.fill: root

        keys: ['workspace']

        onEntered: {
            var index = listView.getDropIndex(drag);
            drag.source.workspace.assign(workspaceModel, index)
            listView.dropItemIndex = index;
            drag.source.inDropArea = true;
        }

        onPositionChanged: {
            var index = listView.getDropIndex(drag);
            if (listView.dropItemIndex == index) return;
            listView.model.move(listView.dropItemIndex, index, 1);
            listView.dropItemIndex = index;
        }

        onExited: {
            drag.source.workspace.unassign()
            listView.dropItemIndex = -1;
            drag.source.inDropArea = false;
        }

        onDropped: {
            drop.accept(Qt.MoveAction);
            listView.dropItemIndex = -1;
            drag.source.inDropArea = false;
        }
    }
    DropArea {
        anchors.fill: parent
        keys: ["application"]

        onPositionChanged: {
            listView.progressiveScroll(drag.x)
            listView.hoveredWorkspaceIndex = listView.getDropIndex(drag)
        }
        onExited: {
            listView.hoveredWorkspaceIndex = -1
        }
    }

    ListView {
        id: listView
        anchors.fill: parent
        anchors.leftMargin: -itemWidth
        anchors.rightMargin: -itemWidth
        boundsBehavior: Flickable.StopAtBounds

        orientation: ListView.Horizontal
        spacing: units.gu(1)
        leftMargin: itemWidth
        rightMargin: itemWidth

        property var screenSize: screen.availableModes[screen.currentModeIndex].size
        property int itemWidth: height * screenSize.width / screenSize.height
        property int foldingAreaWidth: units.gu(10)
        property real realContentX: contentX - originX + leftMargin
        property int dropItemIndex: -1
        property int hoveredWorkspaceIndex: -1

        function getDropIndex(drag) {
            var coords = mapToItem(listView.contentItem, drag.x, drag.y)
            var index = Math.floor((drag.x + listView.realContentX) / (listView.itemWidth + listView.spacing));
            if (index < 0) index = 0;
            var upperLimit = dropItemIndex == -1 ? listView.count : listView.count - 1
            if (index > upperLimit) index = upperLimit;
            return index;
        }

        function progressiveScroll(mouseX) {
            var progress = Math.max(0, Math.min(1, (mouseX - listView.foldingAreaWidth) / (width - listView.leftMargin * 2 - listView.foldingAreaWidth * 2)))
            listView.contentX = listView.originX + (listView.contentWidth - listView.width + listView.leftMargin + listView.rightMargin) * progress - listView.leftMargin
        }

        displaced: Transition { UbuntuNumberAnimation { properties: "x" } }

        delegate: Item {
            id: workspaceDelegate
            objectName: "delegate" + index
            height: parent.height
            width: listView.itemWidth
            Behavior on width { UbuntuNumberAnimation {} }
            visible: listView.dropItemIndex !== index

            property int itemX: -listView.realContentX + index * (listView.itemWidth + listView.spacing)
            property int distanceFromLeft: itemX //- listView.leftMargin
            property int distanceFromRight: listView.width - listView.leftMargin - listView.rightMargin - itemX - listView.itemWidth

            property int maxAngle: 40

            property int itemAngle: {
                if (index == 0) {
                    if (distanceFromLeft < 0) {
                        var progress = (distanceFromLeft + listView.foldingAreaWidth) / listView.foldingAreaWidth
                        return MathUtils.linearAnimation(1, -1, 0, maxAngle, Math.max(-1, Math.min(1, progress)));
                    }
                    return 0
                }
                if (index == listView.count - 1) {
                    if (distanceFromRight < 0) {
                        var progress = (distanceFromRight + listView.foldingAreaWidth) / listView.foldingAreaWidth
                        return MathUtils.linearAnimation(1, -1, 0, -maxAngle, Math.max(-1, Math.min(1, progress)));
                    }
                    return 0
                }

                if (distanceFromLeft < listView.foldingAreaWidth) {
                    // itemX : 10gu = p : 100
                    var progress = distanceFromLeft / listView.foldingAreaWidth
                    return MathUtils.linearAnimation(1, -1, 0, maxAngle, Math.max(-1, Math.min(1, progress)));
                }
                if (distanceFromRight < listView.foldingAreaWidth) {
                    var progress = distanceFromRight / listView.foldingAreaWidth
                    return MathUtils.linearAnimation(1, -1, 0, -maxAngle, Math.max(-1, Math.min(1, progress)));
                }
                return 0
            }

            property int itemOffset: {
                var rotationOffset = (1 - Math.cos(itemAngle * Math.PI / 360)) * listView.itemWidth
                if (index == 0) {
                    if (distanceFromLeft < 0) {
                        return -distanceFromLeft - rotationOffset
                    }
                    return 0
                }
                if (index == listView.count - 1) {
                    if (distanceFromRight < 0) {
                        return distanceFromRight + rotationOffset
                    }
                    return 0
                }

                if (itemX < -listView.foldingAreaWidth) {
                    return -itemX - rotationOffset
                }
                if (distanceFromLeft < listView.foldingAreaWidth) {
                    return (listView.foldingAreaWidth - distanceFromLeft) / 2 - rotationOffset
                }

                if (distanceFromRight < -listView.foldingAreaWidth) {
                    return distanceFromRight + rotationOffset
                }

                if (distanceFromRight < listView.foldingAreaWidth) {
                    return -(listView.foldingAreaWidth - distanceFromRight) / 2 + rotationOffset
                }

                return 0
            }

//            onItemXChanged: if (index == 1) print("x", itemX, listView.contentX)

            z: itemOffset < 0 ? itemOffset : -itemOffset
            transform: [
                Rotation {
                    angle: itemAngle
                    axis { x: 0; y: 1; z: 0 }
                    origin { x: itemAngle < 0 ? listView.itemWidth : 0; y: height / 2 }
                },
                Translate {
                    x: itemOffset
                }
            ]

            WorkspacePreview {
                height: listView.height
                width: listView.itemWidth
                background: root.background
                screenHeight: screen.availableModes[screen.currentModeIndex].size.height
                containsDrag: listView.hoveredWorkspaceIndex == index
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    model.workspace.activate()
                }
            }

            MouseArea {
                id: closeMouseArea
                objectName: "closeMouseArea"
                anchors { left: parent.left; top: parent.top; leftMargin: -height / 2; topMargin: -height / 2 }
                hoverEnabled: true
                height: units.gu(4)
                width: height

                onClicked: {
                    model.workspace.unassign();
                    root.commitScreenSetup();
                }
                Image {
                    id: closeImage
                    source: "../graphics/window-close.svg"
                    anchors.fill: closeMouseArea
                    anchors.margins: units.gu(1)
                    sourceSize.width: width
                    sourceSize.height: height
                    readonly property var mousePos: hoverMouseArea.mapToItem(workspaceDelegate, hoverMouseArea.mouseX, hoverMouseArea.mouseY)
                    readonly property bool shown: (hoverMouseArea.containsMouse || parent.containsMouse)
                                             && mousePos.y < workspaceDelegate.width / 4
                                             && mousePos.y > -units.gu(2)
                                             && mousePos.x > -units.gu(2)
                                             && mousePos.x < workspaceDelegate.height / 4
                    opacity: shown ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { UbuntuNumberAnimation { duration: UbuntuAnimation.SnapDuration } }

                }
            }
        }

        MouseArea {
            id: hoverMouseArea
            anchors.fill: parent
            hoverEnabled: true
            propagateComposedEvents: true
            anchors.leftMargin: listView.leftMargin
            anchors.rightMargin: listView.rightMargin

            property int draggedIndex: -1

            property int startX: 0
            property int startY: 0

            onMouseXChanged: {
                if (!pressed || dragging) {
                    listView.progressiveScroll(mouseX)
                }
            }
            onMouseYChanged: {
                if (Math.abs(mouseY - startY) > units.gu(3)) {
                    drag.axis = Drag.XAndYAxis;
                }
            }

            onReleased: {
                var result = fakeDragItem.Drag.drop();
//                if (result == Qt.IgnoreAction) {
//                    WorkspaceManager.destroyWorkspace(fakeDragItem.workspace);
//                }
                root.commitScreenSetup();
                drag.target = null;
            }

            property bool dragging: drag.active
            onDraggingChanged: {
                if (drag.active) {
                    print("drai", draggedIndex)
                    var ws = listView.model.get(draggedIndex);
                    print("ws:", ws)
                    ws.unassign();
//                    listView.model.remove(draggedIndex, 1)
                }
            }

            onPressed: {
                startX = mouseX;
                startY = mouseY;
                if (listView.model.count < 2) return;

                var coords = mapToItem(listView.contentItem, mouseX, mouseY)
                draggedIndex = listView.indexAt(coords.x, coords.y)
                var clickedItem = listView.itemAt(coords.x, coords.y)

                var itemCoords = clickedItem.mapToItem(listView, -listView.leftMargin, 0);
                fakeDragItem.x = itemCoords.x
                fakeDragItem.y = itemCoords.y
                fakeDragItem.workspace = listView.model.get(draggedIndex)

                var mouseCoordsInItem = mapToItem(clickedItem, mouseX, mouseY);
                fakeDragItem.Drag.hotSpot.x = mouseCoordsInItem.x
                fakeDragItem.Drag.hotSpot.y = mouseCoordsInItem.y

                drag.axis = Drag.YAxis;
                drag.target = fakeDragItem;
            }

            WorkspacePreview {
                id: fakeDragItem
                height: listView.height
                width: listView.itemWidth
                background: root.background
                screenHeight: screen.availableModes[screen.currentModeIndex].size.height
                visible: Drag.active

                Drag.active: hoverMouseArea.drag.active
                Drag.keys: ['workspace']

                property var workspace
                property bool inDropArea: false

                Rectangle {
                    anchors.fill: parent
                    color: "#33000000"
                    opacity: parent.inDropArea ? 0 : 1
                    Behavior on opacity { UbuntuNumberAnimation { } }
                    Rectangle {
                        anchors.centerIn: parent
                        width: units.gu(6)
                        height: units.gu(6)
                        radius: width / 2
                        color: "#aa000000"
                    }

                    Icon {
                        height: units.gu(3)
                        width: height
                        anchors.centerIn: parent
                        name: "edit-delete"
                        color: "white"
                    }
                }

                states: [
                    State {
                        when: fakeDragItem.Drag.active
                        ParentChange { target: fakeDragItem; parent: shell }
                    }
                ]
            }
        }
    }
}
