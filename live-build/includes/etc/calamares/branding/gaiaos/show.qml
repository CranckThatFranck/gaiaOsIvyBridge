import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    function nextSlide() {
        presentation.goToNextSlide()
    }

    Slide {
        Image {
            id: mark
            source: "logo.png"
            width: 420
            height: 140
            fillMode: Image.PreserveAspectFit
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 48
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: mark.bottom
            anchors.topMargin: 24
            width: presentation.width * 0.8
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            color: "#E2E8F0"
            font.pixelSize: 18
            text: "Debian 13, KDE Plasma e o hardware Ivy Bridge deste desktop.\nA instalação usa UEFI e GRUB."
        }
    }

    function onActivate() {
        presentation.currentSlide = 0
    }

    function onLeave() {
    }
}
