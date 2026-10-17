import QtQuick
import QtQuick.Window

Rectangle {
    id: root
    color: "#000000"
    property int stage

    property int hour: new Date().getHours()

    property string timePeriod: {
        if (hour >= 0 && hour < 5)
            return "midnight"
        else if (hour >= 5 && hour < 12)
            return "day"
        else if (hour >= 12 && hour < 17)
            return "afternoon"
        else if (hour >= 17 && hour < 21)
            return "evening"
        else
            return "night"
    }

    property var midnightMessages: [
        "Welcome, Night Owl",
        "Midnight Mode Activated",
        "The stars are still awake with you",
        "Quiet hours, powerful focus",
        "Moonlit session starts now"
    ]

    property var dayMessages: [
        "Welcome to a New Day",
        "Today is your launch window",
        "Fresh light, fresh momentum",
        "Daytime energy is online",
        "A bright start for bold plans"
    ]

    property var afternoonMessages: [
        "Afternoon Momentum Check",
        "Midday grind, keep it smooth",
        "Your progress bar is moving",
        "Power through the afternoon",
        "Strong focus for the second half"
    ]

    property var eveningMessages: [
        "Evening Flow Begins",
        "Sunset hours, steady progress",
        "Golden hour for clean execution",
        "Evening session now live",
        "Close the day with a win"
    ]

    property var nightMessages: [
        "Welcome, Night Owl",
        "Tonight's moon looks beautiful",
        "Night shift, calm and focused",
        "The city sleeps, you create",
        "Deep-night focus mode"
    ]

    property var midnightEvents: [
        "Tonight's moon looks beautiful.",
        "System event: silence and clarity enabled.",
        "Deep work window is now open.",
        "Low noise, high creativity.",
        "This calm hour belongs to you."
    ]

    property var dayEvents: [
        "Today's event: start strong and stay curious.",
        "Morning light is perfect for fresh ideas.",
        "Your daily quest begins now.",
        "Make today meaningful, one step at a time.",
        "A clear day is a great day to build."
    ]

    property var afternoonEvents: [
        "Today's event: keep the momentum alive.",
        "Afternoon focus can change everything.",
        "Progress checkpoint reached — continue forward.",
        "Steady effort, strong results.",
        "Halfway through, still full power."
    ]

    property var eveningEvents: [
        "Today's event: finish with intention.",
        "Sunset is your reminder to end strong.",
        "Wrap up with one more meaningful win.",
        "Evening rhythm, better decisions.",
        "Refine today, prepare tomorrow."
    ]

    property var nightEvents: [
        "Tonight's moon looks beautiful.",
        "Today's event: ideas shine after dark.",
        "Night focus is a different kind of magic.",
        "The quiet night is your creative ally.",
        "Own the night, one calm step at a time."
    ]

    // Lock quote selection at load time using a seeded index
    property int quoteIndex: Math.floor(Math.random() * 5)

    property string greeting: {
        if (timePeriod === "midnight")
            return midnightMessages[quoteIndex]
        else if (timePeriod === "day")
            return dayMessages[quoteIndex]
        else if (timePeriod === "afternoon")
            return afternoonMessages[quoteIndex]
        else if (timePeriod === "evening")
            return eveningMessages[quoteIndex]
        else
            return nightMessages[quoteIndex]
    }

    property string selectedQuote: {
        if (timePeriod === "midnight")
            return midnightEvents[quoteIndex]
        else if (timePeriod === "day")
            return dayEvents[quoteIndex]
        else if (timePeriod === "afternoon")
            return afternoonEvents[quoteIndex]
        else if (timePeriod === "evening")
            return eveningEvents[quoteIndex]
        else
            return nightEvents[quoteIndex]
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

        Rectangle {
            id: imageSource
            width: 800
            height: 600
            color: "transparent"
            anchors.centerIn: parent
            clip: true

            AnimatedImage {
                id: face
                source: "images/arcade.gif"
                anchors.centerIn: parent
                width: 798
                height: 598
                smooth: true
            }
        }

        Image {
            id: busyIndicator
            y: parent.height - 200
            anchors.horizontalCenter: parent.horizontalCenter
            source: "images/loading.svgz"
            sourceSize.height: units.gridUnit * 2
            sourceSize.width: units.gridUnit * 2

            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 1500
                loops: Animation.Infinite
            }
        }

        Column {
            spacing: units.smallSpacing * 2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: units.gridUnit * 2.5

            Text {
                text: root.greeting
                color: "#ffffff"
                font.pixelSize: units.gridUnit * 1.4
                font.bold: true
                opacity: 0.95
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: root.selectedQuote
                color: "#aaaaaa"
                font.pixelSize: units.gridUnit * 1.1
                font.italic: true
                opacity: 0.85
                wrapMode: Text.Wrap
                width: root.width * 0.8
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
        duration: 1000
        easing.type: Easing.InOutQuad
    }
}