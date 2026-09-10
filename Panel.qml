import QtQuick
import QtMultimedia
import Quickshell
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "joramser.camera-test"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  property int currentDeviceIndex: -1
  property bool receivedFrame: false

  readonly property var devices: mediaDevices.videoInputs
  readonly property bool hasCamera: devices.length > 0
  readonly property var selectedDevice: hasCamera && currentDeviceIndex >= 0
    ? devices[currentDeviceIndex]
    : mediaDevices.defaultVideoInput
  readonly property string cameraName: hasCamera && currentDeviceIndex >= 0
    ? normalizedCameraName(String(selectedDevice.description))
    : "No camera detected"
  readonly property bool cameraActive: cameraLoader.item
    ? cameraLoader.item.cameraActive === true
    : false
  readonly property string cameraError: cameraLoader.item
    ? String(cameraLoader.item.cameraError || "")
    : ""
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  function normalizedCameraName(description) {
    var separator = description.lastIndexOf(": ")
    if (separator <= 0) return description

    var product = description.substring(0, separator)
    var interfaceName = description.substring(separator + 2)
    if (interfaceName === product) return product

    // V4L2 card names hold 31 bytes plus a terminator. Some UVC devices repeat
    // the product as the interface name, leaving the second copy truncated.
    var isAscii = /^[\x00-\x7f]*$/.test(description)
    if (isAscii && description.length === 31 && interfaceName !== "" && product.indexOf(interfaceName) === 0)
      return product

    return description
  }

  function preferredDeviceIndex() {
    if (!hasCamera) return -1

    var preferred = String(setting("preferredCamera", "")).trim().toLowerCase()
    if (preferred !== "") {
      for (var i = 0; i < devices.length; ++i) {
        if (String(devices[i].description).toLowerCase().indexOf(preferred) !== -1)
          return i
      }
    }

    var defaultId = String(mediaDevices.defaultVideoInput.id)
    for (var j = 0; j < devices.length; ++j) {
      if (String(devices[j].id) === defaultId) return j
    }
    return 0
  }

  function ensureDevice() {
    if (!hasCamera) {
      currentDeviceIndex = -1
      receivedFrame = false
      return
    }
    if (currentDeviceIndex < 0 || currentDeviceIndex >= devices.length)
      currentDeviceIndex = preferredDeviceIndex()
  }

  function chooseDevice(delta) {
    if (!hasCamera) return
    currentDeviceIndex = (Math.max(0, currentDeviceIndex) + delta + devices.length) % devices.length
    receivedFrame = false
  }

  function open() {
    currentDeviceIndex = preferredDeviceIndex()
    receivedFrame = false
    root.controller.show()
  }

  function close() {
    root.controller.hide()
    receivedFrame = false
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  MediaDevices {
    id: mediaDevices
    onVideoInputsChanged: root.ensureDevice()
  }

  // Qt's FFmpeg backend can retain a V4L2 descriptor after Camera.active is
  // cleared. Destroy the pipeline so closing the panel always frees the device.
  Loader {
    id: cameraLoader
    active: root.opened && root.hasCamera

    sourceComponent: Component {
      Item {
        property alias cameraActive: camera.active
        property alias cameraError: camera.errorString

        Camera {
          id: camera
          cameraDevice: root.selectedDevice
          active: true
        }

        CaptureSession {
          camera: camera
          videoOutput: preview
        }
      }
    }
  }

  Connections {
    target: preview.videoSink
    function onVideoFrameChanged() {
      root.receivedFrame = true
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(680))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (dx !== 0) root.chooseDevice(dx)
      }
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(12)

        Item {
          width: parent.width
          height: title.implicitHeight

          Text {
            id: title
            anchors.left: parent.left
            anchors.right: controls.left
            anchors.rightMargin: Style.space(10)
            text: root.cameraName
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            elide: Text.ElideRight
          }

          Row {
            id: controls
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            PanelActionButton {
              enabled: root.devices.length > 1
              opacity: enabled ? 1 : 0.35
              iconText: "\uf053"
              tooltipText: "Previous camera"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.chooseDevice(-1)
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.hasCamera ? (root.currentDeviceIndex + 1) + " / " + root.devices.length : "0 / 0"
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }

            PanelActionButton {
              enabled: root.devices.length > 1
              opacity: enabled ? 1 : 0.35
              iconText: "\uf054"
              tooltipText: "Next camera"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.chooseDevice(1)
            }
          }
        }

        Rectangle {
          width: parent.width
          height: Math.round(width * 9 / 16)
          radius: Style.cornerRadius
          color: "black"
          clip: true

          VideoOutput {
            id: preview
            anchors.fill: parent
            visible: root.hasCamera
            fillMode: VideoOutput.PreserveAspectFit
            mirrored: setting("mirrorPreview", true)
          }

          Column {
            visible: !root.hasCamera
            anchors.centerIn: parent
            spacing: Style.space(8)

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "\uf030"
              color: Qt.rgba(1, 1, 1, 0.45)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.displayLarge
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "Connect a camera and reopen this panel"
              color: Qt.rgba(1, 1, 1, 0.7)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
            }
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(8)

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(8)
            height: width
            radius: width / 2
            color: root.receivedFrame ? "#45d483" : Qt.darker(root.contentForeground, 1.8)
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.cameraError !== ""
              ? root.cameraError
              : (root.receivedFrame ? "LIVE - frames received" : (root.hasCamera ? "Waiting for video..." : "Camera unavailable"))
            color: root.cameraError !== "" ? "#ff6b6b" : Qt.darker(root.contentForeground, 1.35)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
