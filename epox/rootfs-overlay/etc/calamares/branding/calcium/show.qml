import QtQuick 2.0
import calamares.slideshow 1.0

Presentation
{
    id: presentation

    Timer {
        interval: 30000
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Slide {
        Text {
            anchors.centerIn: parent
            text: qsTr("Calcium OS")
            font.pixelSize: 32
            font.bold: true
            color: "#ffffff"
        }
    }

    Slide {
        Text {
            anchors.centerIn: parent
            text: qsTr("A modern Gentoo-based Linux distribution\nwith GNOME desktop and OpenRC")
            font.pixelSize: 18
            color: "#ffffff"
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Slide {
        Text {
            anchors.centerIn: parent
            text: qsTr("Thank you for choosing Calcium OS!")
            font.pixelSize: 24
            font.bold: true
            color: "#ffffff"
        }
    }
}
