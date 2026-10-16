import QtQuick
import QtQuick.Window

Rectangle {
    id: root
    color: "#0a0c10"
    property int stage

    property int hour: new Date().getHours()

    // Dynamic greeting based on time of day
    property string greeting: {
        if (hour >= 5 && hour < 12)
            return "Good morning"
        else if (hour >= 12 && hour < 17)
            return "Good afternoon"
        else if (hour >= 17 && hour < 21)
            return "Good evening"
        else
            return "Good night"
    }

    property var morningQuotes: [
        "A new day. A new chance to level up.",
        "Wake up. Your future is waiting.",
        "Sunlight means it's time to rise stronger.",
        "Start sharp. Stay unstoppable.",
        "Every morning is a fresh respawn.",
        "Discipline begins before the world wakes.",
        "Today is yours — claim it.",
        "No delays. Begin now.",
        "The early grind builds empires.",
        "Reset. Refocus. Rise."
    ]

    property var afternoonQuotes: [
        "Stay locked in. You're halfway there.",
        "Focus beats talent every time.",
        "Keep pushing. Momentum matters.",
        "No distractions. Just execution.",
        "This is where most people quit. Don't.",
        "Stay consistent. Stay dangerous.",
        "Progress is built right now.",
        "One step more. Then another.",
        "You're in the middle — keep moving.",
        "Pressure creates precision."
    ]

    property var eveningQuotes: [
        "The day isn't over yet.",
        "Finish strong. Always.",
        "Evenings decide winners.",
        "Push a little more before rest.",
        "Consistency beats intensity.",
        "Close the day with progress.",
        "What you do now matters tomorrow.",
        "Stay focused. No wasted hours.",
        "Refine. Improve. Repeat.",
        "End the day better than you started."
    ]

    property var nightQuotes: [
        "Late night, clear mind — build something.",
        "The world is quiet. Make use of it.",
        "Legends don't check the clock.",
        "Silence the noise. Focus on your path.",
        "Night mode: discipline only.",
        "While others sleep, you build.",
        "Dark hours. Bright future.",
        "No shortcuts. Only progress.",
        "Tonight decides tomorrow.",
        "Stay relentless."
    ]

    // Lock quote selection at load time
    property int quoteIndex: Math.floor(Math.random() * 10)

    property string selectedQuote: {
        if (hour >= 5 && hour < 12)
            return morningQuotes[quoteIndex]
        else if (hour >= 12 && hour < 17)
            return afternoonQuotes[quoteIndex]
        else if (hour >= 17 && hour < 21)
            return eveningQuotes[quoteIndex]
        else
            return nightQuotes[quoteIndex]
    }

    onStageChanged: {
        if (stage == 1) {
            introAnimation.running = true;
        } else if (stage == 5) {
            introAnimation.target = busyIndicator;
            introAnimation.from = 1;
            introAnimation.to = 0;
            introAnimation.running = true;
        }
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: 0

        TextMetrics {
            id: units
            text: "M"
            property int gridUnit: boundingRect.height
            property int smallSpacing: Math.max(2, gridUnit / 4)
        }

        Image {
            id: logo
            width: units.gridUnit * 10
            height: units.gridUnit * 10
            source: "images/logo.svg"
            sourceSize.width: units.gridUnit * 10
            sourceSize.height: units.gridUnit * 10
            fillMode: Image.PreserveAspectFit
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -units.gridUnit * 3
            smooth: true
        }

        Image {
            id: busyIndicator
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: logo.bottom
            anchors.topMargin: units.gridUnit * 2
            source: "images/loading-00.svg"
            sourceSize.height: units.gridUnit * 2
            sourceSize.width: units.gridUnit * 2

            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 1200
                loops: Animation.Infinite
            }
        }

        Column {
            spacing: units.smallSpacing * 2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: units.gridUnit * 3

            Text {
                text: root.greeting
                color: "#56b6c2"
                font.pixelSize: units.gridUnit * 1.5
                font.bold: true
                opacity: 0.95
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: root.selectedQuote
                color: "#abb2bf"
                font.pixelSize: units.gridUnit * 1.1
                font.italic: true
                opacity: 0.85
                wrapMode: Text.Wrap
                width: root.width * 0.85
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    OpacityAnimator {
        id: introAnimation
        target: content
        from: 0
        to: 1
        duration: 800
        easing.type: Easing.InOutQuad
    }
}
