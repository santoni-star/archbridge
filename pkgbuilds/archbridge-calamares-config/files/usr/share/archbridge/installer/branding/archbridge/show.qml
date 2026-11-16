import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    Timer {
        interval: 6000
        running: true
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Slide {
        Text {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            color: "#ffffff"
            font.pixelSize: 26
            text: "Installing ArchBridge...\nClean Arch, tuned KDE, Windows programs that just run."
        }
    }

    Slide {
        Text {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            color: "#ffffff"
            font.pixelSize: 26
            text: "Every update takes a snapshot first,\nso you can always roll back."
        }
    }

    Slide {
        Text {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            color: "#ffffff"
            font.pixelSize: 26
            text: "The AI helper is off until you turn it on."
        }
    }
}
